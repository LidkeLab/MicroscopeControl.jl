"""
    Module for the NI USB DAQs.
"""
module NIDAQcard

using NIDAQ
using MicroscopeControl.HardwareInterfaces.DAQInterface

export NIdaq, gui, export_state, showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask
export export_state


include("types.jl")
include("interface_methods.jl")

end