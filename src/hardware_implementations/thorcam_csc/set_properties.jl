function setexposuretime!(camera::ThorCamCSCCamera, exp_time::Clonglong) #Sets exposure to specified time
    camera.exposure_time = exp_time
    is_exposure_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_exposure_time(camera.camera_handle::Ptr{Cvoid}, exp_time::Clonglong)::Cint
    if is_exposure_set != 0
        @error "Exposure time not set"
    end
    return is_exposure_set
end

function setexposuretime(camera::ThorCamCSCCamera)  #uses exposure time in camera object to set exposure time
    is_exposure_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_exposure_time(camera.camera_handle::Ptr{Cvoid}, camera.exposure_time::Clonglong)::Cint
    if is_exposure_set != 0
        @error "Exposure time not set"
    end
    return is_exposure_set
end

function setpolltimeout!(camera::ThorCamCSCCamera, timeout::Cint)
    camera.poll_timeout = timeout
    is_timeout_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_image_poll_timeout(camera.camera_handle::Ptr{Cvoid}, timeout::Cint)::Cint
    if is_timeout_set != 0
        @error "Poll timeout not set"
    end
    return is_timeout_set
end

function setpolltimeout(camera::ThorCamCSCCamera)
    is_timeout_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_image_poll_timeout(camera.camera_handle::Ptr{Cvoid}, camera.poll_timeout::Cint)::Cint
    if is_timeout_set != 0
        @error "Poll timeout not set"
    end
    return is_timeout_set
end

function setoperationmode!(camera::ThorCamCSCCamera, op_mode::Cint)  #Sets operation mode to specified mode
    camera.operation_mode = op_mode
    is_operation_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_operation_mode(camera.camera_handle::Ptr{Cvoid}, op_mode::Cint)::Cint
    if is_operation_set != 0
        @error "Operation mode not set"
    end
    return is_operation_set
end

function setoperationmode(camera::ThorCamCSCCamera) #uses operation mode in camera object to set operation mode
    is_operation_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_operation_mode(camera.camera_handle::Ptr{Cvoid}, camera.operation_mode::Cint)::Cint
    if is_operation_set != 0
        @error "Operation mode not set"
    end
    return is_operation_set
end

function setframespertrigger!(camera::ThorCamCSCCamera, fpt::Cint) #sets frames per trigger to specified number
    camera.frames_per_trigger_zero_for_unlimited = fpt
    is_frames_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_frames_per_trigger_zero_for_unlimited(camera.camera_handle::Ptr{Cvoid}, fpt::Cint)::Cint
    if is_frames_set != 0
        @error "Frames per trigger not set"
    end
    return is_frames_set
end

function setframespertrigger(camera::ThorCamCSCCamera)  #uses frames per trigger in object to set frames per trigger
    is_frames_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_frames_per_trigger_zero_for_unlimited(camera.camera_handle::Ptr{Cvoid}, camera.frames_per_trigger_zero_for_unlimited::Cint)::Cint
    if is_frames_set != 0
        @error "Frames per trigger not set"
    end
    return is_frames_set
end

function setgain(camera::ThorCamCSCCamera, gain::Cint)
    is_gain_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_gain(camera.camera_handle::Ptr{Cvoid}, gain::Cint)::Cint
    if is_gain_set != 0
        @error "Gain not set"
    end
    return is_gain_set
end

#=
function setroi!(camera::ThorCamCSCCamera, upper_left_x::Cint, upper_left_y::Cint, lower_right_x::Cint, lower_right_y::Cint)
    is_roi_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_roi(
        camera.camera_handle::Ptr{Cvoid}, 
        upper_left_x::Cint,
        upper_left_y::Cint,
        lower_right_x::Cint,
        lower_right_y::Cint
    )::Cint

    # camera.roi.x_start = upper_left_x
    # camera.roi.y_start = upper_left_y
    # camera.roi.width = lower_right_x - upper_left_x
    # camera.roi.height = lower_right_y - upper_left_y

    if is_roi_set != 0
        @error "ROI not set"
    end
    return is_roi_set
end

function setroi(camera::ThorCamCSCCamera)
    is_roi_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_roi(
        camera.camera_handle::Ptr{Cvoid}, 
        camera.roi.x_start::Cint,
        camera.roi.y_start::Cint,
        (camera.roi.width + camera.roi.x_start)::Cint,
        (camera.roi.height + camera.roi.y_start)::Cint
    )::Cint
    if is_roi_set != 0
        @error "ROI not set"
    end
    return is_roi_set
end

All ROI functions do not work yet
=#


function setroi(camera::ThorCamCSCCamera)
    x_start = Cint(camera.roi.x_start)
    y_start = Cint(camera.roi.y_start)
    x_end = Cint(camera.roi.x_start + camera.roi.width - 1)
    y_end = Cint(camera.roi.y_start + camera.roi.height - 1)
    is_roi_set = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_roi(
        camera.camera_handle::Ptr{Cvoid}, 
        x_start::Cint,
        y_start::Cint,
        x_end::Cint,
        y_end::Cint
    )::Cint
    if is_roi_set != 0
        @error "ROI not set"
    end
    return is_roi_set
end