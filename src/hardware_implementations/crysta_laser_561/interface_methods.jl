"""
    initialize(light::CrystaLaser)
"""
function initialize(light::CrystaLaser)
    light.properties.is_on = false
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
    if isempty(light.channelsAO)
        @warn "CrystaLaser: no AO channels available for setpower"
        return
    end
    if voltage < light.min_voltage || voltage > light.max_voltage
        @error "The voltage should be between $(light.min_voltage) and $(light.max_voltage)"
        return
    end
    try
        t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
        NIDAQcard.setvoltage(light.daq, t, voltage)
        NIDAQcard.deletetask(light.daq, t)
    catch e
        @warn "CrystaLaser setpower failed: $e"
    end
end

"""
    light_on(light::CrystaLaser)
"""
function LightSourceInterface.light_on(light::CrystaLaser)
    light.properties.is_on = true
    if isempty(light.channelsAO)
        @warn "CrystaLaser: no AO channels available for light_on"
        return
    end
    try
        t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
        NIDAQcard.setvoltage(light.daq, t, 1.0)
        NIDAQcard.deletetask(light.daq, t)
    catch e
        @warn "CrystaLaser light_on failed: $e"
    end
end

"""
    light_off(light::CrystaLaser)
"""
function LightSourceInterface.light_off(light::CrystaLaser)
    light.properties.is_on = false
    if isempty(light.channelsAO)
        @warn "CrystaLaser: no AO channels available for light_off"
        return
    end
    try
        t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
        NIDAQcard.setvoltage(light.daq, t, 0.0)
        NIDAQcard.deletetask(light.daq, t)
    catch e
        @warn "CrystaLaser light_off failed: $e"
    end
end

"""
    shutdown(light::CrystaLaser)
"""
function shutdown(light::CrystaLaser)
    light.properties.is_on = false
    if isempty(light.channelsAO)
        return
    end
    try
        t = NIDAQcard.createtask(light.daq, "AO", light.channelsAO[1])
        NIDAQcard.setvoltage(light.daq, t, 0.0)
        NIDAQcard.deletetask(light.daq, t)
    catch e
        @warn "CrystaLaser shutdown failed: $e"
    end
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