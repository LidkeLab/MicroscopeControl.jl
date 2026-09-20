"""
This builds a generic interface for cameras
"""
module CameraInterface

using GLMakie
using Images
using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, initialize, shutdown
import ...MicroscopeControl: gui, export_state


export Camera, CameraFormat, CameraROI
export gui, start_sequence, start_live
export abort, capture, getdata, getlastframe, live, sequence #, shutdown
export setexposuretime!, setroi!, settriggermode!

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end




