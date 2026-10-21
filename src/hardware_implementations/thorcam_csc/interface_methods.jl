
# The frame's (H, W): the camera's ROI. The driver does not forward `roi` to the SDK, so it must match the size the
# camera delivers, which is the full sensor, 1440 x 1080, unless it was changed in the SDK.
frame_size(camera::ThorCamCSCCamera) = (camera.roi.height, camera.roi.width)

"""
    CameraInterface.getlastframe(camera::ThorCamCSCCamera)

The last frame, `(roi.height, roi.width)` indexed `[y, x]`: the SDK's row-major buffer is converted once with
`CameraInterface.rowmajor_to_yx` (lab decision 0040; see `docs/src/conventions.md`). A zero frame of that shape if no
frame has been collected.
"""
function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    last_frame = ThorCamCSC.getlastframeornothing(camera)    #Gets last frame, loop insures that frame is collected
    height, width = frame_size(camera)
    if last_frame == Nothing
        return zeros(UInt16, height, width)   # (H, W) convention
    else
        # The SDK delivers a row-major buffer; convert it once to (H, W)
        return CameraInterface.rowmajor_to_yx(last_frame, width, height)
    end
end

"""
    CameraInterface.capture(camera::ThorCamCSCCamera)

Capture one frame and return it, `(roi.height, roi.width)` indexed `[y, x]` (see `getlastframe`; lab decision 0040,
`docs/src/conventions.md`).
"""
function CameraInterface.capture(camera::ThorCamCSCCamera)
    camera.capture_mode = SINGLE_FRAME
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setframespertrigger(camera)
    ThorCamCSC.setpolltimeout(camera)

    #Arm Camera
    ThorCamCSC.armcamera(camera)

    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(camera)

    single_image = CameraInterface.getlastframe(camera)

    #Display Image
    return single_image
end

function CameraInterface.sequence(camera::ThorCamCSCCamera)
    camera.capture_mode = SEQUENCE
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))

    #Arm Camera
    ThorCamCSC.armcamera(camera)


    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(camera)
    camera.is_running = 1

    return 
end

function CameraInterface.sequence(camera::ThorCamCSCCamera, sequence_frames::Int)
    camera.capture_mode = SEQUENCE
    camera.sequence_length = sequence_frames
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))

    #Arm Camera
    ThorCamCSC.armcamera(camera)


    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(camera)

 

    camera.is_running = 1

    return
end


function CameraInterface.live(camera::ThorCamCSCCamera)
    camera.capture_mode = LIVE

     #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))
 
    ThorCamCSC.armcamera(camera)

    ThorCamCSC.issuesoftwaretrigger(camera)

    camera.is_running = 1
end

function CameraInterface.abort(camera::ThorCamCSCCamera)
    #Shutdown Camera
    shutdown(camera)
end

"""
    CameraInterface.getdata(camera::ThorCamCSCCamera)

`(roi.height, roi.width, sequence_length)` in `SEQUENCE` mode and `(roi.height, roi.width)` otherwise, indexed
`[y, x[, frame]]` (lab decision 0040; see `docs/src/conventions.md`).
"""
function CameraInterface.getdata(camera::ThorCamCSCCamera)
    if camera.capture_mode == SEQUENCE
        height, width = frame_size(camera)
        sequence_array = zeros(UInt16, height, width, camera.sequence_length)  # (H, W, N) convention
        for i in 1:camera.sequence_length
            single_image = CameraInterface.getlastframe(camera)
            sequence_array[:,:, i] = single_image
        end
        return sequence_array

    elseif camera.capture_mode == SINGLE_FRAME
        data = CameraInterface.getlastframe(camera)
        return data

    elseif camera.capture_mode == LIVE
        data = CameraInterface.getlastframe(camera)
        return data
    end
end