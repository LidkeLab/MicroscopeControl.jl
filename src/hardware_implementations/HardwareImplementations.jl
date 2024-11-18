module HardwareImplementations

include("simulated_camera/SimulatedCamera.jl")
include("dcam4_camera/DCAM4.jl")
include("pi_stage/PI.jl")
include("simulated_stage/SimulatedStage.jl")
include("mcl_stage/MadCityLabs.jl")
include("pi_N472/PI_N472.jl")

include("thorcam_csc/ThorCamCSC.jl")
include("simulated_light/SimulatedLight.jl")
include("nidaq/NIDAQcard.jl")
include("tcube_laser/TCubeLaserControl.jl")
include("daq_transmission_light/TransmissionDaqControl.jl")
include("crysta_laser_561/CrystaLaserControl.jl")
include("vortran_laser_488/VortranLaserControl.jl")
include("ok_xem/OK_XEM.jl")


end