# """
#     initialize(stage::Stage)

# Initializes the given stage. This function is expected to be implemented for each specific stage type.

# # Arguments
# - `stage::Stage`: The stage to be initialized.

# # Description
# This function is responsible for setting up the stage for operation. This may include tasks such as establishing a connection to the stage, setting initial parameters, or moving the stage to a default position. The specific actions taken during initialization may vary depending on the specific type of stage.

# """

# function initialize(stage::Stage)
#     #function to initialize stage
#     @error "initialize not implemented"
# end

# """
#     shutdown(stage::Stage)

# Shuts down the given stage. This function is expected to be implemented for each specific stage type.

# # Arguments
# - `stage::Stage`: The stage to be shut down.

# # Description
# This function is responsible for safely shutting down the stage. This may include tasks such as stopping any ongoing motion, disconnecting from the stage, or resetting the stage to a safe state. The specific actions taken during shutdown may vary depending on the specific type of stage.

# """
# function shutdown(stage::Stage)
#     #function to shutdown stage
#     @error "shutdown not implemented"
# end

"""
    move(stage::Stage, x::Float64, y::Float64, z::Float64)

Moves the given stage to the specified position. This function is expected to be implemented for each specific stage type. 2D stages should ignore the z-coordinate. 1D stages should ignore the y- and z-coordinates.

# Arguments
- `stage::Stage`: The stage to be moved.
- `x::Float64`: The target x-coordinate for the stage.
- `y::Float64`: The target y-coordinate for the stage.
- `z::Float64`: The target z-coordinate for the stage.

# Description
This function is responsible for moving the stage to a specified position. The specific actions taken during the move operation may vary depending on the specific type of stage.

"""
function move(stage::Stage, x::Float64, y::Float64, z::Float64)
    #function to move stage to a position
    @error "move not implemented"
end

"""
    getposition(stage::Stage)

Gets the current position of the given stage. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage whose position is to be retrieved.

# Returns
- A tuple `(x::Float64, y::Float64, z::Float64)` representing the current position of the stage. 2D stages will return a tuple with (x,y), and 1D stages will return a tuple with (x).

# Description
This function is responsible for retrieving the current position of the stage. The specific method of retrieving the position may vary depending on the specific type of stage.

"""
function getposition(stage::Stage)
    #function to get stage position
    @error "getposition not implemented"
end

"""
    getrange(stage::Stage)

Gets the range of motion of the given stage. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage whose range of motion is to be retrieved.

# Returns
- A tuple `(x_range::Tuple{Float64, Float64}, y_range::Tuple{Float64, Float64}, z_range::Tuple{Float64, Float64})` representing the range of motion of the stage in each dimension. For 2D stages, the z_range should be `(0.0, 0.0)` or unspecified. For 1D stages, both the y_range and z_range should be `(0.0, 0.0)` or unspecified.

# Description
This function is responsible for retrieving the range of motion of the stage. The specific method of retrieving the range may vary depending on the specific type of stage.

"""
function getrange(stage::Stage)
    #function to get stage range
    @error "getrange not implemented"
end

"""
    stopmotion(stage::Stage)

Stops any ongoing motion of the given stage. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage whose motion is to be stopped.

# Description
This function is responsible for stopping any ongoing motion of the stage. The specific method of stopping the motion may vary depending on the specific type of stage.

"""
function stopmotion(stage::Stage)
    #function to stop stage motion
    @error "stopmotion not implemented"
end

"""
    home(stage::Stage)

Moves the given stage to its home position. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage to be moved to its home position.

# Description
This function is responsible for moving the stage to its home position. The home position is typically a predefined position that is used as a reference point for other movements. The specific method of moving to the home position may vary depending on the specific type of stage.

"""
function home(stage::Stage)
    #function to move stage to home position
    @error "home not implemented"
end

"""
    servo(stage::Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)

Sets the servo state of the given stage. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage whose servo state is to be set.
- `xtoggle::Bool`: The desired servo state for the x-axis.
- `ytoggle::Bool`: The desired servo state for the y-axis.
- `ztoggle::Bool`: The desired servo state for the z-axis.

# Description
This function is responsible for setting the servo state of the stage. The specific method of setting the servo state may vary depending on the specific type of stage.

"""
function servo(stage::Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)
    #function to set stage servo state
    @error "servo not implemented"
end

"""
    driftcorrection(stage::Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)

Sets the drift correction state of the given stage. This function is expected to be implemented for each specific stage type.

# Arguments
- `stage::Stage`: The stage whose drift correction state is to be set.
- `xtoggle::Bool`: The desired drift correction state for the x-axis.
- `ytoggle::Bool`: The desired drift correction state for the y-axis.
- `ztoggle::Bool`: The desired drift correction state for the z-axis.

# Description
This function is responsible for setting the drift correction state of the stage. The drift correction state controls whether the stage automatically corrects for any drift in its position over time. The specific method of setting the drift correction state may vary depending on the specific type of stage.

"""
function driftcorrection(stage::Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)
    #function to set stage drift correction state
    @error "driftcorrection not implemented"
end

# function export_state(stage::Stage)
#     #function to export stage state
#     @error "export_state not implemented"
# end
