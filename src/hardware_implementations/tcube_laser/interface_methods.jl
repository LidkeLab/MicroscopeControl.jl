"""
    check_err(err, operation::AbstractString, serialNo::AbstractString)

Throw unless a Kinesis call reported success. The TCube LaserDiode calls used
here return a `Cshort` status where `0` is success and anything else is a
Thorlabs error code; every call site below used to assign that status to an
`err` local and never read it, so a failed open, a failed mode change and a
failed setpoint were all indistinguishable from success.

Never point this at a boolean return ([`KBOOL_RET`](@ref)): those are success
FLAGS where `false` means failure, the opposite sense. See [`check_flag`](@ref).

Not hardware-verified (no TCube on the build machine): the `0 == success`
convention is the documented Kinesis one, not something this repo has observed.
"""
function check_err(err, operation::AbstractString, serialNo::AbstractString)
    err == 0 || error("TCubeLaser $serialNo: $operation failed with Thorlabs error code $err")
    return nothing
end

"""
    check_flag(ok, operation::AbstractString, serialNo::AbstractString)

Throw unless a Kinesis call that returns a C++ `bool` success flag returned
`true`. The counterpart of [`check_err`](@ref) for the opposite convention.
"""
function check_flag(ok, operation::AbstractString, serialNo::AbstractString)
    ok === true || error("TCubeLaser $serialNo: $operation reported failure (returned $(repr(ok)))")
    return nothing
end

"""
    REQUEST_WAIT_S

Seconds to wait between an `LD_Request*` call and the `LD_Get*` that reads its
answer. The Kinesis getters return a value cached by the DLL, and the request
refreshes it asynchronously; 0.1 s is what this driver has always waited.
A `Ref` so the test suite can set it to zero. Not hardware-verified.
"""
const REQUEST_WAIT_S = Ref(0.1)

"""
    POLL_INTERVAL_MS

The Kinesis background polling period `initialize` starts, in ms (20 Hz), so
that [`measured_current`](@ref), [`measured_photocurrent`](@ref) and
[`loop_status`](@ref) are single cache reads, at most this old. A documented
constant rather than a keyword: 20 Hz covers the 1-10 Hz a rig logs at.

`[limitation]` that `LD_StartPolling` refreshes the reading caches at this
period is read from the Kinesis header, not observed on hardware. If it does
not, those getters return stale values; `tcube_get_current` issues its own
request and is the fallback.
"""
const POLL_INTERVAL_MS = 50

"""
    effective_max_current(light::TCubeLaser)

The ceiling `setcurrent!` enforces, in mA: the smallest of the caller's
`max_current`, the controller's `controller_max_current` (skipped while it is
`NaN`, i.e. before `initialize`) and `max_setcurrent`, the full-scale current
of the setpoint DAC.

`max_setcurrent` is in the list because a current above full scale has no legal
setpoint: see [`SETPOINT_PROTOCOL_MAX`](@ref) for why the bound is the
controller's 0-32767 protocol range and not `UInt16` storage. Without it,
`setcurrent!` would carry a request the range check had already passed into a
conversion that cannot express it.
"""
function LightSourceInterface.effective_max_current(light::TCubeLaser)
    limits = filter(!isnan, (light.max_current, light.controller_max_current, light.max_setcurrent))
    isempty(limits) && error("TCubeLaser $(light.serialNo): no usable current ceiling; max_current, controller_max_current and max_setcurrent are all NaN")
    return minimum(limits)
end

"""
    SETPOINT_PROTOCOL_MAX

Largest setpoint the controller accepts. `LD_SetLaserSetPoint` takes a 0-32767
value: it is transported as a `UInt16`, but only that range is a legal
setpoint, so the protocol admits half of what the storage type can hold.

That distinction is the reason `max_setcurrent` has to be one of the ceilings
[`effective_max_current`](@ref) enforces. `UInt16` storage would not have
forced it: at the default 220 mA full scale, 300 mA encodes to 44682 and 400 mA
to 59576, both of which fit a `UInt16` and neither of which is a setpoint this
controller can be given.
"""
const SETPOINT_PROTOCOL_MAX = 32767

"""
    setpoint_current(light::TCubeLaser, code)

Decode a controller setpoint back to a current in mA, the inverse of
[`setpoint_code`](@ref)'s scaling.

One definition, used by every place in this driver that turns a raw controller
word into mA -- the setpoint check in `setpoint_code`, the limit read in
[`record_controller_limit!`](@ref) and the readings in
[`measured_current`](@ref) and [`tcube_get_current`](@ref). `setpoint_code`'s
guarantee is stated *in terms of this function*, so it has to be the same
arithmetic in every one of them and not several copies of the same expression.
"""
setpoint_current(light::TCubeLaser, code) = Float64(code) / light.max_setpoint * light.max_setcurrent

"""
    setpoint_code(light::TCubeLaser, current::Float64)

Encode a drive current in mA as the controller's integer setpoint.

Validates the conversion itself, which the range check cannot:
[`check_current`](@ref) compares a request against ceilings and says nothing
about whether the scale factors that encode it are usable. Requests that passed
the check used to die here in `UInt16(...)` with an `InexactError` --
`max_setcurrent` of `0.0` or `NaN`, a `max_setpoint` outside the protocol
range, a negative `min_current` admitting a negative current. Each now throws
an `ArgumentError` naming the field at fault, still before anything is sent.

# The guarantee

`setpoint_current(light, setpoint_code(light, c)) <= c` for every `c` this
function accepts. That is the whole of it, and it is worth reading narrowly:
the *decoded* current is bounded by the request, by this driver's own
arithmetic. What the controller does with the code -- its DAC, its own rounding,
its calibration -- is not something this repo has observed, so no claim is made
about the current at the diode.

Truncation alone does not deliver that. Rounding was the first thing it ruled
out: at the default scale the 160 mA ceiling rounds to code 23831, which
decodes to 160.00305 mA, so the one request sitting exactly on the enforced
limit would be the one to breach it at the wire. But `floor` is applied to
`current / max_setcurrent * max_setpoint`, and that division and multiplication
can each round *up*: a request one ulp below a code boundary can be carried to
the boundary itself, leaving `floor` nothing to cut. A scan of the predecessor
of every code boundary in the default 0-160 mA range found 1794 such requests,
the first at `prevfloat(9 / 32767 * 220) = 0.06042664876247444`, which encodes
to code 9 and decodes back to 0.060426648762474444 -- above the request. The
excesses are single ulps, not overcurrent; the guarantee was still false.

So the candidate code is corrected *downward* while it decodes above the
request. The comparison is `>` against [`setpoint_current`](@ref) -- the same
decode the guarantee is stated in, not an equivalent-looking expression -- and
the loop terminates because code 0 decodes to 0.0 and `current` is validated
non-negative. In practice it runs at most once.

The cost of the whole rule is an undershoot of approximately one code, about
0.0067 mA at the default scale -- "approximately" because the downward
correction can take a boundary predecessor a hair past one code width. At the
bottom of the range that undershoot is the entire request: see
[`setcurrent!`](@ref).
"""
function setpoint_code(light::TCubeLaser, current::Float64)
    (isfinite(light.max_setcurrent) && light.max_setcurrent > 0) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): max_setcurrent is the setpoint DAC's full-scale current in mA and must be finite and positive, got $(light.max_setcurrent)"))
    (isfinite(light.max_setpoint) && 0 < light.max_setpoint <= SETPOINT_PROTOCOL_MAX) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): max_setpoint must be finite and within (0, $(SETPOINT_PROTOCOL_MAX)], the controller's setpoint range, got $(light.max_setpoint)"))
    (isfinite(current) && current >= 0) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): requested current must be finite and non-negative, got $(current) mA (min_current=$(light.min_current))"))
    code = floor(current / light.max_setcurrent * light.max_setpoint)
    code <= light.max_setpoint || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): $(current) mA encodes to setpoint $(code), above the full scale $(light.max_setpoint); it exceeds max_setcurrent=$(light.max_setcurrent) mA and should have been refused by check_current"))
    # Truncation is not enough: the scaling above can round a request up onto a
    # code boundary before `floor` sees it. Correct downward until the decoded
    # current is at or below the request. See the docstring.
    while code > 0 && setpoint_current(light, code) > current
        code -= 1.0
    end
    return UInt16(code)
end

"""
    check_current(light::TCubeLaser, current::Float64)

Validate a requested drive current in mA, throwing an `ArgumentError` naming
the request and both bounds if it is out of range. Returns `current`.

This is the whole of `setcurrent!`'s safety check, kept as its own function so
it can be exercised without a controller attached. It runs *before* any
setpoint is computed or sent: the code before v0.2.3 logged `@error` and then
carried on to call `LD_SetLaserSetPoint` anyway. What that cost depended on the
request. 500 mA on a 160 mA diode never reached the controller -- it logged,
continued, and then died in the conversion, `UInt16(round(...))` with an
`InexactError`. 200 mA did: over the same 160 mA ceiling, but inside the
setpoint DAC's range, so it converted cleanly and was sent. A log line was the
only thing separating the two.
"""
function check_current(light::TCubeLaser, current::Float64)
    lo = light.min_current
    hi = effective_max_current(light)
    if !(lo <= current <= hi)
        throw(ArgumentError(
            "TCubeLaser $(light.serialNo): requested current $(current) mA is outside the allowed range " *
            "[$(lo), $(hi)] mA (min_current=$(light.min_current), max_current=$(light.max_current), " *
            "controller_max_current=$(light.controller_max_current), max_setcurrent=$(light.max_setcurrent))"))
    end
    return current
end

"""
    record_controller_limit!(light::TCubeLaser, raw)

Scale the controller's raw diode current limit reading to mA and store it in
`light.controller_max_current`, returning the scaled value.

Split out of `initialize` so the property that matters here -- that reading the
controller's limit leaves the caller's `max_current` alone -- is testable
without a controller attached.
"""
function record_controller_limit!(light::TCubeLaser, raw)
    light.controller_max_current = setpoint_current(light, raw)
    return light.controller_max_current
end

# ---------------------------------------------------------------------------
# Closed-loop (ConstantPhotocurrent) arithmetic
# ---------------------------------------------------------------------------

"""
    TLD001_TIA_RANGES

The TLD001's photodiode amplifier ranges, full scale in A: 10 µA, 100 µA, 1 mA
and 10 mA. Selected only by the rear-panel DIP switches; software can read the
range (status bits `0x10`-`0x80`) but not set it. From the TLD001 manual and
the Kinesis header; not hardware-verified.
"""
const TLD001_TIA_RANGES = (10e-6, 100e-6, 1e-3, 10e-3)

"""
    DIGPOT_MIN_POS, DIGPOT_MAX_POS, DIGPOT_STEP_ESTIMATE_mA

The TLD001's max-current potentiometer: positions 20..255. The Kinesis header
gives its scale as `position * 220 / 255` mA, and **the controller does not
follow it**: on the 642 nm rig's TLD001 (64849775, 2026-09-28) position 204 gave
a limit of 160.74 mA and 194 gave 152.43 mA -- about 0.83 mA per step, where the
header's scale says 176 and 167. So no clamp value is ever computed from a
position. [`program_clamp!`](@ref) reads the controller's own limit after each
setting. The header's step, 220/255 ≈ 0.863 mA, is kept only as an estimate to
choose the next position from: it is larger than the observed step, so
estimated moves fall short and the search approaches the ceiling from one side.
"""
const DIGPOT_MIN_POS = 20
const DIGPOT_MAX_POS = 255
const DIGPOT_STEP_ESTIMATE_mA = 220.0 / 255

"""
    DIGPOT_MIN_mA

The lowest clamp the header's scale allows, `20 * 220 / 255` = 17.25 mA. A
diode whose ceiling is below it cannot be clamped, so it cannot be built in
power mode. (In adjust mode the rig's controller reported 16.74 mA at position
20, so this is a conservative floor.)
"""
const DIGPOT_MIN_mA = DIGPOT_MIN_POS * 220.0 / 255

"""
    CLAMP_WAIT_S

Seconds to wait around each step of a potentiometer change. A `Ref` so the test
suite can set it to zero. On the rig's TLD001, leaving adjust mode immediately
after `LD_SetMaxCurrentDigPot` left the limit unchanged; with 0.5 s between the
steps it latched.
"""
const CLAMP_WAIT_S = Ref(0.5)

"Fresh read of the controller's diode current limit, in mA."
function read_limit_mA(light::TCubeLaser)
    serialNo = light.serialNo
    check_err(LD_RequestLaserDiodeMaxCurrentLimit(serialNo), "LD_RequestLaserDiodeMaxCurrentLimit", serialNo)
    sleep(REQUEST_WAIT_S[])
    return setpoint_current(light, LD_GetLaserDiodeMaxCurrentLimit(serialNo))
end

"Fresh read of the potentiometer position."
function read_digpot(serialNo::AbstractString)
    check_err(LD_RequestMaxCurrentDigPot(serialNo), "LD_RequestMaxCurrentDigPot", serialNo)
    sleep(REQUEST_WAIT_S[])
    return Int(LD_GetMaxCurrentDigPot(serialNo))
end

"""
    set_digpot!(light::TCubeLaser, position)

Set the potentiometer and return the controller's resulting limit in mA:
`LD_EnableMaxCurrentAdjust(true, false)`, wait, `LD_SetMaxCurrentDigPot`, wait,
confirm the position reads back, `LD_EnableMaxCurrentAdjust(false, false)`,
wait, read the limit. Adjust mode is always left, even on failure. The diode
flag is always `false`. The output must already be off: entering adjust mode
drops the limit to its minimum until the position is set.
"""
function set_digpot!(light::TCubeLaser, position::Int)
    serialNo = light.serialNo
    check_err(LD_EnableMaxCurrentAdjust(serialNo, true, false), "LD_EnableMaxCurrentAdjust", serialNo)
    try
        sleep(CLAMP_WAIT_S[])
        check_err(LD_SetMaxCurrentDigPot(serialNo, UInt16(position)), "LD_SetMaxCurrentDigPot", serialNo)
        sleep(CLAMP_WAIT_S[])
        readback = read_digpot(serialNo)
        readback == position || error(
            "TCubeLaser $serialNo: set the max-current potentiometer to $(position) but it reads back as $(readback)")
    finally
        check_err(LD_EnableMaxCurrentAdjust(serialNo, false, false), "LD_EnableMaxCurrentAdjust", serialNo)
    end
    sleep(CLAMP_WAIT_S[])
    return read_limit_mA(light)
end

"""
    program_clamp!(light::TCubeLaser{ConstantPhotocurrent})

Leave the controller's diode current limit at the highest potentiometer position
whose limit, **as the controller reports it**, does not exceed
`light.max_current`, and return that limit in mA.

The search starts from the current position. It moves by the header's step
estimate ([`DIGPOT_STEP_ESTIMATE_mA`](@ref)), which is larger than the real step
on the rig's controller, so moves fall short and approach the ceiling from one
side. It never needs more than a few settings, and none if the present position
already qualifies. Throws if even the lowest position is above the ceiling, or if
it cannot settle. Output must be off (it is, in `initialize`).
"""
function program_clamp!(light::TCubeLaser{ConstantPhotocurrent})
    ceiling = light.max_current
    pos = read_digpot(light.serialNo)
    limit = read_limit_mA(light)
    below = nothing     # (position, limit) of the best setting found at or under the ceiling
    above = nothing     # lowest position found over the ceiling
    # Settle on the best position found under the ceiling, re-setting it if the
    # search last left the potentiometer somewhere else.
    function settle()
        bpos, blimit = below
        if bpos != pos
            blimit = set_digpot!(light, bpos)
            blimit <= ceiling || error(
                "TCubeLaser $(light.serialNo): the max-current limit read $(blimit) mA on re-setting position $(bpos), above max_current = $(ceiling) mA")
        end
        return blimit
    end
    for _ in 1:16
        if limit <= ceiling
            below = (pos, limit)
            # Up only by whole estimated steps; none fits -> this is it.
            steps = floor(Int, (ceiling - limit) / DIGPOT_STEP_ESTIMATE_mA)
            next = min(pos + steps, DIGPOT_MAX_POS)
            above !== nothing && (next = min(next, above - 1))
            next <= pos && return settle()
        else
            above = above === nothing ? pos : min(above, pos)
            pos == DIGPOT_MIN_POS && error(
                "TCubeLaser $(light.serialNo): even the lowest potentiometer position gives a limit of $(limit) mA, above max_current = $(ceiling) mA")
            next = max(pos - max(1, ceil(Int, (limit - ceiling) / DIGPOT_STEP_ESTIMATE_mA)), DIGPOT_MIN_POS)
            below !== nothing && next <= below[1] && return settle()
        end
        pos = next
        limit = set_digpot!(light, pos)
    end
    error("TCubeLaser $(light.serialNo): the max-current clamp did not settle under max_current = $(ceiling) mA")
end

"""
    photocurrent_from_code(light::TCubeLaser{ConstantPhotocurrent}, code)

Decode a closed-loop setpoint or photocurrent reading to amps: `0..max_setpoint`
spans `0..pd.tia_range`. The one definition [`setoutputpower!`](@ref),
[`measured_photocurrent`](@ref) and [`photocurrent_code`](@ref) share.
"""
photocurrent_from_code(light::TCubeLaser, code, tia_range::Float64) =
    Float64(code) / light.max_setpoint * tia_range

"""
    photocurrent_code(light::TCubeLaser{ConstantPhotocurrent}, photocurrent_A)

Encode a photocurrent in A as the closed-loop setpoint, with the same guarantee
as [`setpoint_code`](@ref): the decoded photocurrent never exceeds the request.
Throws, naming the DIP switch, if the request is above the amplifier's full
scale: no software setting can reach it.
"""
function photocurrent_code(light::TCubeLaser{ConstantPhotocurrent}, photocurrent_A::Float64)
    range = light.pd.tia_range
    (isfinite(photocurrent_A) && photocurrent_A >= 0) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): photocurrent must be finite and non-negative, got $(photocurrent_A) A"))
    code = floor(photocurrent_A / range * light.max_setpoint)
    code <= light.max_setpoint || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): $(photocurrent_A) A of photocurrent is above the amplifier's full scale of $(range) A. " *
        "No software setting can reach it: select a less sensitive range on the rear-panel DIP switch and state it in tia_range."))
    while code > 0 && photocurrent_from_code(light, code, range) > photocurrent_A
        code -= 1.0
    end
    return UInt16(code)
end

"""
    check_power(light::TCubeLaser{ConstantPhotocurrent}, power_mW::Float64)

Validate a requested output power against `properties.min_power..max_power`,
throwing an `ArgumentError` naming the request and both bounds. Returns
`power_mW`. The power-mode counterpart of [`check_current`](@ref).
"""
function check_power(light::TCubeLaser{ConstantPhotocurrent}, power_mW::Float64)
    lo, hi = light.properties.min_power, light.properties.max_power
    (isfinite(power_mW) && lo <= power_mW <= hi) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): requested output power $(power_mW) mW is outside the allowed range " *
        "[$(lo), $(hi)] mW at the laser output (properties.min_power, properties.max_power)"))
    return power_mW
end

# ---------------------------------------------------------------------------
# Verified reads, for the one-off checks in `initialize` and the setters
# ---------------------------------------------------------------------------

"Request, wait, then read the status word: a fresh read, not the polled cache."
function read_status_fresh(serialNo::AbstractString)
    check_err(LD_RequestStatusBits(serialNo), "LD_RequestStatusBits", serialNo)
    sleep(REQUEST_WAIT_S[])
    return UInt32(LD_GetStatusBits(serialNo))
end

"""
# The setpoint only takes while the output is ON

Hardware-verified on the 642 nm rig's TLD001 (64849775, 2026-09-28), and the
single most important fact about this controller:

- `LD_SetLaserSetPoint` sent while the output is **disabled** is **ignored**.
  On the next `LD_EnableOutput` the controller runs on whatever setpoint it had
  stored -- on the rig, a word above full scale, so the diode went straight to
  its current limit (~160 mA, 85-88 mW measured) whatever had been "set".
- Sent while the output is **enabled**, it takes within about one poll: 70 mA
  commanded, 70.0 mA on the front display, no limit flag.
- `LD_GetLaserSetPoint` reports the controller's setpoint only while the output
  is enabled (it read back 10424 for 10425 sent, one code low). With the output
  off it returns a stale word unrelated to anything sent.

So this driver never sends a setpoint with the output off. `setcurrent!` and
`setoutputpower!` record the request and, if the output is on, send and confirm
it; if it is off, the request is applied by `light_on` immediately after it
enables the output. `light_off` zeroes the setpoint BEFORE disabling, so the
controller's stored setpoint is 0 and the next enable starts dark rather than
at a stale value.

`[limitation]` between `LD_EnableOutput` and the setpoint that follows it
(a few ms, one USB round trip) the controller runs on its stored setpoint. After
a `light_off` from this driver that is 0; on a controller last left by other
software it may be anything up to full scale, bounded only by the current limit
(the max-current clamp in power mode).
"""
const SETPOINT_NEEDS_OUTPUT = true

"""
    SETPOINT_CONFIRM_TIMEOUT_S, SETPOINT_READBACK_TOLERANCE

How long [`send_setpoint`](@ref) waits for the polled setpoint to show the code
it sent, in seconds (a `Ref` so the test suite can shorten it), and how many
codes the read-back may differ by: the rig's TLD001 reported 10424 for 10425.
"""
const SETPOINT_CONFIRM_TIMEOUT_S = Ref(1.0)
const SETPOINT_READBACK_TOLERANCE = 2

"Whether the controller reports its output enabled (polled status word)."
output_enabled(serialNo::AbstractString) = UInt32(LD_GetStatusBits(serialNo)) & STATUS_BITS.output_enabled != 0

"""
    send_setpoint(light::TCubeLaser, code::UInt16)

Send a setpoint **with the output on** and wait for the controller to report it
back within [`SETPOINT_READBACK_TOLERANCE`](@ref) codes, throwing if it does not.
Only call it with the output enabled: see [`SETPOINT_NEEDS_OUTPUT`](@ref).
Nothing is recorded by this function.
"""
function send_setpoint(light::TCubeLaser, code::UInt16)
    serialNo = light.serialNo
    check_err(LD_SetLaserSetPoint(serialNo, code), "LD_SetLaserSetPoint", serialNo)
    close_enough(r) = abs(Int(r) - Int(code)) <= SETPOINT_READBACK_TOLERANCE
    deadline = time() + SETPOINT_CONFIRM_TIMEOUT_S[]
    readback = LD_GetLaserSetPoint(serialNo)
    while !close_enough(readback) && time() < deadline
        sleep(0.02)
        readback = LD_GetLaserSetPoint(serialNo)
    end
    close_enough(readback) || error(
        "TCubeLaser $serialNo: sent setpoint $(code) but the controller reports $(readback) after $(SETPOINT_CONFIRM_TIMEOUT_S[]) s")
    return nothing
end

"""
    RAMP_STEP_mW, RAMP_STEP_S

An optional ramp for upward closed-loop setpoint steps, **off by default**
(`RAMP_STEP_mW[] = Inf`: every setpoint is a single write, ~10 ms). Set
`RAMP_STEP_mW[]` to a finite value in mW and [`send_setpoint_ramped`](@ref)
walks any larger upward step in increments of that size, `RAMP_STEP_S[]`
apart. Downward steps and open loop are always sent directly.

Why it exists, for the record (642 nm rig's TLD001, 2026-09-28/29): on one
night a setpoint jumped from 0 to 10 mW locked the loop at ~90 mA / ~21 mW
whatever the request, 3 times out of 3, while the same target reached in steps
settled at 78 mA / 9.3 mW, as the Kinesis application does. Later the same
night, after a Kinesis CONST P session, the jump worked 4 times out of 4
(9.30-9.31 mW). Ramped runs never failed (10 of 10, 10-70 mW). The cause is
not known. The jump is the default because it is the fastest and was reliable
when last tested; if the lock recurs (the symptom: ~90 mA and ~21 mW whatever
is requested) set `RAMP_STEP_mW[] = 3.0` and `RAMP_STEP_S[] = 0.01`, which
were verified on the rig: 1 mW steps worked at 2 s, 50, 20, 10 and 5 ms
spacing; below ~10 ms the USB round trip per write (~15 ms) sets the pace;
3 mW steps at 10 ms reached 40 mW in 0.22 s (38.74 mW) and 70 mW in 0.38 s
(68.59 mW).
"""
const RAMP_STEP_mW = Ref(Inf)

"See [`RAMP_STEP_mW`](@ref)."
const RAMP_STEP_S = Ref(0.01)

"""
    send_setpoint_ramped(light::TCubeLaser, code::UInt16)

Send a setpoint with the output on. In `ConstantPhotocurrent` mode an upward
step larger than [`RAMP_STEP_mW`](@ref) is walked up from the setpoint the
controller currently holds, one step every `RAMP_STEP_S`; the final code is
confirmed by [`send_setpoint`](@ref).
"""
send_setpoint_ramped(light::TCubeLaser{ConstantCurrent}, code::UInt16) = send_setpoint(light, code)
function send_setpoint_ramped(light::TCubeLaser{ConstantPhotocurrent}, code::UInt16)
    serialNo, pd = light.serialNo, light.pd
    isfinite(RAMP_STEP_mW[]) || return send_setpoint(light, code)   # ramp off: one write
    start = Int(LD_GetLaserSetPoint(serialNo))
    step = max(1, round(Int, RAMP_STEP_mW[] / 1000 / pd.wa_calibration / pd.tia_range * light.max_setpoint))
    if 0 <= start && Int(code) - start > step
        for c in (start + step):step:(Int(code) - 1)
            check_err(LD_SetLaserSetPoint(serialNo, UInt16(c)), "LD_SetLaserSetPoint", serialNo)
            sleep(RAMP_STEP_S[])
        end
    end
    send_setpoint(light, code)
end

"""
    intended_code(light::TCubeLaser)

The setpoint the driver's recorded request asks for: `setpoint_code(drive_current)`
in `ConstantCurrent` mode, `photocurrent_code(output_power_requested)` in
`ConstantPhotocurrent` mode, and 0 when nothing has been requested. What
`light_on` sends right after enabling the output.
"""
function intended_code(light::TCubeLaser{ConstantCurrent})
    isnan(light.drive_current) && return UInt16(0)
    check_current(light, light.drive_current) # the ceiling may have dropped since setcurrent!
    return setpoint_code(light, light.drive_current)
end
intended_code(light::TCubeLaser{ConstantPhotocurrent}) =
    isnan(light.pd.output_power_requested) ? UInt16(0) :
    photocurrent_code(light, light.pd.output_power_requested / 1000 / light.pd.wa_calibration)

"Whether a setpoint has been requested since construction: what `light_on` sends if not is 0."
has_request(light::TCubeLaser{ConstantCurrent}) = !isnan(light.drive_current)
has_request(light::TCubeLaser{ConstantPhotocurrent}) = !isnan(light.pd.output_power_requested)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

"""
    initialize(light::TCubeLaser)

Open the controller, start background polling ([`POLL_INTERVAL_MS`](@ref)),
put it in the laser's [`RegulationMode`](@ref), and record the controller's own
diode current limit in `light.controller_max_current`. It never enables the
output. Polling starts first because the setpoint read-back that every verified
write depends on only refreshes through it (see
[`SETPOINT_CONFIRM_TIMEOUT_S`](@ref)).

`ConstantCurrent`: `LD_SetOpenLoopMode`, then the limit read.

`ConstantPhotocurrent` -- the closed-loop entry sequence. Every step is a
refusal that cannot be retrofitted after a diode is damaged, so none may be
simplified away:

1. Read the status bits. Require the key switch (`0x2`) and the interlock
   (`0x8`); throw naming which is missing.
2. Decode the photodiode amplifier range from `0x10`-`0x80`: exactly one bit, or
   throw; and throw if it disagrees with `pd.tia_range`, naming both and the
   rear-panel switch. A range moved between sessions is a silent factor-of-ten
   error in every commanded power.
3. Disable the output. (The setpoint is not zeroed here: the controller
   ignores setpoints while the output is off, see
   [`SETPOINT_NEEDS_OUTPUT`](@ref). `light_on` sends the intended photocurrent
   setpoint immediately after enabling, and the clamp bounds the moment in
   between.)
4. Program the clamp, **the only real protection in power mode**, because the
   loop raises current by itself to hold its setpoint (and a blocked photodiode
   drives it straight to the clamp): [`program_clamp!`](@ref) leaves the
   max-current potentiometer at the highest position whose limit, as the
   controller itself reports it after leaving adjust mode, is `<= max_current`.
   `pd.max_current_clamp` records that reported limit, never a request or a
   value computed from a position (the header's position scale is wrong on the
   rig's controller; see [`DIGPOT_STEP_ESTIMATE_mA`](@ref)).
5. `LD_SetClosedLoopMode`, then re-read the bits and require `0x4`.
6. `LD_SetWACalibFactor(pd.wa_calibration)` and read it back within `Cfloat`
   tolerance, so the front panel and this driver display the same number. The
   factor scales the controller's display only; the driver does its own
   conversion.

If any step after `LD_Open` fails, the handle is closed before the error
propagates -- a half-open controller refuses the next `LD_Open` and so blocks
the retry -- and the original error is the one raised. A power-mode failure
after step 3 leaves the output off.

It deliberately does **not** touch `light.max_current`: that field is the
caller's ceiling for this diode, and overwriting it with the controller's
(typically 160-220 mA) limit silently widened the range `setcurrent!` validates
against, so a rig that asked for an 80 mA ceiling got the controller's instead.

Hardware-verified on the 642 nm rig's TLD001 (64849775, 2026-09-28), output
off: polling refreshes the setpoint cache; a plain potentiometer set is ignored
and adjust mode is required, with a pause before leaving it; the limit the
controller reports is the truth, not the header's scale; entering closed loop
sets status bit `0x4`; the W/A factor reads back. `[limitation]` the second flag
of `LD_EnableMaxCurrentAdjust` (always passed `false`) is not verified.
"""
function initialize(light::TCubeLaser)
    serialNo = light.serialNo
    check_err(TLI_BuildDeviceList(), "TLI_BuildDeviceList", serialNo)
    numdev = TLI_GetDeviceListSize()

    check_err(LD_Open(serialNo), "LD_Open", serialNo)
    try
        # A success FLAG, not a status code: `false` is the failure.
        check_flag(LD_StartPolling(serialNo, POLL_INTERVAL_MS), "LD_StartPolling", serialNo)
        sleep(REQUEST_WAIT_S[])
        enter_mode!(regulation_mode(light), light)
        check_err(LD_RequestReadings(serialNo), "LD_RequestReadings", serialNo)
        # The diode current limit has its OWN request in the Kinesis API, and
        # `LD_RequestReadings` does not stand in for it. Reading the limit
        # after only the generic request can hand back a stale or never-
        # populated cache -- and this value feeds `effective_max_current`, so a
        # stale one widens or narrows the ceiling `setcurrent!` enforces. Not
        # hardware-verified: reported by the 642 nm rig from the Kinesis header
        # while building its probe, which will measure whether the two differ.
        check_err(LD_RequestLaserDiodeMaxCurrentLimit(serialNo),
                  "LD_RequestLaserDiodeMaxCurrentLimit", serialNo)
        sleep(REQUEST_WAIT_S[])
        out = LD_GetLaserDiodeMaxCurrentLimit(serialNo)
        record_controller_limit!(light, out)
    catch
        # The open succeeded, so this handle is ours to close; a controller
        # left open refuses the next `LD_Open` and so blocks the retry. The
        # close is reported but never rethrown: the failure that stopped
        # initialization is the one the caller needs.
        try
            LD_StopPolling(serialNo)
            LD_Close(serialNo)
        catch closeerr
            @error "TCubeLaser $serialNo: LD_Close failed while cleaning up a failed initialize" exception = closeerr
        end
        rethrow()
    end

    @info "Laser initialized" serialNo devices = numdev mode = nameof(typeof(regulation_mode(light))) controller_max_current = "$(light.controller_max_current) mA" enforced_max_current = "$(effective_max_current(light)) mA"
    return nothing
end

enter_mode!(::ConstantCurrent, light::TCubeLaser) =
    check_err(LD_SetOpenLoopMode(light.serialNo), "LD_SetOpenLoopMode", light.serialNo)

function enter_mode!(::ConstantPhotocurrent, light::TCubeLaser)
    serialNo, pd = light.serialNo, light.pd
    name = "TCubeLaser $serialNo"

    # 1. key switch and interlock
    bits = read_status_fresh(serialNo)
    missing_bits = [label for (label, bit) in (("key switch (0x2)", STATUS_BITS.key), ("interlock (0x8)", STATUS_BITS.interlock))
                    if bits & bit == 0]
    isempty(missing_bits) || error("$name: refusing closed loop: $(join(missing_bits, " and ")) not set (status 0x$(string(bits; base=16)))")

    # 2. the amplifier range the controller reports must be the one stated
    reported = LightSourceInterface.tia_range_from_word(bits)
    isnan(reported) && error("$name: refusing closed loop: the status word reports no single photodiode range (status 0x$(string(bits; base=16)))")
    isapprox(reported, pd.tia_range; rtol=1e-9) || error(
        "$name: refusing closed loop: the controller's photodiode range is $(reported) A but tia_range states $(pd.tia_range) A. " *
        "Check the rear-panel DIP switch; the calibration is only valid on the range it was measured on.")

    # 3. output off. The setpoint cannot be zeroed here: the controller ignores
    # setpoints with the output off (SETPOINT_NEEDS_OUTPUT); light_on sends the
    # real one right after enabling.
    check_err(LD_DisableOutput(serialNo), "LD_DisableOutput", serialNo)
    light.properties.is_on = false

    # 4. the clamp, as the controller itself reports it
    pd.max_current_clamp = program_clamp!(light)

    # 5. closed loop, verified
    check_err(LD_SetClosedLoopMode(serialNo), "LD_SetClosedLoopMode", serialNo)
    read_status_fresh(serialNo) & STATUS_BITS.closed_loop != 0 ||
        error("$name: LD_SetClosedLoopMode returned success but the status word does not report closed loop (0x4)")

    # 6. the display calibration, verified
    check_err(LD_SetWACalibFactor(serialNo, Cfloat(pd.wa_calibration)), "LD_SetWACalibFactor", serialNo)
    check_err(LD_RequestWACalibFactor(serialNo), "LD_RequestWACalibFactor", serialNo)
    sleep(REQUEST_WAIT_S[])
    wa = Float64(LD_GetWACalibFactor(serialNo))
    isapprox(wa, pd.wa_calibration; rtol=1e-6) || error(
        "$name: set the W/A calibration factor to $(pd.wa_calibration) but the controller reports $(wa)")
    return nothing
end

"""
    light_on(light::TCubeLaser)

Enable the controller's output, then immediately send the setpoint the driver's
recorded request asks for ([`intended_code`](@ref)) and confirm it, then record
`properties.is_on`. The setpoint has to follow the enable: the controller
ignores setpoints while its output is off ([`SETPOINT_NEEDS_OUTPUT`](@ref)).
Called while the output is already on, this re-sends the recorded request,
replacing any lower value set from Kinesis or the front panel. If nothing has
been requested yet, setpoint 0 is sent, with a warning. In `ConstantCurrent`
mode `drive_current` is checked against the current ceiling before the enable,
so nothing is sent if that throws.

If the setpoint cannot be sent or confirmed after the enable, the output is
disabled again and the original error rethrown. `properties.is_on` is then what
the cleanup left: `false` if the disable succeeded, `true` if it failed too
(both failures are logged), so a failed `light_on` never records a lit diode as
off.

`[limitation]` Between the enable and the setpoint the controller runs on its
stored setpoint, bounded in hardware only by its current-limit potentiometer;
see [`TCubeLaser`](@ref).

A `ConstantPhotocurrent` laser refuses until `initialize` has programmed and
verified its clamp (`pd.max_current_clamp` is not `NaN`).
"""
function LightSourceInterface.light_on(light::TCubeLaser)
    require_clamp(regulation_mode(light), light, "light_on")
    serialNo = light.serialNo
    has_request(light) || @warn "TCubeLaser $(serialNo): light_on before any setpoint was requested; sending setpoint 0, since the controller's stored setpoint cannot be trusted"
    code = intended_code(light)
    check_err(LD_EnableOutput(serialNo), "LD_EnableOutput", serialNo)
    try
        send_setpoint_ramped(light, code)
    catch
        disabled, offerr = false, nothing
        try
            status = LD_DisableOutput(serialNo)
            disabled = status == 0
            disabled || (offerr = "status $status")
        catch err
            offerr = err
        end
        if disabled
            light.properties.is_on = false
            @error "TCubeLaser $(serialNo): setpoint after enable failed; output disabled"
        else
            light.properties.is_on = true
            @error "TCubeLaser $(serialNo): setpoint after enable failed and the disable failed ($offerr); the output may still be ON at the controller's stored setpoint"
        end
        rethrow()
    end
    light.properties.is_on = true
    println("$(light.laser_color)" * "_laser is on")
    return nothing
end

require_clamp(::ConstantCurrent, light::TCubeLaser, op) = nothing
function require_clamp(::ConstantPhotocurrent, light::TCubeLaser, op)
    isnan(light.pd.max_current_clamp) && error(
        "TCubeLaser $(light.serialNo): $op refused: the max-current clamp has not been programmed and verified. " *
        "Call initialize first; it is the only real protection in closed loop.")
    return nothing
end

"""
    setcurrent!(light::TCubeLaser{ConstantCurrent}, current::Float64)

Set the diode drive current, in **mA**.

Validates through [`check_current`](@ref), so an out-of-range request throws
before anything reaches the controller, and encodes through
[`setpoint_code`](@ref), whose guarantee is that the *decoded* current never
exceeds the requested one. With the output **on**, the setpoint is sent and
confirmed from the controller's read-back. With the output **off**, it is
recorded and `light_on` applies it right after enabling -- the controller would
ignore it now ([`SETPOINT_NEEDS_OUTPUT`](@ref)).

# The bottom of the range commands nothing

Because the encoding only ever rounds down, a positive request smaller than one
code encodes to code `0`: at the default scale that is any request below
`220 / 32767 ≈ 0.006714` mA, so a **zero current setpoint** is sent. That is not
the same as turning the laser off: this path does not disable the output and
does not touch `properties.is_on`. Use [`light_off`](@ref) to stop emission.
Rounding such a request up would command more current than was asked for, which
is the rule this driver will not break -- but `drive_current` records the
**requested** current, not the zero that was commanded.

On success, `light.drive_current` holds the accepted current, in mA.
"""
function LightSourceInterface.setcurrent!(light::TCubeLaser{ConstantCurrent}, current::Float64)
    check_current(light, current)
    code = setpoint_code(light, current)
    on = output_enabled(light.serialNo)
    on && send_setpoint(light, code)
    light.drive_current = current
    println("Laser current set to $current mA", on ? "" : " (output off: applied at light_on)")
    return nothing
end

"""
    setoutputpower!(light::TCubeLaser{ConstantPhotocurrent}, power_mW::Float64)

Command the optical power at the laser output, in mW -- the plane where
`pd.wa_calibration` was measured. Not the power at the sample.

1. Refuse unless `initialize` programmed the clamp.
2. [`check_power`](@ref) against `properties.min_power..max_power`.
3. Refuse from the (polled) status word: unless it reports closed loop; if the
   photodiode amplifier is over range; or if it is under range while the output
   is on. An under-range flag with the output off is expected and ignored.
4. Convert: photocurrent `= power_mW / 1000 / wa_calibration` A, encoded by
   [`photocurrent_code`](@ref), rounding DOWN; above full scale it throws
   naming the DIP switch.
5. With the output on, send and confirm the setpoint; with it off, leave it for
   `light_on` ([`SETPOINT_NEEDS_OUTPUT`](@ref)).
6. Record `pd.output_power_requested` and the DECODED `pd.photocurrent_requested`.

It never touches `drive_current`: the loop owns the current. Whether the light
at the output matches is a question for a power meter; see
[`indicated_output_power`](@ref) and [`loop_status`](@ref).
"""
function LightSourceInterface.setoutputpower!(light::TCubeLaser{ConstantPhotocurrent}, power_mW::Float64)
    require_clamp(ConstantPhotocurrent(), light, "setoutputpower!")
    check_power(light, power_mW)
    pd, serialNo = light.pd, light.serialNo
    bits = UInt32(LD_GetStatusBits(serialNo))
    on = bits & STATUS_BITS.output_enabled != 0
    bits & STATUS_BITS.closed_loop != 0 || error(
        "TCubeLaser $serialNo: setoutputpower! refused: the controller is not in closed loop (status 0x$(string(bits; base=16))); " *
        "was the mode changed on the front panel? Call initialize again.")
    (bits & STATUS_BITS.tia_over != 0 || (on && Int(LD_GetPhotoCurrentReading(serialNo)) == PHOTOCURRENT_OVER_RANGE)) && error(
        "TCubeLaser $serialNo: setoutputpower! refused: the photodiode amplifier reports OVER range, so the loop's feedback is invalid")
    # UNDER range means the photocurrent is small for the selected range, not
    # that it is invalid: on the 642 nm rig the flag was set at 1 mW (4.5 µA on
    # the 1 mA range, 2026-09-29) while the loop regulated correctly. Warn only.
    (bits & STATUS_BITS.tia_under != 0 && on) && @warn(
        "TCubeLaser $serialNo: the photodiode amplifier reports UNDER range with the output on; the photocurrent is small for the selected range and its resolution is reduced")
    code = photocurrent_code(light, power_mW / 1000 / pd.wa_calibration)
    on && send_setpoint_ramped(light, code)
    pd.output_power_requested = power_mW
    pd.photocurrent_requested = photocurrent_from_code(light, code, pd.tia_range)
    println("Laser output power set to $power_mW mW (photocurrent setpoint $(pd.photocurrent_requested) A)",
            on ? "" : " (output off: applied at light_on)")
    return nothing
end

"""
    zero_then_disable(light::TCubeLaser)

Send setpoint 0, then disable the output, then record `properties.is_on =
false`. The controller keeps its setpoint across a disable and ignores
setpoints while its output is off, so the zero has to come first: the next
enable then starts dark rather than on a stale value. The zero is one write
([`zero_setpoint`](@ref)) with no status read and no read-back wait: commands
to the controller are handled in order, so it lands before the disable. A
failed zero is logged, before the disable, and never prevents it; a failed
disable throws and leaves `properties.is_on` unchanged. The driver's recorded
request is kept, and `light_on` re-applies it.
"""
function zero_then_disable(light::TCubeLaser)
    serialNo = light.serialNo
    zeroed = zero_setpoint(light)
    isnothing(zeroed) || @error "TCubeLaser $serialNo: zeroing the setpoint before disable failed ($zeroed); the controller's stored setpoint was not cleared"
    check_err(LD_DisableOutput(serialNo), "LD_DisableOutput", serialNo)
    light.properties.is_on = false
    return nothing
end

"""
    zero_setpoint(light::TCubeLaser)

Send setpoint 0 while the output is still on, so the controller does not keep
the last current for its next enable. Never throws: returns `nothing` on
success, otherwise the failure (a status code or an exception) for the caller
to report.
"""
function zero_setpoint(light::TCubeLaser)
    try
        status = LD_SetLaserSetPoint(light.serialNo, UInt16(0))
        return status == 0 ? nothing : "status $status"
    catch err
        return err
    end
end

"""
    light_off(light::TCubeLaser)

Zero the setpoint while the output is still on, then disable the output, then
record it ([`zero_then_disable`](@ref)). A failed zero is logged and does not
throw, since the output is still turned off; a failed disable throws and leaves
`properties.is_on` unchanged. The recorded request (`drive_current`, or
`pd.output_power_requested`) is kept, so `light_on` returns to it.
"""
function LightSourceInterface.light_off(light::TCubeLaser)
    zero_then_disable(light)
    println("$(light.laser_color)" * "_laser is off")
    return nothing
end

"""
    shutdown(light::TCubeLaser)

Zero the setpoint and disable the output ([`zero_then_disable`](@ref)), stop
polling and close the connection. A failed zero is logged; a failed disable
throws, but the connection is closed either way: leaving the Kinesis handle open
would also block the reconnection a caller needs in order to retry the disable.
"""
function shutdown(light::TCubeLaser)
    serialNo = light.serialNo
    try
        zero_then_disable(light)
    finally
        try
            LD_StopPolling(serialNo) # returns Cvoid: no status to check
        catch stoperr
            @error "TCubeLaser $serialNo: LD_StopPolling failed during shutdown" exception = stoperr
        end
        LD_Close(serialNo) # returns Cvoid: no status to check
    end
    println("$(light.laser_color)" * "_laser is shutdown")
    return nothing
end

# ---------------------------------------------------------------------------
# Readbacks
# ---------------------------------------------------------------------------

"""
    measured_current(light::TCubeLaser)

The diode drive current the controller reports, in mA: a polled cache read (see
[`POLL_INTERVAL_MS`](@ref)), decoded by [`setpoint_current`](@ref). The reading
is signed; a raw value outside ±32767 is a protocol error and throws.
"""
function LightSourceInterface.measured_current(light::TCubeLaser)
    raw = Int(LD_GetLaserDiodeCurrentReading(light.serialNo))
    abs(raw) <= SETPOINT_PROTOCOL_MAX || error(
        "TCubeLaser $(light.serialNo): diode current reading $(raw) is outside the protocol's ±$(SETPOINT_PROTOCOL_MAX)")
    return setpoint_current(light, raw)
end

"""
    measured_photocurrent(light::TCubeLaser)

The monitor photodiode current the controller reports, in A: a polled cache
read, scaled over the amplifier range -- `pd.tia_range` in `ConstantPhotocurrent`
mode, and in `ConstantCurrent` mode the range the status word reports (`NaN`
if it reports none). The reading is signed (a small negative offset at idle); a
raw value outside ±32767 is a protocol error and throws.

Available in both modes. In open loop it is what a W/A calibration is measured
against; see `CALIBRATION.md`.
"""
function LightSourceInterface.measured_photocurrent(light::TCubeLaser)
    raw = Int(LD_GetPhotoCurrentReading(light.serialNo))
    return photocurrent_from_raw(light, raw, photocurrent_range(light))
end

"""
    PHOTOCURRENT_OVER_RANGE

The raw photocurrent word the controller reports when the photodiode channel is
over range: `0x8000`, i.e. -32768 read signed. Observed on the 642 nm rig's
TLD001 (2026-09-28) at 110 mA and above, where the reading jumped from about
3200 counts straight to this value. Decoded as `Inf`, and reported by
`loop_status` as `tia_over`.
"""
const PHOTOCURRENT_OVER_RANGE = -32768

# Signed: the idle reading is a small negative offset (-3 on the 642 nm rig), so
# a negative value is a reading, not a protocol error.
function photocurrent_from_raw(light::TCubeLaser, raw::Int, range::Float64)
    raw == PHOTOCURRENT_OVER_RANGE && return Inf
    abs(raw) <= SETPOINT_PROTOCOL_MAX || error(
        "TCubeLaser $(light.serialNo): photocurrent reading $(raw) is outside the protocol's ±$(SETPOINT_PROTOCOL_MAX)")
    return photocurrent_from_code(light, raw, range)
end

photocurrent_range(light::TCubeLaser{ConstantPhotocurrent}) = light.pd.tia_range
photocurrent_range(light::TCubeLaser{ConstantCurrent}) =
    LightSourceInterface.tia_range_from_word(LD_GetStatusBits(light.serialNo))

"""
    indicated_output_power(light::TCubeLaser{ConstantPhotocurrent})

[`measured_photocurrent`](@ref) x `pd.wa_calibration`, in mW at the laser
output. A conversion through a one-time calibration, not a measurement.
"""
LightSourceInterface.indicated_output_power(light::TCubeLaser{ConstantPhotocurrent}) =
    measured_photocurrent(light) * light.pd.wa_calibration * 1000

"""
    loop_status(light::TCubeLaser)

One snapshot of the controller: the status word and both readings, all polled
cache reads. See the interface's [`loop_status`](@ref) for the fields.
"""
function LightSourceInterface.loop_status(light::TCubeLaser)
    word = UInt32(LD_GetStatusBits(light.serialNo))
    current = measured_current(light)
    range = regulation_mode(light) isa ConstantPhotocurrent ? light.pd.tia_range :
            LightSourceInterface.tia_range_from_word(word)
    photocurrent = photocurrent_from_raw(light, Int(LD_GetPhotoCurrentReading(light.serialNo)), range)
    commanded = regulation_mode(light) isa ConstantPhotocurrent ? !isnan(light.pd.output_power_requested) :
                !isnan(light.drive_current)
    return LightSourceInterface.status_snapshot(word, current, photocurrent;
        threshold_current=light.threshold_current, commanded=commanded)
end

"""
    tcube_get_current(light::TCubeLaser)

Read the diode current the controller reports, in mA, with an explicit
`LD_RequestReadings` and wait rather than the polled cache. Slower than
[`measured_current`](@ref), and independent of whether polling refreshes the
cache.
"""
function tcube_get_current(light::TCubeLaser)
    serialNo = light.serialNo
    check_err(LD_RequestReadings(serialNo), "LD_RequestReadings", serialNo)
    sleep(REQUEST_WAIT_S[])
    out = LD_GetLaserDiodeCurrentReading(serialNo)
    return setpoint_current(light, out)
end


"""
    setupIO(light::TCubeLaser)

Create the NI-DAQmx analogue-output task that drives this laser's modulation
input, and store it in `light.task_mod`.

Pass `daq_device=` and `ao_channel=` to the constructor to name the device and
channel explicitly. When they are `nothing` the historical behaviour is kept --
the **second** discovered device and its **second** AO channel -- because
changing which analogue output a working rig drives is not something a driver
should do quietly. What changed is that the discovery path now validates:
where it used to raise a bare `BoundsError` on a single-device rig, it says
what it found and what to pass instead.
"""
function setupIO(light::TCubeLaser)
    devs = NIDAQcard.showdevices(light.daq)
    device = if light.daq_device === nothing
        length(devs) >= 2 || error("TCubeLaser $(light.serialNo): setupIO defaults to the 2nd DAQ device, but discovery found $(length(devs)): $(join(devs, ", ")). Pass `daq_device=` to TCubeLaser to name one.")
        devs[2]
    else
        light.daq_device in devs || error("TCubeLaser $(light.serialNo): daq_device \"$(light.daq_device)\" is not among the DAQ devices found: $(join(devs, ", ")).")
        light.daq_device
    end

    channelsAO = NIDAQcard.showchannels(light.daq, "AO", device)
    channel = if light.ao_channel === nothing
        length(channelsAO) >= 2 || error("TCubeLaser $(light.serialNo): setupIO defaults to the 2nd AO channel of \"$device\", but it has $(length(channelsAO)): $(join(channelsAO, ", ")). Pass `ao_channel=` to TCubeLaser to name one.")
        channelsAO[2]
    else
        light.ao_channel in channelsAO || error("TCubeLaser $(light.serialNo): ao_channel \"$(light.ao_channel)\" is not among the AO channels of \"$device\": $(join(channelsAO, ", ")).")
        light.ao_channel
    end

    light.task_mod = NIDAQcard.createtask(light.daq, "AO", channel)
    return nothing
end

function set_modvoltage(light::TCubeLaser, voltage::Float64)
    NIDAQcard.setvoltage(light.daq, light.task_mod, voltage)
    return nothing
end

"""
    export_state(light::TCubeLaser)

Snapshot for HDF5 serialization. Pure field reads: no transport call, so its
cost and failure modes do not depend on the controller. It records what was
COMMANDED and configured, not what was measured -- evidence that the loop held
its setpoint comes from [`loop_status`](@ref), which a rig logs with its own
timestamps.

Every laser: `regulation_mode` (`"ConstantCurrent"`/`"ConstantPhotocurrent"`),
`setpoint_unit` (`"mA"`/`"mW"`), `min_current_mA`, `max_current_mA`,
`controller_max_current`, `threshold_current_mA`, `drive_current`, `is_on` and
the identifiers and DAQ names.

`ConstantPhotocurrent` also: `power_reference` (`"laser output"`),
`min_output_power_mW`, `max_output_power_mW`, `wa_calibration_W_per_A`,
`tia_range_A`, `tec_stabilised` (`"true"`/`"false"`/`"unknown"`),
`max_current_clamp_mA`, `output_power_requested_mW`, `photocurrent_requested_A`.

`power` and `power_unit` are no longer written: they held an uncalibrated
linear guess under a `"mW"` label.
"""
function export_state(light::TCubeLaser)
    mode = regulation_mode(light)
    attributes = Dict{String,Any}(
        "unique_id" => light.unique_id, "laser_color" => light.laser_color, "serialNo" => light.serialNo,
        "regulation_mode" => string(nameof(typeof(mode))),
        "setpoint_unit" => mode isa ConstantPhotocurrent ? "mW" : "mA",
        "min_current_mA" => light.min_current, "max_current_mA" => light.max_current,
        "controller_max_current" => light.controller_max_current,
        "threshold_current_mA" => light.threshold_current,
        "max_setcurrent" => light.max_setcurrent, "max_setpoint" => light.max_setpoint,
        # `nothing` is not an HDF5-writable attribute value; "" means "not set".
        "daq_device" => something(light.daq_device, ""), "ao_channel" => something(light.ao_channel, ""),
        "drive_current" => light.drive_current,
        "is_on" => light.properties.is_on,
    )
    if mode isa ConstantPhotocurrent
        pd = light.pd
        merge!(attributes, Dict{String,Any}(
            "power_reference" => "laser output",
            "min_output_power_mW" => light.properties.min_power,
            "max_output_power_mW" => light.properties.max_power,
            "wa_calibration_W_per_A" => pd.wa_calibration,
            "tia_range_A" => pd.tia_range,
            # `missing` is not an HDF5-writable attribute value.
            "tec_stabilised" => pd.tec_stabilised === missing ? "unknown" : string(pd.tec_stabilised),
            "max_current_clamp_mA" => pd.max_current_clamp,
            "output_power_requested_mW" => pd.output_power_requested,
            "photocurrent_requested_A" => pd.photocurrent_requested,
        ))
    end
    data = nothing
    children = Dict{String,Any}(
        "daq" => export_state(light.daq) # export_state function from NIDAQcard module
    )

    return attributes, data, children
end

"""
    tcube_refresh(light::TCubeLaser)

Removed in v0.2.3. Always throws; reaches no hardware.

It used to open the device, enable the output, drive a hardcoded **90 mA**,
sleep a second, then disable and close -- a bench procedure whose name warned
nobody, and the one function here that could raise the current on a diode
without being asked for a number. It is kept as a throwing stub rather than
deleted so that `using MicroscopeControl; tcube_refresh(laser)` still resolves
and explains itself, instead of failing with an `UndefVarError` that says
nothing about what the call used to do.
"""
function tcube_refresh(light::TCubeLaser)
    error("TCubeLaser $(light.serialNo): tcube_refresh was removed in v0.2.3 and does nothing. " *
          "It opened the controller, enabled the output, drove a hardcoded 90 mA for one second, " *
          "then disabled and closed -- a bench procedure whose name warned nobody about the current it " *
          "commanded. Use `setcurrent!(light, current)` (ConstantCurrent) or `setoutputpower!(light, mW)` " *
          "(ConstantPhotocurrent) with the value you want, which is checked before anything is sent; " *
          "`light_on`/`light_off` control the output.")
end
