#=
Stage implementation for SmarAct positioners driven by an MCS2 controller
(developed against the SOM-MS-8070 XY microscope stage).

Requires the SmarAct MCS2 SDK; its installer places SmarActCTL.dll in the
system directory, so the DLL is loaded by name rather than by absolute path.
The C headers this driver was written against live in
    C:\SmarAct\MCS2\SDK\C\include\

Layout:
  constants.jl          property keys, state bits, unit conversion
  ctl_api.jl            ccall wrappers with error checking
  types.jl              MCS2Stage and small accessors
  device_information.jl device/channel queries and status flags
  movement.jl           moves, referencing, calibration, motion settings
  interface_methods.jl  the StageInterface implementation
=#

module SmarActMCS2
    using ...MicroscopeControl.HardwareInterfaces.StageInterface

    import ...MicroscopeControl: export_state, initialize, shutdown

    # The MCS2 installer copies SmarActCTL.dll into the Windows system
    # directory, so the plain library name resolves without a full path.
    global const ctlpath = "SmarActCTL"

    include("constants.jl")
    include("ctl_api.jl")
    include("types.jl")
    include("device_information.jl")
    include("movement.jl")
    include("interface_methods.jl")

    export MCS2Stage, MCS2Error                                                     # Types
    export move, getposition, getrange, stopmotion, home, gui                       # Interface specific
    export findmcs2devices, mcs2version, deviceinfo                                 # Discovery
    export numchannels, devicename, serialnumber, positionertype, channeltype       # Device information
    export channelstate, channelstatus, isreferenced, iscalibrated, hassensor       # Channel status
    export updatestatus!, getaxisposition, waitformotion                            # Status and readback
    export moveaxis, moverelative, findreference, calibrate                         # Movement
    export setvelocity!, setacceleration!, setholdtime!, setactuatormode!           # Motion settings
    export setrangelimits!, getrangelimits, zeroposition!                           # Travel limits and origin
end
