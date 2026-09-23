
"""
    `TCubeLaser` A TCubeLaserControl type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
  `power_unit` is `"mA"` and `power` holds the **drive current in mA** that
  was last accepted by `setpower`, not an optical power: this controller
  drives the diode in open-loop current mode and the driver has no
  calibrated way to convert that to milliwatts.
- `laser_color::String`: The color of the laser.
- `min_current::Float64`: Lower bound accepted by `setpower`, in mA. Defaults
  to `0.0`; set it to a diode-specific floor if the diode has one. It is a
  *lower* bound, so it protects nothing on its own -- the ceiling does.
- `max_current::Float64`: The caller's current ceiling in mA, i.e. the rig's
  own limit for this diode. `initialize` does **not** overwrite it (it writes
  `controller_max_current` instead), so a ceiling passed here survives
  initialization and keeps constraining `setpower`.
- `controller_max_current::Float64`: The controller's own diode current limit
  in mA, read from `LD_GetLaserDiodeMaxCurrentLimit` by `initialize`. `NaN`
  until `initialize` runs.
- `max_setcurrent::Float64`: Full-scale current of the setpoint DAC, in mA.
- `max_setpoint::Float64`: Full-scale value of the setpoint DAC.
- `serialNo::String`: Thorlabs Kinesis serial number of the controller.
- `task_mod`: The NI-DAQmx task driving the analogue modulation input, or `0`
  before `setupIO` runs.
- `daq::NIdaq`: The DAQ carrying that modulation channel.
- `daq_device::Union{Nothing,String}`: DAQ device name `setupIO` should use.
  `nothing` keeps the historical discovery behaviour (see `setupIO`).
- `ao_channel::Union{Nothing,String}`: AO channel name `setupIO` should use.
  `nothing` keeps the historical discovery behaviour (see `setupIO`).

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
    controller_max_current::Float64
    max_setcurrent::Float64
    max_setpoint::Float64
    serialNo::String
    task_mod
    daq::NIdaq
    daq_device::Union{Nothing,String}
    ao_channel::Union{Nothing,String}
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

`properties.power_unit` must be `"mA"`; passing properties labelled anything
else throws an `ArgumentError`. The label is not decoration: `setpower` accepts
a drive current and `properties.power` stores that current, so a `"mW"` label
would put milliamps under a milliwatt name and carry it into `export_state` and
the saved HDF5 attributes.

This check is the earliest of three, not the only one. `properties` is mutable
and may be a reference the caller keeps, and the positional constructor
generated for the struct does not come through here at all, so the invariant is
re-checked at `setpower` and `export_state`. See [`check_power_unit`](@ref).
"""
function TCubeLaser(serialNo::String;
    unique_id::String="TCubeLaser",
    properties::LightSourceProperties=LightSourceProperties("mA", 0.0, false, 0.0, 100.0),
    laser_color::String="red",
    min_current::Float64=0.0,
    max_current::Float64=160.0, #220.0 is the max of the TCube
    controller_max_current::Float64=NaN,
    max_setcurrent::Float64=220.0,
    max_setpoint::Float64=32767.0,
    task_mod=0,
    daq::NIdaq=NIdaq(),
    daq_device::Union{Nothing,String}=nothing,
    ao_channel::Union{Nothing,String}=nothing
)
    check_power_unit(properties.power_unit, serialNo)

    TCubeLaser(unique_id, properties, laser_color, min_current, max_current,
        controller_max_current, max_setcurrent, max_setpoint, serialNo, task_mod,
        daq, daq_device, ao_channel)
end
