
"""
    getlastframe(camera::Camera)

Get the last image frame from the camera

# Arguments
- `camera::Camera`: The camera object

# Returns
- `image`: The image frame
"""
function getlastframe(camera::Camera)
    # Get the last image frame from the camera
    # Return an image
    error("getlastframe not implemented for $(typeof(camera))")
end

"""
    getdata(camera::Camera) 

Get the last image frame from the camera

# Arguments
- `camera::Camera`: The camera object

# Returns
- `image`: The image frame
"""
function getdata(camera::Camera)
    # Get the last image frame from the camera
    # Return an array
    error("getdata not implemented for $(typeof(camera))")
end

"""
    capture(cameara::Camera)

Start a capture

# Arguments
- `camera::Camera`: The camera object

# Returns
- nothing
"""
function capture(cameara::Camera)
    # Start a capture
    error("capture not implemented for $(typeof(cameara))")
end


"""
    live(camera::Camera)

Start a live view

# Arguments
- `camera::Camera`: The camera object

# Returns
- nothing
"""
function live(camera::Camera)
    # Start a live view
    error("live not implemented for $(typeof(camera))")
end

"""

    sequence(camera::Camera)

Start collection of a sequence

# Arguments
- `camera::Camera`: The camera object


# Returns
- nothing
"""
function sequence(camera::Camera)
    # Start collection of a sequence
    error("sequence not implemented for $(typeof(camera))")
end


"""
    abort(camera::Camera)

Abort the current operation

# Arguments
- `camera::Camera`: The camera object

# Returns
- nothing
"""
function abort(camera::Camera)
    # Abort the current operation
    error("abort not implemented for $(typeof(camera))")
end

function export_state(camera::Camera)
    # Export the state of the camera
    error("export_state not implemented for $(typeof(camera))")
end

"""
    setexposuretime!(camera::Camera)

Push the camera's `exposure_time` field down to the hardware.

# Arguments
- `camera::Camera`: The camera object
"""
function setexposuretime!(camera::Camera)
    error("setexposuretime! not implemented for $(typeof(camera))")
end

"""
    setroi!(camera::Camera)

Push the camera's `roi::CameraROI` field down to the hardware.

# Arguments
- `camera::Camera`: The camera object
"""
function setroi!(camera::Camera)
    error("setroi! not implemented for $(typeof(camera))")
end

"""
    settriggermode!(camera::Camera)

Push the camera's trigger mode down to the hardware.

# Arguments
- `camera::Camera`: The camera object
"""
function settriggermode!(camera::Camera)
    error("settriggermode! not implemented for $(typeof(camera))")
end