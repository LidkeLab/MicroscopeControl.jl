"""
    CrystaLaserControl

A Module for controlling a laser through a NIDAQ card.
Citation: Ali Kazemi Nasaban Shotorban & Sheng Liu, Lidke Lab, UNM
"""
module CrystaLaserControl

using NIDAQ

using MicroscopeControl.HardwareInterfaces.LightSourceInterface
using MicroscopeControl.HardwareImplementations.NIDAQcard

import MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as laser_561_gui
import MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export CrystaLaser, laser_561_gui, nidaq_gui, initialize, light_on, light_off, setpower

include("types.jl")
include("interface_methods.jl")

end