"""
This builds a generic interface for Data Aquistion Devices (DAQs)

For now this will be implemented for the 
""" 
module TrigInterface

using GLMakie
using Images
using ...MicroscopeControl
import ...MicroscopeControl: gui

export TRIG, Output, Input
# `getdatatypes`, `getranges`, `getnumchannels`, `setvalue`, `getvalue` were
# exported but never implemented for TRIG (the real, channel-qualified API is
# setoutputvalue/setoutputrange/getoutputvalue/getinputvalue); dropped.
# `reset` is not exported: it extends Base.reset (see interface_functions.jl)
# and is callable unqualified everywhere without an export.
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end
