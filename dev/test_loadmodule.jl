using Revise
using MicroscopeControl

# Test the saving function of Red Laser
using MicroscopeControl.HardwareImplementations.TCubeLaserControl
using MicroscopeControl.HardwareImplementations.NIDAQcard

function test_save_to_hdf5(tcube_light::TCubeLaser, file_name::String)
    # Extract the attributes, data and children from the instrument using the export_state function
    attributes, data, children = export_state(tcube_light)
    # Save the attributes and data to the hdf5 file
    save_h5(file_name, (attributes, data, children))
end

## TCube Laser Control ###
file_name = "Y:/Personal Folders/Ali.test_output.h5"
tcube_light = TCubeLaser("64849775")
MicroscopeControl.TCubeLaserControl.initialize(tcube_light)
MicroscopeControl.TCubeLaserControl.light_on(tcube_light)
MicroscopeControl.TCubeLaserControl.setpower(tcube_light, 70.0)

test_save_to_hdf5(tcube_light, file_name)

MicroscopeControl.TCubeLaserControl.light_off(tcube_light)
MicroscopeControl.TCubeLaserControl.shutdown(tcube_light)
##