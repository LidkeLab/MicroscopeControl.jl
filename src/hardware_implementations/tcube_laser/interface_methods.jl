"""
    check_err(err, operation::AbstractString, serialNo::AbstractString)

Throw unless a Kinesis call reported success. The TCube LaserDiode calls used
here return a `Cshort` status where `0` is success and anything else is a
Thorlabs error code; every call site below used to assign that status to an
`err` local and never read it, so a failed open, a failed mode change and a
failed setpoint were all indistinguishable from success.

Not hardware-verified (no TCube on the build machine): the `0 == success`
convention is the documented Kinesis one, not something this repo has observed.
"""
function check_err(err, operation::AbstractString, serialNo::AbstractString)
    err == 0 || error("TCubeLaser $serialNo: $operation failed with Thorlabs error code $err")
    return nothing
end

"""
    legacy_power(light::TCubeLaser, current::Float64)

The value `properties.power` has held since before v0.2.3: the requested
current scaled linearly onto `properties.max_power`. **Deprecated, and
scheduled for removal in 0.3.0** -- read `light.drive_current` instead.

It is a guess, not a measurement. The controller reports no optical power in
the open-loop mode this driver uses, and the bench table preserved in
`TCubeLaserControl.jl` shows the real curve is not this line. It is reproduced
here only so that a rig reading `properties.power` across an upgrade reads the
same number it read before.

Reproducing it exactly needs one step the old expression did not: it divided by
`light.max_current`, and `initialize` used to overwrite that field with the
controller's limit. `max_current` is now the caller's and stays so, so the
divisor is `controller_max_current` once `initialize` has read it and
`max_current` before that -- which is the same quantity the old field held at
each of those two moments.
"""
function legacy_power(light::TCubeLaser, current::Float64)
    divisor = isnan(light.controller_max_current) ? light.max_current : light.controller_max_current
    return current * light.properties.max_power / divisor
end

"""
    effective_max_current(light::TCubeLaser)

The ceiling `setpower` enforces, in mA: the smallest of the caller's
`max_current`, the controller's `controller_max_current` (skipped while it is
`NaN`, i.e. before `initialize`) and `max_setcurrent`, the full-scale current
of the setpoint DAC.

`max_setcurrent` is in the list because a current above full scale has no legal
setpoint: see [`SETPOINT_PROTOCOL_MAX`](@ref) for why the bound is the
controller's 0-32767 protocol range and not `UInt16` storage. Without it,
`setpower` would carry a request the range check had already passed into a
conversion that cannot express it.
"""
function effective_max_current(light::TCubeLaser)
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
[`record_controller_limit!`](@ref) and the reading in
[`tcube_get_current`](@ref). `setpoint_code`'s guarantee is stated *in terms of
this function*, so it has to be the same arithmetic in every one of them and
not three copies of the same expression.
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
correction can take a boundary predecessor a hair past one code width. At the bottom of the range that undershoot is the entire
request: see [`setpower`](@ref).
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

This is the whole of `setpower`'s safety check, kept as its own function so it
can be exercised without a controller attached. It runs *before* any setpoint
is computed or sent: the previous code logged `@error` and then carried on to
call `LD_SetLaserSetPoint` anyway. What that cost depended on the request. 500
mA on a 160 mA diode never reached the controller -- it logged, continued, and
then died in the conversion, `UInt16(round(...))` with an `InexactError`. 200
mA did: over the same 160 mA ceiling, but inside the setpoint DAC's range, so
it converted cleanly and was sent. A log line was the only thing separating the
two.
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

"""
    initialize(light::TCubeLaser)

Open the controller, put it in open-loop mode and record the controller's own
diode current limit in `light.controller_max_current`.

If any step after `LD_Open` fails, the handle is closed before the error
propagates -- a half-open controller refuses the next `LD_Open` and so blocks
the retry -- and the original error is the one raised.

It deliberately does **not** touch `light.max_current`: that field is the
caller's ceiling for this diode, and overwriting it with the controller's
(typically 160-220 mA) limit silently widened the range `setpower` validates
against, so a rig that asked for an 80 mA ceiling got the controller's instead.
"""
function initialize(light::TCubeLaser)
    serialNo = light.serialNo
    check_err(TLI_BuildDeviceList(), "TLI_BuildDeviceList", serialNo)
    numdev = TLI_GetDeviceListSize()

    check_err(LD_Open(serialNo), "LD_Open", serialNo)
    try
        check_err(LD_SetOpenLoopMode(serialNo), "LD_SetOpenLoopMode", serialNo)
        check_err(LD_RequestReadings(serialNo), "LD_RequestReadings", serialNo)
        sleep(0.1)
        out = LD_GetLaserDiodeMaxCurrentLimit(serialNo)
        record_controller_limit!(light, out)
    catch
        # The open succeeded, so this handle is ours to close; a controller
        # left open refuses the next `LD_Open` and so blocks the retry. The
        # close is reported but never rethrown: the failure that stopped
        # initialization is the one the caller needs.
        try
            LD_Close(serialNo)
        catch closeerr
            @error "TCubeLaser $serialNo: LD_Close failed while cleaning up a failed initialize" exception = closeerr
        end
        rethrow()
    end

    @info "Laser initialized" serialNo devices = numdev controller_max_current = "$(light.controller_max_current) mA" enforced_max_current = "$(effective_max_current(light)) mA"
    return nothing
end

"""
    light_on(light::TCubeLaser)

Enable the controller's output, then record it. `properties.is_on` is a
*requested* state across this package, but it is at least written after the
call that was supposed to make it true rather than before it, so a failed
enable no longer leaves the field claiming the laser is on.
"""
function LightSourceInterface.light_on(light::TCubeLaser)
    check_err(LD_EnableOutput(light.serialNo), "LD_EnableOutput", light.serialNo)
    light.properties.is_on = true
    println("$(light.laser_color)" * "_laser is on")
    return nothing
end

"""
    setpower(light::TCubeLaser, current::Float64)

Set the diode drive current, in **mA** -- despite the interface name, this
function has always taken a current.

Validates through [`check_current`](@ref), so an out-of-range request
throws before any setpoint reaches the controller, and encodes the setpoint
through [`setpoint_code`](@ref), whose guarantee is that the *decoded* current
-- `setpoint_current(light, code)`, the driver's own arithmetic -- never exceeds
the requested one.

# The bottom of the range commands nothing

Because the encoding only ever rounds down, a positive request smaller than one
code encodes to code `0`: at the default scale that is any request below
`220 / 32767 ≈ 0.006714` mA, so a **zero current setpoint** is sent. That is
not the same as turning the laser off: this path does not disable the output
and does not touch `properties.is_on`. Use [`light_off`](@ref) to stop
emission. This is
deliberate -- rounding such a request up to one code would command more current
than was asked for, which is the rule this driver will not break -- but it is
worth saying out loud, because `drive_current` records the **requested**
current, not the zero that was commanded. A caller reading it back after a
sub-code request sees its own number, and `export_state` writes that number to
the HDF5 attributes. There is no field here that reports what actually went to
the wire.

# What is recorded

On success, `light.drive_current` holds the current that was accepted, in mA.
That is the field to read.

`properties.power` is also updated, to [`legacy_power`](@ref)'s linear
`current * max_power / <controller limit>` figure under the historical `"mW"`
label. It is an **uncalibrated guess**, contradicted by the bench measurements
preserved as a comment in `TCubeLaserControl.jl` (they came from the deleted
`helpers.jl`), and the controller reports no power in open-loop mode. It is
kept only so an existing rig reads the same number across this upgrade, is
**deprecated**, and is scheduled for removal in 0.3.0.
"""
function LightSourceInterface.setpower(light::TCubeLaser, current::Float64)
    check_current(light, current)
    current_setpoint = setpoint_code(light, current)
    check_err(LD_SetLaserSetPoint(light.serialNo, current_setpoint), "LD_SetLaserSetPoint", light.serialNo)
    light.drive_current = current
    light.properties.power = legacy_power(light, current) # deprecated; see legacy_power
    println("Laser current set to $current mA")
    return nothing
end

"""
    light_off(light::TCubeLaser)

Disable the controller's output, then record it. See [`light_on`](@ref) on the
ordering.
"""
function LightSourceInterface.light_off(light::TCubeLaser)
    check_err(LD_DisableOutput(light.serialNo), "LD_DisableOutput", light.serialNo)
    light.properties.is_on = false
    println("$(light.laser_color)" * "_laser is off")
    return nothing
end

"""
    shutdown(light::TCubeLaser)

Disable the output and close the connection. A failed disable throws, but the
connection is closed either way: leaving the Kinesis handle open would also
block the reconnection a caller needs in order to retry the disable.
"""
function shutdown(light::TCubeLaser)
    serialNo = light.serialNo
    try
        check_err(LD_DisableOutput(serialNo), "LD_DisableOutput", serialNo)
        light.properties.is_on = false
    finally
        LD_Close(serialNo) # returns Cvoid: no status to check
    end
    println("$(light.laser_color)" * "_laser is shutdown")
    return nothing
end

"""
    tcube_get_current(light::TCubeLaser)

Read the diode current the controller reports, in mA.
"""
function tcube_get_current(light::TCubeLaser)
    serialNo = light.serialNo
    check_err(LD_RequestReadings(serialNo), "LD_RequestReadings", serialNo)
    sleep(0.1)
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

Snapshot for HDF5 serialization, matching the package-wide 1-argument
`export_state` contract. Before v0.2.3 the only method took an unused second
positional argument, so this 1-argument call fell through to the throwing
instrument-level stub.

`"drive_current"` is the drive current in mA that `setpower` last accepted, and
is the attribute to read. `"power"`/`"power_unit"` are the deprecated derived
guess described in [`legacy_power`](@ref), written for continuity with files
saved by earlier versions and scheduled for removal in 0.3.0.
"""
function export_state(light::TCubeLaser)
    attributes = Dict(
        "unique_id" => light.unique_id, "laser_color" => light.laser_color, "serialNo" => light.serialNo,
        "min_current" => light.min_current, "max_current" => light.max_current,
        "controller_max_current" => light.controller_max_current,
        "max_setcurrent" => light.max_setcurrent, "max_setpoint" => light.max_setpoint,
        # `nothing` is not an HDF5-writable attribute value; "" means "not set".
        "daq_device" => something(light.daq_device, ""), "ao_channel" => something(light.ao_channel, ""),
        "drive_current" => light.drive_current,
        "power_unit" => light.properties.power_unit, "power" => light.properties.power, "is_on" => light.properties.is_on,
        "min_power" => light.properties.min_power, "max_power" => light.properties.max_power
    )
    data = nothing
    children = Dict(
        "daq" => export_state(light.daq) # export_state function from NIDAQcard module
    )

    return attributes, data, children
end

"""
    EXPORT_STATE_2ARG_WARNED

Whether the deprecated 2-argument [`export_state`](@ref) has already warned in
this session. A plain `Ref` rather than `@warn`'s `maxlog=1` so that the
warning is testable more than once per process.
"""
const EXPORT_STATE_2ARG_WARNED = Ref(false)

"""
    export_state(light::TCubeLaser, ignored)

Deprecated forwarder to [`export_state(::TCubeLaser)`](@ref). Warns once per
session and ignores its second argument, which was never read.

It is kept because removing it would be a break for no benefit. The bug was the
*absence* of the 1-argument method -- `export_state(laser)` matched nothing on
this type and fell through to the throwing instrument-level stub -- so adding
that method is the whole fix, and a caller that had to pass a second argument
to get anything at all keeps working. The forwarder is scheduled for removal in
0.3.0.
"""
function export_state(light::TCubeLaser, ignored)
    if !EXPORT_STATE_2ARG_WARNED[]
        EXPORT_STATE_2ARG_WARNED[] = true
        @warn "export_state(::TCubeLaser, x): the second argument is ignored and this method is deprecated; " *
              "call export_state(laser). The 2-argument form is scheduled for removal in 0.3.0." ignored_argument = ignored
    end
    return export_state(light)
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

`setpower(light, current)` is the replacement: it takes the current explicitly
and refuses one outside the configured range.
"""
function tcube_refresh(light::TCubeLaser)
    error("TCubeLaser $(light.serialNo): tcube_refresh was removed in v0.2.3 and does nothing. " *
          "It opened the controller, enabled the output, drove a hardcoded 90 mA for one second, " *
          "then disabled and closed -- a bench procedure whose name warned nobody about the current it " *
          "commanded. Use `setpower(light, current)` with the current you want, which is checked against " *
          "min_current, max_current, the controller's limit and max_setcurrent before anything is sent; " *
          "`light_on`/`light_off` control the output.")
end
