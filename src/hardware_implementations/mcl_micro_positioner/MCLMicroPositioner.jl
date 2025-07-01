module MCLMicroPositioner
using ..MicroscopeControl
using ..MicroscopeControl.HardwareInterfaces.ObjPositionerInterface

export MclZPositioner
export move, getposition, stopmotion, home
export microdrive_information, microdrive_move_status, microdrive_status, microdrive_stop, microdrive_wait
export mcl_device_attached, mcl_get_firmware_version, mcl_print_device_info, mcl_get_serial_number, mcl_dll_version, mcl_get_product_id
export md1_move_profile_microsteps, md1_single_step, md1_reset_encoder, md1_read_encoder, md1_current_microstep_pos

madlibpath = "C:\\Program Files\\Mad City Labs\\MicroDrive\\Microdrive.dll"

include("types.jl")
include("interface_methods.jl")
include("motion_control.jl")
include("device_information.jl")
include("microdrive1_movement_encoders.jl")
end