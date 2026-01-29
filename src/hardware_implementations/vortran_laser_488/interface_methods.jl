"""
    initialize(light::VortranLaser)
"""
function initialize(light::VortranLaser)
    light.properties.is_on = false
    if length(light.channelsDO) < 12
        @warn "VortranLaser: insufficient DO channels for initialization"
        return nothing
    end
    try
        td = NIDAQcard.createtask(light.daq, "DO", light.channelsDO[12])
        NIDAQcard.setvoltage(light.daq, td, 0.0)
        NIDAQcard.deletetask(light.daq, td)
    catch e
        @warn "VortranLaser initialization failed: $e"
    end
    return nothing
end

"""
    setpower(light::VortranLaser, voltage::Float64)
"""
function LightSourceInterface.setpower(light::VortranLaser, voltage::Float64)
    if length(light.channelsAO) < 2
        @warn "VortranLaser: insufficient AO channels for setpower"
        return
    end
    if voltage < light.min_voltage || voltage > light.max_voltage
        @error "The voltage should be between $(light.min_voltage) and $(light.max_voltage)"
        return
    end
    try
        t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[2])
        NIDAQcard.setvoltage(light.daq, t, voltage)
        NIDAQcard.deletetask(light.daq, t)
    catch e
        @warn "VortranLaser setpower failed: $e"
    end
end

"""
    light_on(light::VortranLaser)
"""
function LightSourceInterface.light_on(light::VortranLaser)
    light.properties.is_on = true
    if length(light.channelsDO) < 12
        @warn "VortranLaser: insufficient DO channels for light_on"
        return
    end
    try
        td = NIDAQcard.createtask(light.daq, "DO", light.channelsDO[12])
        NIDAQcard.setvoltage(light.daq, td, 8.0)
        NIDAQcard.deletetask(light.daq, td)
    catch e
        @warn "VortranLaser light_on failed: $e"
    end
end

"""
    light_off(light::VortranLaser)
"""
function LightSourceInterface.light_off(light::VortranLaser)
    light.properties.is_on = false
    if length(light.channelsDO) < 12
        @warn "VortranLaser: insufficient DO channels for light_off"
        return
    end
    try
        td = NIDAQcard.createtask(light.daq, "DO", light.channelsDO[12])
        NIDAQcard.setvoltage(light.daq, td, 0.0)
        NIDAQcard.deletetask(light.daq, td)
    catch e
        @warn "VortranLaser light_off failed: $e"
    end
end

"""
    shutdown(light::VortranLaser)
"""
function shutdown(light::VortranLaser)
    light.properties.is_on = false
    try
        if length(light.channelsDO) >= 12
            td = NIDAQcard.createtask(light.daq, "DO", light.channelsDO[12])
            NIDAQcard.setvoltage(light.daq, td, 0.0)
            NIDAQcard.deletetask(light.daq, td)
        end
        if length(light.channelsAO) >= 2
            t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[2])
            NIDAQcard.setvoltage(light.daq, t, 0.0)
            NIDAQcard.deletetask(light.daq, t)
        end
    catch e
        @warn "VortranLaser shutdown failed: $e"
    end
end

"""
    export_state(light::VortranLaser)
"""
function export_state(light::VortranLaser)
    attributes = Dict(
                     "unique_id" => light.unique_id, 
                     "laser_color" => light.laser_color,
                     "min_voltage" => light.min_voltage, 
                     "max_voltage" => light.max_voltage,
                     "power_unit" => light.properties.power_unit, 
                     "power" => light.properties.power, 
                     "is_on" => light.properties.is_on,
                     "min_power" => light.properties.min_power, 
                     "max_power" => light.properties.max_power,
                     "channelsAO" => light.channelsAO,
                     "channelsDO" => light.channelsDO
                     )
    data = nothing
    children = Dict(
        "daq" => export_state(light.daq)
        )

    return attributes, data, children
end