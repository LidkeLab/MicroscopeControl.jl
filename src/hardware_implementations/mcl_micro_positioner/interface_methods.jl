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