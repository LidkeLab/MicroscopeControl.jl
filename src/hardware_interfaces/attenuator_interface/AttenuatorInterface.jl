"""
This builds a generic interface for optical attenuators, e.g. liquid crystal
variable attenuators driven by an analog voltage.
"""
module AttenuatorInterface

using GLMakie
using ...MicroscopeControl

export Attenuator, AttenuatorProperties
export setdrivevoltage, getdrivevoltage, settransmission, gettransmission, set_calibration!
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end
