
module XEM_DAC



    using ...MicroscopeControl.HardwareImplementations.OK_XEM

    import ...MicroscopeControl.HardwareImplementations.OK_XEM: setwirein, activetriggerin
    import ...MicroscopeControl: export_state, initialize, shutdown
    
    const okFP = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64\\okFrontPanel.dll"

  
    include("types.jl")
    include("interface_methods.jl")

    export XEM_dac, start, stop, setvoltageA, setvoltageB, setvoltageC, setvoltageD, setvoltageAll
    #export setvoltage, start, stop #, initialize

end