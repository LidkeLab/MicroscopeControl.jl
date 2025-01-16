
"""
    initialize(lightsource::LightSource)

Initialize the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function initialize(lightsource::LightSource)
    # initialize the lightsource
    @error "initialize not implemented"
end


"""
    setpower(lightsource::LightSource,power::Float64)

Set the power of the lightsource.

# Arguments
- `lightsource::LightSource`: A LightSource type.
- `power::Float64`: The power to set the lightsource to.
"""
function setpower(lightsource::LightSource, power::Float64)
    # set the power of the lightsource
    @error "setpower not implemented"
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
    @error "on not implemented"
end

"""
    light_off(lightsource::LightSource)

Turn off the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function light_off(lightsource::LightSource)
    # turn off the lightsource
    @error "off not implemented"
end

"""
    shutdown(lightsource::LightSource)

Shutdown the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function shutdown(lightsource::LightSource)
    # shutdown the lightsource
    @error "shutdown not implemented"
end
    
    """
        export_state(properties::LightSourceProperties)

    Export the state of the lightsource.

    # Arguments
    - `properties::LightSourceProperties`: The properties of the lightsource.

    # # Returns
    # - `attributes::Dict{String,Any}`: The attributes of the lightsource.
    # - `data::Any`: The data of the lightsource.
    # - `children::Dict{String,Any}`: The children of the lightsource.
    """
function export_state(properties::LightSourceProperties)
    # attributes = Dict("power_unit" => properties.power_unit, "power" => properties.power, "is_on" => properties.is_on, "min_power" => properties.min_power, "max_power" => properties.max_power)
    # data = nothing
    # children = Dict()
    # return attributes, data, children
    # export the state of the lightsource
    @error "export_state not implemented"
end