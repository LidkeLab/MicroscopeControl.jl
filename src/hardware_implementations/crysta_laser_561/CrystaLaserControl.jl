"""
    CrystaLaserControl

A Module for controlling a laser through a NIDAQ card.
"""
module CrystaLaserControl

using DAQmx

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as laser_561_gui
import ...MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export CrystaLaser, laser_561_gui, nidaq_gui, light_on, light_off, setpower #, initialize

include("types.jl")
include("interface_methods.jl")

end