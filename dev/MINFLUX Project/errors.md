ERROR: DAQmxError (-50103): The specified resource is reserved. The operation could not be completed as specified.
Stacktrace:
 [1] check_error(code::Int32)
   @ DAQmx C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:113
 [2] macro expansion
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\errors.jl:129 [inlined]
 [3] start!
   @ C:\Users\lidkelab\.julia\packages\DAQmx\6uaKh\src\tasks.jl:24 [inlined]
 [4] beam_characterization(camera::ThorcamDCXCamera, framerate::Float64, exposure_time::Float64, save_dir::String)
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:55
 [5] beam_characterization(camera::ThorcamDCXCamera)
   @ Main c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:44
 [6] top-level scope
   @ c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\voltage_supply_beam_char.jl:630