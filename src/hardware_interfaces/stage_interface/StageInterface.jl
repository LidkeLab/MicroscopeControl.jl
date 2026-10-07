"""
Interface for controlling a translation stage
"""
module StageInterface
    using GLMakie
    using ...MicroscopeControl

    # import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
    import ...MicroscopeControl: gui

    include("interface_types.jl")
    include("interface_functions.jl")
    include("gui.jl")

    # export initialize, shutdown
    export move, getposition, stopmotion, driftcorrection, servo, getrange,home
    export gui
    # `Dimensions` was exported but never defined anywhere in the codebase
    # (stage dimensionality is just the `dimensions::Int` field); dropped.
    export Stage
end