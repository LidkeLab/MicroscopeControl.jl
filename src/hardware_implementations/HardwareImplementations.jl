"""
HardwareImplementations module is a container for all hardware implementations.
Uses Reexport.jl to automatically propagate exports from submodules.
"""
module HardwareImplementations

using Reexport
using ..MicroscopeControl

# Camera implementations
include("simulated_camera/SimulatedCamera.jl")
@reexport using .SimulatedCamera

include("dcam4_camera/DCAM4.jl")
@reexport using .DCAM4

include("thorcam_csc/ThorCamCSC.jl")
@reexport using .ThorCamCSC

include("thorcam_dcx/ThorCamDCx.jl")
@reexport using .ThorCamDCx

# Stage implementations
include("pi_stage/PI.jl")
@reexport using .PI

include("simulated_stage/SimulatedStage.jl")
@reexport using .SimulatedStage

include("mcl_stage/MadCityLabs.jl")
@reexport using .MadCityLabs

include("pi_N472/PI_N472.jl")
@reexport using .PI_N472

# Light source implementations
include("simulated_light/SimulatedLight.jl")
@reexport using .SimulatedLight

include("tcube_laser/TCubeLaserControl.jl")
@reexport using .TCubeLaserControl

include("daq_transmission_light/TransmissionDaqControl.jl")
@reexport using .TransmissionDaqControl

include("crysta_laser_561/CrystaLaserControl.jl")
@reexport using .CrystaLaserControl

include("vortran_laser_488/VortranLaserControl.jl")
@reexport using .VortranLaserControl

# DAQ implementation (must come before OK_XEM which depends on it)
include("nidaq/NIDAQcard.jl")
@reexport using .NIDAQcard

# FPGA implementation (depends on NIDAQcard)
include("ok_xem/OK_XEM.jl")
@reexport using .OK_XEM

# SLM implementation
include("meadowlark_slm/Meadowlark.jl")
@reexport using .Meadowlark

# Work in progress - uncomment when ready
# include("triggerscope/Triggerscope.jl")
# @reexport using .Triggerscope

# include("mcl_micro_positioner/MCLMicroPositioner.jl")
# @reexport using .MCLMicroPositioner

end
