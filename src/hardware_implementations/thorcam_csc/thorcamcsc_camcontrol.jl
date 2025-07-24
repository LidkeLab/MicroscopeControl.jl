#Functions to control camera operations
function armcamera(camera::ThorCamCSCCamera, num_frames::Cint = Cint(2))
    number_of_frames_to_buffer = Cint(num_frames)
    is_camera_armed = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_arm(camera.camera_handle::Ptr{Cvoid}, number_of_frames_to_buffer::Cint)::Cint
    if is_camera_armed != 0
        @error "Camera not armed"
    end
    return is_camera_armed
end

function armcamera(camera::ThorCamCSCCamera)
    is_camera_armed = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_arm(camera.camera_handle::Ptr{Cvoid}, camera.number_of_frames_to_buffer::Cint)::Cint
    if is_camera_armed != 0
        @error "Camera not armed"
    end
    return is_camera_armed
end

function disarmcamera(camera::ThorCamCSCCamera)
    is_camera_disarmed = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_disarm(camera.camera_handle::Ptr{Cvoid})::Cint
    if is_camera_disarmed != 0
        @error "Camera not disarmed"
    end
    return is_camera_disarmed
end

function getroisize(camera::ThorCamCSCCamera)
    image_height = [Cint(2)]
    err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_image_height(camera.camera_handle::Ptr{Cvoid}, image_height::Ptr{Cint})::Cint

    image_width = [Cint(2)]
    err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_image_width(camera.camera_handle::Ptr{Cvoid}, image_width::Ptr{Cint})::Cint

    return (image_width[1], image_height[1])
end

function getsensorsize(camera::ThorCamCSCCamera)
    sensor_height = [Cint(2)]
    err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_sensor_height(camera.camera_handle::Ptr{Cvoid}, sensor_height::Ptr{Cint})::Cint

    sensor_width = [Cint(2)]
    err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_sensor_width(camera.camera_handle::Ptr{Cvoid}, sensor_width::Ptr{Cint})::Cint

    return (sensor_width[1], sensor_height[1])
end

function getlastframeornothing(camera::ThorCamCSCCamera)    #Calls tl_camera_get_pending_frame_or_null, returns Nothing, Nothing if no image collected
    image_buffer_ref = Ref{Ptr{UInt16}}()
    frame_count = Ref{Cint}(Cint(0))
    metadata_ref = Ref{Ptr{Cchar}}()
    metadate_size_bytes = Ref{Cint}(Cint(0))
    image = Vector{UInt16}(undef, camera.roi.width * camera.roi.height)

    is_frame_collected = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_pending_frame_or_null(
        camera.camera_handle::Ptr{Cvoid}, 
        image_buffer_ref::Ref{Ptr{UInt16}}, 
        frame_count::Ref{Cint}, 
        metadata_ref::Ref{Ptr{Cchar}}, 
        metadate_size_bytes::Ref{Cint}
    )::Cint

    if is_frame_collected != 0
        @error "Frame not collected"
        return Nothing
    end
    
    image_buffer = image_buffer_ref[]
    #prevents crashing if no frame is collected
    if image_buffer != C_NULL
        unsafe_copyto!(pointer(image), image_buffer, length(image))
    else
        return Nothing
    end
    return image
end

function issuesoftwaretrigger(camera::ThorCamCSCCamera)
    is_software_trigger_issued = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_issue_software_trigger(camera.camera_handle::Ptr{Cvoid})::Cint
    if is_software_trigger_issued != 0
        @error "Software trigger not issued"
    end
    return is_software_trigger_issued
end

function getframerate(camera::ThorCamCSCCamera)
    frame_rate_ref = Ref{Cdouble}(camera.frame_rate)
    is_framerate_get = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_frame_rate_control_value(
        camera.camera_handle::Ptr{Cvoid}, 
        frame_rate_ref::Ref{Cdouble}
    )::Cint

    if is_framerate_get != 0
        @error "Frame rate not set"
    end

    camera.frame_rate = frame_rate_ref[]
    return camera.frame_rate, is_framerate_get
end

function getexposuretime(camera::ThorCamCSCCamera)
    exposure_time_ref = Ref{Clonglong}(camera.exposure_time)
    is_exposure_time_get = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_exposure_time(
        camera.camera_handle::Ptr{Cvoid}, 
        exposure_time_ref::Ref{Clonglong}
    )::Cint
    if is_exposure_time_get != 0
        @error "Exposure time not set"
    end
    camera.exposure_time = exposure_time_ref[]
    return camera.exposure_time, is_exposure_time_get
end

function getgain(camera::ThorCamCSCCamera)
    gain_ref = Ref{Cint}(camera.gain)
    is_gain_get = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_gain(
        camera.camera_handle::Ptr{Cvoid}, 
        gain_ref::Ref{Cint}
    )::Cint
    if is_gain_get != 0
        @error "Gain not set"
    end
    camera.gain = gain_ref[]
    return camera.gain, is_gain_get
end