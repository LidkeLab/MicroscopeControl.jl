# Spatial Light Modulator
module SLMInterface

using ...MicroscopeControl

import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown

include("interface_types.jl")
include("interface_functions.jl")

end