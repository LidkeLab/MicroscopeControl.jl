# Spatial Light Modulator
"""
The spatial light modulator interface: the abstract type [`SLM`](@ref), [`Pupil`](@ref) and the display
functions.
"""
module SLMInterface

using GLMakie
using Images
using ...MicroscopeControl

export SLM, Pupil
export displayimage, displayzernike, displayblaze

include("interface_types.jl")
include("interface_functions.jl")

end