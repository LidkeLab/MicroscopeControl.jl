"""
    LaserDaqControl

A Module for controlling a laser through a NIDAQ card.
"""
module VortranLaserControl

using NIDAQ

using MicroscopeControl.HardwareInterfaces.LightSourceInterface
using MicroscopeControl.HardwareImplementations.NIDAQcard

import MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as laser_488_gui
import MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export VortranLaser, laser_488_gui, nidaq_gui, initialize, light_on, light_off, setpower

include("types.jl")
include("interface_methods.jl")

end