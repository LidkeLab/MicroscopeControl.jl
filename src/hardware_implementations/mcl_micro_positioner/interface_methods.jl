function ObjPositionerInterface.initialize(positioner::MclZPositioner)
    @info "Initializing Objective Positioner"
    handle = @ccall madlibpath.MCL_InitHandle()::Cint
    positioner.handle = handle
    positioner.connectionstatus = true
    if handle == 0
        @error "Failed to Initialize"
        positioner.connectionstatus = false
    else
        return handle
    end
end

function ObjPositionerInterface.shutdown(positioner::MclZPositioner)
    @ccall madlibpath.MCL_ReleaseHandle(positioner.handle::Cint)::Cvoid
    positioner.connectionstatus = false
    @info "Handle Released"
    return nothing
end

function ObjPositionerInterface.export_state(positioner::MclZPositioner)
        attributes = Dict{String, Any}(
        "label" => positioner.label,
        "units" => positioner.units,
        "handle" => positioner.handle,
        "connectionstatus" => positioner.connectionstatus,
        "real position" => positioner.real_z,
        "target position" => positioner.targ_z,
        "range" => positioner.range,
        "velocity"=> positioner.velocity,
        "axis" => positioner.axis,
        "rounding" => positioner.rounding
    )
    return attributes
end

function ObjPositionerInterface.move(positioner::MclZPositioner, z::Float64)
    positioner.targ_z += z

    # Ensures that the device is not written to while it is moving
    # (If the device is written to while it is moving, the internal clock gets messed up)
    if microdrive_move_status(positioner)
        microdrive_wait(positioner)
    end
    call = @ccall madlibpath.MCL_MD1MoveProfile(
        positioner.velocity::Cdouble, 
        z::Cdouble, 
        positioner.rounding::Cint, 
        positioner.handle::Cint
    )::Cint
    while microdrive_move_status(positioner)
        positioner.ismoving = true
    end
    positioner.ismoving = false
    return HardwareReturn[call]
end

function ObjPositionerInterface.home(positioner::MclZPositioner)
    positioner.targ_z = 0.0
    # get number of microsteps away from zero
    current_pos = md1_read_encoder(positioner)[1]

    call = ObjPositionerInterface.move(positioner, -current_pos) # move to zero
    return call
end

function ObjPositionerInterface.getposition(positioner::MclZPositioner)
    pos = Ref{Cdouble}()
    call = @ccall madlibpath.MCL_MD1ReadEncoder(
        pos::Ref{Cdouble},
        positioner.handle::Cint
    )::Cint
    if call != 0 
        # fatal error, do not want to read bad memory
        error("Failed to get position. Error code: $(HardwareReturn[call])")
    end
    return pos[]
end

function ObjPositionerInterface.stopmotion(positioner::MclZPositioner)
    status = Ref{Cuchar}()
    call = @ccall madlibpath.MCL_MicroDriveStop(
        status::Ref{Cuchar}, # passes pointer
        positioner.handle::Cint
    )::Cint
    if call != 0 
        @error "Failed to stop motion. Error code: $(HardwareReturn[call])"
    end
    return HardwareReturn[call]
end