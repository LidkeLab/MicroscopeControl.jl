#=
This is the stage implementation for the Mad City Labs NanoDrive XYZ stage.

types and interface methods will be interacted with by the gui function in the Stage Interface

handle_methods.jl, standard_device_movement.jl, waveform_aquisition.jl, and device_information.jl will contain C language calls to the MCL DLL
=#

module MadCityLabs
    using MicroscopeAdapt.HardwareInterfaces.StageInterface
    madlibpath = "C:\\Program Files\\Mad City Labs\\NanoDrive\\Madlib.dll"

    include("types.jl")
    include("interface_methods.jl")
    include("handle_management.jl")
    include("device_information.jl")
    include("standard_device_movement.jl")

    export MCLStage                                                                 #This is the type definition for the MCLStage
    export initialize, shutdown, move, getposition, stopmotion, gui, getrange                 #These are Interface Specific
    export inithandle, releasehandle, releaseallhandles                             #Handle handle_management
    export isdeviceattached, printdeviceinfo, getserialnumber, getcommandedposition, getcalibration #Device Information
    export singleread, singlewrite                                                  #Standard Device Movement
end