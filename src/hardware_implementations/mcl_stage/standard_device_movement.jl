#=
For reference, when choosing axis
1 = X
2 = Y
3 = Z
=#

"""
singleread(stage::MCLStage)

Reads the location of specific axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
- `axis::Int`: The axis to read from.
# Description
This function reads the location of the specified axis and updates the structure's real location for that axis.
"""
function singleread(stage::MCLStage, axis::Int)
    if axis == 1
        position = @ccall madlibpath.MCL_SingleReadN(Cint(1)::Cint, stage.id::Cint)::Cdouble
        stage.real_x = position
    elseif axis == 2
        position = @ccall madlibpath.MCL_SingleReadN(Cint(2)::Cint, stage.id::Cint)::Cdouble
        stage.real_y = position
    elseif axis == 3
        position = @ccall madlibpath.MCL_SingleReadN(Cint(3)::Cint, stage.id::Cint)::Cdouble
        stage.real_z = position
    else
        @error "Invalid axis"
        return false
    end

    return position
end

"""
singlereadZ(stage::MCLStage)

Reads the location of the Z axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
# Description
This function reads the location of the Z axis and updates the structure's real location for that axis.
"""
function singlereadZ(stage::MCLStage)
    position = @ccall madlibpath.MCL_SingleReadZ(stage.id::Cint)::Cdouble
    stage.real_z = position
    return position
end

"""
singlewrite(stage::MCLStage, axis::Int, position::Float64)

Moves the stage to a given location on a specific axis

# Arguments
- `stage::MCLStage`: The stage to move.
- `axis::Int`: The axis to move.
- `position::Float64`: The position to move to.

# Description
This function moves the stage to the given position on the specified axis. The function updates the target position for the axis and returns the error code from the move operation.

"""
function singlewrite(stage::MCLStage, axis::Int, position::Float64)
    if axis == 1
        errcode = @ccall madlibpath.MCL_SingleWriteN(position::Cdouble, Cint(1)::Cint, stage.id::Cint)::Cint
        stage.targ_x = position
        return HardwareReturn[errcode]
    elseif axis == 2
        errcode = @ccall madlibpath.MCL_SingleWriteN(position::Cdouble, Cint(2)::Cint, stage.id::Cint)::Cint
        stage.targ_y = position
        return HardwareReturn[errcode]
    elseif axis == 3
        errcode = @ccall madlibpath.MCL_SingleWriteN(position::Cdouble, Cint(3)::Cint, stage.id::Cint)::Cint
        stage.targ_z = position
        return HardwareReturn[errcode]
    else
        @error "Invalid axis"
        return false
    end
end

"""
singlewriteZ(stage::MCLStage)

Sets the position of the Z axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
- `position::Float64`: The position to move to.
# Description
This function sets the location of the Z axis and updates the structure's target location for that axis.
"""
function singlewriteZ(stage::MCLStage, position::Float64)
    errcode = @ccall madlibpath.MCL_SingleWriteZ(position::Cdouble, stage.id::Cint)::Cint
    stage.targ_z = position
    return HardwareReturn[errcode]
end

"""
monitor(stage::MCLStage, axis::Int, position::Float64)

# Arguments
- `stage::MCLStage`: The stage to move.
- `axis::Int`: The axis to move.
- `position::Float64`: The position to move to.

# Returns
- The location of the stage after movement.

# Description
This function moves the stage to a given position then reads the location after movement
"""
function monitor(stage::MCLStage, axis::Int, position::Float64)
    if axis == 1
        location = @ccall madlibpath.MCL_MonitorN(position::Cdouble, Cint(1)::Cint, stage.id::Cint)::Cint
        stage.targ_x = position
        stage.real_x = location
        return location
    elseif axis == 2
        loaction = @ccall madlibpath.MCL_SingleWriteN(position::Cdouble, Cint(2)::Cint, stage.id::Cint)::Cint
        stage.targ_y = position
        stage.real_y = location
        return loaction
    elseif axis == 3
        loaction = @ccall madlibpath.MCL_SingleWriteN(position::Cdouble, Cint(3)::Cint, stage.id::Cint)::Cint
        stage.targ_z = position
        stage.real_z = location
        return loaction
    else
        @error "Invalid axis"
        return false
    end
end

"""
monitorZ(stage::MCLStage)

Sets the position of the Z axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
- `position::Float64`: The position to move to.
# Description
Commands the Nano-Drive to move the Z axis to a position and then reads the current position of the axis.
"""
function monitorZ(stage::MCLStage, position::Float64)
    location = @ccall madlibpath.MCL_MonitorZ(position::Cdouble, stage.id::Cint)::Cint
    stage.targ_z = position
    stage.real_z = location
    return location
end

