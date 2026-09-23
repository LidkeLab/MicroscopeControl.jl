
"""
    TCubeLaserControl 

A Module for controlling a laser through a TCube Laser Controller.
To power cotrol this laser, the module uses the Thorlabs Kinesis library. First, measure the optical power of the laser using a power meter before the laser beam gets coupled into the fiber.
This is because the coupling efficiency might vary over time and it is not reliable to use the power meter after the fiber.
"""
module TCubeLaserControl

using ...MicroscopeControl

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as red_laser_gui


const Thorlabs_Tcube_laser = "C:\\Program Files\\Thorlabs\\Kinesis\\Thorlabs.MotionControl.TCube.LaserDiode.dll"

# Bench data measured on this controller in open-loop mode, preserved from the
# deleted `helpers.jl` (which drove 80 mA into a specific lab laser at include
# time and so could not be kept). Expected power as set on the Kinesis display
# versus the power actually measured before the fiber, in mW; single readings,
# no repeats or statistics:
#
#     expected  measured
#        0.0    < 0.001
#       10.0      9.31
#       20.0     19.11
#       30.0     29.11
#       40.0     39.06
#       50.0     48.97
#       60.0     59.22
#       70.0     69.65
#       80.0     79.50
#
# `helpers.jl` also held the only worked example of the closed-loop bindings
# (`LD_SetClosedLoopMode`, `LD_SetWACalibFactor`, `LD_GetPhotoCurrentReading`).
# A conditional optical scaling is derivable from it:
#
#     power_mW = raw / 32767 * TIA_range_mA * calibration_W_per_A
#
# where `raw` is the word `LD_GetPhotoCurrentReading` returns. The two factors
# are assumptions from one bench setup, not device constants, and the driver
# cannot read either of them back: `helpers.jl` took the TIA range to be 1.0 mA
# and *set* the calibration factor to 224.2 W/A for one photodiode on one rig.
# On another diode, another TIA gain setting or another fibre, both are wrong.
# That is why this is a formula in a comment and not a getter, and why
# `tcube_get_power` was deleted rather than repaired. No closed-loop method is
# implemented here; the bindings themselves remain in `functions_Tlaser.jl`.

include("constants_Tlaser.jl")
include("functions_Tlaser.jl")
include("types.jl")
include("interface_methods.jl")

export TCubeLaser
export red_laser_gui
export light_on, light_off, setpower, shutdown, tcube_get_current
export export_state
# `setupIO` is kept unexported here: OK_XEM also exports an unrelated `setupIO`
# for its own FPGA IO pins, and the two collided as distinct top-level bindings.
# Qualified access remains: TCubeLaserControl.setupIO(laser).

end