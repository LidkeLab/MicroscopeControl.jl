#Functions to control camera operations
function armcamera(camera::ThorCamCSCCamera, num_frames::Cint)
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

# Raw SDK seam: tests replace this call, leaving timeout handling and the sensor copy exercised.
function _sdk_pending_frame(handle, image, count, metadata, metadata_size)
    return @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_pending_frame_or_null(
        handle::Ptr{Cvoid}, image::Ref{Ptr{UInt16}}, count::Ref{Cint},
        metadata::Ref{Ptr{Cchar}}, metadata_size::Ref{Cint})::Cint
end

# A driver-local sentinel, not a vendor status: SDK success with a null buffer means poll timeout.
const FRAME_POLL_TIMEOUT = Cint(-1)

function getlastframeornothing(camera::ThorCamCSCCamera)
    validate_roi(camera)
    image = Ref{Ptr{UInt16}}(C_NULL)
    count = Ref{Cint}(0)
    metadata = Ref{Ptr{Cchar}}(C_NULL)
    metadata_size = Ref{Cint}(0)
    code = _sdk_pending_frame(camera.camera_handle, image, count, metadata, metadata_size)
    camera.last_error = code
    if code != 0
        @error "Frame not collected" code
        return nothing
    elseif image[] == C_NULL
        camera.last_error = FRAME_POLL_TIMEOUT
        return nothing
    end
    return copy_sensor_frame(camera, image[])
end

# Copies the frame the SDK holds at `image_buffer` into a Julia vector. The camera delivers the full sensor, so the
# length is the sensor's pixel count from `camera_format`; the SDK is not asked, so `camera_format` must state the
# sensor the camera delivers, or this reads past the SDK's buffer.
function copy_sensor_frame(camera::ThorCamCSCCamera, image_buffer::Ptr{UInt16})
    image = Vector{UInt16}(undef, prod(sensor_size(camera)))
    unsafe_copyto!(pointer(image), image_buffer, length(image))
    return image
end

function issuesoftwaretrigger(camera::ThorCamCSCCamera)
    is_software_trigger_issued = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_issue_software_trigger(camera.camera_handle::Ptr{Cvoid})::Cint
    if is_software_trigger_issued != 0
        @error "Software trigger not issued"
    end
    return is_software_trigger_issued
end


