"""
Function to initialize PI Stage, right now this requires calibration using PiMikroMove to work correctly, no documentation on how to calibrate using the PI_GCS2 library
"""
function initialize_original(stage::PIStage) #TODO: Error handling
    if stage.connectionstatus == true
        @error "Stage already initialized"
        return
    end

    # Create a buffer string
    bufferstring = Vector{UInt8}(undef, 1024)

    #Find number of connected USB devices, specifically the PI C-867 controller
    numconnected = @ccall gcs2path.PI_EnumerateUSB(bufferstring::Ptr{UInt8}, 1024::Cint, "PI C-867"::Ptr{UInt8})::Cint

    @info "Number of connected devices: " * string(numconnected)

    #Set connection status to true
    if numconnected > 0
        stage.connectionstatus = true
    else
        # The DLL enumerates only controllers nobody has open: a C-867 that Device Manager
        # still lists is held by another process (a second Julia with an initialized stage —
        # under any Windows user —, PIMikroMove, or an open COM port).
        @error "No PI C-867 found by the GCS2 library — controller absent, or held by another process"
        stage.connectionstatus = false
        return
    end
    #Connect to usb device
    stage.id = @ccall gcs2path.PI_ConnectUSB(bufferstring::Ptr{UInt8})::Cint

    @info "Device ID: " * string(stage.id)

    if stage.id < 0
        # The connect itself failed (id -1): typically another process already holds the
        # controller (a second Julia with an initialized stage, PIMikroMove, an open COM port).
        stage.connectionstatus = false
        @error "PI_ConnectUSB failed — the controller is probably held by another process"
        return
    end

    #Set servo mode to on for both axes, noting axis X is labeled "1" and axis Y is labeled "2"
    servo(stage, true, true)

    #Reference stage
    referencemove(stage)

    #Find the max and min position of the axes
    getrange(stage)
    
    #Sleep 1 second for initialization
    ismoving(stage)
    while stage.ismoving[1] == 1 || stage.ismoving[2] == 1
        ismoving(stage)
    end

    #Set velocity to 1 mm/s
    success = setvel(stage, stage.velocity)

    @info "Stage initialized"
    return
end

"""
Function to calibrate PI Stage, not implemented yet as there is no documentation for this stage on calibration using the PI_GCS2 library
Possibly must use PiMikroMove to calibrate, but this is not ideal, however there is a CLI

"""
function referencemove(stage::PIStage)
    ismoved = @ccall gcs2path.PI_FRF(stage.id::Cint, "1 2"::Ptr{UInt8})::Cint
    return ismoved
end


"""
Function to disconnect PI Stage
"""
function shutdown_original(stage::PIStage)
    isconnected = @ccall gcs2path.PI_IsConnected(stage.id::Cint)::Cint

    if isconnected == 1
        @ccall gcs2path.PI_CloseConnection(stage.id::Cint)::Cvoid
        isconnected = @ccall gcs2path.PI_IsConnected(stage.id::Cint)::Cint

        if isconnected == 1
            @error "Stage failed to disconnect"
        else
            @info "Stage disconnected"
            stage.connectionstatus = false
        end
    else
        @error "Stage already disconnected"
        stage.connectionstatus = false
    end
end

"""
Sets the servo state of both the x and y axis
"""
function servo(stage::PIStage, xtoggle::Bool, ytoggle::Bool)
    # PI_SVO takes `const BOOL*` = 32-bit ints, one per axis. Passing two UInt8 made the DLL
    # read axis 2's flag from whatever byte followed the array: servo silently OFF on Y,
    # every PI_MOV refused with GCS error 5 (worked by luck on Julia 1.10, failed on 1.13).
    istoggled = @ccall gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, Cint[xtoggle, ytoggle]::Ptr{Cint})::Cint
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
    @ccall gcs2path.PI_SVO(stage.id::Cint, "1"::Ptr{UInt8}, Cint[xtoggle]::Ptr{Cint})::Cint
    stage.servostatus = (xtoggle, stage.servostatus[2])
end


"""
Sets the servo state of the y axis
"""
function servoy(stage::PIStage, ytoggle::Bool)
    @ccall gcs2path.PI_SVO(stage.id::Cint, "2"::Ptr{UInt8}, Cint[ytoggle]::Ptr{Cint})::Cint
    stage.servostatus = (stage.servostatus[1], ytoggle)
end


function setvel(stage::PIStage,vel::Vector{Float64})

    success = @ccall gcs2path.PI_VEL(stage.id::Cint, "1 2"::Ptr{UInt8}, vel::Ptr{Cdouble})::Cint

    if success == 0
        @error "Failed to set velocity"
    end
    velocity = Vector{Cdouble}(undef, 2)
    success = @ccall gcs2path.PI_qVEL(stage.id::Cint, "1 2"::Ptr{UInt8}, velocity::Ptr{Cdouble})::Cint
    
    if success == 0
        @error "Failed to query velocity"
    else
        stage.velocity = velocity
    end
    return success
end