module MCLMicroPositioner
using ..MicroscopeControl
using ..MicroscopeControl.HardwareImplementations.ObjPositionerInterface

export MclZPositioner

madlibpath = "C:\\Program Files\\Mad City Labs\\MicroDrive\\Microdrive.dll"

include("types.jl")
include("interface_methods.jl")
end