"""
    DCAM4

The driver for Hamamatsu cameras through the DCAM-API: [`DCAM4Camera`](@ref), its `Camera` interface methods,
exposure, ROI and trigger setters, and Julia bindings to the DCAM-API functions it calls.
"""
module DCAM4
using ...Libraries: libdcam

using ...MicroscopeControl.HardwareInterfaces.CameraInterface
using GLMakie

import ...MicroscopeControl.HardwareInterfaces.CameraInterface: Camera, setexposuretime!, setroi!, settriggermode!
import ...MicroscopeControl: export_state, initialize, shutdown

export DCAM4Camera, gui, start_sequence, start_live
export getlastframe, capture, live, sequence, abort, getdata
# `setexposuretime` and `settriggermode` (no bang) were exported but never
# implemented; the real methods are `setexposuretime!` and `settriggermode!`.
export setexposuretime!, setroi!, settriggermode!
export dcamprop_getvalue, DCAM_IDPROP_INTERNALFRAMERATE, CameraROI, dcamapi_uninit
# export export_state

include("dcamerr.jl")
include("dcam_idprop.jl")
include("types.jl")
include("dcam_trace.jl")
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