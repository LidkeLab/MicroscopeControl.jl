module SimulatedLight

using MicroscopeControl.HardwareInterfaces.LightSourceInterface

export SimLight, gui

include("types.jl")
include("interface_methods.jl")

end