(implementation) pkg> ┌ Error: HVA200 voltage apply failed
└ @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:247
BoundsError: attempt to access 1×4 Matrix{Float64} at index [2, 1]
Stacktrace:
 [1] getindex
   @ .\essentials.jl:14 [inlined]
 [2] (::var"#120#135"{Float64, Float64, Observable{Float64}, Observable{Float64}, Observable{Float64}, Observable{Float64}, Label, Label, Base.RefValue{Any}, Base.RefValue{Any}, Base.RefValue{Any}})()
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:234