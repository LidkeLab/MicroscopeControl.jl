module SimulatedCamera

using ...MicroscopeControl.HardwareInterfaces.CameraInterface

export SimCamera, gui

include("types.jl")
include("interface_methods.jl")

end