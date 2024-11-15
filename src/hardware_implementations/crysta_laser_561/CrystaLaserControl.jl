"""
    CrystaLaserControl

A Module for controlling a laser through a NIDAQ card.
Citation: Ali Kazemi Nasaban Shotorban & Sheng Liu, Lidke Lab, UNM
"""
module CrystaLaserControl

using NIDAQ

using MicroscopeAdapt.HardwareInterfaces.LightSourceInterface
using MicroscopeAdapt.HardwareImplementations.NIDAQcard

import MicroscopeAdapt.HardwareInterfaces.LightSourceInterface: gui as laser_561_gui
import MicroscopeAdapt.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export CrystaLaser, laser_561_gui, nidaq_gui, initialize, light_on, light_off, setpower

include("types.jl")
include("interface_methods.jl")

end