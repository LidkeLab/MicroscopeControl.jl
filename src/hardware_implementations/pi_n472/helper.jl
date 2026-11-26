

function set_refpos(stage::N472)
    axes = join(stage.axes, " ")
    success = PI_POS(stage.id, axes, stage.homepos)
    return success
end

function reference_ref(stage::N472,axisId::Int)
    ax = stage.axes[axisId]
    success = PI_FRF(stage.id, ax)
    isready = Int32[0]
    while isready[1] == 0
        success = PI_IsControllerReady(stage.id,isready)
        if success == FALSE
            break
        end
    end
    if success == FALSE
        @error "Failed to reference axis $ax"
    else
        @info "Axis $ax is referenced"
    end
    return 
end

function move_abs(stage::N472, pos::Vector{Float64})
    axes = join(stage.axes, " ")
    success = PI_MOV(stage.id, axes, pos)
    
    # success = PI_IsMoving(stage.id, stage.axes, stage.ismoving)
    # while any(Bool.(stage.ismoving))
    #     success = PI_IsMoving(stage.id, stage.axes, stage.ismoving)
    #     if success == FALSE
    #         break
    #     end
    # end
    # TODO: check whether the stage is on target
    #isontarget = zeros(BOOL,3)
    success = PI_qONT(stage.id, axes, stage.isontarget)
    while ~all(Bool.(stage.isontarget))
        success = PI_qONT(stage.id, axes, stage.isontarget)
        if success == FALSE
            break
        end
    end
    return success
end


function setservo(stage::N472,axisId::Int, servoON::BOOL)
    ax = stage.axes[axisId]
    state = [servoON]
    success = PI_SVO(stage.id, ax, state)
    if success == FALSE
        @error "Failed to toggle servo for axis $ax to $servoON"
    else
        @info "Servo for axis $ax is $servoON"    
        success = PI_qSVO(stage.id, ax, state)
        stage.servostatus[axisId] = state[1]     

    end
    return success
end

"""
    setvel(stage::N472, vel::Vector{Float64}) -> BOOL

Set the closed-loop move velocity of all axes with the GCS2 `PI_VEL` call, one value per axis in the order of
`stage.axes`, then read the velocities back with `PI_qVEL` into `stage.velocity` (so the field holds what
the controller reports, not what was requested). `vel` is passed to the controller unchanged; the code states
no unit, and the default `stage.velocity` is `0.01` for `units="mm"`. Returns `FALSE` if the set failed,
otherwise the result of the read-back (`TRUE` or `FALSE`); a failure is also logged with `@error`, never
thrown. [`initialize`](@ref) calls it with `stage.velocity`. Needs an open connection.
"""
function setvel(stage::N472,vel::Vector{Float64})
    axes = join(stage.axes, " ")
    success = PI_VEL(stage.id, axes, vel)
    
    if success == FALSE
        @error "Failed to set velocity"
    end

    qsuccess = PI_qVEL(stage.id, axes, stage.velocity)
    if qsuccess == FALSE
        @error "Failed to query velocity"
    end
    return success == FALSE ? FALSE : qsuccess
end
