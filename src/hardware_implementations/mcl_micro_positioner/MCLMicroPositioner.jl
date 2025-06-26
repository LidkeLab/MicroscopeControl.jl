module MCLMicroPositioner
using ..MicroscopeControl
using ..MicroscopeControl.HardwareImplementations.ObjPositionerInterface

export MclZPositioner
export move, get_position, stop_motion
export microdrive_information, microdrive_move_status, microdrive_status, microdrive_stop, microdrive_wait

madlibpath = "C:\\Program Files\\Mad City Labs\\MicroDrive\\Microdrive.dll"

include("types.jl")
include("interface_methods.jl")
include("motion_control.jl")
end