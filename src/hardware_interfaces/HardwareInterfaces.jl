
"""
This module is a container for all hardware interfaces
"""
module HardwareInterfaces

using ..MicroscopeControl
import ..MicroscopeControl: AbstractInstrument
# import ..MicroscopeControl: export_state, initialize, shutdown


include("camera_interface/CameraInterface.jl")
include("slm_interface/SLMInterface.jl")
include("stage_interface/StageInterface.jl")

include("lightsource_interface/LightSourceInterface.jl")
include("daq_interface/DAQInterface.jl")
include("triggerscope_interface/TrigInterface.jl")
include("scanner_interface/ScannerInterface.jl")
end
