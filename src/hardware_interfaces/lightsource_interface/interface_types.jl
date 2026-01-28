"""
`LightSource` is an abstract type that defines the interface for a light source.
"""
abstract type LightSource <: AbstractInstrument end

"""
    LightSourceProperties

Generic properties for a light source.

# Fields
- `power_unit::String`: The unit of the power of the light source.
- `power::Float64`: The current power of the light source.
- `is_on::Bool`: Whether the light source is on or off.
- `min_power::Float64`: The minimum power of the light source.
- `max_power::Float64`: The maximum power of the light source.
"""
mutable struct LightSourceProperties
    power_unit::String
    power::Float64
    is_on::Bool
    min_power::Float64
    max_power::Float64
end