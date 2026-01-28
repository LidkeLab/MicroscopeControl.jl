module Meadowlark

using ...MicroscopeControl.HardwareInterfaces.SLMInterface
using GLMakie, Images

import ...MicroscopeControl.HardwareInterfaces.SLMInterface: SLM
import ...MicroscopeControl: export_state, initialize, shutdown

export MLSLM, Pupil, Sequence
export displayimage, displayzernike, displayblaze
export genblazed!, genzernike!

include("types.jl")
include("meadowlark_sdk.jl")
include("meadowlark_dev.jl")
include("gen_patterns.jl")

end