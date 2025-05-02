"""
Function to initialize PI Stage, right now this requires calibration using PiMikroMove to work correctly, no documentation on how to calibrate using the PI_GCS2 library
"""
function initialize(stage::PIStage) #TODO: Error handling
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
"""
function export_state(stage::PIStage)
    attributes = Dict{String, Any}(
        "stage_label" => stage.stagelabel,
        "units" => stage.units,
        "dimensions" => stage.dimensions,
        "connected" => stage.connectionstatus,
        "id" => stage.id,
        "position_x" => stage.real_x,
        "position_y" => stage.real_y,
        "target_x" => stage.targ_x,
        "target_y" => stage.targ_y,
        "range_x" => stage.range_x,
        "range_y" => stage.range_y,
        "is_moving_x" => stage.ismoving[1],
        "is_moving_y" => stage.ismoving[2],
        "servo_status_x" => stage.servostatus[1],
        "servo_status_y" => stage.servostatus[2],
        "velocity_x" => stage.velocity[1],
        "velocity_y" => stage.velocity[2]
    )
    
    data = nothing
    children = Dict{String, Any}()

    return attributes, data, children
end