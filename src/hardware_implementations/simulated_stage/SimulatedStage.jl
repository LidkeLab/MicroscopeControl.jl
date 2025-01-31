module SimulatedStage
    using ...MicroscopeControl.HardwareInterfaces.StageInterface
    using GLMakie

    import ...MicroscopeControl: export_state, initialize, shutdown

    include("types.jl")
    include("interface_methods3d.jl")
    include("interface_methods2d.jl")
    include("interface_methods1d.jl")

    export SimStage3d, SimStage2d, SimStage1d
    export move, getposition, stopmotion, gui #, initialize, shutdown
end