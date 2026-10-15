"""
Backends for the beam-steering interface: the hardware that actually puts the two axis
voltages out.

Both `Galvo` and `EOD` work over either of these, so they live here rather than in
either device's folder. Adding a third way to emit a voltage pair means adding one more
`SteeringBackend` here — no change to the devices.

- `TriggerscopeBackend` — a pair of Triggerscope4 16-bit DAC channels
- `DAQmxBackend`        — a pair of National Instruments analog outputs, via NI-DAQmx
"""
module BeamSteeringBackends

using ...MicroscopeControl
using ...MicroscopeControl.HardwareInterfaces.BeamSteeringInterface
using ..Triggerscope

using DAQmx
using DAQmx: AOTask, start!, stop!, clear!, write_scalar

import ...MicroscopeControl: initialize, shutdown

export TriggerscopeBackend, DAQmxBackend
export rangelimits, min_voltage_step

include("types.jl")
include("backend_methods.jl")

end
