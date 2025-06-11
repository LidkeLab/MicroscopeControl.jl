module Galvanometer
using ...MicroscopeControl.HardwareImplementations.Triggerscope
using ...MicroscopeControl.HardwareInterfaces.Scanner

import ...MicroscopeControl.HardwareImplementations.Triggerscope: gui as triggerscope_gui
import ...MicroscopeControl.HardwareImplementations.Triggerscope: initialize as init_triggerscope

export Galvanometer, set_voltage, reset, scan_path, gui

include("types.jl")
include("interface_methods.jl")
end