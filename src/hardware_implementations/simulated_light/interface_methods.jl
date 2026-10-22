function LightSourceInterface.setpower(light::SimLight, power::Float64)
    if light.modulator !== nothing
        # While on, the level goes to the modulator first, so an ArgumentError (or any throw) leaves the record as it was.
        light.properties.is_on && apply_level!(light, power, () -> (light.properties.is_on = false))
    end
    light.properties.power = power
end

function LightSourceInterface.light_on(light::SimLight)
    if light.modulator !== nothing
        try
            setpower(light.modulator, 0.0)   # level 0 before the enable: a throw enables nothing
        catch
            light.properties.is_on = false
            rethrow()
        end
        light.properties.is_on = true
        apply_level!(light, light.properties.power, () -> (light.properties.is_on = false); darken_argument_errors=true)   # enabled already: every throw darkens
        return nothing
    end
    light.properties.is_on = true
end

function LightSourceInterface.light_off(light::SimLight)
    light.modulator === nothing && return (light.properties.is_on = false)
    zerr = zero_modulator!(light)
    light.properties.is_on = false
    propagate_interrupt(zerr)   # an interrupted 0 V write passes on only after the switch-off
    return false
end

function initialize(light::SimLight)
    if light.modulator !== nothing
        light.properties.is_on = false   # the output is off, the modulator at 0 V
        open_modulator!(light)
        return nothing
    end
    light.properties.is_on = true
end

function shutdown(light::SimLight)
    light.modulator === nothing && return (light.properties.is_on = false)
    zerr = zero_modulator!(light)
    light.properties.is_on = false
    try
        close_modulator!(light)
    finally
        propagate_interrupt(zerr)
    end
    return nothing
end

"""
    export_state(light::SimLight)
"""
function export_state(light::SimLight)
    attributes = Dict{String, Any}(
        "unique_id" => light.unique_id,
        "power_unit" => light.properties.power_unit, 
        "power" => light.properties.power, 
        "is_on" => light.properties.is_on,
        "min_power" => light.properties.min_power, 
        "max_power" => light.properties.max_power
    )
    
    data = nothing
    children = Dict{String, Any}()
    light.modulator === nothing || (children["modulator"] = export_state(light.modulator))

    return attributes, data, children
end