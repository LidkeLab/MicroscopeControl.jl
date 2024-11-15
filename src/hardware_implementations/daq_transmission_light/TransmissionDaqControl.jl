"""
    TransmissionDaqControl

A Module for controlling transmission light through a NIDAQ card.
Citation: Ali Kazemi Nasaban Shotorban & Sheng Liu, Lidke Lab, UNM
"""
module TransmissionDaqControl

using NIDAQ

using MicroscopeAdapt.HardwareInterfaces.LightSourceInterface
using MicroscopeAdapt.HardwareImplementations.NIDAQcard

import MicroscopeAdapt.HardwareInterfaces.LightSourceInterface: gui as tr_light_gui
import MicroscopeAdapt.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export DaqTrLight, tr_light_gui, nidaq_gui, initialize, light_on, light_off, setpower

include("types.jl")
include("interface_methods.jl")

end