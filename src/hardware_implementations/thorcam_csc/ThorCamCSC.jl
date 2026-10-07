# Thorlabs compact scientific camera

module ThorCamCSC
using ...MicroscopeControl.HardwareInterfaces.CameraInterface
using GLMakie

import ...MicroscopeControl.HardwareInterfaces.CameraInterface: Camera, setexposuretime!
import ...MicroscopeControl: export_state, initialize, shutdown

export ThorCamCSCCamera, gui, shutdown, initialize
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime, setexposuretime!, setroi, setgain, setframerate
export getgain, getroisize, getframerate, getexposuretime
# `set_exposuretime`, `set_triggermode`, `set_roi` and `setroi!` were exported but are
# not implemented for this camera; dropped.

# include statements

include("types.jl")
include("thorcamcsc_sdk.jl")
include("thorcam_dev.jl")
include("thorcamcsc_helpers.jl")
include("thorcamcsc_camcontrol.jl")
include("set_properties.jl")
include("interface_methods.jl")
end

