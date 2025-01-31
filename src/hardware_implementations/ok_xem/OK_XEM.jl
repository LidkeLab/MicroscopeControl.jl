module OK_XEM
    using ...MicroscopeControl.HardwareImplementations.NIDAQcard

    import ...MicroscopeControl: export_state, initialize, shutdown

    const okFP = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64\\okFrontPanel.dll"

    include("constants_okFP.jl")
    include("functions_okFP.jl")
    include("types.jl")
    include("interface_methods.jl")

    export XEM
    export setexposure, enable,setupIO #, initialize

end