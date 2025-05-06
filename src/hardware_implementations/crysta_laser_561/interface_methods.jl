"""
    initialize(light::CrystaLaser)
"""
function initialize(light::CrystaLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    return nothing
end

"""
    setpower(light::CrystaLaser, voltage::Float64)

Set the power of the laser by setting the voltage of the NIDAQ card.

# Arguments
- `light::CrystaLaser`: The laser to set the power of.
- `voltage::Float64`: The voltage to set the laser to.
"""
function LightSourceInterface.setpower(light::CrystaLaser, voltage::Float64)
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

"""
    light_on(light::CrystaLaser)
"""
function LightSourceInterface.light_on(light::CrystaLaser)
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

"""
    light_off(light::CrystaLaser)
"""
function LightSourceInterface.light_off(light::CrystaLaser)
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
    shutdown(light::CrystaLaser)
"""
function shutdown(light::CrystaLaser)
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
    export_state(light::CrystaLaser)
"""
function export_state(light::CrystaLaser)
    attributes = Dict{String, Any}(
        "unique_id" => light.unique_id,
        "laser_color" => light.laser_color,
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
        "channels_AO" => copy(light.channelsAO),
        "channels_DO" => copy(light.channelsDO)
    )
    
    data = nothing
    
    # Include the DAQ state as a child component
    children = Dict{String, Any}(
        "daq" => export_state(light.daq)
    )

    return attributes, data, children
end