
function StageInterface.initialize(stage::N472)
    if stage.connectionstatus == true
        @error "Stage already initialized"
        return
    end

    # Create a buffer string
    buffersize = 128
    devstring = zeros(UInt8, buffersize)
    controllername = "C-885"
    numdevice = PI_EnumerateUSB(devstring, buffersize, controllername)
    devstring = filter(x -> x != 0x00, devstring)
    


    #Set connection status to true
    if numdevice > 0
        stage.connectionstatus = true
    else
        @error "No devices connected"
        stage.connectionstatus = false
        return
    end

    #Connect to usb device
    stage.id = PI_ConnectUSB(devstring)
    @info "PI device: " * String(devstring)
    @info "Device ID: " * string(stage.id)

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

function StageInterface.shutdown(stage::N472)
    isconnected = PI_IsConnected(stage.id)
    if isconnected == TRUE
        PI_CloseConnection(stage.id)
        @info "Stage disconnected"
    else
        @info "Stage not connected"
    end
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
    success = PI_HLT(stage.id, stage.axes)
    return success
end

function StageInterface.driftcorrection(stage::N472, axisId::Int, dcON::BOOL)
    @error "Drift correction not supported by $(stage.stagelabel)"
end