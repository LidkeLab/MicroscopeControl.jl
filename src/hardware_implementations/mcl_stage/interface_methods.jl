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