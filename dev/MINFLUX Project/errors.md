┌ Error: HVA200 voltage apply failed
└ @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:223
BoundsError: attempt to access 1×2 Matrix{Float64} at index [2, 1]
Stacktrace:
 [1] getindex
   @ .\essentials.jl:14 [inlined]
 [2] (::var"#335#350"{Float64, Float64, Observable{Float64}, Observable{Float64}, Label, Label, Base.RefValue{Any}, Base.RefValue{Any}, Base.RefValue{Any}})()
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:214┌ Error: HVA200 voltage apply failed
└ @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:223
DAQmxError (-50103): The specified resource is reserved. The operation could not be completed as specified.
Stacktrace:
 [1] check_error(code::Int32)
   @ DAQmx C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:113
 [2] macro expansion
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:129 [inlined]
 [3] start!
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\tasks.jl:24 [inlined]
 [4] (::var"#335#350"{Float64, Float64, Observable{Float64}, Observable{Float64}, Label, Label, Base.RefValue{Any}, Base.RefValue{Any}, Base.RefValue{Any}})()
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:208