using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.MCLMicroPositioner

positioner = MclZPositioner()

initialize(positioner)

positioner.velocity = 1.0
move(positioner, 3.0)
stop_motion(positioner)
get_position(positioner)
microdrive_wait(positioner)
microdrive_status(positioner)
microdrive_information(positioner)
mcl_device_attached(positioner, UInt32(1000))
mcl_get_firmware_version(positioner)
mcl_print_device_info(positioner)
mcl_get_serial_number(positioner)
mcl_dll_version(positioner)
mcl_get_product_id(positioner)

shutdown(positioner)