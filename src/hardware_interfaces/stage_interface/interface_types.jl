"""
'Stage' is an abstract type that represents a translation stage. Specific stage types should be defined as subtypes of Stage.
"""
abstract type Stage <: AbstractInstrument end

"""
    StageFormat

Generic properties for a translation stage.

# Fields
- `label::String`: The label of the stage.
- `units::String`: The units of the stage.
- `id::Int`: The ID of the stage.
- `dimensions::Int`: The number of dimensions of the stage.
- `connectionstatus::Bool`: Whether the stage is connected.
- `real_x::Float64`: The real x position of the stage.
- `real_y::Float64`: The real y position of the stage.
- `real_z::Float64`: The real z position of the stage.
- `targ_x::Float64`: The target x position of the stage.
- `targ_y::Float64`: The target y position of the stage.
- `targ_z::Float64`: The target z position of the stage.
- `range_x::Tuple{Float64, Float64}`: The range of motion of the stage in the x dimension.
- `range_y::Tuple{Float64, Float64}`: The range of motion of the stage in the y dimension.
- `range_z::Tuple{Float64, Float64}`: The range of motion of the stage in the z dimension.
- `servostatus::Tuple{Bool, Bool, Bool}`: The status of the servo motors in each dimension.
- `driftcorrectionstatus::Tuple{Bool, Bool, Bool}`: The status of the drift correction in each dimension.
"""
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