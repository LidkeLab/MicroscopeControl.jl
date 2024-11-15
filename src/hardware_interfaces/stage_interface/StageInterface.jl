"""
Interface for controlling a translation stage
"""
module StageInterface
    using GLMakie

    include("interface_types.jl")
    include("interface_functions.jl")
    include("gui.jl")

    export initialize, shutdown, move, getposition, stopmotion, driftcorrection, servo, getrange,home
    export gui
    export Stage, Dimensions
end