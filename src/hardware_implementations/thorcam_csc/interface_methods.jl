function CameraInterface.initialize(camera::ThorCamCSCCamera)
    #Set Camera Properties
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))
    return camera
end

function CameraInterface.getlastframe(camera::ThorCamCSCCamera)
    last_frame = ThorCamCSC.getlastframeornothing(camera)    #Gets last frame, loop insures that frame is collected
    if last_frame == Nothing 
        return zeros(UInt16, 1440, 1080)   #returns all zeros if frame not collected
        #return zeros(UInt16, 1080, 1440)
    else 
        last_frame = reshape(last_frame, 1440, 1080)
        return last_frame'
        #return rotr90(last_frame)
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
    ThorCamCSC.disarmcamera(camera)  
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
    ThorCamCSC.setexposuretime(camera)
    ThorCamCSC.setoperationmode(camera)
    ThorCamCSC.setpolltimeout(camera)
    # ThorCamCSC.setroi(camera)
    ThorCamCSC.setframespertrigger!(camera, Cint(0))
    #ThorCamCSC.setgain(camera, Cint(480))
 
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
        sequence_array = zeros(UInt16, 1440, 1080, camera.sequence_length)
        #sequence_array = zeros(UInt16, 1080, 1440, camera.sequence_length)
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