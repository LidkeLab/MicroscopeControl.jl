
"""
    `TCubeLaser` A TCubeLaserControl type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
  `power_unit` defaults to `"mW"` and `power` holds a **derived, uncalibrated**
  figure -- see the note below; `drive_current` is the field that holds what
  was actually commanded.
- `laser_color::String`: The color of the laser.
- `min_current::Float64`: Lower bound accepted by `setpower`, in mA. Defaults
  to `0.0`; set it to a diode-specific floor if the diode has one. It is a
  *lower* bound, so it protects nothing on its own -- the ceiling does.
- `max_current::Float64`: The caller's current ceiling in mA, i.e. the rig's
  own limit for this diode. `initialize` does **not** overwrite it (it writes
  `controller_max_current` instead), so a ceiling passed here survives
  initialization and keeps constraining `setpower`.
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
- `drive_current::Float64`: The drive current in mA that `setpower` last
  accepted, and the only field here that reports what was commanded. `NaN`
  before the first successful `setpower`.

The first ten fields are in the order they have always been in, so positional
construction from before v0.2.3 still works; the four added fields are at the
end and an inner constructor taking the old ten defaults them.

# `properties.power` is an uncalibrated guess (deprecated)

`power` is `current * properties.max_power / <controller limit>`, a linear
current-to-power model this driver has no way to measure, and the bench
measurements preserved as a comment in `TCubeLaserControl.jl` contradict it.
The controller reports no optical power in the open-loop mode this driver
uses. `power`/`power_unit` are kept for compatibility, are **deprecated**, and
are scheduled for removal in 0.3.0. Read `drive_current` instead, which is the
number the driver actually acted on.

`setpower` validates against the *smallest* of `min_current`'s counterparts:
`max_current`, `controller_max_current` (ignored while `NaN`) and
`max_setcurrent`. See [`check_current`](@ref).
"""
mutable struct TCubeLaser <: LightSource
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

    function TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current)
        new(unique_id, properties, laser_color, min_current, max_current,
            max_setcurrent, max_setpoint, serialNo, task_mod, daq,
            controller_max_current, daq_device, ao_channel, drive_current)
    end

    # The pre-v0.2.3 positional arity. The four fields added since are at the
    # end of the struct precisely so this can default them, and so a caller
    # that built one of these positionally does not have to be rewritten to
    # receive the safety fixes.
    function TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq)
        new(unique_id, properties, laser_color, min_current, max_current,
            max_setcurrent, max_setpoint, serialNo, task_mod, daq,
            NaN, nothing, nothing, NaN)
    end
end


"""
    TCubeLaser(serialNo::String; kwargs...)

Construct a `TCubeLaser` for the Kinesis device `serialNo`. Pure: it opens
nothing, so every keyword below is a declaration of intent that `initialize`
and `setupIO` later act on.

The keywords match the field names documented on [`TCubeLaser`](@ref). The two
worth stating here:

- `max_current` is **your** ceiling for this diode and is never overwritten;
  `initialize` records the controller's own limit separately in
  `controller_max_current`, and `setpower` enforces the smaller of the two.
- `min_current` defaults to `0.0`. A non-zero default would reject safe small
  currents without protecting against large ones.

`setpower` takes a drive **current in mA**, despite the interface name, and
records it in `drive_current`. `properties.power_unit` defaults to `"mW"` and
`properties.power` to the derived linear guess described on
[`TCubeLaser`](@ref); both are deprecated and unreliable, and neither is
checked or enforced.
"""
function TCubeLaser(serialNo::String;
    unique_id::String="TCubeLaser",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
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
    drive_current::Float64=NaN
)
    TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
        max_setcurrent, max_setpoint, serialNo, task_mod, daq,
        controller_max_current, daq_device, ao_channel, drive_current)
end
