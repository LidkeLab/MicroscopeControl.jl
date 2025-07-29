# Written by Martin Zanazzi and Abbie Gatsch Summer 2025
# A note on structure and inheretence in MicroscopeControl.jl
# During summer 2025 it was decided that while stages and objective positioners are similar, 
# so similar that they could theoretically be ran by the same code, they are different enough 
# that a different Interface that extends stage should be used

# the structure now looks like this 
# Abstract Instrument
#   -> Stage
#       -> Zpositioner

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