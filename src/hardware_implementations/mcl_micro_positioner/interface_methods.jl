function initialize(positioner::MclZPositioner)
    @info "Initializing Objective Positioner"
    handle = @ccall madlibpath.MCL_InitHandle()::Cint
    positioner.handle = handle
    positioner.connectionstatus = true
    if handle == 0
        @error "Failed to Initialize"
    else
        return handle
    end
end

function shutdown(positioner::MclZPositioner)
    @ccall madlibpath.MCL_ReleaseHandle(positioner.handle::Cint)::Cvoid
    positioner.connectionstatus = false
    @info "Handle Released"
    return nothing
end

function export_state(positioner::MclZPositioner)
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
    positioner.targ_z = z

    # Ensures that the device is not written to while it is moving
    # (If the device is written to while it is moving, the internal clock gets messed up)
    if microdrive_move_status(positioner)
        microdrive_wait(positioner)
    end

    call = @ccall madlibpath.MCL_MicroDriveMoveProfile(
        positioner.axis::Cint, 
        positioner.velocity::Cdouble, 
        positioner.targ_z::Cdouble, 
        positioner.rounding::Cint, 
        positioner.handle::Cint
    )
    return HardwareReturn[call]
end

function ObjPositionerInterface.get_position(positioner::MclZPositioner)
    pos = Vector{Cdouble}(undef, 1)  # allocate memory
    @ccall madlibpath.MCL_MD1ReadEncoder(
        pos::ptr{Cdouble},
        positioner.handle::Cint
    )
    if call != 0 
        # fatal error, do not want to read bad memory
        error("Failed to get position. Error code: $(HardwareReturn[call])")
    end
    return pos
end

function ObjPositionerInterface.stop_motion(positioner::MclZPositioner)
    status = Vector{Cuchar}(undef, 1) # allocate memory as array of bytes
    call = @ccall madlibpath.MCL_MicroDriveStop(
        status::Ptr{Cuchar}, # passes pointer
        positioner.handle::Cint
    )
    if call != 0 
        @error "Failed to stop motion. Error code: $(HardwareReturn[call])"
    end
    return HardwareReturn[call]
end