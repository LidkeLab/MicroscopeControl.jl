module SimulatedCamera

using MicroscopeAdapt.HardwareInterfaces.CameraInterface

export SimCamera, gui

include("types.jl")
include("interface_methods.jl")

end