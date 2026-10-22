"""
This builds a generic interface for light sources: Laser, LED and Lamps
"""
module LightSourceInterface

using GLMakie
using Images
using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
import ...MicroscopeControl: gui
# Methods a modulator defines (it is not an AbstractInstrument, so the instrument stubs do not reach it).
import ...MicroscopeControl: initialize, shutdown, export_state

export LightSource, LightSourceProperties
export setpower, light_on, light_off #, shutdown, initialize, export_state
export gui

# Regulated laser diodes: the mode types, the photodiode loop and the unit-true
# setters and readbacks that replace `setpower` for them. See diode_laser.jl.
export DiodeLaser, RegulationMode, ConstantCurrent, ConstantPhotocurrent, PhotodiodeLoop
export setcurrent!, setoutputpower!, setlevel!
export measured_current, measured_photocurrent, indicated_output_power, loop_status
export regulation_mode, supported_modes

# Light-source modulators: something that puts a level on a light's analogue input. Only the type is
# exported; `output_id`, `open_modulator!`, `close_modulator!`, `RecordingModulator` and
# `modulation_violations` are public (MicroscopeControl.<name>), for driver authors and tests.
export AbstractModulationControl

include("interface_types.jl")
include("interface_functions.jl")
include("diode_laser.jl")
include("modulation.jl")
include("gui.jl")
include("diode_laser_gui.jl")

end
