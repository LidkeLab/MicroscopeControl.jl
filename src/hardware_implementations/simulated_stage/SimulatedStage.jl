module SimulatedStage
    using MicroscopeControl.HardwareInterfaces.StageInterface
    using GLMakie

    include("types.jl")
    include("interface_methods3d.jl")
    include("interface_methods2d.jl")
    include("interface_methods1d.jl")

    export SimStage3d, SimStage2d, SimStage1d
    export initialize, shutdown, move, getposition, stopmotion, gui
end