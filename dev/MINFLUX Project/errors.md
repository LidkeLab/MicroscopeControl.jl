Failed to precompile MicroscopeControl [aa70d9ae-4a1e-49fd-870a-8ccfd99f4c3e] to "C:\\Users\\lidkelab\\.julia\\compiled\\v1.10\\MicroscopeControl\\jl_E00D.tmp".
ERROR: LoadError: UndefVarError: `NIDAQcard` not defined
Stacktrace:
 [1] include(mod::Module, _path::String)
   @ Base .\Base.jl:495
 [2] include(x::String)
   @ MicroscopeControl.HardwareImplementations C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:4
 [3] top-level scope
   @ C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:19
 [4] include(mod::Module, _path::String)
   @ Base .\Base.jl:495
 [5] include(x::String)
   @ MicroscopeControl C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\MicroscopeControl.jl:4
 [6] top-level scope
   @ C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\MicroscopeControl.jl:15
 [7] include
   @ .\Base.jl:495 [inlined]
 [8] include_package_for_output(pkg::Base.PkgId, input::String, depot_path::Vector{String}, dl_load_path::Vector{String}, load_path::Vector{String}, concrete_deps::Vector{Pair{Base.PkgId, UInt128}}, source::Nothing)
   @ Base .\loading.jl:2292
 [9] top-level scope
   @ stdin:4
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\tcube_laser\TCubeLaserControl.jl:2
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:1
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\MicroscopeControl.jl:1
in expression starting at stdin: