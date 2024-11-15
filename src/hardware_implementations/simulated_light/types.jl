"""
    `SimLight` A SimulatedLight type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
"""
mutable struct SimLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
end

function SimLight(;
    unique_id::String="SimLight",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0))
    SimLight(unique_id, properties)
end
