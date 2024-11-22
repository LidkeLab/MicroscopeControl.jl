module PI
    using MicroscopeControl.HardwareInterfaces.StageInterface

    global const gcs2path = "C:\\Program Files (x86)\\Physik Instrumente (PI)\\Software Suite\\Development\\C++\\API\\PI_GCS2_DLL_x64.dll"

    include("types.jl")
    include("move_methods.jl")
    include("query_methods.jl")
    include("config_methods.jl")
    include("interface_methods.jl")

    export PIStage
    export initialize, shutdown
    export servoxy, servox, servoy, driftcorrection
    export immediatestop, referencemove, stopmotion
    export movexy, movex, movey, getposition, getxposition, getyposition, ismoving, isxmoving, isymoving, moveandwait
    export gui
end