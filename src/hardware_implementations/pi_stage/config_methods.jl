"""
Initialize the PI stage. Connects to the first PI C-867 the GCS2 library enumerates, turns both
servos on, starts the reference move, waits for the controller and for both axes to report
referenced, reads the travel range, waits for motion to stop, and sets `stage.velocity`.

`connectionstatus` becomes true only when all of that succeeded. A failure after the connect
closes the connection and throws. Enumeration and connect failures log `@error` and return with
`connectionstatus == false`.

`[limitation]` Not yet run on hardware; the wait for `PI_IsControllerReady` needs a rig check on
the C-867. The stage needs calibration using PiMikroMove to work correctly; there is no
documentation on how to calibrate using the PI_GCS2 library.
"""
function initialize_original(stage::PIStage)
    if stage.connectionstatus == true
        @error "Stage already initialized"
        return
    end

    # Create a buffer string
    bufferstring = Vector{UInt8}(undef, 1024)

    #Find number of connected USB devices, specifically the PI C-867 controller
    numconnected = PI_EnumerateUSB(bufferstring, 1024, "PI C-867")

    @info "Number of connected devices: " * string(numconnected)

    if numconnected <= 0
        # The DLL enumerates only controllers nobody has open: a C-867 that Device Manager
        # still lists is held by another process (a second Julia with an initialized stage —
        # under any Windows user —, PIMikroMove, or an open COM port).
        @error "No PI C-867 found by the GCS2 library — controller absent, or held by another process"
        return
    end
    #Connect to usb device
    stage.id = PI_ConnectUSB(bufferstring)

    @info "Device ID: " * string(stage.id)

    if stage.id < 0
        # The connect itself failed (id -1): typically another process already holds the
        # controller (a second Julia with an initialized stage, PIMikroMove, an open COM port).
        @error "PI_ConnectUSB failed — the controller is probably held by another process"
        return
    end

    # Everything after the connect is inside the cleanup: a failure closes the connection so a
    # retried initialize starts clean, and connectionstatus is set only once all of it succeeded.
    try
        #Set servo mode to on for both axes, noting axis X is labeled "1" and axis Y is labeled "2"
        servo(stage, true, true)

        #Reference stage. A rejected FRF (e.g. GCS error 5, servo off on one axis) used to be
        # ignored: every later PI_MOV was refused too, while the driver's cached position said
        # the stage was centred. Refuse to come back from initialize unreferenced.
        if referencemove(stage) != 1
            error("PI_FRF refused (GCS error $(_pi_geterror(stage))); stage is not referenced")
        end
        _waitforready(stage; timeout = REFERENCE_TIMEOUT_S[])
        _waitforreference(stage; timeout = REFERENCE_TIMEOUT_S[])

        #Find the max and min position of the axes
        getrange(stage)

        #Wait for any remaining motion to finish
        ismoving(stage)
        while stage.ismoving[1] == 1 || stage.ismoving[2] == 1
            ismoving(stage)
        end

        #Set the velocity to `stage.velocity`
        success = setvel(stage, stage.velocity)
    catch
        shutdown_original(stage)
        rethrow()
    end

    stage.connectionstatus = true
    @info "Stage initialized"
    return
end

"""
Start the reference move (`PI_FRF`) on both axes and return the GCS BOOL, 1 if accepted.
`initialize` waits for it to finish.
"""
function referencemove(stage::PIStage)
    ismoved = PI_FRF(stage.id, "1 2")
    return ismoved
end

# PI_GetError returns and clears the controller's last GCS error code (0 = none).
_pi_geterror(stage::PIStage) = PI_GetError(stage.id)

"""
How long `initialize` waits, in seconds, for the controller to become ready and then for both
axes to report referenced. A `Ref` so tests can shorten it.
"""
const REFERENCE_TIMEOUT_S = Ref(60.0)

"""
Poll `PI_IsControllerReady` every 0.1 s until the controller reports ready; throw if the call
fails or it is not ready within `timeout` seconds.

`[limitation]` Not yet run on hardware; the wait needs a rig check on the C-867.
"""
function _waitforready(stage::PIStage; timeout::Real = REFERENCE_TIMEOUT_S[])
    ready = Ref{Cint}(0)
    deadline = time() + timeout
    while true
        ok = PI_IsControllerReady(stage.id, ready)
        ok == 0 && error("PI_IsControllerReady failed (GCS error $(_pi_geterror(stage)))")
        ready[] != 0 && return nothing
        time() > deadline && error("PI controller not ready after $(timeout) s")
        sleep(0.1)
    end
end

"""
Poll `PI_qFRF` until both axes report referenced; throw if that has not happened within
`timeout` seconds or the query itself fails.
"""
function _waitforreference(stage::PIStage; timeout::Real = 60.0)
    # PI_qFRF fills `BOOL*`: one 32-bit int per axis, like PI_SVO.
    referenced = zeros(Cint, 2)
    deadline = time() + timeout
    while true
        ok = PI_qFRF(stage.id, "1 2", referenced)
        ok == 1 || error("PI_qFRF failed (GCS error $(_pi_geterror(stage)))")
        all(!=(0), referenced) && return nothing
        time() > deadline && error("PI stage not referenced after $(timeout) s: " *
            "qFRF = $(Int.(referenced)), GCS error $(_pi_geterror(stage))")
        sleep(0.1)
    end
end


"""
Function to disconnect PI Stage
"""
function shutdown_original(stage::PIStage)
    isconnected = PI_IsConnected(stage.id)

    if isconnected == 1
        PI_CloseConnection(stage.id)
        isconnected = PI_IsConnected(stage.id)

        if isconnected == 1
            @error "Stage failed to disconnect"
        else
            @info "Stage disconnected"
            stage.connectionstatus = false
            stage.id = Cint(-1)
        end
    else
        @error "Stage already disconnected"
        stage.connectionstatus = false
        stage.id = Cint(-1)
    end
end

"""
Sets the servo state of both the x and y axis
"""
function servo(stage::PIStage, xtoggle::Bool, ytoggle::Bool)
    # PI_SVO takes `const BOOL*` = 32-bit ints, one per axis. Passing two UInt8 made the DLL
    # read axis 2's flag from whatever byte followed the array: servo silently OFF on Y,
    # every PI_MOV refused with GCS error 5 (worked by luck on Julia 1.10, failed on 1.13).
    istoggled = PI_SVO(stage.id, "1 2", Cint[xtoggle, ytoggle])
    stage.servostatus = (xtoggle, ytoggle)

    if istoggled == 1
        @info "Servo toggled to: " * string(xtoggle) * ", " * string(ytoggle)
    else
        @error "Servo failed to toggle"
    end
end

"""
Sets the servo state of the x axis
"""
function servox(stage::PIStage, xtoggle::Bool)
    PI_SVO(stage.id, "1", Cint[xtoggle])
    stage.servostatus = (xtoggle, stage.servostatus[2])
end


"""
Sets the servo state of the y axis
"""
function servoy(stage::PIStage, ytoggle::Bool)
    PI_SVO(stage.id, "2", Cint[ytoggle])
    stage.servostatus = (stage.servostatus[1], ytoggle)
end


function setvel(stage::PIStage,vel::Vector{Float64})

    success = PI_VEL(stage.id, "1 2", vel)

    if success == 0
        @error "Failed to set velocity"
    end
    velocity = Vector{Cdouble}(undef, 2)
    success = PI_qVEL(stage.id, "1 2", velocity)
    
    if success == 0
        @error "Failed to query velocity"
    else
        stage.velocity = velocity
    end
    return success
end