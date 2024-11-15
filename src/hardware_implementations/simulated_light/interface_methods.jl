function LightSourceInterface.setpower(light::SimLight, power::Float64)
    light.properties.power = power
end

function LightSourceInterface.light_on(light::SimLight)
    light.properties.is_on = true
end

function LightSourceInterface.light_off(light::SimLight)
    light.properties.is_on = false
end

function LightSourceInterface.shutdown(light::SimLight)
    light.properties.is_on = false
end