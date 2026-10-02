"""
    Module for two-axis electro-optic deflectors driven through high-voltage amplifiers.

An `EOD` is a `BeamSteerer`, so it is driven with `setvoltage`/`setangle` and scanned
with `gridscan` like a galvo. On top of that it knows about the amplifier between the
DAQ and the crystals, so the same deflector can be commanded in DAQ volts, in crystal
volts, or in milliradians.
"""
module EODControl

using ...MicroscopeControl
using ...MicroscopeControl.HardwareInterfaces.BeamSteeringInterface
using ..BeamSteeringBackends

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.BeamSteeringInterface: angle_setpoint_voltage, getangle

export EOD
export setcrystalvoltage, getcrystalvoltage, crystal_limits
export amplifier_factor, tocrystal, todaq

include("types.jl")
include("interface_methods.jl")

end
