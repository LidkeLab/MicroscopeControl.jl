# This file contains wrappers for the Motion Control C functions for the microdrive

"""
    microdrive_move_status(positioner::MclZPositioner)
Checks to see if the device is moving. Should be called before writing to encoders, as it could
mess up their internal clock.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `ismoving::Bool`: Returns true 1 if moving, false 0 if not 
"""
function microdrive_move_status(positioner::MclZPositioner)
    ismoving = Ref{Cint}() # allocate mem
    call = @ccall madlibpath.MCL_MicroDriveMoveStatus(
        ismoving::Ref{Cint},
        positioner.handle::Cint
    )::Cint
    if call != 0 
        @error "Failed to retrive move status. Error code: $(HardwareReturn[call])"
    end
    return Bool(ismoving[])
end

"""
    microdrive_wait(positioner::MclZPositioner)
Waits untill the stage stops moving. Manual says it should be about 10ms with a working device.
Call after every function to ensure that internal clock of MicroDrive doesn't get messed up.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - Error code, decoded
"""
function microdrive_wait(positioner::MclZPositioner)
    call = @ccall madlibpath.MCL_MicroDriveWait(positioner.handle::Cint)::Cint
    return HardwareReturn[call]
end

"""
    microdrive_status(positioner::MclZPositioner)
Reads the current state of the limit switches 

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - Status 
        - MicroDrive(0x2500)
            - Bit 4, Success/Failure
            - Bit 3, Y Forward Limit Switch
            - Bit 2, Y Reverse Limit Switch
            - Bit 1, X Forward Limit Switch
            - Bit 0, x Reverse Limit Switch
        - MicroDrive1
            - Bit 4, Success/Failure
            - Bit 3, Forward Limit Switch
            - Bit 2, Reverse Limit Switch
"""
function microdrive_status(positioner::MclZPositioner)
    status = Ref{Cuchar}() # allocate memory 
    call = @ccall madlibpath.MCL_MicroDriveStatus(
        status::Ref{Cuchar},
        positioner.handle::Cint
    )::Cint

    if call != 0 
        @error "Failed to retrive MicroDrive Status. Error code: $(HardwareReturn[call])"
    end
    return status[]
end

"""
    microdrive_stop(positioner::MclZPositioner)
Stops the stage from moving

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - Error code, decoded
    - Status 
        - MicroDrive(0x2500)
            - Bit 4, Success/Failure
            - Bit 3, Y Forward Limit Switch
            - Bit 2, Y Reverse Limit Switch
            - Bit 1, X Forward Limit Switch
            - Bit 0, x Reverse Limit Switch
        - MicroDrive1
            - Bit 4, Success/Failure
            - Bit 3, Forward Limit Switch
            - Bit 2, Reverse Limit Switch
"""
function microdrive_stop(positioner::MclZPositioner)
    # same code as stop_motion, but also returns status
    status = Ref{Cuchar}()
    call = @ccall madlibpath.MCL_MicroDriveStop(
        status::Ref{Cuchar}, # passes pointer
        positioner.handle::Cint
    )::Cint
    if call != 0 
        @error "Failed to stop motion. Error code: $(HardwareReturn[call])"
    end
    return HardwareReturn[call], status[]
end

"""
    microdrive_information(positioner::MclZPositioner)
Obtains information about the state of the MicroDrive, including encoder resolution
step size, max velocity, and min velocity.

# Arguments
    - `positioner::MclZPositioner`: the positioner or stage

# Returns 
    - `status::Dict{String, Float64}`
"""
function microdrive_information(positioner::MclZPositioner)
    res = Ref{Cdouble}() 
    step_size = Ref{Cdouble}()
    max_velocity = Ref{Cdouble}()
    min_velocity = Ref{Cdouble}()

    call = @ccall madlibpath.MCL_MicroDriveInformation(
        res::Ref{Cdouble},
        step_size::Ref{Cdouble},
        max_velocity::Ref{Cdouble},
        min_velocity::Ref{Cdouble},
        positioner.handle::Cint
    )::Cint

    if call != 0 
        @error "Failed to retrive MicroDrive information. Error code: $(HardwareReturn[call])"
    end

    status = Dict{String, Float64}(
        "Resolution"=> res[],
        "Step Size" => step_size[],
        "Maximum Velocity" => max_velocity[],
        "Minimum Velocity" => min_velocity[]
    )
    return status
end