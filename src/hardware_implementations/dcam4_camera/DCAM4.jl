"""
    DCAM4

A module for controlling DCAM4 cameras within the MicroscopeAdapt.jl package. It offers functionalities 
for capturing images, adjusting exposure times, setting regions of interest, and handling DCAM4-specific 
errors. It interfaces directly with the DCAM4 API, providing a low-latency solution for high-speed 
microscopy applications.
"""
module DCAM4

using MicroscopeControl.HardwareInterfaces.CameraInterface
using GLMakie

export DCAM4Camera, gui, initialize, shutdown, start_sequence, start_live
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime, settriggermode, setroi!, setexposuretime!

include("dcamerr.jl")
include("dcam_idprop.jl")
include("types.jl")
include("dcamapi.jl")
include("dcamdev.jl")
include("dcamprop.jl")
include("dcamwait.jl")
include("dcambuf.jl")
include("dcamcap.jl")
include("dcam_helpers.jl")
include("interface_methods.jl")
include("gui_param.jl")

end