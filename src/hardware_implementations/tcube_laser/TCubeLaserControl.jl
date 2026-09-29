
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
# Not exported by the interface: the shared ceiling generic this driver extends,
# and the status-word layout it shares with its simulated twin.
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: effective_max_current, STATUS_BITS


const Thorlabs_Tcube_laser = "C:\\Program Files\\Thorlabs\\Kinesis\\Thorlabs.MotionControl.TCube.LaserDiode.dll"

include("constants_Tlaser.jl")
include("functions_Tlaser.jl")
include("types.jl")
include("interface_methods.jl")

export TCubeLaser
export red_laser_gui
export light_on, light_off, shutdown, tcube_get_current
# `tcube_refresh` is an exported name from before v0.2.3 and stays one: the
# method now throws and explains itself rather than vanishing into an
# `UndefVarError`. See its docstring.
export tcube_refresh
export export_state
# `setupIO` is kept unexported here: OK_XEM also exports an unrelated `setupIO`
# for its own FPGA IO pins, and the two collided as distinct top-level bindings.
# Qualified access remains: TCubeLaserControl.setupIO(laser).

end