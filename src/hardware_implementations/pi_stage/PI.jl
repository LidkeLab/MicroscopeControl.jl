module PI
    using ...MicroscopeControl.HardwareInterfaces.StageInterface

    import ...MicroscopeControl: export_state, initialize, shutdown

    global const gcs2path = "C:\\Program Files (x86)\\Physik Instrumente (PI)\\Software Suite\\Development\\C++\\API\\PI_GCS2_DLL_x64.dll"

    include("types.jl")
    include("move_methods.jl")
    include("query_methods.jl")
    include("config_methods.jl")
    include("interface_methods.jl")

    export PIStage
    # export initialize, shutdown
    # `servo`, `stopmotion` and `getposition` are PI-local implementations wrapped
    # by the StageInterface methods in interface_methods.jl; exporting them here
    # would shadow the generic interface functions at the top level.
    # `servoxy`, `movexy`, `isxmoving`, `isymoving` were exported but never
    # implemented (dead exports left MicroscopeControl.<name> undefined); dropped.
    export servox, servoy, driftcorrection
    export immediatestop, referencemove
    export movex, movey, getxposition, getyposition, ismoving, moveandwait
    export gui
end