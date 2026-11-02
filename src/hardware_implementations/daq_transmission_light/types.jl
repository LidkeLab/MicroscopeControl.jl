"""
    DaqTrLight(; daq=NIdaq(), channel=nothing, properties, ...)

A single AO line controls both level and emission. `setpower` takes volts and
stores the request while off; `light_on` applies it. The initial request is
1.0 V clamped to the voltage range. `initialize`, `light_off` and `shutdown`
write 0 V before recording off, retaining the request for the next enable.

A named `channel` skips discovery. Otherwise the legacy device/channel
selection applies. A supplied `properties` object is kept and its unit and
bounds are changed to volts (with a warning when its unit was not "V").
"""
mutable struct DaqTrLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
    daq::DAQ
    min_voltage::Float64
    max_voltage::Float64
    channelsAO::Array{String}
    channelsDO::Array{String}
    channel::String
    level_requested::Float64
    lock::ReentrantLock
end

function DaqTrLight(;
    unique_id::String="DaqTrLight",
    min_voltage=0.0, max_voltage=5.0,
    properties::LightSourceProperties=LightSourceProperties("V", 0.0, false, min_voltage, max_voltage),
    device_index::Int=2,
    daq::DAQ=NIdaq(), channel::Union{Nothing,String}=nothing)
    if channel === nothing
        channelsAO, channelsDO = NIDAQcard._light_channels(daq, unique_id, device_index)
        channel = NIDAQcard._discovered_channel(channelsAO, 1)
    else
        channelsAO, channelsDO = [channel], String[]
    end
    NIDAQcard._voltage_properties!(properties, min_voltage, max_voltage, unique_id)
    return DaqTrLight(unique_id, properties, daq, min_voltage, max_voltage,
        channelsAO, channelsDO, channel, clamp(1.0, min_voltage, max_voltage), ReentrantLock())
end
