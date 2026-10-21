
"""
    getlastframe(camera::Camera)

Get the last image frame from the camera

# Arguments
- `camera::Camera`: The camera object

# Returns
- `image`: The image frame, `(height, width)` indexed `[y, x]`, `[1, 1]` at the top left

Image layout: lab decision 0040; see `docs/src/conventions.md`. A driver converts its SDK's row-major buffer once,
with `rowmajor_to_yx`, and returns the result as it is.
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
- `image`: The image frame, `(height, width)`, or a sequence's stack, `(height, width, N)`, indexed `[y, x]` with
  `[1, 1]` at the top left

Image layout: lab decision 0040; see `docs/src/conventions.md`. A driver converts its SDK's row-major buffer once,
with `rowmajor_to_yx`, and returns the result as it is.
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
- nothing, or the frame where the driver returns it: `(height, width)` indexed `[y, x]` (lab decision 0040; see
  `docs/src/conventions.md`)
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
- nothing; read frames with `getlastframe` or `getdata`, `(height, width)` indexed `[y, x]` (lab decision 0040; see
  `docs/src/conventions.md`)
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
- nothing; read the stack with `getdata`, `(height, width, N)` indexed `[y, x, frame]` (lab decision 0040; see
  `docs/src/conventions.md`)
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

"""
    export_state(camera::Camera)

Return the camera's `(attributes, data, children)` tuple for `save_h5`. A driver that puts frames in `data` (the
bundled drivers put none) follows the image layout: `(height, width[, N])` indexed `[y, x]`, unpermuted, which
`save_h5` writes as it is and tags with `dimension_order` (lab decision 0040; see `docs/src/conventions.md`).
"""
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