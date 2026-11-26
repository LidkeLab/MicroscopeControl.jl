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

"""
    attenuator_gui(attenuator::Attenuator) -> GLMakie.Screen

The same function as [`gui`](@ref) for an attenuator, under the name this module exports for the
`LCC1620`. It opens a window with a drive-voltage slider (volts, from `properties.min_voltage` to
`properties.max_voltage` in 0.01 V steps, starting at `properties.drive_voltage`) and a text box that moves the
slider, prints the attenuator's type to standard output, and returns the `Screen`. Each change of the slider
value, including one made through the text box, calls `setdrivevoltage` with the new voltage, so the
window commands the device as soon as it is used. Needs a display (GLMakie).
"""
attenuator_gui

export setdrivevoltage, getdrivevoltage, settransmission, gettransmission, set_calibration!

include("types.jl")
include("interface_methods.jl")

end
