function LightSourceInterface.setpower(light::SimLight, power::Float64)
    light.properties.power = power
end

function LightSourceInterface.light_on(light::SimLight)
    light.properties.is_on = true
end

function LightSourceInterface.light_off(light::SimLight)
    light.properties.is_on = false
end

function initialize(light::SimLight)
    light.properties.is_on = true
end

function shutdown(light::SimLight)
    light.properties.is_on = false
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

    return attributes, data, children
end