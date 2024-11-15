"""
    Module for the NI USB DAQs.
"""
module NIDAQcard

using NIDAQ
using MicroscopeAdapt.HardwareInterfaces.DAQInterface

export NIdaq, gui

include("types.jl")
include("interface_methods.jl")

end