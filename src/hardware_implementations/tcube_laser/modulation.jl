# ---------------------------------------------------------------------------
# External (analog) modulation through the rear MOD IN input, driven by a DAQ
# ---------------------------------------------------------------------------
#
# The TLD001 adds the voltage on its rear SMA MOD IN to the software setpoint when its
# control source includes the external input (TLD001 manual, section 5.5): 0 to 10 V
# = 0 to the photodiode's full-scale power in closed loop, 0 to the current limit in
# open loop, regardless of the setpoint; a negative voltage subtracts. Unlike
# `setoutputpower!`, which sends a setpoint over USB and then waits `lock_check_s` to
# verify the loop (1.3-1.6 s on the 642 nm rig), a modulation change is one DAQ write.
#
# Measured on the 642 nm rig (TLD001 64849775, closed loop, 1 mA range, 224.2 W/A, USB-6008
# Dev2/ao1, 2026-10-13): +22.5 mW per volt (the 22.42 the manual's scaling predicts); a
# DAQ write takes 0.50 ms median, 0.74 ms p99, 3 ms max; on beads at 200 Hz a 1 -> 21 mW
# step lands within one 5 ms frame (one transition frame per edge, no overshoot); the
# USB-6008's 0 V reads as about +0.2 mW (its output offset); with control source 5
# (software + potentiometer) the input is ignored.
#
# ONE setpoint register (same rig and day): the controller does not hold "software setpoint"
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
they add). `[limitation]` on the 642 nm rig's TLD001 a source of 2 or 3 reads back as 1
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
    enable_modulation!(light::TCubeLaser; daq_device = light.daq_device, ao_channel = light.ao_channel,
                       writer = nothing, v_range = nothing)

Drive the controller's rear MOD IN from a DAQ analog output: create the AO task
([`setupIO`](@ref), with `daq_device`/`ao_channel` if given), write 0 V, then set the
control source to software + external (`3`; the front potentiometer, which would add its
own offset, is left out). The previous source is kept and restored by
[`disable_modulation!`](@ref). Then [`setmodulation!`](@ref) adds power (or current) in one
DAQ write. `writer` (`v -> nothing`) and `v_range` (`(v_min, v_max)`) replace the DAQ, for
tests. A no-op when already enabled.

Wiring: a BNC/SMA cable from the AO channel to MOD IN; on the 642 nm rig `Dev2/ao1`
(USB-6008, 0-5 V).
"""
function enable_modulation!(light::TCubeLaser; daq_device=light.daq_device, ao_channel=light.ao_channel,
                            writer=nothing, v_range=nothing)
    m = light.modulation
    m.enabled && return nothing
    per_volt = modulation_scale(light)
    if writer === nothing
        light.daq_device = daq_device
        light.ao_channel = ao_channel
        setupIO(light)
        device = something(light.daq_device, String(split(something(light.ao_channel, ""), "/")[1]))
        isempty(device) && (device = NIDAQcard.showdevices(light.daq)[2])   # setupIO's historical default
        if v_range === nothing
            r = NIDAQcard.DAQmx.ao_voltage_ranges(device)
            v_range = isempty(r) ? (-10.0, 10.0) : (r[1, 1], r[1, 2])
        end
        writer = v -> (NIDAQcard.setvoltage(light.daq, light.task_mod, Float64(v)); nothing)
    end
    v_range === nothing && (v_range = (-10.0, 10.0))
    writer(0.0)
    prev = control_source(light)
    set_control_source!(light, LD_SOURCE_SOFTWARE | LD_SOURCE_EXTERNAL)
    m.per_volt, m.v_min, m.v_max = per_volt, Float64(v_range[1]), Float64(v_range[2])
    m.prev_source, m.write, m.level, m.enabled = prev, writer, 0.0, true
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
"""
function setmodulation!(light::TCubeLaser, level::Real)
    m = light.modulation
    m.enabled || error("TCubeLaser $(light.serialNo): setmodulation! needs enable_modulation! first")
    isfinite(level) || throw(ArgumentError("TCubeLaser $(light.serialNo): modulation must be finite, got $level"))
    v = level / m.per_volt
    m.v_min <= v <= m.v_max || throw(ArgumentError(
        "TCubeLaser $(light.serialNo): modulation $level $(modulation_unit(light)) needs $v V, outside the DAQ channel's [$(m.v_min), $(m.v_max)] V"))
    check_total(light, modulation_base(light), level)
    m.write(v)
    m.level = Float64(level)
    return nothing
end

"The modulation currently added (0 when disabled), in the setpoint's unit."
modulation_level(light::TCubeLaser) = light.modulation.enabled ? light.modulation.level : 0.0

"""
    zero_modulation(light) -> Nothing or the exception

Write 0 V when modulation is enabled; never throws (the switch-off paths call it first and
must go on to disable the output whatever happens here).
"""
function zero_modulation(light::TCubeLaser)
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

"""
    disable_modulation!(light::TCubeLaser)

Write 0 V, restore the control source read by [`enable_modulation!`](@ref) (software only if
it was not read) and mark modulation disabled. Both steps are attempted; the first failure
is rethrown, and a failed restore leaves it marked enabled (the input may still be live).
A no-op when not enabled.
"""
function disable_modulation!(light::TCubeLaser)
    m = light.modulation
    m.enabled || return nothing
    zerr = zero_modulation(light)
    serr = try
        set_control_source!(light, m.prev_source > 0 ? m.prev_source : LD_SOURCE_SOFTWARE)
        nothing
    catch e
        e
    end
    # Still enabled if the source was not restored: the input may still be live.
    isnothing(serr) && ((m.enabled, m.write, m.level) = (false, nothing, 0.0))
    isnothing(zerr) || throw(zerr)
    isnothing(serr) || throw(serr)
    return nothing
end
