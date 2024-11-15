module SimulatedLight

using MicroscopeAdapt.HardwareInterfaces.LightSourceInterface

export SimLight, gui

include("types.jl")
include("interface_methods.jl")

end