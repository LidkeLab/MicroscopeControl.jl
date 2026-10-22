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

"""
    usb_locked(f, light::TCubeLaser)

Run `f()` (one Kinesis enable or disable call) holding `light.usb_lock` when the light has a modulator; without one `f()`
runs as it always did. Nothing else is called under it, and it is never held while `light.lock` is taken.
"""
usb_locked(f, light::TCubeLaser) = light.modulator === nothing ? f() : lock(f, light.usb_lock)

"""
    enable_output!(light::TCubeLaser)

`LD_EnableOutput`. With a modulator it runs under `usb_lock` after checking that the activation that calls it is still
current (`arm_gen == generation`), so no enable follows a `light_off`, `shutdown`, `initialize` or newer `light_on`.
"""
function enable_output!(light::TCubeLaser)
    serialNo = light.serialNo
    usb_locked(light) do
        light.modulator === nothing || light.closing && error(
            "TCubeLaser $serialNo: enable refused: a shutdown has begun")
        light.modulator === nothing || light.arm_gen[] == light.generation[] || error(
            "TCubeLaser $serialNo: enable refused: superseded by a light_off, initialize, shutdown or another light_on")
        light.modulator === nothing || (light.properties.is_on = true)   # on (or unknown) from the moment the enable is sent, never after a supersession
        check_err(LD_EnableOutput(serialNo), "LD_EnableOutput", serialNo)
    end
    return nothing
end

"""
    disable_now!(light::TCubeLaser)

`LD_DisableOutput` under `usb_lock`, at once: it needs neither `lock` nor a MOD IN write. The output is recorded off
only after it succeeds; a failure leaves `disable_pending` set and throws.
"""
function disable_now!(light::TCubeLaser)
    serialNo = light.serialNo
    usb_locked(light) do
        try
            check_err(LD_DisableOutput(serialNo), "LD_DisableOutput", serialNo)
        catch
            light.disable_pending = true
            rethrow()
        end
        light.disable_pending = false
        light.properties.is_on = false
    end
    return nothing
end

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
    # The output is still (possibly) enabled: handing the controller back to the front knob, or giving up the output
    # to another light, would be wrong. Both wait for a successful disable.
    light.disable_pending && return nothing
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
function confirm_modulated_setpoint(light::TCubeLaser, code::UInt16; superseded=() -> false)
    serialNo = light.serialNo
    tol = max(MOD_CONFIRM_WORDS, ceil(Int, MOD_CONFIRM_FRACTION * Int(code)))
    close_enough(r) = abs(Int(r) - Int(code)) <= tol
    deadline = time() + SETPOINT_CONFIRM_TIMEOUT_S[]
    readback = LD_GetLaserSetPoint(serialNo)
    while !close_enough(readback) && time() < deadline
        sleep(0.02)
        superseded() && break
        readback = LD_GetLaserSetPoint(serialNo)
    end
    superseded() && return nothing   # the caller reports it
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

Write level 0 to the modulator if the light has one; never throws (an `InterruptException` is returned). `nothing` means
the MOD IN level is known to be 0, or the light has no modulator. A modulator that is not open (the light holds no claim)
is NOT known to be at 0: an error is returned. A caller sends a USB setpoint only when this returned `nothing`: a USB write
at a MOD IN level would absorb the level.
"""
function mod_zero!(light::TCubeLaser)
    light.modulator === nothing && return nothing
    # Not open: the output is not this light's yet (or any more), its level is unknown, so no USB setpoint is safe.
    modulator_open(light) || return ErrorException("the modulator is not open, so its level is unknown")
    return zero_modulator!(light)
end

"""
    light_on_modulated(light::TCubeLaser)

[`light_on`](@ref) for a light with a modulator, in three stages around two waits (see "Locking" on [`TCubeLaser`](@ref)):

1. **Arm**, under `light.lock`: bump `generation` and record it (`arm_gen`); write level 0 to the modulator and require that
   write to succeed; `require_clamp` and `check_scale!` (now at 0 V, so their USB setpoints act as plain USB); the enable
   under `usb_lock` after a generation check ([`enable_output!`](@ref)); USB setpoint 0 and its read-back (a setpoint sent
   while off is ignored, so the base is known only after a write made while on); set `arming`.
2. Sleep [`MOD_SETTLE_S`](@ref), unlocked. A level setter meanwhile only records. `light_off` and `shutdown` disable at
   once; `initialize` and another `light_on` take the lock; all of them bump `generation`.
3. **Apply**, under `light.lock`: if `generation` moved, throw "superseded" and touch nothing (whoever bumped it owns the
   hardware). Otherwise read the CURRENT request and put it on the modulator. Then, unlocked, poll the read-back
   ([`confirm_modulated_setpoint`](@ref)) and run `check_lock` (closed loop), re-checking `generation` at each step. Last,
   under the lock, apply a request a setter recorded meanwhile and clear `arming`: the light is on.

A throw while this activation is still current writes level 0, sends no USB zero (the output is disabled first), disables
and rethrows; if `generation` moved, it throws "superseded" and touches nothing. An interrupt in the sleep ends dark the
same way. `light_off` waits for neither lock before it disables.
"""
function light_on_modulated(light::TCubeLaser)
    serialNo = light.serialNo
    gen = 0
    current() = light.generation[] == gen && !light.closing
    superseded_error() = ErrorException(
        "TCubeLaser $serialNo: light_on was superseded by a light_off, initialize, shutdown or another light_on; it wrote nothing more")
    check_current_activation() = current() || throw(superseded_error())
    # Cleanup that runs only while this activation is still the current one: after a supersession the superseder owns the
    # hardware, and a stale activation touching it would undo the superseder.
    function end_dark(what)
        lock(light.lock) do
            if current()
                light.arming = false
                disable_after_failure(light, what)
            end
        end
    end
    lock(light.lock) do
        # A shutdown that began while this call waited for the lock is final: nothing may arm or enable after it.
        light.closing && error("TCubeLaser $serialNo: light_on refused: a shutdown has begun (initialize clears it)")
        gen = bump_generation!(light)   # supersedes any activation in flight and any earlier arming
        light.arm_gen[] = gen
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
        try
            enable_output!(light)                       # gated: no enable after a light_off
            check_current_activation()
            send_setpoint(light, UInt16(0))
            light.pd isa PhotodiodeLoop && (light.pd.zero_failed = false)   # a zero landed with the output on
            light.arming = true
        catch
            current() && (light.arming = false; disable_after_failure(light, "enable or setpoint 0 after enable"))
            current() || throw(superseded_error())
            rethrow()
        end
    end
    try
        sleep(MOD_SETTLE_S[])
    catch
        # An interrupt in the wait: the light is enabled and arming; end it dark unless something else owns it now.
        end_dark("the settle wait of light_on")
        rethrow()
    end
    code = UInt16(0)
    written = 0.0
    lock(light.lock) do
        check_current_activation()                      # superseded: nothing is written
        try
            code = intended_code(light)                 # the current request, checked against the ceiling now
            written = modulated_request(light)
            setpower(light.modulator, written)          # may block on its transport; light_off does not need this lock
        catch
            end_dark("modulator level after the settle wait")
            rethrow()
        end
    end
    try
        confirm_modulated_setpoint(light, code; superseded=() -> !current())
        check_current_activation()
        check_lock(light, code)                         # reads only, with sleeps: unlocked
        check_current_activation()
    catch e
        current() || throw(superseded_error())
        end_dark("the confirm or lock check of light_on")
        rethrow()
    end
    lock(light.lock) do
        check_current_activation()
        try
            req = modulated_request(light)
            req == written || setpower(light.modulator, req)   # a setter recorded a newer request while arming
            light.arming = false                               # on
        catch
            end_dark("applying a request recorded during arming")
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
    # A failed write leaves the output at an unknown level: DISABLE FIRST (a stalled MOD zero must not keep it on), then zero.
    apply_level!(light, p, () -> disable_after_failure(light, "setpoint change through the modulator"); zero_first=false)
    return true
end

"""
    disable_after_failure_modulated(light::TCubeLaser, what)

[`disable_after_failure`](@ref) for a light with a modulator, never throwing: disable at once ([`disable_now!`](@ref); no
wait for a MOD IN write), then write level 0. No USB zero is sent (the output is off, so the controller would ignore it, and
one at a MOD IN level would absorb it). `properties.is_on` is false only after the disable succeeded.
"""
function disable_after_failure_modulated(light::TCubeLaser, what::AbstractString)
    serialNo = light.serialNo
    disabled, offerr = false, nothing
    try
        disable_now!(light)
        disabled = true
    catch err
        offerr = err
    end
    zerr = modulator_open(light) ? zero_modulator!(light) : nothing
    zeronote = zerr === nothing ? "" : "; writing level 0 to the modulator failed ($zerr)"
    if disabled
        @error "TCubeLaser $serialNo: $what failed; output disabled$zeronote"
    else
        @error "TCubeLaser $serialNo: $what failed and the disable failed ($offerr)$zeronote; the output may still be ON"
    end
    return disabled
end

"""
    light_off_modulated(light::TCubeLaser)

`light_off` for a light with a modulator: bump `generation` (so an activation in flight throws "superseded" and no enable
can follow), disable at once under `usb_lock` ([`disable_now!`](@ref)) without waiting for `light.lock` or a MOD IN write,
then take `lock` to clear `arming` and write level 0. No USB zero is sent: the controller ignores one with the output off,
and the next `light_on` writes USB 0 at 0 V after its enable. A failed disable throws after the level-0 write, and stays
pending; an interrupted 0 V write passes on after the disable.
"""
function light_off_modulated(light::TCubeLaser)
    bump_generation!(light)
    derr = try
        disable_now!(light)
        nothing
    catch e
        e
    end
    zerr = lock(light.lock) do
        light.arming = false
        modulator_open(light) ? zero_modulator!(light) : nothing
    end
    propagate_interrupt(zerr)
    derr === nothing || throw(derr)
    return nothing
end

"""
    shutdown_modulated(light::TCubeLaser)

`shutdown` for a light with a modulator: bump `generation`, disable at once, then (under `lock`) write level 0 and, only if
the disable succeeded, restore the control source and release the modulator; stop polling and close the handle either way.
A disable that failed stays pending with the claim and the source kept, and the next `shutdown` reopens the handle to
retry it. With the handle already closed it retries only what is pending ([`shutdown_disconnected`](@ref)).
"""
function shutdown_modulated(light::TCubeLaser)
    serialNo = light.serialNo
    light.closing = true            # final: no activation may arm or enable from here on (initialize clears it)
    bump_generation!(light)
    if !light.connected
        return lock(light.lock) do
            light.arming = false
            shutdown_disconnected(light)
        end
    end
    derr = try
        disable_now!(light)
        nothing
    catch e
        e
    end
    zerr = nothing
    merr = nothing
    lock(light.lock) do
        light.arming = false
        # An activation that was queued on the lock ahead of this section has been refused (`closing`); the disable is
        # established again as the last hardware step, so nothing that ran in between leaves the output on.
        if derr === nothing
            try
                disable_now!(light)
            catch e
                derr = e
            end
        end
        zerr = modulator_open(light) ? zero_modulator!(light) : nothing
        merr = end_modulation!(light)   # defers itself while the disable is pending
        try
            LD_StopPolling(serialNo)
        catch stoperr
            @error "TCubeLaser $serialNo: LD_StopPolling failed during shutdown" exception = stoperr
        end
        LD_Close(serialNo)
        light.connected = false
    end
    propagate_interrupt(zerr)
    derr === nothing || throw(derr)
    merr === nothing || throw(merr)
    println("$(light.laser_color)" * "_laser is shutdown")
    return nothing
end
