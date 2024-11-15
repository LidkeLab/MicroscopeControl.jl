function LightSourceInterface.initialize(light::CrystaLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    return nothing
end

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

function LightSourceInterface.shutdown(light::CrystaLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    voltage::Float64 = 0.0
    t = NIDAQcard.createtask(daq,"AO",light.channelsAO[1])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

# function createt(light::CrystaLaser)
#     if light.laser_color == "488"
#         j = 1
#     elseif light.laser_color == "561"
#         j = 2
#     end
#     t = NIDAQcard.createtask(light.daq,"AO",light.channelsAO[j])
#     return t
# end