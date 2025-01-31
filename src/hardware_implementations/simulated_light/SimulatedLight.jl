module SimulatedLight

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface

import ...MicroscopeControl: export_state, initialize, shutdown

export SimLight, gui

include("types.jl")
include("interface_methods.jl")

end