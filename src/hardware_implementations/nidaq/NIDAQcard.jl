"""
    Module for the NI USB DAQs.
"""
module NIDAQcard

using NIDAQ
using MicroscopeAdapt.HardwareInterfaces.DAQInterface

export NIdaq, gui, export_state, showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask


include("types.jl")
include("interface_methods.jl")

end