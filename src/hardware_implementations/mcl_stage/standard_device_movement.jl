#=
For reference, when choosing axis
1 = X
2 = Y
3 = Z
=#

# Raw vendor seams for the checked single-axis reads and writes below.
_mcl_read(axis::Int, id::Int) = @ccall libmadlib.MCL_SingleReadN(axis::Cint, id::Cint)::Cdouble
_mcl_read_z(id::Int) = @ccall libmadlib.MCL_SingleReadZ(id::Cint)::Cdouble
_mcl_write(position::Float64, axis::Int, id::Int) =
    @ccall libmadlib.MCL_SingleWriteN(position::Cdouble, axis::Cint, id::Cint)::Cint
_mcl_write_z(position::Float64, id::Int) =
    @ccall libmadlib.MCL_SingleWriteZ(position::Cdouble, id::Cint)::Cint

function checked_mcl_value(value, operation)
    if !isfinite(value) || value < 0
        code = isfinite(value) && isinteger(value) ? get(HardwareReturn, Int(value), "unknown error") : "invalid value"
        error("MCLStage $operation failed: $code ($value)")
    end
    return value
end

function check_mcl_write(code, operation)
    code == 0 || error("MCLStage $operation failed: $(get(HardwareReturn, Int(code), "unknown error")) ($code)")
    return HardwareReturn[code]
end

"""
singleread(stage::MCLStage)

Reads the location of specific axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
- `axis::Int`: The axis to read from.
# Description
Updates the axis position only after a nonnegative, finite SDK result; a negative error code throws.
"""
function singleread(stage::MCLStage, axis::Int)
    if !(axis in 1:3)
        @error "Invalid axis"
        return false
    end
    position = checked_mcl_value(_mcl_read(axis, stage.id), "read axis $axis")
    setfield!(stage, (:real_x, :real_y, :real_z)[axis], position)
    return position
end

"""
singlereadZ(stage::MCLStage)

Reads the location of the Z axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
# Description
Updates the Z position only after a nonnegative, finite SDK result; a negative error code throws.
"""
function singlereadZ(stage::MCLStage)
    position = checked_mcl_value(_mcl_read_z(stage.id), "read Z")
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
This function moves the stage to the given position on the specified axis. It records the accepted target only on `MCL_SUCCESS` and returns that status string. A refused write throws before changing the target.

"""
function singlewrite(stage::MCLStage, axis::Int, position::Float64)
    if !(axis in 1:3)
        @error "Invalid axis"
        return false
    end
    result = check_mcl_write(_mcl_write(position, axis, stage.id), "write axis $axis")
    setfield!(stage, (:targ_x, :targ_y, :targ_z)[axis], position)
    return result
end

"""
singlewriteZ(stage::MCLStage)

Sets the position of the Z axis
# Arguments
- `stage::MCLStage`: The stage whose handle is to be released.
- `position::Float64`: The position to move to.
# Description
Records the Z target only on `MCL_SUCCESS`; a refused write throws and preserves the previous target.
"""
function singlewriteZ(stage::MCLStage, position::Float64)
    result = check_mcl_write(_mcl_write_z(position, stage.id), "write Z")
    stage.targ_z = position
    return result
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
        location = @ccall libmadlib.MCL_MonitorN(position::Cdouble, Cint(1)::Cint, stage.id::Cint)::Cint
        stage.targ_x = position
        stage.real_x = location
        return location
    elseif axis == 2
        loaction = @ccall libmadlib.MCL_SingleWriteN(position::Cdouble, Cint(2)::Cint, stage.id::Cint)::Cint
        stage.targ_y = position
        stage.real_y = location
        return loaction
    elseif axis == 3
        loaction = @ccall libmadlib.MCL_SingleWriteN(position::Cdouble, Cint(3)::Cint, stage.id::Cint)::Cint
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
    location = @ccall libmadlib.MCL_MonitorZ(position::Cdouble, stage.id::Cint)::Cint
    stage.targ_z = position
    stage.real_z = location
    return location
end

