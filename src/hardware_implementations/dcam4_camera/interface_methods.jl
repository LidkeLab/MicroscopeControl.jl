# Methods required by the camera interface

"""
    CameraInterface.getlastframe(camera::DCAM4Camera)

Wait for the next frame for at most `capture_timeout_ms(exposure, readout)`, with the readout cached by
`readout_time` (refreshed by `live`, `sequence` and `capture`). On a timeout or a failed wait it logs,
sets `last_error` and returns `nothing`. A frame that cannot be copied returns `nothing` with `last_error` set.
"""
function CameraInterface.getlastframe(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    timeout_ms = capture_timeout_ms(camera.exposure_time, cached_readout_time(camera))
    err, hwait = dcamwait_open(hdcam)
    if is_failed(err)
        @error "Failed to open a frame wait: $err"
        camera.last_error = err
        return nothing
    end
    try
        err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_ms)
        if is_failed(err)
            if is_timeout(err)
                @error "Timeout to get last frame on event $event after $timeout_ms ms: $err"
            else
                @error "Failed to get last frame on event $event: $err"
            end
            camera.last_error = err
            return nothing
        end
        err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
        frame === nothing && (camera.last_error = err)
        return frame
    finally
        dcamwait_close(hwait)
    end
end

"""
    CameraInterface.capture(camera::DCAM4Camera)

`capture` refuses (throws) while a live view or sequence is running (`is_running`); otherwise it first stops and
releases any leftover from an earlier call. It waits at most
`capture_timeout_ms(exposure, readout)` (2 x (exposure + readout) + 1 s, with the readout read from the camera).
A timeout or a failed wait logs, sets `last_error` and throws, after the capture is stopped and the buffer
released. A failed buffer allocation or start returns `nothing` with `last_error` set, as before. A frame that cannot be copied returns `nothing` with `last_error` set.
"""
function CameraInterface.capture(camera::DCAM4Camera)
    # Never stop or release a capture another task may be waiting on: a live view's
    # getlastframe loop crashes the process if its buffer is released under the wait.
    camera.is_running && error("DCAM4Camera $(camera.unique_id): capture refused while a live view or " *
        "sequence is running (is_running). Stop the live view or sequence first (abort(camera), or " *
        "getdata after a sequence).")
    hdcam = camera.camera_handle
    camera.capture_mode = SINGLE_FRAME
    # Only leftovers get here (a failed capture, or a sequence that ended and was never read):
    # properties cannot change while a buffer is attached.
    stop_and_release!(camera)
    setexposuretime!(camera)
    settriggermode!(camera)
    setroi!(camera)
    readout_s = readout_time(camera)
    timeout_ms = capture_timeout_ms(camera.exposure_time, readout_s)

    hwait = C_NULL
    try
        err = dcambuf_alloc(hdcam, Int32(1))
        if is_failed(err)
            camera.last_error = err
            return nothing
        end
        # Arm the wait BEFORE the start, so a frame that is ready early cannot be missed.
        err, hwait = dcamwait_open(hdcam)
        if is_failed(err)
            camera.last_error = err
            error("DCAM4Camera $(camera.unique_id): capture could not open a frame wait ($(err)).")
        end
        err = dcamcap_start(hdcam, Int32(DCAMCAP_START_SNAP))
        if is_failed(err)
            camera.last_error = err
            return nothing
        end
        err, _ = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_ms)
        if is_failed(err)
            camera.last_error = err
            what = is_timeout(err) ?
                "timed out after $(timeout_ms) ms (exposure $(camera.exposure_time) s, readout $(readout_s) s)" :
                "frame wait failed ($(err))"
            @error "DCAM4Camera $(camera.unique_id): capture $(what)"
            error("DCAM4Camera $(camera.unique_id): capture $(what). The capture was stopped and its buffer " *
                  "released, so the camera can be used again.")
        end
        err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
        frame === nothing && (camera.last_error = err)
        return frame
    finally
        # On every exit, so the camera is usable afterwards. A failure here is logged, never
        # thrown, so it cannot replace the error that got us here.
        try
            stop_and_release!(camera)
        catch e
            @error "DCAM4Camera $(camera.unique_id): cleanup after capture failed" exception = e
        end
        hwait == C_NULL || dcamwait_close(hwait)
    end
end

"""
    CameraInterface.live(camera::DCAM4Camera; nframes=10)

# Keyword Arguments
- `nframes::Int = 10`: The number of frames to capture
"""
function CameraInterface.live(camera::DCAM4Camera; nframes=10)
    # Start a live view
    camera.capture_mode = LIVE
    abort(camera)
    setexposuretime!(camera)
    settriggermode!(camera)
    setroi!(camera)
    readout_time(camera)  # refresh the cached readout for getlastframe

    # Allocate memory for the image buffer
    err = dcambuf_alloc(camera.camera_handle, Int32(nframes))
    if is_failed(err)
        camera.last_error = err
        return
    end

    # Start the capture of the sequence
    err = dcamcap_start(camera.camera_handle, Int32(DCAMCAP_START_SEQUENCE))
    if is_failed(err)
        camera.last_error = err
        return
    end

    camera.is_running = 1
end

"""
    CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)

Start a sequence of `nframes` and return. A task marks `is_running` false when the sequence ends, or after
`capture_timeout_ms(N * exposure, N * readout)`, when it stops a capture still running (logged, with `last_error`
set). The task acts only while the sequence is current (no `abort`, `live`, `sequence`, `capture` or `getdata`
since); it always ends, and a throw inside it still clears `is_running` for its own sequence.
"""
function CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)
    # Start collection of a sequence
    camera.capture_mode = SEQUENCE
    camera.sequence_length = Int32(nframes)
    abort(camera)
    setexposuretime!(camera)

    settriggermode!(camera)
    setroi!(camera)
    timeout_ms = capture_timeout_ms(camera.exposure_time * camera.sequence_length, readout_time(camera) * camera.sequence_length)

    # Allocate memory for the image buffer
    err = dcambuf_alloc(camera.camera_handle, Int32(camera.sequence_length))
    if is_failed(err)
        @error "Failed to allocate memory for the image buffer: $err"
        camera.last_error = err
        return
    end

    # Start the capture of the sequence
    err = dcamcap_start(camera.camera_handle, Int32(DCAMCAP_START_SNAP))
    if is_failed(err)
        camera.last_error = err
        return
    end
    camera.is_running = 1
    gen = camera.capture_generation  # this sequence's generation (abort, above, already moved it on)
    @async begin
        println("Starting sequence")
        current() = camera.capture_generation == gen
        try
            # Bounded like getdata. A capture stuck BUSY is stopped, but only while it is still this
            # sequence: a newer live view or sequence must never be stopped by a stale poller.
            if !wait_not_busy(camera, timeout_ms, "sequence"; current = current) && current()
                dcamcap_stop(camera.camera_handle)
            end
        finally
            # Only this sequence's poller may clear is_running; a newer capture owns it now.
            current() && (camera.is_running = false)
            println("Sequence done")
        end
    end
    return
end

"""
    CameraInterface.sequence(camera::DCAM4Camera)
"""
function CameraInterface.sequence(camera::DCAM4Camera)
    return CameraInterface.sequence(camera, camera.sequence_length)
end


"""
    CameraInterface.abort(camera::DCAM4Camera)

Stop any capture and release its buffer (`stop_and_release!`). Returns `nothing`.
"""
CameraInterface.abort(camera::DCAM4Camera) = stop_and_release!(camera)

"""
    CameraInterface.getdata(camera::DCAM4Camera)

In SEQUENCE mode it polls the capture status until the sequence ends, for at most
`capture_timeout_ms(N * exposure, N * readout)`, and reads the N frames. In SINGLE_FRAME mode it reads the
newest frame at once. In LIVE mode it returns the newest frame at once and leaves the live view running (no stop,
no release, `is_running` unchanged). A timeout, a failed status read or a frame that cannot be read logs, sets
`last_error` and returns `nothing`; so does a sequence that transferred fewer frames than requested, with
`last_error` set to `DCAMERR_LOSTFRAME`. Every other exit stops the capture and releases the buffer.
"""
function CameraInterface.getdata(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    n = camera.sequence_length
    if camera.capture_mode == LIVE
        # Leave the live view running, with no stop and no release: a threaded live reader
        # crashes the process if its buffer is released under it.
        err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
        frame === nothing && (camera.last_error = err)
        return frame
    end
    try
        if camera.capture_mode == SEQUENCE
            # 2 x N x (exposure + readout) + 1 s, inside the try so a throw here still cleans up.
            timeout_ms = capture_timeout_ms(camera.exposure_time * n, cached_readout_time(camera) * n)
            # Poll the status against that deadline rather than wait for the end-of-cycle event:
            # a sequence that has already ended cannot be missed, and an interrupt can land.
            wait_not_busy(camera, timeout_ms, "getdata") || return nothing
            # READY also describes a buffer that was allocated but never ran: check the frame count.
            terr, info = dcamcap_transferinfo(hdcam)
            if !is_failed(terr) && info.nFrameCount < n
                camera.last_error = DCAMERR_LOSTFRAME
                @error "DCAM4Camera $(camera.unique_id): getdata found $(info.nFrameCount) of $(n) frames transferred"
                return nothing
            end
            im_width, im_height = dcamprop_getsize(hdcam)
            data = zeros(UInt16, im_height, im_width, n)  # (H, W, N) convention
            for i in 1:n
                err, frame = dcambuf_getframe_err(hdcam, Int32(i - 1))
                if frame === nothing
                    camera.last_error = err
                    @error "DCAM4Camera $(camera.unique_id): getdata could not read frame $(i) of $(n) ($(err))"
                    return nothing
                end
                data[:, :, i] = frame
            end
            return data
        elseif camera.capture_mode == SINGLE_FRAME
            # No cycle to wait for: read the newest frame now.
            err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
            frame === nothing && (camera.last_error = err)
            return frame
        end
    finally
        # On every exit: stop the capture and release the buffer. A failure here is logged, never
        # thrown, so it cannot replace the error or the data that got us here.
        try
            stop_and_release!(camera)
        catch e
            @error "DCAM4Camera $(camera.unique_id): cleanup after getdata failed" exception = e
        end
    end
end

### After this line is under development ###
"
    extract_properties(camera::DCAM4Camera)

Extract the properties of the camera.

# Arguments
- `camera::DCAM4Camera`: A DCAM4Camera type.

# Returns
- `properties::Dict`: A dictionary of properties.
"
function extract_properties(camera::DCAM4Camera)
    
    properties = Dict{String, Any}()
    
    # Get first property ID
    err, idprop = dcamprop_getnextid(camera.camera_handle, Int32(0), DCAMPROP_OPTION_SUPPORT)
    
    # Iterate through all properties
    while (idprop != 0)
        try
            # Get property information
            prop = dcam_get_propinfo(camera.camera_handle, idprop)
            
            # Get current value
            err, value = dcamprop_getvalue(camera.camera_handle, idprop)
            
            # Store property information
            properties[prop.name] = Dict(
                "value" => value,
                "type" => prop.type,
                "unit" => prop.unit,
                "range" => prop.range,
                "writable" => prop.writable == 1,
                "readable" => prop.readable == 1
            )
            
            # For Mode type, also store options
            if prop.type == "Mode"
                properties[prop.name]["options"] = prop.options
            end
            
        catch e
            @warn "Failed to get property info for ID: $idprop" exception=e
        end
        
        # Get next property ID
        err, idprop = dcamprop_getnextid(camera.camera_handle, idprop, DCAMPROP_OPTION_SUPPORT)
        if DCAM4.is_failed(err)
            @error "Failed to get next property ID" exception=err
            break
        end
    end
    
    return properties
end

"""
    export_state(camera::DCAM4Camera)
"""
function export_state(camera::DCAM4Camera)
    # Convert frame_rate if it's a tuple
    frame_rate_value = isa(camera.frame_rate, Tuple) ? collect(camera.frame_rate) : camera.frame_rate
    
    attributes = Dict(
        "unique_id" => camera.unique_id,  
        "camera_format_x_pixels" => camera.camera_format.x_pixels,
        "camera_format_y_pixels" => camera.camera_format.y_pixels, 
        "camera_format_pixelsize" => camera.camera_format.pixelsize,
        "camera_format_gain" => camera.camera_format.gain, 
        "exposure_time" => camera.exposure_time,
        "frame_rate" => frame_rate_value, # Use converted value
        "roi_x" => camera.roi.x_start, 
        "roi_y" => camera.roi.y_start, 
        "roi_width" => camera.roi.width,
        "roi_height" => camera.roi.height, 
        "capture_mode" => Int(camera.capture_mode),
        "trigger_mode" => Int(camera.trigger_mode),
        "sequence_length" => camera.sequence_length, 
        "last_error" => Int(camera.last_error),
        "is_running" => camera.is_running,
        "camerastate" => camera.camerastate
    )

    data = nothing
    children = Dict()
    return attributes, data, children
end

function shutdown(camera::DCAM4Camera)
    dcamdev_close(camera.camera_handle)
    dcamapi_uninit()
end

function initialize(camera::DCAM4Camera)
    return nothing
end