module MCS2Stage_mod

using ...MicroscopeControl.HardwareInterfaces.StageInterface
import ...MicroscopeControl: export_state, initialize, shutdown

# Path to the SmarAct DLL 
const SmarAct = "C:\\Windows\\System32\\SmarActCTL.dll"

# Load sub-files in dependency order 
# 1. Constants first — everything else depends on the type aliases
include("constants_smaract.jl")   # SA_CTL_* constants and type aliases

# 2. Low-level DLL wrappers
include("functions_smaract.jl")   # ccall wrappers for every SDK function

# 3. Struct definition (needs the type aliases from constants)
include("types_smaract.jl")       # MCS2Stage struct + constructor

# 4. Motion helpers (needs the struct + functions)
include("helper_smaract.jl")

# 5. High-level interface methods (needs the helpers)
include("interface_methods_smaract.jl")  

# 6. Adapts MCS2Stage onto the shared StageInterface contract
include("stageinterface_bridge_smaract.jl")

# Public exports
export MCS2Stage          # the stage struct + constructor

# Interface methods (exports: initialize, shutdown, gui)
export initialize!
export shutdown!
export move!, move_um!
export getposition!
export home!
export stopmotion!
export export_state

# Motion helpers 
export find_reference!
export find_travel_range!
export set_velocity!
export set_acceleration!
export query_positions!
export stop_all!, stop_channel!

# GUI
export gui

end
