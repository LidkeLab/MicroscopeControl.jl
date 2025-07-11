#=
This is the stage implementation for the Mad City Labs NanoDrive XYZ stage.

types and interface methods will be interacted with by the gui function in the Stage Interface

handle_methods.jl, standard_device_movement.jl, waveform_aquisition.jl, and device_information.jl will contain C language calls to the MCL DLL
=#

module MadCityLabs
    using ...MicroscopeControl.HardwareInterfaces.StageInterface

    import ...MicroscopeControl: export_state, initialize, shutdown

    madlibpath = "C:\\Program Files\\Mad City Labs\\NanoDrive\\Madlib.dll"

    include("types.jl")
    include("interface_methods.jl")
    include("handle_management.jl")
    include("device_information.jl")
    include("standard_device_movement.jl")

    export MCLStage                                                                 #This is the type definition for the MCLStage
    export move, getposition, stopmotion, gui, getrange #, initialize, shutdown     #These are Interface Specific
    export inithandle, releasehandle, releaseallhandles                             #Handle handle_management
    export isdeviceattached, printdeviceinfo, getserialnumber, getcommandedposition, getcalibration #Device Information
    export singleread, singlewrite, singlereadZ, singlewriteZ, monitorZ             #Standard Device Movement
    export move_to_z, get_z_position
end