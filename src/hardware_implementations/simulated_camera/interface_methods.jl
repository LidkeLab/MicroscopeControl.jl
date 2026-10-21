
"""
    initialize(camera::SimCamera)

No-op: the simulated camera needs no hardware connection.
"""
function initialize(camera::SimCamera)
    return nothing
end

"""
    shutdown(camera::SimCamera)

No-op: the simulated camera needs no hardware connection to close.
"""
function shutdown(camera::SimCamera)
    return nothing
end

"""
    CameraInterface.getlastframe(camera::SimCamera)

A random `UInt16` frame of shape `(roi.height, roi.width)`, indexed `[y, x]` (lab decision 0040; see
`docs/src/conventions.md`). The values carry no orientation; the shape does.
"""
function CameraInterface.getlastframe(camera::SimCamera)
    # Get the last image frame from the camera
    # Return an image
    sleep(camera.exposure_time)
    return rand(UInt16, camera.roi.height, camera.roi.width)
end

function CameraInterface.capture(camera::SimCamera)
    camera.capture_mode = SINGLE_FRAME
    # Start a capture
end

function CameraInterface.live(camera::SimCamera)
    # Start a live view
    camera.capture_mode = LIVE
    camera.is_running = 1
end

function CameraInterface.sequence(camera::SimCamera)
    # Start collection of a sequence
    camera.capture_mode = SEQUENCE
    camera.is_running = 1
    @async begin
        for i in 1:camera.sequence_length
            sleep(camera.exposure_time)
        end
        camera.is_running = 0
    end
end

function CameraInterface.abort(camera::SimCamera)
    # Abort a capture
    camera.is_running = 0
end

"""
    CameraInterface.getdata(camera::SimCamera)

Random `UInt16` data: `(roi.height, roi.width, sequence_length)` in `SEQUENCE` mode and `(roi.height, roi.width)`
otherwise, indexed `[y, x[, frame]]` (lab decision 0040; see `docs/src/conventions.md`).
"""
function CameraInterface.getdata(camera::SimCamera)
    if camera.capture_mode == SEQUENCE
        return rand(UInt16, camera.roi.height, camera.roi.width, camera.sequence_length)  # (H, W, N) convention
    elseif camera.capture_mode == SINGLE_FRAME
        return rand(UInt16, camera.roi.height, camera.roi.width)
    elseif camera.capture_mode == LIVE
        return rand(UInt16, camera.roi.height, camera.roi.width)
    end
end