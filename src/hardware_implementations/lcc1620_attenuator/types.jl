
"""
    `LCC1620` A Thorlabs LCC1620/M liquid crystal attenuator inherited from `Attenuator`,
driven through a NIDAQ card analog output channel.

# Fields
- `unique_id::String`: A unique identifier for the attenuator.
- `properties::AttenuatorProperties`: The properties of the attenuator.
- `daq::NIdaq`: The NIDAQ card.
- `ao_channel::String`: The analog output channel driving the attenuator (e.g. "Dev2/ao1").
- `task::Union{Nothing, DAQmx.AOTask}`: The persistent analog output task, created by `initialize`.
"""
mutable struct LCC1620 <: Attenuator
    unique_id::String
    properties::AttenuatorProperties
    daq::NIdaq
    ao_channel::String
    task::Union{Nothing, DAQmx.AOTask}
end

function LCC1620(;
    unique_id::String="LCC1620",
    device_index::Int=2,
    ao_channel_index::Int=2,
    ao_channel::String="",
    min_voltage::Float64=0.0,
    max_voltage::Float64=5.0
    )
    daq = NIdaq()
    properties = AttenuatorProperties(0.0, NaN, min_voltage, max_voltage, Float64[], Float64[])

    if isempty(ao_channel)
        try
            devs = NIDAQcard.showdevices(daq)
            if length(devs) >= device_index && devs[device_index] != ""
                channelsAO = NIDAQcard.showchannels(daq, "AO", devs[device_index])
                if length(channelsAO) >= ao_channel_index
                    ao_channel = channelsAO[ao_channel_index]
                else
                    @warn "AO channel index $ao_channel_index not available for LCC1620 (found $(length(channelsAO)) channels)"
                end
            else
                @warn "NI-DAQ device index $device_index not available for LCC1620 (found $(length(devs)) devices)"
            end
        catch e
            @warn "Failed to initialize NI-DAQ for LCC1620: $e"
        end
    end

    LCC1620(unique_id, properties, daq, ao_channel, nothing)
end
