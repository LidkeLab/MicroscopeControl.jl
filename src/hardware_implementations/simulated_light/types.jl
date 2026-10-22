"""
    `SimLight` A SimulatedLight type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
- `modulator::Union{Nothing,AbstractModulationControl}`: What puts the level on the light's output, or `nothing`
  (the default: every method runs as it always did). With one, `initialize` opens it and leaves the light OFF (a
  light without one is on after `initialize`), `light_on` writes level 0, then the recorded `properties.power`,
  `light_off` and `shutdown` write 0 first, and `setpower` records and writes the level only while the light is
  on. An `ArgumentError` from the modulator changes nothing; any other throw darkens the light and is rethrown.
  `SimLight` is the plain-`setpower` reference for the convention in [`LightSource`](@ref).
"""
mutable struct SimLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
    const modulator::Union{Nothing,AbstractModulationControl}
end

SimLight(unique_id::String, properties::LightSourceProperties) = SimLight(unique_id, properties, nothing)

function SimLight(;
    unique_id::String="SimLight",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
    modulator::Union{Nothing,AbstractModulationControl}=nothing)
    SimLight(unique_id, properties, modulator)
end
