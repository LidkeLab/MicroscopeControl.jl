module SimulatedCamera

using ...MicroscopeControl.HardwareInterfaces.CameraInterface

import ...MicroscopeControl: export_state, initialize, shutdown

export SimCamera, gui

include("types.jl")
include("interface_methods.jl")

end