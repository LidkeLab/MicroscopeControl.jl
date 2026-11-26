"""
    LaserDaqControl

A Module for controlling a laser through a NIDAQ card.
"""
module VortranLaserControl

using ...MicroscopeControl.HardwareInterfaces.DAQInterface: DAQ
using ...MicroscopeControl

import ...MicroscopeControl: export_state, initialize, shutdown

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as laser_488_gui
import ...MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export VortranLaser, laser_488_gui, nidaq_gui, light_on, light_off, setpower

"""
    laser_488_gui(light::LightSource) -> GLMakie.Screen

The same function as [`gui`](@ref), under the name this module exports for its light. For a `VortranLaser` it opens
a panel in the light's own power unit and range and returns its `GLMakie.Screen`; opening the panel issues no
command. Closing the panel does not switch the light off. Needs a display (GLMakie).
"""
laser_488_gui

# `nidaq_gui` is documented once, in CrystaLaserControl: the three light modules export the same binding.

include("types.jl")
include("interface_methods.jl")

end