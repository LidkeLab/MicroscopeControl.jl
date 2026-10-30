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
include("libraries.jl")
using .Libraries
include("instrument.jl")
export AbstractInstrument
export AbstractSystem, AbstractSystemState
export export_state, initialize, shutdown, get_state, set_state, gui

# Hardware interfaces (abstract types + method signatures)
include("hardware_interfaces/HardwareInterfaces.jl")
@reexport using .HardwareInterfaces

# Hardware implementations (concrete device drivers)
include("hardware_implementations/HardwareImplementations.jl")
@reexport using .HardwareImplementations

# The light-source modulator lifecycle: public (documented, qualified access as `MicroscopeControl.<name>`), not
# exported. For driver authors and for downstream tests of a light that takes a `modulator`.
using .HardwareInterfaces.LightSourceInterface: output_id, open_modulator!, close_modulator!, RecordingModulator, modulation_violations
public output_id, open_modulator!, close_modulator!, RecordingModulator, modulation_violations

# Beam steering: only the device API is exported. The calibration arithmetic, the limit helpers, the backend contract
# (for backend authors and fakes) and the amplifier conversions are public, not exported.
using .HardwareInterfaces.BeamSteeringInterface: voltage_to_angle, angle_to_voltage, angle_setpoint_voltage,
    checklimits, resolve_limits, gridpoints, write_voltages!, openbackend!, closebackend!, backend_limits, snap_limits
using .HardwareImplementations.BeamSteeringBackends: rangelimits, min_voltage_step
using .HardwareImplementations.EODControl: crystal_limits, amplifier_factor, tocrystal, todaq
public voltage_to_angle, angle_to_voltage, angle_setpoint_voltage, checklimits, resolve_limits, gridpoints,
    write_voltages!, openbackend!, closebackend!, backend_limits, snap_limits,
    rangelimits, min_voltage_step, crystal_limits, amplifier_factor, tocrystal, todaq

# HDF5 file saving utilities
include("h5_file_saving.jl")
export save_h5, save_attributes_and_data

# Claude Code skill installer for downstream repos
include("skills.jl")
export install_skills, uninstall_skills, list_skills

end
