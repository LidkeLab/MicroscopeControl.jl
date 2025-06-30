using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.MCLMicroPositioner
using MicroscopeControl.HardwareImplementations.MadCityLabs



positioner = MclZPositioner()
piezo = MCLStage()

initialize(piezo)
singlewriteZ(piezo, 1.0)
singlereadZ(piezo)
monitorZ(piezo, 2.0)
shutdown(piezo)

piezo.id

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

md1_move_profile_microsteps(positioner, 989)
md1_single_step(positioner, 1)
md1_reset_encoder(positioner)
md1_read_encoder(positioner)
md1_current_microstep_pos(positioner)
shutdown(positioner)