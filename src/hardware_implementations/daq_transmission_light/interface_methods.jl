function initialize(light::DaqTrLight)
    return nothing
end

function LightSourceInterface.setpower(light::DaqTrLight, voltage::Float64)
    if isempty(light.channelsAO)
        @warn "No AO channels available for DaqTrLight"
        return
    end
    if voltage < light.min_voltage || voltage > light.max_voltage
        @error "The voltage should be between $(light.min_voltage) and $(light.max_voltage)"
        return
    end
    t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
    NIDAQcard.setvoltage(light.daq, t, voltage)
    NIDAQcard.deletetask(light.daq, t)
end

function LightSourceInterface.light_on(light::DaqTrLight)
    light.properties.is_on = true
    if isempty(light.channelsAO)
        @warn "No AO channels available for DaqTrLight"
        return
    end
    voltage = 1.0
    t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
    NIDAQcard.setvoltage(light.daq, t, voltage)
    NIDAQcard.deletetask(light.daq, t)
end

function LightSourceInterface.light_off(light::DaqTrLight)
    light.properties.is_on = false
    if isempty(light.channelsAO)
        @warn "No AO channels available for DaqTrLight"
        return
    end
    voltage::Float64 = 0.0
    t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
    NIDAQcard.setvoltage(light.daq, t, voltage)
    NIDAQcard.deletetask(light.daq, t)
end

function shutdown(light::DaqTrLight)
    light.properties.is_on = false
    if isempty(light.channelsAO)
        return
    end
    voltage::Float64 = 0.0
    t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
    NIDAQcard.setvoltage(light.daq, t, voltage)
    NIDAQcard.deletetask(light.daq, t)
end

"""
    export_state(light::DaqTrLight)
"""
function export_state(light::DaqTrLight)
    attributes = Dict{String, Any}(
        "unique_id" => light.unique_id,
        # Light source properties
        "power_unit" => light.properties.power_unit, 
        "power" => light.properties.power, 
        "is_on" => light.properties.is_on,
        "min_power" => light.properties.min_power, 
        "max_power" => light.properties.max_power,
        # DAQ control parameters
        "min_voltage" => light.min_voltage,
        "max_voltage" => light.max_voltage,
        # DAQ channels
        "channels_AO" => copy(light.channelsAO),  # Analog output channels
        "channels_DO" => copy(light.channelsDO)   # Digital output channels
    )
    
    data = nothing
    
    # Include the DAQ state as a child component
    children = Dict{String, Any}(
        "daq" => export_state(light.daq)
    )

    return attributes, data, children
end