"""
    VortranLaser(; daq=NIdaq(), ao_channel=nothing, do_channel=nothing, properties, ...)

The AO line sets the requested level in volts; the DO line enables emission.
Named channels skip discovery for those outputs. Unnamed channels retain the
legacy selection: device 1, AO index 2, DO index 12. The initial AO request is
`NaN` (unknown); `initialize` only disables DO. `shutdown` attempts both DO 0
and AO 0, recording each successful command and reporting every failure.

A supplied `properties` object is kept and its unit and bounds are changed to
volts, with a warning when its unit was not "V".
"""
mutable struct VortranLaser <: LightSource
    unique_id::String
    properties::LightSourceProperties
    laser_color::String
    daq::DAQ
    min_voltage::Float64
    max_voltage::Float64
    channelsAO::Array{String}
    channelsDO::Array{String}
    ao_channel::String
    do_channel::String
    level_requested::Float64
    lock::ReentrantLock
end

function VortranLaser(;
    unique_id::String="VortranLaser",
    min_voltage=0.0, max_voltage=5.0,
    properties::LightSourceProperties=LightSourceProperties("V", 0.0, false, min_voltage, max_voltage),
    laser_color::String="488", daq::DAQ=NIdaq(),
    ao_channel::Union{Nothing,String}=nothing, do_channel::Union{Nothing,String}=nothing)
    channelsAO, channelsDO = NIDAQcard._light_channels(daq, unique_id, 1; ao=ao_channel, do_line=do_channel)
    ao_channel === nothing && (ao_channel = NIDAQcard._discovered_channel(channelsAO, 2))
    do_channel === nothing && (do_channel = NIDAQcard._discovered_channel(channelsDO, 12))
    NIDAQcard._voltage_properties!(properties, min_voltage, max_voltage, unique_id)
    return VortranLaser(unique_id, properties, laser_color, daq, min_voltage, max_voltage,
        channelsAO, channelsDO, ao_channel, do_channel, NaN, ReentrantLock())
end
