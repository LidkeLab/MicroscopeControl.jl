"""
SLMInterface is a module for controlling a Spatial Light Modulator (SLM)
"""
module SLMInterface

using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown

include("interface_types.jl")
include("interface_functions.jl")

end