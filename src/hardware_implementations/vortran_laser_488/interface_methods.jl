function LightSourceInterface.initialize(light::VortranLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    td = NIDAQcard.createtask(daq,"DO",channelsDO[12])
    NIDAQcard.setvoltage(daq,td, 0.0)
    NIDAQcard.deletetask(daq,td)
    return nothing
end

function LightSourceInterface.setpower(light::VortranLaser, voltage::Float64)
    daq = light.daq
    min_voltage = light.min_voltage
    max_voltage = light.max_voltage
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    if voltage < light.min_voltage || voltage > light.max_voltage
        @error "The voltage should be between $(light.min_voltage) and $(light.max_voltage)"
        return
    end
    t = NIDAQcard.createtask(daq,"AO",channelsAO[2])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.light_on(light::VortranLaser)
    light.properties.is_on = true
    # power = 20.0
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    # voltage = (power-10)/90*(light.max_voltage-light.min_voltage)+light.min_voltage
    # light.properties.power = power
    voltage = 1.0
    daq = light.daq
    td = NIDAQcard.createtask(daq,"DO",channelsDO[12])
    NIDAQcard.setvoltage(daq,td, 8.0)
    NIDAQcard.deletetask(daq,td)
    # t = NIDAQcard.createtask(daq,"AO",light.channelsAO[2])
    # NIDAQcard.setvoltage(daq,t, voltage)
    # NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.light_off(light::VortranLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    voltage::Float64 = 0.0
    td = NIDAQcard.createtask(daq,"DO",channelsDO[12])
    NIDAQcard.setvoltage(daq,td, 0.0)
    NIDAQcard.deletetask(daq,td)
    # t = NIDAQcard.createtask(daq,"AO",light.channelsAO[2])
    # NIDAQcard.setvoltage(daq,t, voltage)
    # NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.shutdown(light::VortranLaser)
    light.properties.is_on = false
    daq = light.daq
    channelsAO = light.channelsAO
    channelsDO = light.channelsDO
    voltage::Float64 = 0.0
    td = NIDAQcard.createtask(daq,"DO",channelsDO[12])
    NIDAQcard.setvoltage(daq,td, 0.0)
    NIDAQcard.deletetask(daq,td)
    t = NIDAQcard.createtask(daq,"AO",light.channelsAO[2])
    NIDAQcard.setvoltage(daq,t, voltage)
    NIDAQcard.deletetask(daq,t)
end

function LightSourceInterface.export_state(light::VortranLaser)

    attributes = Dict(
                     "unique_id" => light.unique_id, "laser_color" => light.laser_color, "serialNo" => light.serialNo,
                     "min_current" => light.min_current, "max_current" => light.max_current,
                     "max_setcurrent" => light.max_setcurrent, "max_setpoint" => light.max_setpoint,
                     "power_unit" => light.properties.power_unit, "power" => light.properties.power, "is_on" => light.properties.is_on,
                     "min_power" => light.properties.min_power, "max_power" => light.properties.max_power
                     )
    data = nothing
    children = Dict(
        "daq" => DAQInterface.export_state(light.daq)
        )

    return attributes, data, children
end

# function createt(light::VortranLaser)
#     if light.laser_color == "488"
#         j = 1
#     elseif light.laser_color == "561"
#         j = 2
#     end
#     t = NIDAQcard.createtask(light.daq,"AO",light.channelsAO[j])
#     return t
# end