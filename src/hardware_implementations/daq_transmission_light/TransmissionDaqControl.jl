"""
    TransmissionDaqControl

A Module for controlling transmission light through a NIDAQ card.
Citation: Ali Kazemi Nasaban Shotorban & Sheng Liu, Lidke Lab, UNM
"""
module TransmissionDaqControl

using ...MicroscopeControl.HardwareInterfaces.DAQInterface: DAQ

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as tr_light_gui
import ...MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export DaqTrLight, tr_light_gui, nidaq_gui, light_on, light_off, setpower #, initialize

"""
    tr_light_gui(light::LightSource) -> GLMakie.Screen

The same function as [`gui`](@ref), under the name this module exports for its light. For a `DaqTrLight` it opens
a panel in the light's own power unit and range and returns its `GLMakie.Screen`; opening the panel issues no
command. Closing the panel does not switch the light off. Needs a display (GLMakie).
"""
tr_light_gui

# `nidaq_gui` is documented once, in CrystaLaserControl: the three light modules export the same binding.

include("types.jl")
include("interface_methods.jl")

end