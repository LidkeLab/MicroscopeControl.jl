# Methods required by the camera interface

"""
    CameraInterface.getlastframe(camera::DCAM4Camera)

Wait for the next frame for at most `capture_timeout_ms(exposure, readout)`. On a timeout or a failed wait it logs,
sets `last_error` and returns `nothing`.
"""
function CameraInterface.getlastframe(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    timeout_ms = capture_timeout_ms(camera.exposure_time, readout_time(camera))
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
        return dcambuf_getlastframe(hdcam)
    finally
        dcamwait_close(hwait)
    end
end

"""
    CameraInterface.capture(camera::DCAM4Camera)

`capture` first stops any earlier capture and releases its buffer. It waits at most
`capture_timeout_ms(exposure, readout)` (2 x (exposure + readout) + 1 s, with the readout read from the camera).
A timeout or a failed wait logs, sets `last_error` and throws, after the capture is stopped and the buffer
released. A failed buffer allocation or start returns `nothing` with `last_error` set, as before.
"""
function CameraInterface.capture(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    camera.capture_mode = SINGLE_FRAME
    # Clear whatever an earlier call left (a live view, a sequence, a failed capture):
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
        return dcambuf_getlastframe(hdcam)
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
"""
function CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)
    # Start collection of a sequence
    camera.capture_mode = SEQUENCE
    camera.sequence_length = Int32(nframes)
    abort(camera)
    setexposuretime!(camera)

    settriggermode!(camera)
    setroi!(camera)

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
    err, frameinterval = DCAM4.dcamprop_getvalue(camera.camera_handle, DCAM4.DCAM_IDPROP_INTERNAL_FRAMEINTERVAL)

    err, status = DCAM4.dcamcap_status(camera.camera_handle)
    #println("Starting sequence")
    @async begin
        println("Starting sequence")
        while status == DCAM4.DCAMCAP_STATUS_BUSY
            #println("Sequence running")
            sleep(frameinterval)
            err, status = DCAM4.dcamcap_status(camera.camera_handle)
            #println(status)            
        end
        camera.is_running = 0
        println("Sequence done")
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
"""
function CameraInterface.abort(camera::DCAM4Camera)
    # Abort a capture
    dcamcap_stop(camera.camera_handle::Ptr{Cvoid})
    err = dcambuf_release(camera.camera_handle)
    camera.is_running = 0
end

"""
    CameraInterface.getdata(camera::DCAM4Camera)

Wait for the end of the cycle for at most `capture_timeout_ms(N * exposure, N * readout)`. A cycle that has
already ended is read at once. A timeout logs, sets `last_error` and returns `nothing`. Every exit stops the
capture, releases the buffer and closes the wait, so in LIVE mode `getdata` ends the live view.
"""
function CameraInterface.getdata(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    n = camera.sequence_length
    # 2 x N x (exposure + readout) + 1 s: a full-frame readout can be longer than the exposure.
    timeout_milisec = capture_timeout_ms(camera.exposure_time * n, readout_time(camera) * n)
    hwait = C_NULL
    try
        # A cycle that has already ended (READY: stopped, with the buffer attached) is read at once.
        # Waiting for its CYCLEEND could miss it, and the cleanup below would then drop the data.
        serr, status = dcamcap_status(hdcam)
        if is_failed(serr) || status != DCAMCAP_STATUS_READY
            err, hwait = dcamwait_open(hdcam)
            if is_failed(err)
                # No wait to arm (dcamwait_open logged it): read what is there, as a failed wait
                # always did, rather than hand DCAM a null wait handle.
                camera.last_error = err
                hwait = C_NULL
            else
                display(timeout_milisec)
                err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_CYCLEEND), timeout_milisec)
                if is_timeout(err)
                    display(event)
                    @error "DCAM4Camera $(camera.unique_id): getdata timed out after $(timeout_milisec) ms"
                    camera.last_error = err
                    return nothing
                end
            end
        end

        if camera.capture_mode == SEQUENCE
            display("Getting sequence data")
            im_width, im_height = dcamprop_getsize(hdcam)
            data = zeros(UInt16, im_height, im_width, n)  # (H, W, N) convention
            for i in 1:n
                data[:, :, i] = dcambuf_getframe(hdcam, Int32(i - 1))
            end
            return data
        elseif camera.capture_mode == SINGLE_FRAME || camera.capture_mode == LIVE
            return dcambuf_getlastframe(hdcam)
        end
    finally
        # On every exit: stop, release the buffer, close the wait. A failure here is logged, never
        # thrown, so it cannot replace the error or the data that got us here.
        try
            stop_and_release!(camera)
        catch e
            @error "DCAM4Camera $(camera.unique_id): cleanup after getdata failed" exception = e
        end
        hwait == C_NULL || dcamwait_close(hwait)
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