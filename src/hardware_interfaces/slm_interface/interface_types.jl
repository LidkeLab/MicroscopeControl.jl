

"""
    SLM

Abstract type for a spatial light modulator. Unlike the other device classes it is not a subtype of
`AbstractInstrument`. Its one driver is `MLSLM` (Meadowlark).
"""
abstract type SLM end

"""
    Pupil(x_center, y_center, x_radius, y_radius)

The pupil an SLM pattern is meant for: center and radii, all `Float64`. `MLSLM` stores one in its `pupil` field
and writes it in `export_state`; no pattern generator reads it (`genzernike!` takes its own center and radius).
"""
mutable struct Pupil
    x_center::Float64
    y_center::Float64
    x_radius::Float64
    y_radius::Float64
end


#=
mutable struct SimSLM <: SLM
    width::Int
    height::Int
    pixelsize::Float64
    wavelength::Float64
    phase::Array{Float64,2}
    offset::Array{Float64,2}
    pupil::Pupil
end
=#

