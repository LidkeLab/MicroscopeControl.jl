# Thorlabs DCx camera

module ThorCamDCx

using ...MicroscopeControl.HardwareInterfaces.CameraInterface
using GLMakie
using CEnum

import ...MicroscopeControl.HardwareInterfaces.CameraInterface: Camera
import ...MicroscopeControl: export_state, initialize, shutdown

export ThorcamDCXCamera, gui, shutdown
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime!, setroi!


const uc480 = "C:\\Windows\\System32\\uc480_64.dll"


# include statements

include("constants_uc480.jl")
include("functions_uc480.jl")
include("types.jl")
include("interface_methods.jl")

end