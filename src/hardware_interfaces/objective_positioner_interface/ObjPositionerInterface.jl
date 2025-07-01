module ObjPositionerInterface
using ...MicroscopeControl
using GLMakie
using ..MicroscopeControl.HardwareInterfaces.StageInterface

export Zpositioner
export move, getposition, home, stopmotion
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end