"""
This module is a container for all hardware interfaces.
Uses Reexport to automatically propagate exports from submodules.
"""
module HardwareInterfaces

using ..MicroscopeControl
import ..MicroscopeControl: AbstractInstrument
using Reexport

# Include and re-export all interface modules
# Each submodule exports its abstract types and generic function signatures

include("camera_interface/CameraInterface.jl")
@reexport using .CameraInterface

include("slm_interface/SLMInterface.jl")
@reexport using .SLMInterface

include("stage_interface/StageInterface.jl")
@reexport using .StageInterface

include("lightsource_interface/LightSourceInterface.jl")
@reexport using .LightSourceInterface

include("daq_interface/DAQInterface.jl")
@reexport using .DAQInterface

# Commented out - not currently in use
# include("triggerscope_interface/TrigInterface.jl")
# @reexport using .TrigInterface

# include("objective_positioner_interface/ObjPositionerInterface.jl")
# @reexport using .ObjPositionerInterface

end
