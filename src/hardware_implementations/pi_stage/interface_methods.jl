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

