function initialize(stage::MCLStage)
    @info "Initializing stage"
    # Initialize stage
    handle = inithandle(stage)

    if handle > 0 
        # Set stage range
        StageInterface.getrange(stage)
    else
        @error "Stage failed to initialize"
    end

    return handle
end

function shutdown(stage::MCLStage)
    @info "Shutting down stage"
    # Shutdown stage
    releasehandle(stage)
    return nothing
end

function StageInterface.move(stage::MCLStage, x::Float64, y::Float64, z::Float64)
    @info "Stage moving to position: " * string(x) * ", " * string(y) * ", " * string(z)

    # Move stage to position
    
    errcodex = singlewrite(stage, 1, x)
    errcodey = singlewrite(stage, 2, y)
    errcodez = singlewrite(stage, 3, z)

    return (errcodex, errcodey, errcodez)
end

function move_to_z(stage::MCLStage, z::Float64)
    @info "Z stage moving to position: " * string(z)

    # Move Z stage to position
    # errcodez = singlewriteZ(stage, z)
    errcodez = singlewrite(stage, 3, z)

    return errcodez
end

function get_z_position(stage::MCLStage)
    @info "Getting Z stage position"

    # Get Z stage position
    # z = singlereadZ(stage)
    z = singleread(stage, 3)

    return z
end

function StageInterface.home(stage::MCLStage)
    @info "Homing stage"

    # Home stage
    errcodes = StageInterface.move(stage, 0.0, 0.0, 0.0)

    return errcodes
end

function StageInterface.stopmotion(stage::MCLStage)
    @error "STOP MOTION NOT IMPLEMENTED"
end

function StageInterface.getposition(stage::MCLStage)
    @info "Getting stage position"

    x = singleread(stage, 1)
    y = singleread(stage, 2)
    z = singleread(stage, 3)

    return (x, y, z)
end

function StageInterface.getrange(stage::MCLStage)
    @info "Getting stage range"

    getcalibration(stage, 1)
    getcalibration(stage, 2)
    getcalibration(stage, 3)

    return (stage.range_x, stage.range_y, stage.range_z)
end

"""
    export_state(stage::MCLStage)
"""
function export_state(stage::MCLStage)
    attributes = Dict{String, Any}(
        "stage_label" => stage.stagelabel,
        "units" => stage.units,
        "id" => stage.id,
        "dimensions" => stage.dimensions,
        "connected" => stage.connectionstatus,
        "position_x" => stage.real_x,
        "position_y" => stage.real_y,
        "position_z" => stage.real_z,
        "target_x" => stage.targ_x,
        "target_y" => stage.targ_y,
        "target_z" => stage.targ_z,
        "range_x" => isa(stage.range_x, Tuple) ? collect(stage.range_x) : stage.range_x,
        "range_y" => isa(stage.range_y, Tuple) ? collect(stage.range_y) : stage.range_y,
        "range_z" => isa(stage.range_z, Tuple) ? collect(stage.range_z) : stage.range_z
    )
    
    data = nothing
    children = Dict{String, Any}()

    return attributes, data, children
end