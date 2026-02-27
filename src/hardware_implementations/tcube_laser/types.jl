
"""
    `TCubeLaser` A TCubeLaserControl type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
- `laser_color::String`: The color of the laser.
- `min_current`::Float64: The minimum current of the laser Controller.
- `max_current`::Float64: The maximum current of the laser Controller.
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
end


function TCubeLaser(serialNo::String;
    unique_id::String="TCubeLaser",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
    laser_color::String="red",
    min_current::Float64=60.0,
    max_current::Float64=160.0, #220.0 is the max of the TCube
    max_setcurrent::Float64=220.0,
    max_setpoint::Float64=32767.0,
    task_mod=0,
    daq::NIdaq=NIdaq()
)

    TCubeLaser(unique_id, properties, laser_color, min_current, max_current, max_setcurrent, max_setpoint, serialNo, task_mod, daq)
end