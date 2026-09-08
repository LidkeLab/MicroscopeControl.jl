"""
    LCC1620Attenuator

A Module for controlling a Thorlabs LCC1620/M liquid crystal attenuator
through a Triggerscope V4 DAC output.
Citation: Ali Kazemi Nasaban Shotorban, Lidke Lab, UNM
"""
module LCC1620Attenuator

using ...MicroscopeControl.HardwareInterfaces.AttenuatorInterface
using ...MicroscopeControl.HardwareImplementations.Triggerscope

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.AttenuatorInterface: gui as attenuator_gui

export LCC1620, attenuator_gui
export setdrivevoltage, getdrivevoltage, settransmission, gettransmission, set_calibration!

include("types.jl")
include("interface_methods.jl")

end
