
function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    last_frame = ThorCamCSC.getlastframeornothing(camera)    #Gets last frame, loop insures that frame is collected
    if last_frame == Nothing
        return zeros(UInt16, 1080, 1440)   # (H, W) convention
    else
        # Reshape from row-major C buffer and permute to column-major Julia (H, W)
        last_frame = permutedims(reshape(last_frame, 1440, 1080), (2, 1))
        return last_frame
    end
end

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

function CameraInterface.getdata(camera::ThorCamCSCCamera)
    if camera.capture_mode == SEQUENCE
        sequence_array = zeros(UInt16, 1080, 1440, camera.sequence_length)  # (H, W, N) convention
        for i in 1:sequence_frames
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
