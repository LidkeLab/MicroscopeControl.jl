

"""
Function to update the position of the PI Stage
"""
function getposition(stage::PIStage)
    position = Vector{Cdouble}(undef, 2)
    PI_qPOS(stage.id, "1 2", position)

    @info "Stage position: " * string(position[1]) * ", " * string(position[2])
    stage.real_x = position[1]
    stage.real_y = position[2]
end

"""
Function to update the x position of the PI Stage
"""
function getxposition(stage::PIStage)
    xposition = Cdouble(0.0)
    PI_qPOS(stage.id, "1", [xposition])
    stage.real_x = xposition
end

"""
Function to update the y position of the PI Stage
"""
function getyposition(stage::PIStage)
    yposition = Cdouble(0.0)
    PI_qPOS(stage.id, "2", [yposition])
    stage.real_y = yposition
end

"""
BOOL PI_IsMoving (int ID, const char* szAxes, BOOL* pbValueArray)

Function to check if the PI Stage is moving, both the x and y axis are checked
"""
function ismoving(stage::PIStage)
    ismoving = zeros(UInt32, 2)
    PI_IsMoving(stage.id, "1 2", ismoving)
    stage.ismoving = (Bool(ismoving[1]), Bool(ismoving[2]))
end

function getrange(stage::PIStage)
    # Both reads run, so a failed min does not skip the max.
    okmin = findmin(stage)
    okmax = findmax(stage)
    return okmin == 1 && okmax == 1 ? Cint(1) : Cint(0)
end

"""

"""
function findmin(stage::PIStage)
    minpositions = zeros(Cdouble, 2)
    ok = PI_qTMN(stage.id, "1 2", minpositions)
    if ok == 1
        stage.range_x = (minpositions[1], stage.range_x[2])
        stage.range_y = (minpositions[2], stage.range_y[2])
    end
    return ok
end

"""

"""
function findmax(stage::PIStage)
    maxpositions = zeros(Cdouble, 2)
    ok = PI_qTMX(stage.id, "1 2", maxpositions)
    if ok == 1
        stage.range_x = (stage.range_x[1], maxpositions[1])
        stage.range_y = (stage.range_y[1], maxpositions[2])
    end
    return ok
end