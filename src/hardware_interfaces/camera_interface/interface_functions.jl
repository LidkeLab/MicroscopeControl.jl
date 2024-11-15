
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
    @error "getlastframe not implemented"
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
    @error "getdata not implemented"
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
    @error "capture not implemented"
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
    @error "live not implemented"
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
    @error "sequence not implemented"
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
    @error "abort not implemented"
end


