"""
    _cstring(buf) -> String

The bytes of `buf` up to its first NUL, as a `String`.
"""
function _cstring(buf::Vector{UInt8})
    i = findfirst(==(0x00), buf)
    return String(buf[1:(i === nothing ? end : i - 1)])
end

function initialize(stage::N472)
    if stage.connectionstatus == true
        @error "Stage already initialized"
        return
    end

    # Enumerate the C-885 controllers the GCS2 DLL can see. The DLL lists only
    # controllers nobody has open: one that Device Manager still shows but is
    # missing here is held by another process (a second Julia, PIMikroMove, an
    # open COM port).
    buffersize = 1024
    buffer = zeros(UInt8, buffersize)
    controllername = "C-885"
    numdevice = PI_EnumerateUSB(buffer, buffersize, controllername)
    if numdevice <= 0
        @error "No PI C-885 found by the GCS2 library — controller absent, or held by another process"
        stage.connectionstatus = false
        return
    end

    # The buffer holds one NUL-terminated description per line. Pass the first
    # line as a `String`: Julia strings are always NUL-terminated for
    # `Ptr{Cchar}`, whereas the old code stripped every 0x00 byte and handed
    # the DLL a bare `Vector{UInt8}`, terminated only by whatever happened to
    # follow it in memory (usually a zero, so it usually worked).
    devstring = String(first(split(_cstring(buffer), '\n')))
    @info "PI device: " * devstring

    #Connect to usb device
    stage.id = PI_ConnectUSB(devstring)
    @info "Device ID: " * string(stage.id)
    if stage.id < 0
        # The connect itself failed (id -1): typically another process already
        # holds the controller. Leave the flag cleared so `initialize` can be
        # retried on the same object.
        stage.connectionstatus = false
        @error "PI_ConnectUSB failed for \"$devstring\" (init error $(PI_GetInitError())) — the controller is probably held by another process"
        return
    end
    stage.connectionstatus = true

    #Query the unit of the physical position
    axes = join(stage.axes, " ")
    #unitstring = zeros(UInt8, buffersize)
    #success = PI_qPUN(stage.id, axes, unitstring, buffersize)
    #stage.units = String(unitstring)

    #query reference mode
    refmode = zeros(BOOL, 3)
    
    success = PI_RON(stage.id, axes, refmode)
    success = PI_qRON(stage.id, axes, refmode)
    @info "Reference mode: " * string(refmode)

    # set the current position as the reference position
    success = set_refpos(stage)

    # turn on servo 
    for i in eachindex(stage.axes)
        servo(stage, i, TRUE)
    end
    #Query the travel range
    success = PI_qTMN(stage.id, axes, stage.minpos)
    success = PI_qTMX(stage.id, axes, stage.maxpos)

    #set velocity
    success = setvel(stage, stage.velocity)

    @info "Stage initialized"
    return
end

function shutdown(stage::N472)
    isconnected = PI_IsConnected(stage.id)
    if isconnected == TRUE
        PI_CloseConnection(stage.id)
        @info "Stage disconnected"
    else
        @info "Stage not connected"
    end
    # Clear the flag so the same object can be initialized again; before this
    # a second `initialize` after `shutdown` was refused as "already initialized".
    stage.connectionstatus = false
    return
end

function StageInterface.move(stage::N472, pos::Vector{Float64})
    success = move_abs(stage, pos)
    getposition(stage)
    return success
end

function StageInterface.getposition(stage::N472)
    axes = join(stage.axes, " ")
    success = PI_qPOS(stage.id, axes, stage.pos)
    @info "Current position: " * string(stage.pos)
    return success
end

function StageInterface.servo(stage::N472, axisId::Int, servoON::BOOL)
    success = setservo(stage, axisId, servoON)
    return success
end

function StageInterface.home(stage::N472)
    # the default position
    success = move(stage, stage.homepos)
    return success
end

function StageInterface.stopmotion(stage::N472)
    # Every GCS2 axes argument is one space-separated string. `stage.axes` is a
    # Vector{String}; passing it as Ptr{Cchar} handed the DLL a pointer to
    # string references, not characters, so the halt never reached the axes.
    axes = join(stage.axes, " ")
    success = PI_HLT(stage.id, axes)
    return success
end

function StageInterface.driftcorrection(stage::N472, axisId::Int, dcON::BOOL)
    @error "Drift correction not supported by $(stage.stagelabel)"
end

"""
    export_state(stage::N472)
"""
function export_state(stage::N472)
    attributes = Dict{String, Any}(
        "stage_label" => stage.stagelabel,
        "units" => stage.units,
        "dimensions" => stage.dimensions,
        "axes" => join(stage.axes, " "),
        "connected" => stage.connectionstatus,
        "id" => stage.id,
        "position" => copy(stage.pos),
        "min_position" => copy(stage.minpos),
        "max_position" => copy(stage.maxpos),
        "home_position" => copy(stage.homepos),
        "velocity" => copy(stage.velocity),
        "is_on_target" => [Bool(x) for x in stage.isontarget],  # Convert BOOL to Julia Bool
        "servo_status" => [Bool(x) for x in stage.servostatus]  # Convert BOOL to Julia Bool
    )
    
    data = nothing
    children = Dict{String, Any}()

    return attributes, data, children
end