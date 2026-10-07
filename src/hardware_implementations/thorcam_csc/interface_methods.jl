function CameraInterface.initialize(camera::ThorCamCSCCamera)
    #Set Camera Properties
    sensor_size = getsensorsize(camera)
    camera.roi = CameraROI(0, 0, sensor_size[1], sensor_size[2])
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))
    return camera
end

function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    last_frame = ThorCamCSC.getlastframeornothing(camera)    #Gets last frame, loop insures that frame is collected
    if last_frame == Nothing
        # (H, W), matching the real frame below — the empty frame used to come back
        # transposed relative to it.
        return zeros(UInt16, camera.roi.height, camera.roi.width)
    else
        # Reshape from the row-major C buffer and permute to column-major Julia (H, W).
        # Sized from the ROI rather than the full sensor, so a cropped frame is read back
        # with the dimensions it was actually captured at.
        last_frame = permutedims(reshape(last_frame, camera.roi.width, camera.roi.height), (2, 1))
        return last_frame
    end
end

function CameraInterface.capture(camera::ThorCamCSCCamera)
    camera.capture_mode = SINGLE_FRAME
    #Set Camera Properties
    setroi(camera)
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setframespertrigger(camera)
    ThorCamCSC.setpolltimeout(camera)

    #Arm Camera
    ThorCamCSC.armcamera(camera)

    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(camera)

    single_image = CameraInterface.getlastframe(camera)
    ThorCamCSC.disarmcamera(camera)  
    #Display Image
    return single_image
end

function CameraInterface.sequence(camera::ThorCamCSCCamera)
    camera.capture_mode = SEQUENCE
    #Set Camera Properties
    setroi(camera)
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
    setroi(camera)
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(sequence_frames))

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
    setroi(camera)
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))
    setframerate(camera)
    setgain(camera)
 
    ThorCamCSC.armcamera(camera)

    ThorCamCSC.issuesoftwaretrigger(camera)

    camera.is_running = 1
end

function CameraInterface.abort(camera::ThorCamCSCCamera)
    #Shutdown Camera
    #shutdown(camera)
    disarmcamera(camera) 
end

function CameraInterface.getdata(camera::ThorCamCSCCamera)
    if camera.capture_mode == SEQUENCE
        # (H, W, N), sized from the ROI so it matches what getlastframe returns.
        sequence_array = zeros(UInt16, camera.roi.height, camera.roi.width, camera.sequence_length)
        for i in 1:camera.sequence_length
            single_image = CameraInterface.getlastframe(camera)
            sequence_array[:,:, i] = single_image
        end
        disarmcamera(camera) 
        return sequence_array

    elseif camera.capture_mode == SINGLE_FRAME
        data = CameraInterface.getlastframe(camera)
        disarmcamera(camera) 

        return data

    elseif camera.capture_mode == LIVE
        data = CameraInterface.getlastframe(camera)
        disarmcamera(camera) 
        return data
    end
end