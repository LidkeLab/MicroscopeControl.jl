"""
    DaqTrLight(; daq=NIdaq(), channel=nothing, properties, ...)

A single AO line controls both level and emission. `setpower` takes volts and
stages the request unless `line_enabled` permits a write. The next successful
`light_on` applies a staged request and clears `level_staged`. With no staged request, `light_on` writes 1.0 V clamped
to the voltage range and records that default. `initialize`, `light_off` and
`shutdown` write 0 V before recording off. All preserve the requested level
(initially `NaN`); only `light_off` preserves a pending stage. A failed off
records possible emission (`is_on = true`) but revokes permission to write
levels (`line_enabled = false`).

A named `channel` skips discovery. Otherwise the legacy device/channel
selection applies. Default properties use volts and the voltage bounds. A
supplied `properties` object is kept unchanged; accepted commands update its
`power` only when its unit is "V".
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
    level_staged::Bool
    line_enabled::Bool
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
    return DaqTrLight(unique_id, properties, daq, min_voltage, max_voltage,
        channelsAO, channelsDO, channel, NaN, false, false, ReentrantLock())
end
