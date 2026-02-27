(MicroscopeControl) pkg> activate dev\beam_Car
  Activating project at `C:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\beam_Car`

julia> __precompile__(false)


Info Given MicroscopeControl was explicitly requested, output will be shown live
WARNING: Method definition armcamera(MicroscopeControl.HardwareImplementations.ThorCamCSC.ThorCamCSCCamera) in module ThorCamCSC at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\thorcam_csc\thorcamcsc_camcontrol.jl:2 overwritten at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\thorcam_csc\thorcamcsc_camcontrol.jl:11.
ERROR: Method overwriting is not permitted during Module precompilation. Use `__precompile__(false)` to opt-out of precompilation.
  ? MicroscopeControl
[ Info: Precompiling MicroscopeControl [aa70d9ae-4a1e-49fd-870a-8ccfd99f4c3e]
WARNING: Method definition armcamera(MicroscopeControl.HardwareImplementations.ThorCamCSC.ThorCamCSCCamera) in module ThorCamCSC at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\thorcam_csc\thorcamcsc_camcontrol.jl:2 overwritten at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\thorcam_csc\thorcamcsc_camcontrol.jl:11.
ERROR: Method overwriting is not permitted during Module precompilation. Use `__precompile__(false)` to opt-out of precompilation.
[ Info: Skipping precompilation since __precompile__(false). Importing MicroscopeControl [aa70d9ae-4a1e-49fd-870a-8ccfd99f4c3e].
ERROR: LoadError: ArgumentError: Package MicroscopeControl does not have NIDAQ in its dependencies:
- You may have a partially installed environment. Try `Pkg.instantiate()`
  to ensure all packages in the environment are installed.
- Or, if you have MicroscopeControl checked out for development and have
  added NIDAQ as a dependency but haven't updated your primary
  environment's manifest file, try `Pkg.resolve()`.
- Otherwise you may need to report an issue with MicroscopeControl
Stacktrace:
 [1] macro expansion
   @ .\loading.jl:1846 [inlined]
 [2] macro expansion
   @ .\lock.jl:267 [inlined]
 [3] __require(into::Module, mod::Symbol)
   @ Base .\loading.jl:1823
 [4] #invoke_in_world#3
   @ .\essentials.jl:926 [inlined]
 [5] invoke_in_world
   @ .\essentials.jl:923 [inlined]
 [6] require(into::Module, mod::Symbol)
   @ Base .\loading.jl:1816
 [7] include(mod::Module, _path::String)
   @ Base .\Base.jl:495
 [8] include(x::String)
   @ MicroscopeControl.HardwareImplementations C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:4
 [9] top-level scope
   @ C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:18
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\nidaq\NIDAQcard.jl:1
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\hardware_implementations\HardwareImplementations.jl:1
in expression starting at C:\Users\lidkelab\.julia\dev\MicroscopeControl\src\MicroscopeControl.jl:1

        
        
        
        
ERROR: LoadError: UndefVarError: `MCLMicroPositioner` not defined
Stacktrace:
 [1] include(fname::String)
   @ Base.MainInclude .\client.jl:494
 [2] top-level scope
   @ c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\beam_char_save.jl:15
in expression starting at c:\Users\lidkelab\.julia\dev\MicroscopeControl\dev\MINFLUX Project\dev_helper_funcs.jl:7