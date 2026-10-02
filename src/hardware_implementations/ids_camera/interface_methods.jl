_ok(status::peak_status) = status == PEAK_STATUS_SUCCESS || status == PEAK_STATUS_VALUE_ADJUSTED

"""Configure IDS GenTL producers for the current Julia process when needed."""
function _configure_gentl!()
    path_key = "GENICAM_GENTL64_PATH"
    !isempty(get(ENV, path_key, "")) && return nothing

    ids_root = raw"C:\Program Files\IDS\ids_peak"
    producer_dirs = [
        joinpath(ids_root, "ids_ueyegentl", "64"),
        joinpath(ids_root, "ids_gevgentl", "64"),
        joinpath(ids_root, "ids_u3vgentl", "64"),
    ]
    available_dirs = filter(isdir, producer_dirs)
    isempty(available_dirs) && error("IDS GenTL producers were not found under $ids_root. Install IDS Peak and set $path_key to its 64-bit CTI directories.")
    ENV[path_key] = join(available_dirs, ';')
    return nothing
end

"""Return the human-readable diagnostic maintained by the IDS SDK."""
function _last_error_message()
    error_code = Ref{peak_status}(PEAK_STATUS_SUCCESS)
    message_size = Ref{Csize_t}(0)
    status = peak_Library_GetLastError(error_code, Ptr{Cchar}(C_NULL), message_size)
    (!_ok(status) || message_size[] == 0) && return ""

    message = fill(Cchar(0), message_size[])
    status = peak_Library_GetLastError(error_code, message, message_size)
    !_ok(status) && return ""
    terminator = findfirst(==(Cchar(0)), message)
    last_index = isnothing(terminator) ? length(message) : terminator - 1
    bytes = UInt8.(message[1:last_index])
    return String(bytes) * " (SDK error code $(UInt32(error_code[])))"
end

function _check(camera::IDSCamera, status::peak_status, operation::AbstractString)
    camera.last_error = status
    _ok(status) && return nothing
    detail = _last_error_message()
    suffix = isempty(detail) ? "" : ": $detail"
    error("IDS Peak $operation failed with status $(UInt32(status))$suffix")
end

function _require_open(camera::IDSCamera)
    camera.camera_handle == C_NULL && error("IDS camera is not initialized; call initialize(camera) first")
end

function _frame_timeout_ms(camera::IDSCamera)
    UInt32(clamp(ceil(Int, 3_000 / max(camera.frame_rate, eps())), 1, typemax(UInt32)))
end

function _copy_frame!(camera::IDSCamera)
    frame_ref = Ref{peak_frame_handle}(Ptr{peak_frame}(C_NULL))
    status = peak_Acquisition_WaitForFrame(camera.camera_handle, _frame_timeout_ms(camera), frame_ref)
    _check(camera, status, "waiting for a frame")
    frame = frame_ref[]

    try
        peak_Frame_IsComplete(frame) == PEAK_FALSE && error("IDS Peak returned an incomplete frame")
        buffer = Ref{peak_buffer}()
        _check(camera, peak_Frame_Buffer_Get(frame, buffer), "getting the frame buffer")
        bytes = camera.roi.width * camera.roi.height
        source = unsafe_wrap(Vector{UInt8}, buffer[].memoryAddress, bytes; own=false)
        # Peak buffers are row-major; package image data uses (height, width).
        return permutedims(reshape(copy(source), camera.roi.width, camera.roi.height), (2, 1))
    finally
        _check(camera, peak_Frame_Release(camera.camera_handle, frame), "releasing a frame")
    end
end

function initialize(camera::IDSCamera)
    camera.library_initialized && return camera
    _configure_gentl!()
    _check(camera, peak_Library_Init(), "initializing the library")
    camera.library_initialized = true

    count = Ref{Csize_t}(0)
    _check(camera, peak_CameraList_Update(C_NULL), "updating the camera list")
    _check(camera, peak_CameraList_Get(C_NULL, count), "getting the camera count")
    count[] == 0 && error("No IDS cameras are connected")

    descriptors = Vector{peak_camera_descriptor}(undef, count[])
    _check(camera, peak_CameraList_Get(descriptors, count), "getting the camera list")
    handle = Ref{peak_camera_handle}(Ptr{peak_camera}(C_NULL))
    for descriptor in descriptors
        peak_Camera_GetAccessStatus(descriptor.cameraID) == PEAK_ACCESS_READWRITE || continue
        status = peak_Camera_Open(descriptor.cameraID, handle)
        _ok(status) && break
    end
    handle[] == C_NULL && error("No connected IDS camera is available for read/write access")
    camera.camera_handle = handle[]

    _check(camera, peak_Camera_ResetToDefaultSettings(camera.camera_handle), "resetting camera settings")
    _check(camera, peak_PixelFormat_Set(camera.camera_handle, PEAK_PIXEL_FORMAT_MONO8), "setting MONO8 pixel format")

    size = Ref{peak_size}()
    _check(camera, peak_ROI_Size_Get(camera.camera_handle, size), "getting image size")
    camera.roi = CameraROI(0, 0, Int(size[].width), Int(size[].height))
    camera.camera_format = CameraFormat(camera.roi.width, camera.roi.height, 0.0, 1.0, "IDS Peak")

    exposure = Ref{Cdouble}(0)
    _check(camera, peak_ExposureTime_Get(camera.camera_handle, exposure), "getting exposure time")
    camera.exposure_time = exposure[] / 1e6
    rate = Ref{Cdouble}(0)
    _check(camera, peak_FrameRate_Get(camera.camera_handle, rate), "getting frame rate")
    camera.frame_rate = rate[]
    return camera
end

function setexposuretime!(camera::IDSCamera, exposure_time::Real=camera.exposure_time)
    _require_open(camera)
    _check(camera, peak_ExposureTime_Set(camera.camera_handle, Cdouble(exposure_time * 1e6)), "setting exposure time")
    value = Ref{Cdouble}(0)
    _check(camera, peak_ExposureTime_Get(camera.camera_handle, value), "getting exposure time")
    camera.exposure_time = value[] / 1e6
    return camera.exposure_time
end

function setframerate!(camera::IDSCamera, frame_rate::Real=camera.frame_rate)
    _require_open(camera)
    _check(camera, peak_FrameRate_Set(camera.camera_handle, Cdouble(frame_rate)), "setting frame rate")
    value = Ref{Cdouble}(0)
    _check(camera, peak_FrameRate_Get(camera.camera_handle, value), "getting frame rate")
    camera.frame_rate = value[]
    return camera.frame_rate
end

function setroi!(camera::IDSCamera, roi::CameraROI=camera.roi)
    _require_open(camera)
    native_roi = Ref{peak_roi}()
    # `peak_roi` is a generated opaque C struct.  Set its nested members
    # through its pointer accessors rather than through a copied Julia value.
    native_ptr = Base.unsafe_convert(Ptr{peak_roi}, native_roi)
    native_ptr.offset.x = UInt32(roi.x_start)
    native_ptr.offset.y = UInt32(roi.y_start)
    native_ptr.size.width = UInt32(roi.width)
    native_ptr.size.height = UInt32(roi.height)
    # The Comfort API receives an ROI by value; only the corresponding Get
    # function takes a pointer.
    _check(camera, peak_ROI_Set(camera.camera_handle, native_roi[]), "setting ROI")
    _check(camera, peak_ROI_Get(camera.camera_handle, native_roi), "getting ROI")
    camera.roi = CameraROI(Int(native_roi[].offset.x), Int(native_roi[].offset.y),
        Int(native_roi[].size.width), Int(native_roi[].size.height))
    return camera.roi
end

function CameraInterface.capture(camera::IDSCamera)
    _require_open(camera)
    camera.capture_mode = SINGLE_FRAME
    setexposuretime!(camera)
    setroi!(camera)
    _check(camera, peak_Acquisition_Start(camera.camera_handle, UInt32(1)), "starting single-frame acquisition")
    image = _copy_frame!(camera)
    camera.data = reshape(image, size(image)..., 1)
    return image
end

function CameraInterface.live(camera::IDSCamera)
    _require_open(camera)
    camera.is_running && abort(camera)
    camera.capture_mode = LIVE
    setexposuretime!(camera)
    setroi!(camera)
    _check(camera, peak_Acquisition_Start(camera.camera_handle, UInt32(PEAK_INFINITE)), "starting live acquisition")
    camera.is_running = true
    return nothing
end

function CameraInterface.getlastframe(camera::IDSCamera)
    _require_open(camera)
    if !camera.is_running
        return capture(camera)
    end
    image = _copy_frame!(camera)
    camera.data = reshape(image, size(image)..., 1)
    return image
end

function CameraInterface.sequence(camera::IDSCamera, nframes::Real)
    _require_open(camera)
    nframes > 0 || throw(ArgumentError("nframes must be positive"))
    camera.is_running && abort(camera)
    camera.capture_mode = SEQUENCE
    camera.sequence_length = Int(nframes)
    setexposuretime!(camera)
    setroi!(camera)
    _check(camera, peak_Acquisition_Start(camera.camera_handle, UInt32(camera.sequence_length)), "starting sequence acquisition")
    camera.is_running = true
    return nothing
end

CameraInterface.sequence(camera::IDSCamera) = CameraInterface.sequence(camera, camera.sequence_length)

function CameraInterface.getdata(camera::IDSCamera)
    _require_open(camera)
    if camera.capture_mode != SEQUENCE
        return getlastframe(camera)
    end
    data = Array{UInt8}(undef, camera.roi.height, camera.roi.width, camera.sequence_length)
    try
        for i in axes(data, 3)
            data[:, :, i] = _copy_frame!(camera)
        end
    finally
        camera.is_running = false
    end
    camera.data = data
    return data
end

function CameraInterface.abort(camera::IDSCamera)
    camera.camera_handle == C_NULL && return nothing
    if camera.is_running || peak_Acquisition_IsStarted(camera.camera_handle) == PEAK_TRUE
        _check(camera, peak_Acquisition_Stop(camera.camera_handle), "stopping acquisition")
    end
    camera.is_running = false
    return nothing
end

function shutdown(camera::IDSCamera)
    camera.camera_handle != C_NULL && begin
        abort(camera)
        _check(camera, peak_Camera_Close(camera.camera_handle), "closing camera")
        camera.camera_handle = C_NULL
    end
    if camera.library_initialized
        _check(camera, peak_Library_Exit(), "exiting the library")
        camera.library_initialized = false
    end
    return nothing
end

function export_state(camera::IDSCamera)
    attributes = Dict(
        "unique_id" => camera.unique_id,
        "camera_format_x_pixels" => camera.camera_format.x_pixels,
        "camera_format_y_pixels" => camera.camera_format.y_pixels,
        "exposure_time" => camera.exposure_time,
        "frame_rate" => camera.frame_rate,
        "roi_x" => camera.roi.x_start,
        "roi_y" => camera.roi.y_start,
        "roi_width" => camera.roi.width,
        "roi_height" => camera.roi.height,
        "capture_mode" => Int(camera.capture_mode),
        "trigger_mode" => Int(camera.trigger_mode),
        "sequence_length" => camera.sequence_length,
        "is_running" => camera.is_running,
        "last_error" => UInt32(camera.last_error),
    )
    return attributes, nothing, Dict()
end
