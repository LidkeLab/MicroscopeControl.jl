"""
MicroscopeControl is the main module for the MicroscopeControl package. It exports all the abstract types and methods for the instrument, as well as the implementations for the hardware interfaces. It also exports the methods for saving data to an HDF5 file, and the methods for controlling the camera, stage, light source, DAQ, and FPGA. Finally, it re-exports the GUI method for the user interface.
"""
module MicroscopeControl

using HDF5

# To export the abstract types and methods for all the instruments
include("instrument.jl")
export AbstractInstrument
export export_state, initialize, shutdown

# Including the hardware interfaces and implementations and the HDF5 file saving methods
include("hardware_interfaces/HardwareInterfaces.jl")
include("hardware_implementations/HardwareImplementations.jl")
include("h5_file_saving.jl")

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
using .HardwareImplementations.ThorCamDCx
using .HardwareImplementations.Triggerscope
using .HardwareImplementations.Galvanometer

# # Export all HardwareImplementations modules
# export DCAM4, SimulatedCamera, SimulatedStage, PI, MadCityLabs, PI_N472, ThorCamCSC
# export SimulatedLight, NIDAQcard, TCubeLaserControl, TransmissionDaqControl
# export CrystaLaserControl, VortranLaserControl, OK_XEM

# Export h5 file saving methods
export save_h5, save_attributes_and_data

# Re-export camera implementations
export SimCamera, DCAM4Camera, ThorCamCSCCamera, ThorCamDCXCamera
export start_sequence, start_live
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime, settriggermode, setroi!, setexposuretime!
export dcamprop_getvalue, DCAM_IDPROP_INTERNALFRAMERATE, CameraROI, dcamapi_uninit

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
export setexposure, enable, setupIO

# Re-export triggerscope implementations
export Triggerscope4

# Re-export common GUI methods
export gui

end
