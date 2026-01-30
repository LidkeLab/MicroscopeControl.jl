"""
    Module for the NI USB DAQs.
"""
module NIDAQcard

using DAQmx
using ...MicroscopeControl.HardwareInterfaces.DAQInterface

import ...MicroscopeControl: export_state, initialize, shutdown

export NIdaq, gui, showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask #, export_state


include("types.jl")
include("interface_methods.jl")

end