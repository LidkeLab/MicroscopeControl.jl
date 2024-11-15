Base.@kwdef mutable struct SimStage3d <: Stage
    label::String = "Simulated 3D Stage"
    id::Int = 0
    dimensions::Int = 3
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    real_z::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    targ_z::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    range_y::Tuple{Float64, Float64} = (0, 100)
    range_z::Tuple{Float64, Float64} = (0, 100)
    servostatus::Tuple{Bool, Bool, Bool} = (false, false, false)
    driftcorrectionstatus::Tuple{Bool, Bool, Bool} = (false, false, false)
end

Base.@kwdef mutable struct SimStage2d <: Stage
    label::String = "Simulated 2D Stage"
    id::Int = 0
    dimensions::Int = 2
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    range_y::Tuple{Float64, Float64} = (0, 100)
    servostatus::Tuple{Bool, Bool} = (false, false)
    driftcorrectionstatus::Tuple{Bool, Bool} = (false, false)
end

Base.@kwdef mutable struct SimStage1d <: Stage
    label::String = "Simulated 1D Stage"
    id::Int = 0
    dimensions::Int = 1
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    targ_x::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    servostatus::Bool = false
    driftcorrectionstatus::Bool = false
end