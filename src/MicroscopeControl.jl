module MicroscopeControl

include("instrument.jl")
include("hardware_interfaces/HardwareInterfaces.jl")
include("hardware_implementations/HardwareImplementations.jl")

using .HardwareImplementations.SimulatedCamera
using .HardwareImplementations.DCAM4
using .HardwareImplementations.PI
using .HardwareImplementations.SimulatedStage
using .HardwareImplementations.MadCityLabs
using .HardwareImplementations.PI_N472
using .HardwareImplementations.ThorCamCSC
using .HardwareImplementations.SimulatedLight
using .HardwareImplementations.NIDAQcard
using .HardwareImplementations.TCubeLaserControl
using .HardwareImplementations.TransmissionDaqControl
using .HardwareImplementations.CrystaLaserControl
using .HardwareImplementations.VortranLaserControl
using .HardwareImplementations.OK_XEM

# Re-export camera implementations
export SimCamera, DCAM4Camera, ThorCamCSC
export initialize, shutdown, start_sequence, start_live
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime, settriggermode, setroi!, setexposuretime!

# Re-export stage implementations
export PIStage, MCLStage, SimStage, N472
export move, getposition, stopmotion, getrange
export setvel, reference, servoxy, movexy

# Re-export light source implementations
export SimLight, TCubeLaser, DaqTrLight, CrystaLaser, VortranLaser
export light_on, light_off, setpower

# Re-export DAQ implementations
export NIdaq
export showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask

# Re-export FPGA implementations
export XEM
export initialize, setexposure, enable, setupIO

# Re-export common GUI methods
export gui

# For all instruments:
export export_state, initialize, shutdown

end
