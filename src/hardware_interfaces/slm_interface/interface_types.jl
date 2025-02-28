
"""
SLM is an abstract type for a Spatial Light Modulator.
"""
abstract type SLM <: AbstractInstrument end

"""
    Pupil

A mutable struct that represents the

# Fields
- `x_center::Float64`: The x coordinate of the center of the pupil.
- `y_center::Float64`: The y coordinate of the center of the pupil.
- `x_radius::Float64`: The x radius of the pupil.
- `y_radius::Float64`: The y radius of the pupil.
"""
mutable struct Pupil
    x_center::Float64
    y_center::Float64
    x_radius::Float64
    y_radius::Float64
end

"""
    SimSLM

A mutable struct that represents a simulated Spatial Light Modulator.

# Fields
- `width::Int`: The width of the SLM in pixels.
- `height::Int`: The height of the SLM in pixels.
- `pixelsize::Float64`: The size of a pixel in microns.
- `wavelength::Float64`: The wavelength of the light in microns.
- `phase::Array{Float64,2}`: The phase of the SLM in radians.
- `offset::Array{Float64,2}`: The offset of the SLM in radians.
- `pupil::Pupil`: The pupil of the S
"""
mutable struct SimSLM <: SLM
    width::Int
    height::Int
    pixelsize::Float64
    wavelength::Float64
    phase::Array{Float64,2}
    offset::Array{Float64,2}
    pupil::Pupil
end


