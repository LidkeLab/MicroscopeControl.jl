"""
This builds a generic interface for National Instruments DAQ cards
"""
module DAQInterface

using GLMakie
using Images

export DAQ
export showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask, addchannel!, export_state
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end
