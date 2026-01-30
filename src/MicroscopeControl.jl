"""
MicroscopeControl is the main module for the MicroscopeControl package.
It exports all abstract types and methods for instruments, as well as the
implementations for all hardware interfaces. It also provides methods for
saving data to HDF5 files, and the GUI methods for user interfaces.

Uses Reexport.jl to cleanly propagate exports from submodules.
"""
module MicroscopeControl

using HDF5
using Reexport

# Core instrument abstraction
include("instrument.jl")
export AbstractInstrument
export export_state, initialize, shutdown

# Hardware interfaces (abstract types + method signatures)
include("hardware_interfaces/HardwareInterfaces.jl")
@reexport using .HardwareInterfaces

# Hardware implementations (concrete device drivers)
include("hardware_implementations/HardwareImplementations.jl")
@reexport using .HardwareImplementations

# HDF5 file saving utilities
include("h5_file_saving.jl")
export save_h5, save_attributes_and_data

end
