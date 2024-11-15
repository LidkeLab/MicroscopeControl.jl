module PI_N472
    using MicroscopeAdapt.HardwareInterfaces.StageInterface
    using GLMakie
    const PI_GCS2 = "C:\\Program Files (x86)\\Physik Instrumente (PI)\\Software Suite\\Development\\C++\\API\\PI_GCS2_DLL_x64.dll"


    include("constants_GCS2.jl")
    include("functions_GCS2.jl")
    include("types.jl")
    include("helper.jl")
    include("interface_methods.jl")
    include("gui.jl")

    export N472
    export setvel, reference
    export gui
end