"""
This builds a generic interface for Data Aquistion Devices (DAQs)

For now this will be implemented for the 
""" 
module TrigInterface

using GLMakie
using Images
using ...MicroscopeControl

export TRIG, Output, Input
export getdatatypes, getranges, getnumchannels, setvalue, getvalue
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end
