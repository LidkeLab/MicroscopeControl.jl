
module HardwareInterfaces

include("camera_interface/CameraInterface.jl")
include("slm_interface/SLMInterface.jl")
include("stage_interface/StageInterface.jl")

include("lightsource_interface/LightSourceInterface.jl")
include("daq_interface/DAQInterface.jl")
end
