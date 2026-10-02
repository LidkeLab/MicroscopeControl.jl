"""
This builds a generic interface for two-axis beam-steering devices — galvanometer mirror
pairs and electro-optic deflectors — that deflect a beam by putting a voltage on each of
two axes.

The interface separates three things:

- `BeamSteerer`      — the device the experiment talks to (`Galvo`, `EOD`)
- `SteeringBackend`  — whatever actually emits the two voltages (a Triggerscope DAC pair,
                       an NI analog-output pair). Swapping the backend does not change a
                       single call in an experiment script.
- `AngleCalibration` — the 2×2 mrad/V map plus zero-angle offset that turns a deflection
                       angle into the voltages that produce it.

Voltages are in volts, angles in milliradians.
"""
module BeamSteeringInterface

using ...MicroscopeControl
using ..DAQInterface

import ...MicroscopeControl: AbstractInstrument
import ...MicroscopeControl: export_state, initialize, shutdown
import ..DAQInterface: setvoltage

export BeamSteerer, SteeringBackend, AngleCalibration
export setvoltage, getvoltage, setangle, getangle, zeroaxes
export voltage_to_angle, angle_to_voltage, angle_setpoint_voltage, checklimits
export gridpoints, gridscan
export write_voltages!, openbackend!, closebackend!, backend_limits, resolve_limits

include("interface_types.jl")
include("interface_functions.jl")

end
