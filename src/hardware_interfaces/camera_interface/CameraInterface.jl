"""
This builds a generic interface for cameras
"""
module CameraInterface

using GLMakie
using Images
using ...MicroscopeControl

import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown


export Camera, CameraFormat, CameraROI
export gui, start_sequence, start_live
export abort, capture, getdata, getlastframe, live, sequence #, shutdown 

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end




