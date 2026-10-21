
"""
    CameraInterface.getlastframe(camera::ThorCamCSCCamera)

The last frame, `(roi.height, roi.width)` indexed `[y, x]` (lab decision 0040; see `docs/src/conventions.md`). The
camera always delivers the full sensor, `camera_format.y_pixels` x `camera_format.x_pixels`, because the driver never
sends `roi` to it: the SDK's row-major buffer is converted once with `CameraInterface.rowmajor_to_yx`, and `roi`
(`x_start`, `y_start`, 1-based) is then applied in software, so a small `roi` gives no readout speedup. Throws an
`ArgumentError`, before anything is copied, if `roi` is not inside the sensor. A zero frame of the `roi`'s shape if no
frame has been collected.
"""
function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    validate_roi(camera)
    last_frame = ThorCamCSC.getlastframeornothing(camera)    #Gets last frame, loop insures that frame is collected
    height, width = frame_size(camera)
    if last_frame == Nothing
        return zeros(UInt16, height, width)   # (H, W) convention
    else
        # The SDK delivers a row-major buffer of the full sensor; convert it once to (H, W), then crop
        sensor_height, sensor_width = sensor_size(camera)
        full = CameraInterface.rowmajor_to_yx(last_frame, sensor_width, sensor_height)
        y0, x0 = camera.roi.y_start, camera.roi.x_start
        return full[y0:y0+height-1, x0:x0+width-1]
    end
end

"""
    CameraInterface.capture(camera::ThorCamCSCCamera)

Capture one frame and return it, `(roi.height, roi.width)` indexed `[y, x]`, the full sensor cropped to `roi` in
software (see `getlastframe`; lab decision 0040, `docs/src/conventions.md`).
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
`[y, x[, frame]]` (lab decision 0040; see `docs/src/conventions.md`). Each frame is the full sensor cropped to `roi`
in software; see `getlastframe`.
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