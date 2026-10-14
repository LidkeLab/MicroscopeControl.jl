# ---------------------------------------------------------------------------
# External (analog) modulation through the rear MOD IN input, driven by a DAQ
# ---------------------------------------------------------------------------
#
# The TLD001 adds the voltage on its rear SMA MOD IN to the software setpoint when its
# control source includes the external input (TLD001 manual, section 5.5): 0 to 10 V
# = 0 to the photodiode's full-scale power in closed loop, 0 to the current limit in
# open loop, regardless of the setpoint; a negative voltage subtracts. Unlike
# `setoutputpower!`, which sends a setpoint over USB and then waits `lock_check_s` to
# verify the loop (over a second on the TLD001 tested), a modulation change is one write.
#
# Verified on a TLD001 in closed loop (2026-10-13, NI USB DAQ output): the measured volts-to-mW
# scale matched `modulation_scale` (`tia_range x wa_calibration / 10`) to 0.4 %; a DAQ write
# took about 0.5 ms; on a camera at 200 Hz a step landed within one 5 ms frame (one
# transition frame per edge, no overshoot); a DAQ's 0 V output offset adds a fraction of a mW;
# with control source 5 (software + potentiometer) the input is ignored.
#
# ONE setpoint register (same controller and day): the controller does not hold "software setpoint"
# and "external input" separately. A USB setpoint write sets its register outright, and a
# later MOD IN change adds only its DIFFERENCE (`LD_GetLaserSetPoint` reads the sum). A write
# of the request alone while modulated therefore absorbs the modulation (10 on, +5, write 12
# -> 12 mW, then 0 V -> 7 mW). So every USB write here sends request + `modulation_level`
# (`setoutputpower!`, `setcurrent!`, `light_on` via `intended_code`), and `check_lock`
# checks what was sent.

"Control-source flags of `LD_SetControlSource` (Kinesis `LD_InputSourceFlags`); they add."
const LD_SOURCE_SOFTWARE = 1
const LD_SOURCE_EXTERNAL = 2
const LD_SOURCE_POT = 4

# `LD_InputSourceFlags` is a Julia enum with the three single flags only, so a sum (3, 5, 7)
# cannot be constructed from it; the controller takes and reports sums.
source_flags(n::Integer) = Core.bitcast(LD_InputSourceFlags, convert(Base.Enums.basetype(LD_InputSourceFlags), n))

"""
    control_source(light::TCubeLaser) -> Int

The controller's control-source flags (1 software, 2 external SMA, 4 front potentiometer;
they add). `[limitation]` on the TLD001 tested a source of 2 or 3 reads back as 1
while the external input demonstrably works, so the read-back cannot confirm the external
flag; 5 reads back as 5.
"""
function control_source(light::TCubeLaser)
    request_twice(LD_RequestControlSource, "LD_RequestControlSource", light.serialNo)
    return Int(LD_GetControlSource(light.serialNo))
end

"""
    set_control_source!(light::TCubeLaser, flags::Integer)

Set the control-source flags (see [`control_source`](@ref)). The software flag is required:
this driver's setpoints must keep reaching the diode. Not persisted to the controller
(`LD_PersistSettings` is not called), so a power cycle restores the stored source.
"""
function set_control_source!(light::TCubeLaser, flags::Integer)
    (flags & LD_SOURCE_SOFTWARE != 0 && 0 < flags <= 7) || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): control-source flags must include software (1) and lie in 1..7, got $flags"))
    check_err(LD_SetControlSource(light.serialNo, source_flags(flags)), "LD_SetControlSource", light.serialNo)
    return nothing
end

"""
    modulation_scale(light) -> Float64

What 1 V on MOD IN adds: mW in closed loop (`tia_range x wa_calibration / 10`), mA in open
loop (the controller's current limit / 10, known after `initialize`).
"""
modulation_scale(light::TCubeLaser{ConstantPhotocurrent}) = light.pd.tia_range * light.pd.wa_calibration * 1000 / 10
function modulation_scale(light::TCubeLaser{ConstantCurrent})
    isnan(light.controller_max_current) && error(
        "TCubeLaser $(light.serialNo): the open-loop modulation scale is the controller's current limit / 10 V, read by initialize; initialize first")
    return light.controller_max_current / 10
end

"""
    with_setpoint_lock(f, light::TCubeLaser)

Run `f()` holding the laser's setpoint lock (`light.modulation.lock`, reentrant). Every
call that writes the controller's setpoint register holds it, because the register is
shared: a USB setpoint write replaces it outright and a MOD IN change adds its difference
(see the top of this file). Two writers interleaving would leave the register at a total
nobody checked against the ceiling, and a modulation change inside a verified setpoint
write (ramp, read-back, lock check) would make the driver's record disagree with the
controller. [`setmodulation!`](@ref) does not wait for it: it refuses when it is held.
"""
with_setpoint_lock(f, light::TCubeLaser) = lock(f, light.modulation.lock)

"""
    MOD_SETTLE_S

Seconds after a setpoint write (`LD_SetLaserSetPoint`) during which a MOD IN change is NOT
safe. Measured on a TLD001 in closed loop (2026-10-14, rig scripts `settle_window*.jl`): a
change up to about 0.95 s after the last write was LOST, entirely or in part. The light kept
the old total, and every later change counted from it, so the light and the driver's record
differed by that step (±5 mW in the test) until the next write. From 1.0 s on, every change was
applied. Status and photocurrent reads do not cause it, and MOD IN changes alone are applied
at any rate tested (2 kHz). 1.3 s leaves a 30 % margin. A `Ref`, so tests can shorten it.

With modulation enabled and the output on, `light_on`, `setoutputpower!` and `setcurrent!` wait
until this long after their last write before they return (holding the setpoint lock), and
[`setmodulation!`](@ref) refuses inside the window. A base change therefore takes about 0.35 s
more, and every modulation change after it is applied.
"""
const MOD_SETTLE_S = Ref(1.3)

"Seconds left until a MOD IN change is safe after the last setpoint write (≤ 0 when it is)."
modulation_settle_left(light::TCubeLaser) = light.modulation.written_at + MOD_SETTLE_S[] - time()

"With modulation enabled and the output on, wait out [`MOD_SETTLE_S`](@ref) after the last setpoint write."
function wait_modulation_settled(light::TCubeLaser)
    (light.modulation.enabled && light.properties.is_on) || return nothing
    t = modulation_settle_left(light)
    t > 0 && sleep(t)
    return nothing
end

"""
    enable_modulation!(light::TCubeLaser; ao_channel, daq_device = nothing, v_range = nothing)
    enable_modulation!(light::TCubeLaser; writer, v_range, output_id, close = nothing)

Drive the controller's rear MOD IN from an analogue output, named by the caller: there is
no default output, because which output is wired to which controller belongs to the rig's
own code. Either

- a DAQ channel: `ao_channel = "<device>/ao<n>"` (or set on the constructor; `daq_device`
  defaults to the channel's device part). The AO task is created ([`setupIO`](@ref)) and
  `v_range` defaults to the channel's own range from NI-DAQmx. The task is deleted when the
  output is released; or
- any other output (a Triggerscope DAC, another card): `writer` (`v -> nothing`), its
  `v_range` (`(v_min, v_max)`, required: the driver cannot read it) and an `output_id`
  naming it (e.g. `"Triggerscope <port> DAC <n>"`, required, for the guard below). An
  optional `close` (`() -> nothing`) runs when the output is released.

Then 0 V is written and the control source set to software + external (`3`; the front
potentiometer, which would add its own offset, is left out). The previous source is kept
and restored by [`disable_modulation!`](@ref). [`setmodulation!`](@ref) then adds power in
one write. A no-op when already enabled. Refused in open loop (see below). If any step
fails, the output is released (the DAQ task deleted, the claim dropped) and the error
rethrown. Holds the setpoint lock ([`with_setpoint_lock`](@ref)).

Several lasers: each laser enables its own modulation and claims its output. A second
laser object asking for an output another one holds (the same DAQ channel, or the same
`output_id`) is refused until the first one's `disable_modulation!`/`shutdown`, also when
both objects are for the same serial number.

Wiring: a BNC/SMA cable from the output to the controller's MOD IN.
"""
function enable_modulation!(light::TCubeLaser; daq_device=light.daq_device, ao_channel=light.ao_channel,
                            writer=nothing, v_range=nothing, output_id::Union{Nothing,AbstractString}=nothing,
                            close=nothing)
    with_setpoint_lock(light) do
        _enable_modulation!(light, daq_device, ao_channel, writer, v_range, output_id, close)
    end
end

function _enable_modulation!(light::TCubeLaser, daq_device, ao_channel, writer, v_range, output_id, closer)
    m = light.modulation
    m.enabled && return nothing
    light isa TCubeLaser{ConstantCurrent} && error(
        "TCubeLaser $(light.serialNo): MOD IN modulation is refused in open loop (ConstantCurrent). Measured on a TLD001 " *
        "(2026-10-13): the input acts only after the control source is set while the output is on, every setcurrent! " *
        "or off/on disarms it, and after re-arming the delivered current was up to 5 mA off what the driver would " *
        "record. Use closed loop (ConstantPhotocurrent), where it is verified; see CALIBRATION.md, \"External modulation\".")
    daq = writer === nothing
    if daq
        closer === nothing || throw(ArgumentError(
            "TCubeLaser $(light.serialNo): close= is for a writer; the driver deletes its own DAQ task"))
        light.daq_device = daq_device
        light.ao_channel = ao_channel
        device, output = resolve_ao(light)
    else
        (output_id === nothing || v_range === nothing) && throw(ArgumentError(
            "TCubeLaser $(light.serialNo): with a writer, name the output (output_id = \"...\") and give its voltage " *
            "range (v_range = (v_min, v_max)): the driver cannot read either from an arbitrary output"))
        output = String(output_id)
    end
    claim_output!(light, output)
    try
        if daq
            setupIO(light)
            closer = () -> close_daq_output!(light)   # from here on, a failure deletes the task
            if v_range === nothing
                r = NIDAQcard.DAQmx.ao_voltage_ranges(device)
                v_range = isempty(r) ? (-10.0, 10.0) : (r[1, 1], r[1, 2])
            end
            writer = v -> (NIDAQcard.setvoltage(light.daq, light.task_mod, Float64(v)); nothing)
        end
        writer(0.0)
        prev = control_source(light)
        set_control_source!(light, LD_SOURCE_SOFTWARE | LD_SOURCE_EXTERNAL)
        m.per_volt, m.v_min, m.v_max = modulation_scale(light), Float64(v_range[1]), Float64(v_range[2])
        m.prev_source, m.write, m.close, m.level, m.output, m.enabled = prev, writer, closer, 0.0, output, true
    catch
        cerr = run_close(closer)
        if isnothing(cerr)
            release_output!(light, output)
        else
            @error "TCubeLaser $(light.serialNo): releasing modulation output \"$output\" after a failed enable failed; it stays claimed" exception = cerr
        end
        rethrow()
    end
    return nothing
end

"Delete the DAQ task `setupIO` created, if any."
function close_daq_output!(light::TCubeLaser)
    t = light.task_mod
    t isa Integer && return nothing   # no task (the constructor's 0)
    NIDAQcard.deletetask(light.daq, t)
    light.task_mod = 0
    return nothing
end

"Run a release function: `nothing` on success (or when there is none), else the exception."
function run_close(closer)
    closer === nothing && return nothing
    try
        closer()
        return nothing
    catch e
        return e
    end
end

# Which laser object holds each modulation output, process-wide.
const MODULATION_OUTPUTS = Dict{String,Any}()
const MODULATION_OUTPUTS_LOCK = ReentrantLock()

"Claim `output` for this laser object, or refuse when another one holds it. `nothing` claims nothing."
function claim_output!(light::TCubeLaser, output)
    output === nothing && return nothing
    lock(MODULATION_OUTPUTS_LOCK) do
        holder = get(MODULATION_OUTPUTS, output, nothing)
        if !(holder === nothing || holder === light)
            who = holder.serialNo == light.serialNo ? "another TCubeLaser object for the same serial $(holder.serialNo)" :
                "TCubeLaser $(holder.serialNo)"
            error("TCubeLaser $(light.serialNo): modulation output \"$output\" is already driving the MOD IN of $who. " *
                "Give each laser its own output (ao_channel=, or output_id= with a writer), or disable the other laser's modulation first.")
        end
        MODULATION_OUTPUTS[output] = light
    end
    return nothing
end

"Release `output` if this laser object holds it."
function release_output!(light::TCubeLaser, output)
    output === nothing && return nothing
    lock(MODULATION_OUTPUTS_LOCK) do
        get(MODULATION_OUTPUTS, output, nothing) === light && delete!(MODULATION_OUTPUTS, output)
    end
    return nothing
end

# The setpoint the modulation adds to, in its unit (0 when nothing was requested yet).
modulation_base(light::TCubeLaser{ConstantPhotocurrent}) = (p = light.pd.output_power_requested; isnan(p) ? 0.0 : p)
modulation_base(light::TCubeLaser{ConstantCurrent}) = (c = light.drive_current; isnan(c) ? 0.0 : c)
modulation_ceiling(light::TCubeLaser{ConstantPhotocurrent}) = light.properties.max_power
modulation_ceiling(light::TCubeLaser{ConstantCurrent}) = effective_max_current(light)
modulation_unit(::TCubeLaser{ConstantPhotocurrent}) = "mW"
modulation_unit(::TCubeLaser{ConstantCurrent}) = "mA"

"""
    check_total(light, base, level)

Refuse (`ArgumentError`) when the setpoint `base` plus the modulation `level` would exceed
the laser's ceiling (`properties.max_power` in closed loop, the current ceiling in open loop)
or go below 0.
"""
function check_total(light::TCubeLaser, base::Real, level::Real)
    total, hi, u = base + level, modulation_ceiling(light), modulation_unit(light)
    0 <= total <= hi || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): setpoint $base $u + modulation $level $u = $total $u is outside [0, $hi] $u"))
    return nothing
end

"""
    setmodulation!(light::TCubeLaser, level::Real)

Add `level` (mW in closed loop, mA in open loop) to the software setpoint through MOD IN:
one DAQ write, no USB call to the controller, no lock check, so it returns in about a
millisecond. Refused when modulation is not enabled, when the voltage is outside the DAQ
channel's range, or when setpoint + `level` is outside [0, ceiling]. Takes effect only while
the output is on; `light_off`, `shutdown` and every failure cleanup write 0 V first.
Drive MOD IN only through this function: the driver adds the level to every USB setpoint
it sends (the controller's one setpoint register, see the top of this file), so a voltage
written by other code would be absorbed by the next `setoutputpower!`.

**Refused at once, without waiting, while another call holds the laser's setpoint lock**
([`with_setpoint_lock`](@ref)): `setoutputpower!`/`setcurrent!` (over a second with the
verified write and the lock check), `light_on`, `light_off`, `shutdown`, `initialize`, or
an enable/disable. Nothing is written then and the level stays what it was. Without this, a
level checked against the old setpoint could land on top of the new one and exceed
`max_power`. Set the base before a fast run, not during it.

Also refused while the output is on within [`MOD_SETTLE_S`](@ref) of the last setpoint write:
the controller loses a MOD IN change made that soon (measured). The slow calls already wait
that out before they return, so this only fires after a write from a path that does not
(e.g. modulation enabled right after a base change).

The volts-per-unit scale is recomputed on every call ([`modulation_scale`](@ref)). If the
writer throws, the voltage it left is unknown: 0 V is written and the level recorded as 0;
if that fails too, the level keeps its previous value, an error is logged, and the writer's
error is rethrown.
"""
function setmodulation!(light::TCubeLaser, level::Real)
    m = light.modulation
    trylock(m.lock) || error(
        "TCubeLaser $(light.serialNo): setmodulation!($level) refused: a setpoint change, switch-on/off or modulation " *
        "change is in progress on this laser (it holds the setpoint lock). Nothing was written; the modulation stays at " *
        "$(m.level). Set the base power before a fast run, not during it.")
    try
        m.enabled || error("TCubeLaser $(light.serialNo): setmodulation! needs enable_modulation! first")
        left = modulation_settle_left(light)
        (light.properties.is_on && left > 0) && error(
            "TCubeLaser $(light.serialNo): setmodulation!($level) refused: the controller is still settling after a setpoint " *
            "write ($(round(Int, 1000 * left)) ms left of MOD_SETTLE_S = $(MOD_SETTLE_S[]) s); a MOD IN change now would be " *
            "lost and leave the light off the driver's record. Nothing was written.")
        isfinite(level) || throw(ArgumentError("TCubeLaser $(light.serialNo): modulation must be finite, got $level"))
        per_volt = modulation_scale(light)
        v = level / per_volt
        m.v_min <= v <= m.v_max || throw(ArgumentError(
            "TCubeLaser $(light.serialNo): modulation $level $(modulation_unit(light)) needs $v V, outside the DAQ channel's [$(m.v_min), $(m.v_max)] V"))
        check_total(light, modulation_base(light), level)
        try
            m.write(v)
        catch
            # The writer may have applied the voltage before it threw: put the input back at a known 0 V.
            try
                m.write(0.0)
                m.level = 0.0
            catch zerr
                @error "TCubeLaser $(light.serialNo): writing 0 V after a failed modulation write failed too; the voltage on MOD IN is unknown" exception = zerr
            end
            rethrow()
        end
        m.per_volt = per_volt
        m.level = Float64(level)
    finally
        unlock(m.lock)
    end
    return nothing
end

"The modulation currently added (0 when disabled), in the setpoint's unit."
modulation_level(light::TCubeLaser) = light.modulation.enabled ? light.modulation.level : 0.0

"""
    zero_modulation(light) -> Nothing or the exception

Write 0 V when modulation is enabled; never throws (the switch-off paths call it first and
must go on to disable the output whatever happens here). Holds the setpoint lock, so the
0 V and the recorded level change together.
"""
function zero_modulation(light::TCubeLaser)
    with_setpoint_lock(light) do
        m = light.modulation
        m.enabled || return nothing
        try
            m.write(0.0)
            m.level = 0.0
            return nothing
        catch e
            return e
        end
    end
end

"""
    disable_modulation!(light::TCubeLaser)

Write 0 V, restore the control source read by [`enable_modulation!`](@ref) (software only if
it was not read), then release the output (delete the DAQ task, drop the claim) and mark
modulation disabled. Every step is attempted and the first failure rethrown.

It stays **enabled**, keeping its output and its claim, whenever a voltage may still add to
the setpoint: the source was not restored, or the 0 V write failed and the restored source
still includes the external input (3 or 7). The level is then still added to every USB
setpoint, as it is still on the input, and a retry can finish the job. If only the release
fails, modulation is marked disabled but the output stays claimed (the task may still hold
the channel). A no-op when not enabled. Holds the setpoint lock.
"""
function disable_modulation!(light::TCubeLaser)
    with_setpoint_lock(light) do
        m = light.modulation
        m.enabled || return nothing
        zerr = zero_modulation(light)
        restore = m.prev_source > 0 ? m.prev_source : LD_SOURCE_SOFTWARE
        serr = try
            set_control_source!(light, restore)
            nothing
        catch e
            e
        end
        # Nothing can add any more when the source was restored and either 0 V is on the input or the
        # restored source ignores the input.
        input_dead = isnothing(serr) && (isnothing(zerr) || restore & LD_SOURCE_EXTERNAL == 0)
        cerr = nothing
        if input_dead
            cerr = run_close(m.close)
            isnothing(cerr) && (release_output!(light, m.output); m.output = nothing)
            m.enabled, m.write, m.close, m.level = false, nothing, nothing, 0.0
        end
        isnothing(zerr) || throw(zerr)
        isnothing(serr) || throw(serr)
        isnothing(cerr) || throw(cerr)
        return nothing
    end
end
