module MCLMicroPositioner
using ..MicroscopeControl
using ..MicroscopeControl.HardwareInterfaces.ObjPositionerInterface

export MclZPositioner
export move, get_position, stop_motion
export microdrive_information, microdrive_move_status, microdrive_status, microdrive_stop, microdrive_wait
export mcl_device_attached, mcl_get_firmware_version, mcl_print_device_info, mcl_get_serial_number, mcl_dll_version, mcl_get_product_id

madlibpath = "C:\\Program Files\\Mad City Labs\\MicroDrive\\Microdrive.dll"

include("types.jl")
include("interface_methods.jl")
include("motion_control.jl")
include("device_information.jl")
end