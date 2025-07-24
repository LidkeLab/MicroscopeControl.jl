# Thorlabs compact scientific camera

module ThorCamCSC
using ...MicroscopeControl.HardwareInterfaces.CameraInterface
using GLMakie

import ...MicroscopeControl.HardwareInterfaces.CameraInterface: Camera
import ...MicroscopeControl: export_state, initialize, shutdown

export ThorCamCSCCamera, gui, shutdown, initialize
export capture, live, sequence, abort
export setexposuretime!, setexposuretime, set_triggermode, setroi, setroi!, setgain, setframerate
export getgain, getroisize, getdata, getlastframe, getframerate, getexposuretime

# include statements

include("types.jl")
include("thorcamcsc_sdk.jl")
include("thorcam_dev.jl")
include("thorcamcsc_helpers.jl")
include("thorcamcsc_camcontrol.jl")
include("set_properties.jl")
include("interface_methods.jl")
end

