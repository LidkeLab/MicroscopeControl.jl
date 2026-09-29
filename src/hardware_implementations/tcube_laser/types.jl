
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

`setpower` is not defined for this type (it throws): it took mA while its
name and `properties.power_unit` said mW, and flipping the mode would have
turned an 80 mA call into an 80 mW one without a word.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: `is_on` is the requested output state. In
  `ConstantPhotocurrent` mode `min_power`/`max_power` are the ENFORCED bounds of
  `setoutputpower!`, in mW at the laser output, and the endpoints of
  `setlevel!`. In `ConstantCurrent` mode they are not read; `power` and
  `power_unit` are not written by this driver in either mode.
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
two added in 0.3.0 are at the end, so the pre-0.3.0 positional forms still
construct: they build a `TCubeLaser{ConstantCurrent}` with both defaulted.
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

# The pre-0.3.0 positional arities, both building a ConstantCurrent laser: the
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
    TCubeLaser(serialNo::String; mode, kwargs...)

Construct a `TCubeLaser` for the Kinesis device `serialNo`. Pure: it opens
nothing, so every keyword is a declaration that `initialize` and `setupIO` later
act on. The keywords match the field names documented on
[`TCubeLaser`](@ref).

`mode` is **required**, with no default: `ConstantCurrent()` or
`ConstantPhotocurrent()`. It is required rather than defaulted until closed loop
has been verified on hardware, so that no existing construction line changes
meaning silently.

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
laser = TCubeLaser("64849775"; mode = ConstantCurrent(), min_current = 70.0, max_current = 160.0)
```

In `ConstantPhotocurrent` mode `wa_calibration`, `tia_range`, `tec_stabilised`
and `properties` (whose `min_power`/`max_power` become the enforced mW bounds)
are required: a rig cannot reach power mode without a measured calibration, a
stated amplifier range and an answer to the temperature question. In
`ConstantCurrent` mode passing any of the first three throws, and `properties`
defaults to `LightSourceProperties("mA", 0.0, false, min_current, max_current)`.

- `max_current` is **your** ceiling for this diode and is never overwritten;
  `initialize` records the controller's own limit separately in
  `controller_max_current`, and `setcurrent!` enforces the smaller of the two.
- `min_current` defaults to `0.0`. A non-zero default would reject safe small
  currents without protecting against large ones.
"""
function TCubeLaser(serialNo::String;
    mode::Union{Nothing,RegulationMode}=nothing,
    unique_id::String="TCubeLaser",
    properties::Union{Nothing,LightSourceProperties}=nothing,
    laser_color::String="red",
    min_current::Float64=0.0,
    max_current::Float64=160.0, #220.0 is the max of the TCube
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
)
    name = "TCubeLaser $serialNo"
    mode === nothing && throw(ArgumentError(
        "$name: the `mode` keyword is required: ConstantCurrent() (open loop, setcurrent! in mA) or " *
        "ConstantPhotocurrent() (closed loop, setoutputpower! in mW, needs wa_calibration, tia_range, tec_stabilised and properties). " *
        "There is no default, so no construction line changes meaning when one is chosen."))
    pd = if mode isa ConstantPhotocurrent
        absent = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                     :tec_stabilised => tec_stabilised, :properties => properties) if v === nothing]
        isempty(absent) || throw(ArgumentError(
            "$name: a ConstantPhotocurrent laser needs these keywords, none of which has a default: $(join(absent, ", ")). " *
            "wa_calibration is W/A measured with a power meter at the laser output; tia_range is the rear-panel DIP switch in A; " *
            "tec_stabilised is true, false or missing; properties carries the enforced min_power/max_power in mW."))
        PhotodiodeLoop(; wa_calibration=wa_calibration, tia_range=tia_range, tec_stabilised=tec_stabilised)
    else
        given = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                    :tec_stabilised => tec_stabilised) if v !== nothing]
        isempty(given) || throw(ArgumentError(
            "$name: $(join(given, ", ")) describe a photodiode loop, which only a ConstantPhotocurrent laser has; " *
            "this one is $(nameof(typeof(mode)))"))
        nothing
    end
    props = something(properties, LightSourceProperties("mA", 0.0, false, min_current, max_current))
    TCubeLaser{typeof(mode)}(unique_id, props, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current,
        threshold_current, pd)
end
