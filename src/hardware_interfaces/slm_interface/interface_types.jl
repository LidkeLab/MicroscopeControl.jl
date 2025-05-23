

abstract type SLM end

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

