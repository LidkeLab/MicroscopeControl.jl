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
    numconnected = @ccall gcs2path.PI_EnumerateUSB(bufferstring::Ptr{UInt8}, 1024::Int, "PI C-867"::Ptr{UInt8})::Cint

    @info "Number of connected devices: " * string(numconnected)

    #Set connection status to true
    if numconnected > 0
        stage.connectionstatus = true
    else
        @error "No devices connected"
        stage.connectionstatus = false
        return
    end
    #Connect to usb device
    stage.id = @ccall gcs2path.PI_ConnectUSB(bufferstring::Ptr{UInt8})::Cint

    @info "Device ID: " * string(stage.id)

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
    end
end

"""
Sets the servo state of both the x and y axis
"""
function servo(stage::PIStage, xtoggle::Bool, ytoggle::Bool)
    istoggled = @ccall gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, [UInt8(xtoggle), UInt8(ytoggle)]::Ptr{UInt8})::Cint
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
    @ccall gcs2path.PI_SVO(stage.id::Cint, "1"::Ptr{UInt8}, [UInt8(xtoggle)]::Ptr{UInt8})::Cint
    stage.servostatus[1] = xtoggle
end


"""
Sets the servo state of the y axis
"""
function servoy(stage::PIStage, ytoggle::Bool)
    @ccall gcs2path.PI_SVO(stage.id::Cint, "2"::Ptr{UInt8}, [UInt8(ytoggle)]::Ptr{UInt8})::Cint
    stage.servostatus[2] = ytoggle
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