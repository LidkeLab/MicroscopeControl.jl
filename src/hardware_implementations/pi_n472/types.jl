"""
    Struct for PI-N472 linear actuator (3 axes)
"""
mutable struct N472 <: Stage
    stagelabel::String
    units::String
    dimensions::Int
    axes::Vector{String}
    connectionstatus::Bool
    id::Cint
    pos::Vector{Float64}
    minpos::Vector{Float64}
    maxpos::Vector{Float64}
    homepos::Vector{Float64}
    velocity::Vector{Float64}
    isontarget::Vector{BOOL}
    servostatus::Vector{BOOL}
end

"""
    Constructor for the N472 type
"""

function N472(;
    stagelabel::String="PI-N472",
    units::String="mm",
    dimensions::Int=1,
    axes::Vector{String}=["1", "3", "5"],
    connectionstatus::Bool=false,
    id::Cint=Cint(0),
    pos::Vector{Float64}=[0.0, 0.0, 0.0],
    minpos::Vector{Float64}=[0.0, 0.0, 0.0],
    maxpos::Vector{Float64}=[7.0, 7.0, 7.0],
    homepos::Vector{Float64}=[0.0, 0.0, 0.0],
    velocity::Vector{Float64}=[0.01, 0.01, 0.01],
    isontarget::Vector{BOOL}=[FALSE, FALSE, FALSE],
    servostatus::Vector{BOOL}=[FALSE, FALSE, FALSE])
    N472(stagelabel, units, dimensions, axes, connectionstatus, id, pos, minpos, maxpos, homepos, velocity, isontarget, servostatus)
end

