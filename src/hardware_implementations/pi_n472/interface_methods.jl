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

    # An absent, unpowered or held controller fails here or at the connect below.
    buffersize = 1024
    buffer = zeros(UInt8, buffersize)
    controllername = "C-885"
    numdevice = PI_EnumerateUSB(buffer, buffersize, controllername)
    if numdevice <= 0
        @error "No PI C-885 found by the GCS2 library (absent, unpowered, or held by another process)"
        stage.connectionstatus = false
        return
    end

    # Descriptions are '\n'-separated with one NUL at the end; pass the first as a String (NUL-terminated for Ptr{Cchar}).
    devstring = String(strip(first(split(_cstring(buffer), '\n'))))
    @info "PI device: " * devstring

    #Connect to usb device
    stage.id = PI_ConnectUSB(devstring)
    @info "Device ID: " * string(stage.id)
    if stage.id < 0
        # Connect failed (id -1): leave the flag cleared so initialize can be retried.
        stage.connectionstatus = false
        @error "PI_ConnectUSB failed for \"$devstring\" (init error $(PI_GetInitError())); the controller may be held by another process"
        return
    end
    stage.connectionstatus = true

    # Every step from here is checked; on failure close the connection so a retry starts clean.
    try
        axes = join(stage.axes, " ")
        failed(step) = error("N472 initialize: $step failed (GCS error $(PI_GetError(stage.id)))")

        #query reference mode
        refmode = zeros(BOOL, 3)

        PI_RON(stage.id, axes, refmode) == FALSE && failed("PI_RON")
        PI_qRON(stage.id, axes, refmode) == FALSE && failed("PI_qRON")
        @info "Reference mode: " * string(refmode)

        # set the current position as the reference position
        set_refpos(stage) == FALSE && failed("set_refpos (PI_POS)")

        # turn on servo
        for i in eachindex(stage.axes)
            servo(stage, i, TRUE) == FALSE && failed("servo axis $i")
        end

        #Query the travel range
        PI_qTMN(stage.id, axes, stage.minpos) == FALSE && failed("PI_qTMN")
        PI_qTMX(stage.id, axes, stage.maxpos) == FALSE && failed("PI_qTMX")

        #set velocity
        setvel(stage, stage.velocity) == FALSE && failed("setvel")
    catch
        shutdown(stage)
        rethrow()
    end

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
    # Clearing both lets the object be re-initialized and stops a stale id closing another object's connection.
    stage.connectionstatus = false
    stage.id = Cint(-1)
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
    # GCS2 axes arguments are one space-separated string.
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