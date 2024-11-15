module OK_XEM
    using MicroscopeAdapt.HardwareImplementations.NIDAQcard
    const okFP = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64\\okFrontPanel.dll"

    include("constants_okFP.jl")
    include("functions_okFP.jl")
    include("types.jl")
    include("interface_methods.jl")

    export XEM
    export initialize,setexposure, enable,setupIO

end