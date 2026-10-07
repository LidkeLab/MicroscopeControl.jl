"""
This builds a generic interface for light sources: Laser, LED and Lamps
"""
module LightSourceInterface

using GLMakie
using Images
using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
import ...MicroscopeControl: gui

export LightSource, LightSourceProperties
export setpower, light_on, light_off #, shutdown, initialize, export_state
export gui

# Regulated laser diodes: the mode types, the photodiode loop and the unit-true
# setters and readbacks that replace `setpower` for them. See diode_laser.jl.
export DiodeLaser, RegulationMode, ConstantCurrent, ConstantPhotocurrent, PhotodiodeLoop
export setcurrent!, setoutputpower!, setlevel!
export measured_current, measured_photocurrent, indicated_output_power, loop_status
export regulation_mode, supported_modes

include("interface_types.jl")
include("interface_functions.jl")
include("diode_laser.jl")
include("gui.jl")
include("diode_laser_gui.jl")

end
