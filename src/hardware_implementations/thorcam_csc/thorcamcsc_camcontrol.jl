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

function getlastframeornothing(camera::ThorCamCSCCamera)    #Calls tl_camera_get_pending_frame_or_null, returns Nothing, Nothing if no image collected
    image_buffer_ref = Ref{Ptr{UInt16}}()
    frame_count = Ref{Cint}(Cint(0))
    metadata_ref = Ref{Ptr{Cchar}}()
    metadate_size_bytes = Ref{Cint}(Cint(0))
    image = Vector{UInt16}(undef, 1440 * 1080)

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


