# these are the functions inhereted from ObjPositionerInterface and AbstractInstrument

function initialize(positioner::Piezo)
    @info "initalizing Piezo"

    handle_id = @ccall nanoDrivePath.MCL_InitHandle()::Cint
    positioner.handle = handle_id

    # Failure code == 0
    if handle_id == 0
        @error "Falied to find and connect to Piezo Positioner"
        positioner.connected = false
        return handle_id
    end

    # get and set range of positioner
    callibration = @ccall nanoDrivePath.MCL_GetCalibration(
        Cint(1)::Cint, # axis
        positioner.handle::Cint) # which handle?
    positioner.range = callibration

    return handle_id
end

function shutdown(positioner::Piezo)
    @info "Shutting down Piezo"
    @ccall nanoDrivePath.MCL_ReleaseHandle(stage.id::Cint)
    stage.connectionstatus = false
    return nothing
end

function export_state(positioner::Piezo)
    attributes = Dict{String, Any}(
        "unique_id" => positioner.unique_id,
        "units" => positioner.units,
        "handle" => positioner.handle,
        "connected" => positioner.connected,
        "real position" => positioner.real_pos,
        "target position" => positioner.target,
        "range" => positioner.range
    )
    return attributes
end

function ObjPositionerInterface.move(positioner::Piezo, pos::Foat64)
    @info "Moving objective to $pos"
    # Perhaps single write N should go here instead
    err = @ccall nanoDrivePath.MCL_SingleWriteZ(
        pos::Cdouble, 
        positioner.handle::Cint)
    stage.target = pos
    return err
end

function ObjPositionerInterface.reset(positioner::Piezo)
    @info "Resetting the objective"
    # Perhaps single write N should go here instead
    err = @ccall nanoDrivePath.MCL_SingleWriteZ(
        Cdouble(0.0),
        positioner.handle::Cint)
    stage.target = pos
    return err
end

function ObjPositionerInterface.get_position(positioner::Piezo)
    # Perhaps single write N should go here instead
    pos = @ccall nanoDrivePath.MCL_SingleReadZ(positioner.handle::Cint)
    stage.real_pos = pos
    return pos
end

function ObjPositionerInterface.stop_motion(positioner::Piezo)
    @error "No Stop Motion for NanoDriveC"
end