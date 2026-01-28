# Spatial Light Modulator
module SLMInterface

using GLMakie
using Images
using ...MicroscopeControl

export SLM, Pupil
export displayimage, displayzernike, displayblaze

include("interface_types.jl")
include("interface_functions.jl")

end