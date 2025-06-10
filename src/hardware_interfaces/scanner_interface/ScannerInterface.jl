module ScannerInterface

using GLMakie
using ...MicroscopeControl

export Scanner, set_voltage, reset, scan_path

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end