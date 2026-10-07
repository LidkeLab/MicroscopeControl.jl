"""
    TransmissionDaqControl

A Module for controlling transmission light through a NIDAQ card.
Citation: Ali Kazemi Nasaban Shotorban & Sheng Liu, Lidke Lab, UNM
"""
module TransmissionDaqControl

using DAQmx

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as tr_light_gui
import ...MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export DaqTrLight, tr_light_gui, nidaq_gui, light_on, light_off, setpower #, initialize

include("types.jl")
include("interface_methods.jl")

end