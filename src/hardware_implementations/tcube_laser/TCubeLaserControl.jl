
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

include("constants_Tlaser.jl")
include("functions_Tlaser.jl")
include("types.jl")
include("interface_methods.jl")

export TCubeLaser
export red_laser_gui
export light_on, light_off, setpower, shutdown, tcube_get_current, tcube_refresh, setupIO
export export_state

end