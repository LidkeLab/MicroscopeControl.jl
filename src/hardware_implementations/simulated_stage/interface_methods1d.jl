function initialize(stage::SimStage1d)
    #function to initialize stage
    println("Initializing stage...")
    stage.connectionstatus = true
end

function shutdown(stage::SimStage1d)
    #function to shutdown stage
    println("Shutting down stage...")
    stage.connectionstatus = false
end

function StageInterface.move(stage::SimStage1d, x::Float64)
    #function to move stage to a position
    println("Moving stage to position ($x)...")
    stage.targ_x = x
end

function StageInterface.getposition(stage::SimStage1d)
    #function to get stage position
    println("Getting stage position...")
    stage.real_x = stage.targ_x
end

function StageInterface.getrange(stage::SimStage1d)
    #function to get stage range
    println("Getting stage range...")
    return stage.range_x
end

function StageInterface.stopmotion(stage::SimStage1d)
    #function to stop stage motion
    println("Stopping stage motion...")
    # Implementation depends on the specific stage API
end

function StageInterface.home(stage::SimStage1d)
    #function to move stage to home position
    println("Moving stage to home position...")
    stage.real_x = 0.0
end

function StageInterface.servo(stage::SimStage1d, xtoggle::Bool)
    #function to set stage servo state
    println("Setting stage servo state...")
    stage.servostatus = xtoggle
end

function StageInterface.driftcorrection(stage::SimStage1d, xtoggle::Bool)
    #function to set stage drift correction state
    println("Setting stage drift correction state...")
    stage.driftcorrectionstatus = xtoggle
end