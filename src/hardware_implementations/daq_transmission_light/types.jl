
"""
    `DaqTrLight` A LaserDaqControl type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
- `daq::NIdaq`: The NIDAQ card.
- `t::Task`: The task of the NIDAQ card.
- 'min_voltage'::Float64: The minimum voltage of the laser.
- 'max_voltage'::Float64: The maximum voltage of the laser.
- 'channelsAO'::Array{String}: The channels of the NIDAQ card.
"""
mutable struct DaqTrLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
    daq::NIdaq
    min_voltage::Float64
    max_voltage::Float64
    channelsAO::Array{String}
    channelsDO::Array{String}
end


function DaqTrLight(;
    unique_id::String="DaqTrLight",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
    device_index::Int=2
    )
    daq = NIdaq()
    channelsAO = String[]
    channelsDO = String[]
    min_voltage::Float64 = 0.0
    max_voltage::Float64 = 5.0

    try
        devs = NIDAQcard.showdevices(daq)
        if length(devs) >= device_index && devs[device_index] != ""
            channelsAO = NIDAQcard.showchannels(daq, "AO", devs[device_index])
            channelsDO = NIDAQcard.showchannels(daq, "DO", devs[device_index])
        else
            @warn "NI-DAQ device index $device_index not available for DaqTrLight (found $(length(devs)) devices)"
        end
    catch e
        @warn "Failed to initialize NI-DAQ for DaqTrLight: $e"
    end

    DaqTrLight(unique_id, properties, daq, min_voltage, max_voltage, channelsAO, channelsDO)
end