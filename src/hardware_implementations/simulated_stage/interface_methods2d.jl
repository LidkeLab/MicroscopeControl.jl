function StageInterface.initialize(stage::SimStage2d)
    #function to initialize stage
    println("Initializing stage...")
    stage.connectionstatus = true
end

function StageInterface.shutdown(stage::SimStage2d)
    #function to shutdown stage
    println("Shutting down stage...")
    stage.connectionstatus = false
end

function StageInterface.move(stage::SimStage2d, x::Float64, y::Float64)
    #function to move stage to a position
    println("Moving stage to position ($x, $y)...")
    stage.targ_x = x
    stage.targ_y = y
end

function StageInterface.getposition(stage::SimStage2d)
    #function to get stage position
    println("Getting stage position...")
    stage.real_x = stage.targ_x
    stage.real_y = stage.targ_y
end

function StageInterface.getrange(stage::SimStage2d)
    #function to get stage range
    println("Getting stage range...")
    return (stage.range_x, stage.range_y)
end

function StageInterface.stopmotion(stage::SimStage2d)
    #function to stop stage motion
    println("Stopping stage motion...")
    # Implementation depends on the specific stage API
end

function StageInterface.home(stage::SimStage2d)
    #function to move stage to home position
    println("Moving stage to home position...")
    stage.real_x = 0.0
    stage.real_y = 0.0
end

function StageInterface.servo(stage::SimStage2d, xtoggle::Bool, ytoggle::Bool)
    #function to set stage servo state
    println("Setting stage servo state...")
    stage.servostatus = (xtoggle, ytoggle)
end

function StageInterface.driftcorrection(stage::SimStage2d, xtoggle::Bool, ytoggle::Bool)
    #function to set stage drift correction state
    println("Setting stage drift correction state...")
    stage.driftcorrectionstatus = (xtoggle, ytoggle)
end