"""
Interface for controlling a translation stage
"""
module StageInterface
    using GLMakie
    using ...MicroscopeControl

    # import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
    
    include("interface_types.jl")
    include("interface_functions.jl")
    include("gui.jl")

    # export initialize, shutdown
    export move, getposition, stopmotion, driftcorrection, servo, getrange,home
    export gui
    export Stage, Dimensions
end