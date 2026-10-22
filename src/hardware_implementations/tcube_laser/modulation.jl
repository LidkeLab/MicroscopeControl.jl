# ---------------------------------------------------------------------------
# A modulator on the rear MOD IN input
# ---------------------------------------------------------------------------
#
# With `modulator !== nothing` the TLD001's rear SMA MOD IN carries the level (see "With a modulator"
# on `TCubeLaser`). The controller keeps ONE setpoint register (TLD001 64865766 and 64849775): a USB
# `LD_SetLaserSetPoint` sets it outright, taking the MOD IN voltage at that moment as the reference, and a later
# MOD IN change adds only its DIFFERENCE (`LD_GetLaserSetPoint` reads the sum). So with the modulator at 0 V a
# USB 0 leaves the register at `V x scale`: absolute, the DAQ's 0 V offset cancelled. That is the whole model:
# the driver never sends a USB setpoint other than 0 (and the calibration reference, `check_scale!`) while the
# modulator holds a level, and puts the level on MOD IN only after a settle wait and a USB zero made while on.
#
# Control source 3 (software + external) is used, never 5 or 7: the front potentiometer adds an offset, and a cube
# was found at 5. A source of 2 (external only) would make the register absolute in both loops and skip the settle
# wait (-1.3 s per `light_on`) but needs premises not yet measured on both cubes; it is not implemented. Where it
# would go: `MODULATED_SOURCE`, and `light_on_modulated`'s steps 3 and 4 (and `check_scale!`, whose reference is a
# USB setpoint, would set source 3 around its emission).

"Control-source flags of `LD_SetControlSource` (Kinesis `LD_InputSourceFlags`); they add."
const LD_SOURCE_SOFTWARE = 1
const LD_SOURCE_EXTERNAL = 2
const LD_SOURCE_POT = 4

"The control source a light with a modulator runs in: software + external (3)."
const MODULATED_SOURCE = LD_SOURCE_SOFTWARE | LD_SOURCE_EXTERNAL

# `LD_InputSourceFlags` is a Julia enum with the three single flags only, so a sum (3, 5, 7)
# cannot be constructed from it; the controller takes and reports sums.
source_flags(n::Integer) = Core.bitcast(LD_InputSourceFlags, convert(Base.Enums.basetype(LD_InputSourceFlags), n))

"""
    control_source(light::TCubeLaser) -> Int

The controller's control-source flags (1 software, 2 external SMA, 4 front potentiometer; they add), from a fresh
read. `[limitation]` On the TLD001s tested a source of 2 or 3 reads back as 1 while the external input works, so the
read-back cannot confirm the external flag, and a cube found at 3 is restored to 1; 5 reads back as 5.
"""
function control_source(light::TCubeLaser)
    request_twice(LD_RequestControlSource, "LD_RequestControlSource", light.serialNo)
    return Int(LD_GetControlSource(light.serialNo))
end

"""
    set_control_source!(light::TCubeLaser, flags::Integer)

Set the control-source flags (see [`control_source`](@ref)). The software flag is required: this driver's setpoints
must keep reaching the diode. Not persisted to the controller (`LD_PersistSettings` is not called), so a power cycle
restores the stored source.
"""
function set_control_source!(light::TCubeLaser, flags::Integer)
    (flags & LD_SOURCE_SOFTWARE != 0 && 0 < flags <= 7) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): control-source flags must include software (1) and lie in 1..7, got $flags"))
    check_err(LD_SetControlSource(light.serialNo, source_flags(flags)), "LD_SetControlSource", light.serialNo)
    return nothing
end

"""
    MOD_SETTLE_S

Seconds after a setpoint write (`LD_SetLaserSetPoint`) during which a MOD IN change is NOT safe. Measured on TLD001
64849775 in closed loop (2026-10-14): a change up to about 0.95 s after the last write was LOST, entirely or in part.
At 1.0 s a change was often partly lost; from 1.1 s every change was applied, at bases of 2 to 60 mW with steps of 1 to
10 mW. On TLD001 64865766 (2026-10-19): lost up to 0.91 s, applied from 1.00 s, 117 of 117. Status and photocurrent
reads do not cause it, and MOD IN changes alone were applied at every rate tried (up to 2 kHz). 1.3 s leaves about
0.2 s of margin over 1.1 s. A `Ref`, so tests can shorten it.

With a modulator, [`light_on`](@ref) waits this long between its USB zero and the first level it puts on MOD IN.
Every later level change is a MOD IN change alone, so none of them waits.
"""
const MOD_SETTLE_S = Ref(1.3)

"""
    MOD_CONFIRM_WORDS, MOD_CONFIRM_FRACTION

How far the setpoint register may be from the code the request asks for when [`light_on`](@ref) confirms a MOD IN
level: `max(MOD_CONFIRM_WORDS, MOD_CONFIRM_FRACTION * code)` words. Wide enough for the DAC's own offset, the
readback's rounding and `per_volt`'s measured precision; far narrower than the 3.2x the manual's scale was off in
closed loop on 64865766.
"""
const MOD_CONFIRM_WORDS = 30
const MOD_CONFIRM_FRACTION = 0.03

"The level `light_on` puts on MOD IN: the recorded request, 0 when nothing was requested."
modulated_request(light::TCubeLaser{ConstantCurrent}) = isnan(light.drive_current) ? 0.0 : light.drive_current
modulated_request(light::TCubeLaser{ConstantPhotocurrent}) =
    isnan(light.pd.output_power_requested) ? 0.0 : light.pd.output_power_requested

"Whether `light` holds its modulator's output, i.e. the modulator is open from an earlier `initialize`."
modulator_open(light::TCubeLaser) = light.modulator !== nothing && holds_output(light, output_id(light.modulator))

"Count an event that supersedes a `light_on` in progress (see `light_on_modulated`); returns the new count."
bump_generation!(light::TCubeLaser) = Threads.atomic_add!(light.generation, 1) + 1

"""
    begin_modulation!(light::TCubeLaser)

End of `initialize` for a light with a modulator, the output off: open the modulator (claim its output, 0 V), record
the control source (once per open/close cycle, so a second `initialize` keeps the first) and set source 3.
"""
function begin_modulation!(light::TCubeLaser)
    light.modulator === nothing && return nothing
    open_modulator!(light)
    light.source_before === nothing && (light.source_before = control_source(light))
    set_control_source!(light, MODULATED_SOURCE)
    return nothing
end

"""
    reopened(f, light::TCubeLaser)

Run `f()` with the Kinesis handle open: as it is when `light.connected`, else opened for the one call and closed
again, deliberately (a `shutdown` retried after the handle closed, with a restore or a disable still pending).
"""
function reopened(f, light::TCubeLaser)
    light.connected && return f()
    check_err(LD_Open(light.serialNo), "LD_Open", light.serialNo)
    light.connected = true
    try
        return f()
    finally
        try
            LD_Close(light.serialNo)
        catch cerr
            @error "TCubeLaser $(light.serialNo): LD_Close failed after a reopen" exception = cerr
        end
        light.connected = false
    end
end

"""
    restore_control_source!(light::TCubeLaser)

Put back the control source `begin_modulation!` recorded (software only if it did not include software) and forget it.
With the handle closed, it is reopened for the one command ([`reopened`](@ref)).
"""
function restore_control_source!(light::TCubeLaser)
    before = light.source_before
    before === nothing && return nothing
    restore = (0 < before <= 7 && before & LD_SOURCE_SOFTWARE != 0) ? before : LD_SOURCE_SOFTWARE
    reopened(light) do
        set_control_source!(light, restore)
    end
    light.source_before = nothing
    return nothing
end

"""
    end_modulation!(light::TCubeLaser) -> Nothing or the exception

Restore the control source `begin_modulation!` recorded ([`restore_control_source!`](@ref)), then
[`close_modulator!`](@ref). Both are attempted; failures are logged and the first returned, so a caller can finish
closing the handle before it throws. A failed `close_modulator!` keeps the claim for the next call.
"""
function end_modulation!(light::TCubeLaser)
    light.modulator === nothing && return nothing
    err = nothing
    if light.source_before !== nothing
        try
            restore_control_source!(light)
        catch e
            err = e
            @error "TCubeLaser $(light.serialNo): restoring the control source failed; the controller may still be in source $MODULATED_SOURCE" exception = e
        end
    end
    try
        close_modulator!(light)
    catch e
        err === nothing && (err = e)
        @error "TCubeLaser $(light.serialNo): closing the modulator failed; its output stays claimed and the next shutdown retries" exception = e
    end
    return err
end

"""
    confirm_modulated_setpoint(light::TCubeLaser, code)

Poll the controller's setpoint register (`LD_GetLaserSetPoint`, which reads the sum of the USB word and MOD IN's
contribution) until it is within `max(MOD_CONFIRM_WORDS, MOD_CONFIRM_FRACTION * code)` words of `code`, the code the
request asks for, or [`SETPOINT_CONFIRM_TIMEOUT_S`](@ref); throw if it never is. This is the check on the modulator's
`per_volt`: a scale that disagrees with the laser's own (the manual's, 3.2x too high in closed loop on 64865766), a dead
cable, an unarmed control source and a MOD IN change the controller lost all leave the register elsewhere. It also
catches interleavings: a `light_off` during the wait leaves a stale read-back (65530), a level change from another
task is lost and the register shows the old level.
"""
function confirm_modulated_setpoint(light::TCubeLaser, code::UInt16)
    serialNo = light.serialNo
    tol = max(MOD_CONFIRM_WORDS, ceil(Int, MOD_CONFIRM_FRACTION * Int(code)))
    close_enough(r) = abs(Int(r) - Int(code)) <= tol
    deadline = time() + SETPOINT_CONFIRM_TIMEOUT_S[]
    readback = LD_GetLaserSetPoint(serialNo)
    while !close_enough(readback) && time() < deadline
        sleep(0.02)
        readback = LD_GetLaserSetPoint(serialNo)
    end
    close_enough(readback) || error(
        "TCubeLaser $serialNo: the modulator's level was expected to put the setpoint register at $(code) (within $(tol) words) " *
        "but the controller reports $(readback) after $(SETPOINT_CONFIRM_TIMEOUT_S[]) s. Check the modulator's per_volt against " *
        "the laser's own scale (CALIBRATION.md, \"MOD IN scale\"), the cable to MOD IN, and that the control source includes the external input.")
    return nothing
end

"""
    with_light_lock(f, light::TCubeLaser)

Run `f()` holding the light's lock when it has a modulator; without one there is no lock and `f()` runs as it always did.
"""
with_light_lock(f, light::TCubeLaser) = light.modulator === nothing ? f() : lock(f, light.lock)

"""
    mod_zero!(light::TCubeLaser) -> Nothing or the exception

Write level 0 to the modulator if the light has one and holds its output (it is open); never throws (an
`InterruptException` is returned). `nothing` means the MOD IN level is known to be 0 (or is not this light's: no modulator,
or not opened). A caller sends a USB setpoint only when this returned `nothing`: a USB write at a MOD IN level would
absorb the level.
"""
mod_zero!(light::TCubeLaser) = modulator_open(light) ? zero_modulator!(light) : nothing

"""
    light_on_modulated(light::TCubeLaser)

[`light_on`](@ref) for a light with a modulator, in two critical sections of the light's lock around a sleep:

1. **Arm** (under the lock): bump `generation` (superseding anything in flight) and record it; write level 0 to the
   modulator and require that write to succeed; `require_clamp` and `check_scale!` (now at 0 V, so their USB setpoints
   act as plain USB); `LD_EnableOutput`; USB setpoint 0 and its read-back (a setpoint sent while off is ignored, so the
   base is known only after a write made while on); set `arming`.
2. Sleep [`MOD_SETTLE_S`](@ref), unlocked. A level setter meanwhile only records; `light_off`, `initialize`, `shutdown`
   and another `light_on` can take the lock and bump `generation`.
3. **Apply** (under the lock): if `generation` moved, throw "superseded" and touch nothing (whoever bumped it owns the
   hardware). Otherwise read the CURRENT request, put it on the modulator, [`confirm_modulated_setpoint`](@ref) and
   `check_lock` (closed loop), clear `arming`: the light is on.

A throw in either critical section, or an interrupt in the sleep, writes level 0, sends the USB zero only if that
succeeded, disables and rethrows. `[limitation]` The arm section holds the lock through the preflight's fresh reads (and
the reference check's emission when it runs), a fraction of a second to about a second, so a `light_off` waits that long.
"""
function light_on_modulated(light::TCubeLaser)
    serialNo = light.serialNo
    gen = 0
    lock(light.lock) do
        gen = bump_generation!(light)   # supersedes any activation in flight and any earlier arming
        light.arming = false
        # 0 V first, and it must succeed: every USB setpoint below then acts as plain USB.
        try
            setpower(light.modulator, 0.0)
        catch
            output_may_be_on(light) && disable_after_failure(light, "light_on (writing level 0 to the modulator)")
            rethrow()
        end
        require_clamp(regulation_mode(light), light, "light_on")
        try
            check_scale!(light)
        catch
            output_may_be_on(light) && disable_after_failure(light, "light_on (the calibration-reference check refused while the output may be on)")
            rethrow()
        end
        light.pd isa PhotodiodeLoop && light.pd.zero_failed && @warn "TCubeLaser $serialNo: the last setpoint zero failed, so the controller's stored setpoint may be stale (after a failed re-check, the calibration-reference word read as a power target); the first moments after this enable may run toward it, bounded by the programmed clamp"
        has_request(light) || @warn "TCubeLaser $(serialNo): light_on before any setpoint was requested; sending setpoint 0, since the controller's stored setpoint cannot be trusted"
        intended_code(light)   # the current request against the ceiling, before anything is enabled
        light.properties.is_on = true
        try
            check_err(LD_EnableOutput(serialNo), "LD_EnableOutput", serialNo)
            send_setpoint(light, UInt16(0))
            light.arming = true
        catch
            light.arming = false
            disable_after_failure(light, "enable or setpoint 0 after enable")
            rethrow()
        end
    end
    try
        sleep(MOD_SETTLE_S[])
    catch
        # An interrupt in the wait: the light is enabled and arming; end it dark unless something else owns it now.
        lock(light.lock) do
            if light.generation[] == gen
                light.arming = false
                disable_after_failure(light, "the settle wait of light_on")
            end
        end
        rethrow()
    end
    lock(light.lock) do
        light.generation[] == gen || error(
            "TCubeLaser $serialNo: light_on was superseded by a light_off, initialize, shutdown or another light_on while it waited; it wrote nothing more")
        try
            code = intended_code(light)             # the current request, checked against the ceiling now
            setpower(light.modulator, modulated_request(light))
            confirm_modulated_setpoint(light, code)
            check_lock(light, code)
            light.arming = false                    # on
        catch
            light.arming = false
            disable_after_failure(light, "modulator level or its confirm after the settle wait")   # writes level 0 first
            rethrow()
        end
    end
    println("$(light.laser_color)" * "_laser is on")
    return nothing
end

"""
    shutdown_disconnected(light::TCubeLaser)

A `shutdown` of a light with a modulator whose Kinesis handle is already closed (the first `shutdown` could not release
the modulator, restore the control source, or disable the output): retry only what is pending, with no closed-handle
call. A disable or source still pending reopens the handle for those commands ([`reopened`](@ref)); the output is
recorded off only after `LD_DisableOutput` succeeds.
"""
function shutdown_disconnected(light::TCubeLaser)
    err = nothing
    if light.disable_pending
        try
            reopened(light) do
                check_err(LD_DisableOutput(light.serialNo), "LD_DisableOutput", light.serialNo)
            end
            light.disable_pending = false
            light.properties.is_on = false
        catch e
            err = e
            @error "TCubeLaser $(light.serialNo): retrying the disable failed; the output may still be ON" exception = e
        end
    end
    merr = end_modulation!(light)
    err === nothing && (err = merr)
    err === nothing || throw(err)
    return nothing
end

"""
    set_level_modulated!(light::TCubeLaser, p::Float64) -> Bool

The level setters' common tail for a light with a modulator, called with the light's lock held. While the light is on
(and not arming), put `p` on the modulator: one write, no USB call, no fresh read, no lock check, no ramp. While it is off or
arming nothing is written (an arming `light_on` applies the latest recorded request). An `ArgumentError` from the
modulator changes nothing; any other throw writes 0 (tried), disables and rethrows. Returns whether a level was written.
"""
function set_level_modulated!(light::TCubeLaser, p::Float64)
    (light.properties.is_on && !light.arming) || return false
    apply_level!(light, p, () -> disable_after_failure(light, "setpoint change through the modulator"))
    return true
end
