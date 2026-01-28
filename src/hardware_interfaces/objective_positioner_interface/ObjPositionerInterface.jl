module ObjPositionerInterface
using ...MicroscopeControl
using GLMakie

export Zpositioner
export move, get_position, reset, stop_motion
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end