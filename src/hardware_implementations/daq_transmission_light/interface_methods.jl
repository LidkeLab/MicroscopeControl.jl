function initialize(light::DaqTrLight)
    return nothing
end

function LightSourceInterface.setpower(light::DaqTrLight, voltage::Float64)
    daq = light.daq
    min_voltage = light.min_voltage
    max_voltage = light.max_voltage
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    if voltage < light.min_voltage || voltage > light.max_voltage
        @error "The voltage should be between $(light.min_voltage) and $(light.max_voltage)"
        return
    end
    t = NIDAQcard.createtask(daq,"AO",channelsAO[1])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.light_on(light::DaqTrLight)
    light.properties.is_on = true
    # power = 20.0
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    # voltage = (power-10)/90*(light.max_voltage-light.min_voltage)+light.min_voltage
    # light.properties.power = power
    voltage = 1.0
    daq = light.daq
    t = NIDAQcard.createtask(daq,"AO",light.channelsAO[1])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.light_off(light::DaqTrLight)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    voltage::Float64 = 0.0
    t = NIDAQcard.createtask(daq,"AO",light.channelsAO[1])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

function shutdown(light::DaqTrLight)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    voltage::Float64 = 0.0
    t = NIDAQcard.createtask(daq,"AO",light.channelsAO[1])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
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