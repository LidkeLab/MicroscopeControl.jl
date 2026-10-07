
"""
Function to move PI Stage to a specific position
"""
function move(stage::PIStage, x::Float64, y::Float64)
    ok = PI_MOV(stage.id, "1 2", [Cdouble(x),Cdouble(y)])
    ok == 1 || @error "PI_MOV refused — stage not connected, not referenced, or servo off"
    stage.targ_x = x
    stage.targ_y = y
    @info "Stage moving to position: " * string(x) * ", " * string(y)
end

"""
Function to move PI Stage, and wait for completion
"""
function moveandwait(stage::PIStage, x::Float64, y::Float64)
    PI_MOV(stage.id, "1 2", [Cdouble(x),Cdouble(y)])
    stage.targ_x = x
    stage.targ_y = y
    ismoving(stage)
    while stage.ismoving[1] == 1 || stage.ismoving[2] == 1
        ismoving(stage)
    end
end


"""
Function to move PI Stage X axis to a specific position
"""
function movex(stage::PIStage, x::Float64)
    PI_MOV(stage.id, "1", [Cdouble(x)])
    stage.targ_x = x
end

"""
Function to move PI Stage Y axis to a specific position
"""
function movey(stage::PIStage, y::Float64)
    PI_MOV(stage.id, "2", [Cdouble(y)])
    stage.targ_y = y
end

"""
Function call to smoothly stop motion of the PI Stage
"""
function stopmotion(stage::PIStage)
    isstopped = PI_HLT(stage.id, "1 2")
    if isstopped == 1
        @info "Motion successfully stopped"
    else
        @error "Motion unsucessfully stopped"
    end
end

"""
Function call to immediately stop the PI Stage
"""
function immediatestop(stage::PIStage)
    isstopped = PI_STP(stage.id)
    if isstopped == 1
        @info "Motion successfully stopped"
    else
        @error "Motion unsucessfully stopped"
    end
end
