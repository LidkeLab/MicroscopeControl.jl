
"""
    TCubeLaser{M<:RegulationMode} <: DiodeLaser

A laser diode on a Thorlabs TLD001 T-Cube controller, in one of two regulation
modes fixed at construction:

- `TCubeLaser{ConstantCurrent}`: open loop. The controller holds the drive
  current; command it with [`setcurrent!`](@ref), in mA.
- `TCubeLaser{ConstantPhotocurrent}`: closed loop. The controller holds the
  monitor photodiode current; command it with [`setoutputpower!`](@ref), in mW
  at the laser output, converted through `pd.wa_calibration`. See
  `CALIBRATION.md` beside this file for how that number is measured.

`setpower(laser, mA)` still works on a `ConstantCurrent` laser: it forwards to
`setcurrent!` and is deprecated. On a `ConstantPhotocurrent` laser it throws,
so that an 80 mA call can never become an 80 mW one.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: `is_on` is the requested output state. In
  `ConstantPhotocurrent` mode `min_power`/`max_power` are the ENFORCED bounds of
  `setoutputpower!`, in mW at the laser output, and the endpoints of
  `setlevel!`. In `ConstantCurrent` mode they are not read. `power` is
  deprecated: an open-loop `setcurrent!` writes it as 0.2.4's figure
  `drive_current * properties.max_power / <controller limit>`, an uncalibrated
  guess that is NOT in `power_unit`'s unit (the `"mA"` label covers only
  `min_power`/`max_power` in open loop). With the default `properties`, whose
  `max_power` is now `max_current`, the figure differs from 0.2.4's
  default-properties value; `drive_current` is the number to read. A
  `ConstantPhotocurrent` laser never writes `power`.
- `laser_color::String`: The color of the laser.
- `min_current::Float64`: The lowest drive current this rig will command, in
  mA: `setcurrent!`'s floor and `setlevel!`'s zero. Defaults to `0.0`. It is a
  *lower* bound, so it protects nothing on its own -- the ceiling does.
- `max_current::Float64`: The caller's current ceiling in mA, i.e. the rig's
  own limit for this diode. Never overwritten by `initialize`. In
  `ConstantPhotocurrent` mode it is also the clamp `initialize` programs into
  the controller's max-current potentiometer, because there the loop raises the
  current by itself.
- `max_setcurrent::Float64`: Full-scale current of the setpoint DAC, in mA.
- `max_setpoint::Float64`: Full-scale value of the setpoint DAC.
- `serialNo::String`: Thorlabs Kinesis serial number of the controller.
- `task_mod`: The NI-DAQmx task driving the analogue modulation input, or `0`
  before `setupIO` runs.
- `daq::NIdaq`: The DAQ carrying that modulation channel.
- `controller_max_current::Float64`: The controller's own diode current limit
  in mA, read from `LD_GetLaserDiodeMaxCurrentLimit` by `initialize`. `NaN`
  until `initialize` runs.
- `daq_device::Union{Nothing,String}`: DAQ device name `setupIO` should use.
  `nothing` keeps the historical discovery behaviour (see `setupIO`).
- `ao_channel::Union{Nothing,String}`: AO channel name `setupIO` should use.
  `nothing` keeps the historical discovery behaviour (see `setupIO`).
- `drive_current::Float64`: The drive current in mA that `setcurrent!` last
  accepted: the last accepted *request*, not what reached the wire (a request
  below one setpoint code encodes to zero). `NaN` before the first. It stays
  `NaN` for the life of a `ConstantPhotocurrent` laser: the loop owns the
  current there, and a requested value would be a fiction. Read
  [`measured_current`](@ref) for what the controller reports.
- `threshold_current::Float64`: The diode's lasing threshold in mA, declared by
  the rig from a bench sweep (the controller cannot report it). `NaN` when
  unknown. Used by the panel marker and by `loop_status`'s `below_threshold`
  check; never as a bound.
- `pd::Union{Nothing,PhotodiodeLoop}`: The photodiode loop's calibration and
  state; a [`PhotodiodeLoop`](@ref) exactly when `M === ConstantPhotocurrent`,
  `nothing` otherwise.

The first fourteen fields are in the order they have always been in, and the
two added in 0.2.5 are at the end, so the pre-0.2.5 positional forms still
construct: they build a `TCubeLaser{ConstantCurrent}` with both defaulted.

# The setpoint only takes while the output is on

The Thorlabs TLD001 ignores `LD_SetLaserSetPoint` while its output is disabled
and, on the next `LD_EnableOutput`, runs on whatever setpoint it had stored
(observed on the 642 nm rig's TLD001 64849775, 2026-09-28). So a requested
setpoint (`setcurrent!`, `setoutputpower!`) reaches the diode only because
`light_on` sends it right after enabling, and `light_off` and `shutdown` zero
the setpoint before disabling, so the next enable starts dark.

`[limitation]` Between the enable and the setpoint that follows it (one USB
round trip) the controller runs on its stored setpoint: 0 after this driver's
`light_off` or `shutdown`, but anything up to the controller's current limit if
other software left it there. In that window the current-limit potentiometer
is the only hardware bound; set it at or below the diode's rating.
"""
mutable struct TCubeLaser{M<:RegulationMode} <: DiodeLaser
    unique_id::String
    properties::LightSourceProperties
    laser_color::String
    min_current::Float64
    max_current::Float64
    max_setcurrent::Float64
    max_setpoint::Float64
    serialNo::String
    task_mod
    daq::NIdaq
    controller_max_current::Float64
    daq_device::Union{Nothing,String}
    ao_channel::Union{Nothing,String}
    drive_current::Float64
    threshold_current::Float64
    pd::Union{Nothing,PhotodiodeLoop}

    function TCubeLaser{M}(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current,
        threshold_current, pd) where {M<:RegulationMode}
        M in supported_modes(TCubeLaser) || throw(ArgumentError(
            "TCubeLaser $serialNo: mode $(M) is not one of $(supported_modes(TCubeLaser))"))
        name = "TCubeLaser $serialNo"
        LightSourceInterface.check_diode_config(M, pd, properties, Float64(max_current), name)
        if M === ConstantPhotocurrent
            isnan(drive_current) || throw(ArgumentError(
                "$name: drive_current must be NaN on a ConstantPhotocurrent laser, where the loop owns the current; got $(drive_current)"))
            any(r -> isapprox(pd.tia_range, r; rtol=1e-9), TLD001_TIA_RANGES) || throw(ArgumentError(
                "$name: tia_range = $(pd.tia_range) A is not a TLD001 photodiode range; it must be one of $(TLD001_TIA_RANGES) A, as set on the rear-panel DIP switch"))
            max_current >= DIGPOT_MIN_mA || throw(ArgumentError(
                "$name: max_current = $(max_current) mA is below the lowest current the TLD001's max-current potentiometer can be set to ($(DIGPOT_MIN_mA) mA), " *
                "so power mode could not clamp this diode. Use mode = ConstantCurrent()."))
        end
        new{M}(unique_id, properties, laser_color, min_current, max_current,
            max_setcurrent, max_setpoint, serialNo, task_mod, daq,
            controller_max_current, daq_device, ao_channel, drive_current,
            threshold_current, pd)
    end
end

# The pre-0.2.5 positional arities, both building a ConstantCurrent laser: the
# fields added since sit at the end of the struct precisely so these can
# default them. Positional construction cannot build a power-mode laser; that
# needs the calibration keywords.
TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
    max_setcurrent, max_setpoint, serialNo, task_mod, daq,
    controller_max_current, daq_device, ao_channel, drive_current) =
    TCubeLaser{ConstantCurrent}(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current, NaN, nothing)

TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
    max_setcurrent, max_setpoint, serialNo, task_mod, daq) =
    TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        NaN, nothing, nothing, NaN)

LightSourceInterface.supported_modes(::Type{<:TCubeLaser}) = (ConstantCurrent, ConstantPhotocurrent)
LightSourceInterface.regulation_mode(::Type{TCubeLaser{M}}) where {M} = M()

"""
    TCubeLaser(serialNo::String; kwargs...)

Construct a `TCubeLaser` for the Kinesis device `serialNo`. Pure: it opens
nothing, so every keyword is a declaration that `initialize` and `setupIO` later
act on. The keywords match the field names documented on
[`TCubeLaser`](@ref).

`mode` defaults to `ConstantCurrent()`, which is exactly the 0.2.x behaviour, so
no existing construction line changes meaning. Closed loop is chosen explicitly
with `mode = ConstantPhotocurrent()`. The default will not change.

```julia
# 642 nm rig, closed loop. Calibration: see CALIBRATION.md beside this file.
laser = TCubeLaser("64849775";
    mode              = ConstantPhotocurrent(),
    wa_calibration    = 224.2,     # W/A, measured with a power meter before the fibre
    tia_range         = 1e-3,      # A: the rear-panel DIP switch, as set
    tec_stabilised    = missing,   # honest until checked
    threshold_current = 65.0,      # mA, from a bench sweep
    max_current       = 150.0,     # mA: programmed as the loop's clamp
    properties        = LightSourceProperties("mW", 0.0, false, 2.0, 80.0))

# The same diode in open loop.
laser = TCubeLaser("64849775"; mode = ConstantCurrent(), # mode is optional here: the default
    min_current = 70.0, max_current = 160.0)
```

In `ConstantPhotocurrent` mode `wa_calibration`, `tia_range`, `tec_stabilised`,
`max_current` and `properties` (whose `min_power`/`max_power` become the enforced mW bounds)
are required: a rig cannot reach power mode without a measured calibration, a
stated amplifier range, an answer to the temperature question and an explicit
clamp. In
`ConstantCurrent` mode passing any of the first three throws, and `properties`
defaults to `LightSourceProperties("mA", 0.0, false, min_current, max_current)`.

- `max_current` is **your** ceiling for this diode and is never overwritten. In
  `ConstantCurrent` mode it defaults to `160.0`; in `ConstantPhotocurrent` mode
  it has no default, because it is the clamp `initialize` programs and the only
  real protection while the loop raises the current by itself;
  `initialize` records the controller's own limit separately in
  `controller_max_current`, and `setcurrent!` enforces the smaller of the two.
- `min_current` defaults to `0.0`. A non-zero default would reject safe small
  currents without protecting against large ones.
"""
function TCubeLaser(serialNo::String;
    mode::RegulationMode=ConstantCurrent(),
    unique_id::String="TCubeLaser",
    properties::Union{Nothing,LightSourceProperties}=nothing,
    laser_color::String="red",
    min_current::Float64=0.0,
    max_current::Union{Nothing,Float64}=nothing, # ConstantCurrent: 160.0; 220.0 is the max of the TCube
    controller_max_current::Float64=NaN,
    max_setcurrent::Float64=220.0,
    max_setpoint::Float64=32767.0,
    task_mod=0,
    daq::NIdaq=NIdaq(),
    daq_device::Union{Nothing,String}=nothing,
    ao_channel::Union{Nothing,String}=nothing,
    drive_current::Float64=NaN,
    threshold_current::Float64=NaN,
    wa_calibration::Union{Nothing,Real}=nothing,
    tia_range::Union{Nothing,Real}=nothing,
    tec_stabilised::Union{Nothing,Bool,Missing}=nothing,
    ramp_step_mW::Union{Nothing,Real}=nothing,
    ramp_step_s::Union{Nothing,Real}=nothing,
    lock_check_s::Union{Nothing,Real}=nothing,
    lock_ratio::Union{Nothing,Real}=nothing,
)
    name = "TCubeLaser $serialNo"
    pd = if mode isa ConstantPhotocurrent
        absent = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                     :tec_stabilised => tec_stabilised, :properties => properties,
                                     :max_current => max_current) if v === nothing]
        isempty(absent) || throw(ArgumentError(
            "$name: a ConstantPhotocurrent laser needs these keywords, none of which has a default: $(join(absent, ", ")). " *
            "wa_calibration is W/A measured with a power meter at the laser output; tia_range is the rear-panel DIP switch in A; " *
            "tec_stabilised is true, false or missing; properties carries the enforced min_power/max_power in mW; " *
            "max_current is the clamp initialize programs into the controller, the only real protection in closed loop."))
        loop_kw = (; (kw => v for (kw, v) in (:ramp_step_mW => ramp_step_mW, :ramp_step_s => ramp_step_s,
                                              :lock_check_s => lock_check_s, :lock_ratio => lock_ratio) if v !== nothing)...)
        PhotodiodeLoop(; wa_calibration=wa_calibration, tia_range=tia_range, tec_stabilised=tec_stabilised, loop_kw...)
    else
        given = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                    :tec_stabilised => tec_stabilised, :ramp_step_mW => ramp_step_mW,
                                    :ramp_step_s => ramp_step_s, :lock_check_s => lock_check_s,
                                    :lock_ratio => lock_ratio) if v !== nothing]
        isempty(given) || throw(ArgumentError(
            "$name: $(join(given, ", ")) describe a photodiode loop, which only a ConstantPhotocurrent laser has; " *
            "this one is $(nameof(typeof(mode)))"))
        nothing
    end
    max_current = something(max_current, 160.0)
    props = something(properties, LightSourceProperties("mA", 0.0, false, min_current, max_current))
    TCubeLaser{typeof(mode)}(unique_id, props, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current,
        threshold_current, pd)
end
