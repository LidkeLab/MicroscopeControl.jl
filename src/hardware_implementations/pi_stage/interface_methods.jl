"""
Initialize the PI stage; see `initialize_original` for the sequence and its failure behaviour.
"""
function initialize(stage::PIStage)
    initialize_original(stage)
end

function shutdown(stage::PIStage)
    shutdown_original(stage)
end

"""
Function to move PI Stage to a specific position
"""
function StageInterface.move(stage::PIStage, x::Float64, y::Float64)
    move(stage, x, y)
end


"""
Function call to immediately stop motion of the PI Stage

"""
function StageInterface.stopmotion(stage::PIStage)
   stopmotion(stage)
end

"""
Function to update the position of the PI Stage
"""
function StageInterface.getposition(stage::PIStage)
    getposition(stage)
end

"""
Function to update the position range of the PI Stage
"""
function StageInterface.getrange(stage::PIStage)
    getrange(stage)
    return stage.range_y  # preserves 0.2.5's return value
end


"""
Move to home position
"""
function StageInterface.home(stage::PIStage)
    ismoved = move(stage, 12.5, 12.5)
    
    @info "Stage moving to home position"
    return ismoved
end


"""
Function to toggel the drift correction of the stage. 1 is for on, 0 is for off.
"""
function StageInterface.driftcorrection(stage::PIStage, xtoggle::Bool, ytoggle::Bool)
    @error "Drift correction not supported by PI Stage"
end


"""
Sets the servo state of both the x and y axis
"""
function StageInterface.servo(stage::PIStage, xtoggle::Bool, ytoggle::Bool)
    servo(stage, xtoggle, ytoggle)
end

"""
    export_state(stage::PIStage)

Read the connected stage's position through `getposition`, without moving it. `position_fresh::Bool` is true
only when this read succeeds. If disconnected or the read throws, warn once with the error and export the
last-read position; an acquisition save is not interrupted.
"""
function export_state(stage::PIStage)
    position, position_fresh = StageInterface._export_position(stage, (stage.real_x, stage.real_y)) do
        StageInterface.getposition(stage)
        (stage.real_x, stage.real_y)
    end
    attributes = Dict{String, Any}(
        "stage_label" => stage.stagelabel,
        "units" => stage.units,
        "dimensions" => stage.dimensions,
        "position_fresh" => position_fresh,
        "connected" => stage.connectionstatus,
        "id" => stage.id,
        "position_x" => position[1],
        "position_y" => position[2],
        "target_x" => stage.targ_x,
        "target_y" => stage.targ_y,
        "range_x" => collect(stage.range_x),  # Convert tuple to array
        "range_y" => collect(stage.range_y)   # Convert tuple to array
    )
    
    data = nothing
    children = Dict{String, Any}()

    return attributes, data, children
end