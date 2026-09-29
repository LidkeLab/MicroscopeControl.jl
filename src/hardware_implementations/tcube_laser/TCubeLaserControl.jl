
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

# Closed-loop (constant power) calibration of the 642 nm rig: TLD001 serial
# 64849775, monitor photodiode on the 1 mA TIA range. Measured by Ali Kazemi Nasaban Shotorban
# with a power meter before the fiber (see the module docstring), and recorded
# in the deleted `helpers.jl` (Oct 2024, which drove the laser at include time
# and so could not be kept):
#
#     W/A calibration factor   224.2   (LD_SetWACalibFactor)
#     TIA range                1.0 mA  (rear-panel DIP switch; read-only in software)
#
# Closed-loop entry and command sequence from `helpers.jl`:
#
#     LD_SetClosedLoopMode(serialNo)
#     LD_SetWACalibFactor(serialNo, 224.2)
#     LD_SetLaserSetPoint(serialNo, UInt16(round(power_mW * 32767 / 224.2 / 1.0)))
#
# In closed loop the setpoint word is photocurrent, 0..32767 = 0..TIA full
# scale, so the conversions both ways are
#
#     word     = power_mW / calibration_W_per_A / TIA_range_mA * 32767
#     power_mW = raw / 32767 * TIA_range_mA * calibration_W_per_A
#
# where `raw` is the word `LD_GetPhotoCurrentReading` returns. Verification, in
# closed loop with those two factors: power commanded through the formula
# versus power measured before the fiber, in mW; single readings, no repeats
# or statistics:
#
#     commanded  measured
#        0.0     < 0.001
#       10.0       9.31
#       20.0      19.11
#       30.0      29.11
#       40.0      39.06
#       50.0      48.97
#       60.0      59.22
#       70.0      69.65
#       80.0      79.50
#
# Measured power sits 0.35–1.03 mW below the command at every point: within
# 1.5 % from 60 mW up, 2–4.5 % at 20–50 mW, and 7 % at 10 mW.
#
# These numbers belong to this photodiode, this TIA range and this measurement
# plane: moving the DIP switch or replacing the diode invalidates them, and the
# driver cannot read the W/A factor's provenance back. Closed loop regulates the
# monitor photocurrent, so without a TEC-stabilised mount the delivered power
# can still drift with diode temperature. No closed-loop method is implemented
# here yet; the bindings remain in `functions_Tlaser.jl`.

include("constants_Tlaser.jl")
include("functions_Tlaser.jl")
include("types.jl")
include("interface_methods.jl")

export TCubeLaser
export red_laser_gui
export light_on, light_off, setpower, shutdown, tcube_get_current
# `tcube_refresh` is an exported name from before v0.2.3 and stays one: the
# method now throws and explains itself rather than vanishing into an
# `UndefVarError`. See its docstring.
export tcube_refresh
export export_state
# `setupIO` is kept unexported here: OK_XEM also exports an unrelated `setupIO`
# for its own FPGA IO pins, and the two collided as distinct top-level bindings.
# Qualified access remains: TCubeLaserControl.setupIO(laser).

end