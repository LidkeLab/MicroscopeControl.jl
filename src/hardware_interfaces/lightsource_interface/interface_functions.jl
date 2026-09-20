
"""
    setpower(lightsource::LightSource,power::Float64)

Set the power of the lightsource.

# Arguments
- `lightsource::LightSource`: A LightSource type.
- `power::Float64`: The power to set the lightsource to.
"""
function setpower(lightsource::LightSource, power::Float64)
    # set the power of the lightsource
    error("setpower not implemented for $(typeof(lightsource))")
end

"""
    light_on(lightsource::LightSource)

Turn on the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
- `ipower::Float64`: The initial power of the light source.
"""
function light_on(lightsource::LightSource, ipower::Float64)
    # turn on the lightsource
    error("light_on not implemented for $(typeof(lightsource))")
end

"""
    light_off(lightsource::LightSource)

Turn off the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function light_off(lightsource::LightSource)
    # turn off the lightsource
    error("light_off not implemented for $(typeof(lightsource))")
end
