"""
This builds a generic interface for light sources: Laser, LED and Lamps
"""
module LightSourceInterface

using GLMakie
using Images


export LightSource, LightSourceProperties
export setpower, light_on, light_off, shutdown, initialize, export_state
export gui

include("interface_types.jl")
include("interface_functions.jl")
include("gui.jl")

end