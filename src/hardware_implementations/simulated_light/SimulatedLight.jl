module SimulatedLight

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: open_modulator!, close_modulator!, zero_modulator!, apply_level!, propagate_interrupt

export SimLight, gui

include("types.jl")
include("interface_methods.jl")

end