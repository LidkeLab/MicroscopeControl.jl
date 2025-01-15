abstract type Stage <: AbstractInstrument end

mutable struct StageFormat <: Stage
    label::String
    units::String
    id::Int
    dimensions::Int
    connectionstatus::Bool
    real_x::Float64
    real_y::Float64
    real_z::Float64
    targ_x::Float64
    targ_y::Float64
    targ_z::Float64
    range_x::Tuple{Float64, Float64}
    range_y::Tuple{Float64, Float64}
    range_z::Tuple{Float64, Float64}
    servostatus::Tuple{Bool, Bool, Bool}
    driftcorrectionstatus::Tuple{Bool, Bool, Bool}
end