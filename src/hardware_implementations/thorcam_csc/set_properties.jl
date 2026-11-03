# The TSI exposure value is in microseconds; image poll timeout is in milliseconds.
# Round up so the timeout is at least two exposures plus one second, bounded by the SDK's Cint.
function exposure_poll_timeout(exposure_us::Integer)
    exposure_us >= 0 || throw(ArgumentError("Exposure must be nonnegative"))
    return Cint(clamp(cld(Int128(exposure_us), 500) + 1000, 1, typemax(Cint)))
end

_sdk_set_exposure(handle::Ptr{Cvoid}, value::Clonglong) =
    @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_exposure_time(handle::Ptr{Cvoid}, value::Clonglong)::Cint
_sdk_set_poll_timeout(handle::Ptr{Cvoid}, value::Cint) =
    @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_set_image_poll_timeout(handle::Ptr{Cvoid}, value::Cint)::Cint

function check_csc(camera::ThorCamCSCCamera, code::Cint, operation)
    camera.last_error = code
    code == 0 || error("ThorCamCSCCamera $operation failed (SDK code $code)")
    return code
end

function setexposuretime!(camera::ThorCamCSCCamera, exp_time::Clonglong)
    exposure_poll_timeout(exp_time) # Validate before writing, including with an explicit timeout.
    code = check_csc(camera, _sdk_set_exposure(camera.camera_handle, exp_time), "set exposure")
    camera.exposure_time = exp_time
    # The exposure has already changed even if the subsequent timeout write fails.
    setpolltimeout(camera)
    return code
end

setexposuretime(camera::ThorCamCSCCamera) = setexposuretime!(camera, camera.exposure_time)

function _apply_poll_timeout!(camera::ThorCamCSCCamera, timeout::Cint, explicit::Bool)
    code = check_csc(camera, _sdk_set_poll_timeout(camera.camera_handle, timeout), "set poll timeout")
    setfield!(camera, :poll_timeout, timeout) # An automatic update is not a caller field assignment.
    camera.poll_timeout_explicit = explicit
    return code
end

"""
    setpolltimeout!(camera::ThorCamCSCCamera, timeout::Cint)

Set an explicit poll timeout in milliseconds. After the SDK accepts it, keep it across exposure changes and
acquisitions. A refused write throws and preserves the last accepted timeout and its explicit/automatic setting.
"""
setpolltimeout!(camera::ThorCamCSCCamera, timeout::Cint) = _apply_poll_timeout!(camera, timeout, true)

function setpolltimeout(camera::ThorCamCSCCamera)
    timeout = camera.poll_timeout_explicit ? camera.poll_timeout : exposure_poll_timeout(camera.exposure_time)
    return _apply_poll_timeout!(camera, timeout, camera.poll_timeout_explicit)
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
