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
    enable_modulation!(light::TCubeLaser; ao_channel, daq_device = nothing, v_range = nothing)
    enable_modulation!(light::TCubeLaser; writer, v_range, output_id)

Drive the controller's rear MOD IN from an analogue output, named by the caller: there is
no default output, because which output is wired to which controller belongs to the rig's
own code. Either

- a DAQ channel: `ao_channel = "<device>/ao<n>"` (or set on the constructor; `daq_device`
  defaults to the channel's device part). The AO task is created ([`setupIO`](@ref)) and
  `v_range` defaults to the channel's own range from NI-DAQmx; or
- any other output (a Triggerscope DAC, another card): `writer` (`v -> nothing`), its
  `v_range` (`(v_min, v_max)`, required: the driver cannot read it) and an `output_id`
  naming it (e.g. `"Triggerscope <port> DAC <n>"`, required, for the guard below).

Then 0 V is written and the control source set to software + external (`3`; the front
potentiometer, which would add its own offset, is left out). The previous source is kept
and restored by [`disable_modulation!`](@ref). [`setmodulation!`](@ref) then adds power in
one write. A no-op when already enabled. Refused in open loop (see below).

Several lasers: each laser enables its own modulation and claims its output. A second
laser asking for an output another laser holds (the same DAQ channel, or the same
`output_id`) is refused until the first one's `disable_modulation!`/`shutdown`.

Wiring: a BNC/SMA cable from the output to the controller's MOD IN.
"""
function enable_modulation!(light::TCubeLaser; daq_device=light.daq_device, ao_channel=light.ao_channel,
                            writer=nothing, v_range=nothing, output_id::Union{Nothing,AbstractString}=nothing)
    m = light.modulation
    m.enabled && return nothing
    light isa TCubeLaser{ConstantCurrent} && error(
        "TCubeLaser $(light.serialNo): MOD IN modulation is refused in open loop (ConstantCurrent). Measured on a TLD001 " *
        "(2026-10-13): the input acts only after the control source is set while the output is on, every setcurrent! " *
        "or off/on disarms it, and after re-arming the delivered current was up to 5 mA off what the driver would " *
        "record. Use closed loop (ConstantPhotocurrent), where it is verified; see CALIBRATION.md, \"External modulation\".")
    per_volt = modulation_scale(light)
    if writer === nothing
        light.daq_device = daq_device
        light.ao_channel = ao_channel
        device, channel = resolve_ao(light)
        output = channel
        claim_output!(light, output)
        try
            setupIO(light)
        catch
            release_output!(light, output)
            rethrow()
        end
        if v_range === nothing
            r = NIDAQcard.DAQmx.ao_voltage_ranges(device)
            v_range = isempty(r) ? (-10.0, 10.0) : (r[1, 1], r[1, 2])
        end
        writer = v -> (NIDAQcard.setvoltage(light.daq, light.task_mod, Float64(v)); nothing)
    else
        (output_id === nothing || v_range === nothing) && throw(ArgumentError(
            "TCubeLaser $(light.serialNo): with a writer, name the output (output_id = \"...\") and give its voltage " *
            "range (v_range = (v_min, v_max)): the driver cannot read either from an arbitrary output"))
        output = String(output_id)
        claim_output!(light, output)
    end
    try
        writer(0.0)
        prev = control_source(light)
        set_control_source!(light, LD_SOURCE_SOFTWARE | LD_SOURCE_EXTERNAL)
        m.per_volt, m.v_min, m.v_max = per_volt, Float64(v_range[1]), Float64(v_range[2])
        m.prev_source, m.write, m.level, m.output, m.enabled = prev, writer, 0.0, output, true
    catch
        release_output!(light, output)
        rethrow()
    end
    return nothing
end

# Which laser (serial number) holds each modulation output, process-wide.
const MODULATION_OUTPUTS = Dict{String,String}()
const MODULATION_OUTPUTS_LOCK = ReentrantLock()

"Claim `output` for this laser, or refuse when another laser holds it. `nothing` claims nothing."
function claim_output!(light::TCubeLaser, output)
    output === nothing && return nothing
    lock(MODULATION_OUTPUTS_LOCK) do
        holder = get(MODULATION_OUTPUTS, output, nothing)
        (holder === nothing || holder == light.serialNo) || error(
            "TCubeLaser $(light.serialNo): modulation output \"$output\" is already driving the MOD IN of TCubeLaser $holder. " *
            "Give each laser its own output (ao_channel=, or output_id= with a writer), or disable the other laser's modulation first.")
        MODULATION_OUTPUTS[output] = light.serialNo
    end
    return nothing
end

"Release `output` if this laser holds it."
function release_output!(light::TCubeLaser, output)
    output === nothing && return nothing
    lock(MODULATION_OUTPUTS_LOCK) do
        get(MODULATION_OUTPUTS, output, nothing) == light.serialNo && delete!(MODULATION_OUTPUTS, output)
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
    if isnothing(serr)
        release_output!(light, m.output)
        m.enabled, m.write, m.level, m.output = false, nothing, 0.0, nothing
    end
    isnothing(zerr) || throw(zerr)
    isnothing(serr) || throw(serr)
    return nothing
end
