module ObjPositionerInterface
using ...MicroscopeControl

export Zpositioner
export move, get_position, reset, stop_motion

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end