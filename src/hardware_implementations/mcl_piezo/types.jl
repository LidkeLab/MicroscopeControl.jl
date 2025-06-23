"""
    `Piezo` is a mutable struct inhereted from `Zpositioner`. It is used to control the Z-positioner of a microscope 
    using a Mad City Labs peizo positioner and a Nano-Drive.
# Feilds
    -   

"""
Base.@kwdef mutable struct Piezo <: Zpositioner
    unique_id::String ="MCL_Piezo",
    units::String,
    handle::Int = 0,
    connected::Bool = false,
    real_pos::Float64 = 0.0,
    target::Float64 = 0.0,
    range::Tuple{Float64, Float64}
end