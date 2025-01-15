#=
This file contains the type definitions for the MCLStage struct.

Type Names may not match the Madlibs.dll naming convention as they correspond to the fields the gui function will be looking for.
=# 

Base.@kwdef mutable struct MCLStage <: Stage
    stagelabel::String = "MCL-NanoXYZ"
    units::String = "Microns"
    id::Int = 0                                 #This is the device handle
    dimensions::Int = 3
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    real_z::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    targ_z::Float64 = 0.0
    range_x::Tuple{Float64,Float64} = (0, 300)
    range_y::Tuple{Float64,Float64} = (0, 300)
    range_z::Tuple{Float64,Float64} = (0, 300)
end
