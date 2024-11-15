

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

function setvel(stage::N472,vel::Vector{Float64})
    axes = join(stage.axes, " ")
    success = PI_VEL(stage.id, axes, vel)
    
    if success == FALSE
        @error "Failed to set velocity"
    end

    success = PI_qVEL(stage.id, axes, stage.velocity)
    if success == FALSE
        @error "Failed to query velocity"
    end
    return success
end