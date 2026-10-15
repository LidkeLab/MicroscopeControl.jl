"""
    Module for two-axis galvanometer mirror pairs.

A `Galvo` is a `BeamSteerer`, so it is driven with `setvoltage`/`setangle` and scanned
with `gridscan` over whichever `SteeringBackend` it was built on — a Triggerscope DAC
pair or an NI analog-output pair.
"""
module GalvoControl

using ...MicroscopeControl
using ...MicroscopeControl.HardwareInterfaces.BeamSteeringInterface
using ..BeamSteeringBackends

import ...MicroscopeControl: export_state, initialize, shutdown

export Galvo

include("types.jl")
include("interface_methods.jl")

end
