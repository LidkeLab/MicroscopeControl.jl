module MCLPiezoPositioner
using ..MicroscopeControl
using ..MicroscopeControl.HardwareImplementations.ObjPositionerInterface

nanoDrivePath = "C:\\Program Files\\Mad City Labs\\NanoDrive\\Madlib.dll"

export Piezo
export move, reset, get_position, stop_motion

include("types.jl")
include("interface_methods.jl")
end