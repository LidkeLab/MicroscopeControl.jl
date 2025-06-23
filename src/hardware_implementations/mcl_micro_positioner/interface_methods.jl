function initialize(positioner::MCLZPositioner)
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

function shutdown(positioner::MCLZPositioner)
    @ccall madlibpath.MCL_ReleaseHandle(positioner.handle::Cint)::Cvoid
    positioner.connectionstatus = false
    @info "Handle Released"
    return nothing
end

function export_state(positioner::MLCZPositioner)
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

function ObjPositionerInterface.move(positioner::MCLZPositioner, z::Float64)
    positioner.targ_z = z
    call = @ccall madlibpath.MCL_MicroDriveMoveProfile(
        positioner.axis::Cint, 
        positioner.velocity::Cdouble, 
        positioner.targ_z::Cdouble, 
        positioner.rounding::Cint, 
        positioner.handle::Cint
    )
    return HardwareReturn[call]
end

function ObjPositionerInterface.get_position(positioner::MCLZPositioner)

end

function ObjPositionerInterface.stop_motion(positioner::MCLZPositioner)
    call = @ccall madlibpath.MCL_MicroDriveStop(
        Cuchar(00000000)::Cuchar, # Status, see manual for more info
        positioner.handle::Cint
    )
    return HardwareReturn[call]
end