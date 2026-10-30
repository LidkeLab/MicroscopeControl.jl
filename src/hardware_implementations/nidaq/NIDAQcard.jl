"""
    Module for the NI USB DAQs.
"""
module NIDAQcard

using DAQmx
using ...MicroscopeControl.HardwareInterfaces.DAQInterface

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: AbstractModulationControl, setpower, output_id, holds_resources

export NIdaq, gui, showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask #, export_state
export NIDAQModulator


include("types.jl")
include("interface_methods.jl")
include("modulator.jl")

end