┌ Error: HVA200 voltage apply failed
└ @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:225
DAQmxError (-50103): The specified resource is reserved. The operation could not be completed as specified.
Stacktrace:
 [1] check_error(code::Int32)
   @ DAQmx C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:113
 [2] macro expansion
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:129 [inlined]
 [3] start!
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\tasks.jl:24 [inlined]
 [4] (::var"#459#474"{Float64, Float64, Observable{Float64}, Observable{Float64}, Label, Label, Base.RefValue{Any}, Base.RefValue{Any}, Base.RefValue{Any}})()
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:209