# The one private image reader used by capture, getdata, and getlastframe.
function read_frame_or_nothing(camera::ThorCamCSCCamera)
    validate_roi(camera)
    last_frame = getlastframeornothing(camera)
    if last_frame === nothing
        camera.last_error == 0 && (camera.last_error = FRAME_POLL_TIMEOUT)
        return nothing
    end
    height, width = frame_size(camera)
    sensor_height, sensor_width = sensor_size(camera)
    full = CameraInterface.rowmajor_to_yx(last_frame, sensor_width, sensor_height)
    y0, x0 = camera.roi.y_start, camera.roi.x_start
    return full[y0:y0+height-1, x0:x0+width-1]
end

"""
    CameraInterface.getlastframe(camera::ThorCamCSCCamera)

The last frame, `(roi.height, roi.width)` indexed `[y, x]` (lab decision 0040; see `docs/src/conventions.md`). The
camera always delivers the full sensor, `camera_format.y_pixels` x `camera_format.x_pixels`, because the driver never
sends `roi` to it: the SDK's row-major buffer is converted once with `CameraInterface.rowmajor_to_yx`, and `roi`
(`x_start`, `y_start`, 1-based) is then applied in software, so a small `roi` gives no readout speedup. Throws an
`ArgumentError`, before anything is copied, if `roi` is not inside the sensor. Returns `nothing` if the poll times
out or the SDK read fails, with `last_error` set
(`-1` is the driver poll-timeout sentinel). Unless set explicitly with the constructor keyword, `setpolltimeout!`,
or a `poll_timeout` field assignment,
the poll timeout follows exposure: two exposures plus one second, rounded up to milliseconds and bounded by the SDK
integer limit. Explicit timeouts survive acquisition and exposure changes; refused writes preserve the timeout cache.
No placeholder image is returned.

`camera_format` must state the sensor the camera delivers: the driver does not ask the SDK for the image size, so a
`camera_format` larger than the sensor makes the copy read past the SDK's buffer, and a smaller one returns a sheared
image.
"""
function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    return read_frame_or_nothing(camera)
end

function require_frame(camera::ThorCamCSCCamera, description)
    frame = read_frame_or_nothing(camera)
    frame === nothing && error("ThorCamCSCCamera $description did not arrive within $(camera.poll_timeout) ms (last_error=$(camera.last_error))")
    return frame
end

"""
    CameraInterface.capture(camera::ThorCamCSCCamera)

Capture one frame and return it, `(roi.height, roi.width)` indexed `[y, x]`, the full sensor cropped to `roi` in
software (see `getlastframe`, including its requirement that `camera_format` state the sensor the camera delivers;
lab decision 0040, `docs/src/conventions.md`). Throws if the frame does not arrive; no placeholder is returned.
"""
function CameraInterface.capture(camera::ThorCamCSCCamera)
    camera.capture_mode = SINGLE_FRAME
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setframespertrigger(camera)

    #Arm Camera
    ThorCamCSC.armcamera(camera)

    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(camera)

    single_image = require_frame(camera, "capture frame")

    #Display Image
    return single_image
end

function CameraInterface.sequence(camera::ThorCamCSCCamera)
    camera.capture_mode = SEQUENCE
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
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
in software; see `getlastframe`, including its requirement that `camera_format` state the sensor the camera delivers.
Throws on a failed read or poll timeout, naming the missing sequence frame; no incomplete stack is returned.
"""
function CameraInterface.getdata(camera::ThorCamCSCCamera)
    if camera.capture_mode == SEQUENCE
        height, width = frame_size(camera)
        sequence_array = zeros(UInt16, height, width, camera.sequence_length)  # (H, W, N) convention
        for i in 1:camera.sequence_length
            single_image = require_frame(camera, "sequence frame $i of $(camera.sequence_length)")
            sequence_array[:,:, i] = single_image
        end
        return sequence_array

    elseif camera.capture_mode == SINGLE_FRAME
        data = require_frame(camera, "frame")
        return data

    elseif camera.capture_mode == LIVE
        data = require_frame(camera, "frame")
        return data
    end
end

"""
    export_state(camera::ThorCamCSCCamera)

Settings only, with exposure in microseconds and 1-based software ROI offsets. No SDK calls or image reads.
"""
function export_state(camera::ThorCamCSCCamera)
    attributes = Dict{String,Any}(
        "unique_id" => String(first(split(String(copy(camera.unique_id)), '\0'))),
        "camera_format_x_pixels" => camera.camera_format.x_pixels,
        "camera_format_y_pixels" => camera.camera_format.y_pixels,
        "exposure_time" => camera.exposure_time,
        "exposure_time_unit" => "us",
        "poll_timeout_ms" => camera.poll_timeout,
        "roi_x" => camera.roi.x_start, "roi_y" => camera.roi.y_start,
        "roi_width" => camera.roi.width, "roi_height" => camera.roi.height,
        "roi_origin" => 1,
        "capture_mode" => Int(camera.capture_mode), "trigger_mode" => Int(camera.trigger_mode),
        "sequence_length" => camera.sequence_length, "last_error" => camera.last_error,
        "is_running" => camera.is_running, "camera_state" => camera.camera_state)
    return attributes, nothing, Dict{String,Any}()
end
