# This file are the functions that every objective positioner will inheret from the `Zpositioner` interface.

"""
    move(positioner::Zpositioner, z::Float64)
Moves the objective positioner to a specified position.

# Arguments
- `positioner::Zpositioner`: The objective positioner to be moved.
- `z::Float64`: The target z-coordinate for the positioner.
"""

function move(positioner::Zpositioner, z::Float64)
    @error "Move() not implimented"
end

"""
    get_position(positioner::Zpositioner)
Gets the current possition of the objective positioner.

# Arguments
- `positioner::Zpositioner`: The objective positioner whose position is to be retrieved.
"""

function get_position(positioner::Zpositioner)
    @error "get_position() not implimented"
end

"""
    reset(positioner::Zpositioner)
Resets the objective positioner back to a safe "home" state.

# Arguments
- `positioner::Zpositioner`: The objective positioner who will be reset.
"""

function reset(positioner::Zpositioner)
    @error "reset() not implimented"
end

"""
    stop_motion(positioner::Zpositioner)
Stops the motion of the objective positioner.

# Arguments
- `positioner::Zpositioner`: The objective positioner whose motion will halt.
"""

function stop_motion(positioner::Zpositioner)
    @error "stop_motion() not implimented"
end