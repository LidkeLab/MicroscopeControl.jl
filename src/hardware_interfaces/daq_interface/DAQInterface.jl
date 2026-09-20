"""
This builds a generic interface for National Instruments DAQ cards
"""
module DAQInterface

using GLMakie
using Images
using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
import ...MicroscopeControl: gui

export DAQ
export showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask, addchannel!
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end
