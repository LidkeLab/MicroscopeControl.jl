"""
Structure for the PI stage
"""
mutable struct PIStage <: Stage
    stagelabel::String
    units::String
    dimensions::Int
    connectionstatus::Bool
    id::Cint
    real_x::Float64
    real_y::Float64
    targ_x::Float64
    targ_y::Float64
    range_x::Tuple{Float64, Float64}
    range_y::Tuple{Float64, Float64}
    ismoving::Tuple{Bool, Bool}
    servostatus::Tuple{Bool, Bool}
    velocity::Vector{Float64}
end

"""
Constructor for the PI Stage Type, allows for creation on "empty", disconnected stage

Initialize function must be called to connect to the stage, so the constructor just sets default values
"""
function PIStage(;
    stagelabel::String = "PI-U751",
    units::String = "Milimeters",
    dimensions::Int = 2, 
    connectionstatus::Bool = false, 
    id::Cint = Cint(0), 
    x::Float64 = 12.5,
    y::Float64 = 12.5,
    targ_x::Float64 = 12.5,
    targ_y::Float64 = 12.5,
    range_x::Tuple{Float64, Float64} = (0.0, 25.0),
    range_y::Tuple{Float64, Float64} = (0.0, 25.0),
    velocity::Vector{Float64} = [1.0, 1.0],
    ismoving = (false, false),
    servostatus = (false, false))
    PIStage(stagelabel,units, dimensions, connectionstatus, id, x, y, targ_x, targ_y, range_x, range_y, ismoving, servostatus, velocity)
end
