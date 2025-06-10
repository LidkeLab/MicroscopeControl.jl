module Galvanometer
using ...MicrosopeControl.HardwareImplimentations.Triggerscope
using ...MicrosopeControl.HardwareInterfaces.Scanner

import ...MicrosopeControl.HardwareImplimentations.Triggerscope: gui as triggerscope_gui
import ...MicrosopeControl.HardwareImplimentations.Triggerscope: initialize as init_triggerscope

export Galvanometer, set_voltage, reset, scan_path, gui

include("types.jl")
include("interface_methods.jl")
end