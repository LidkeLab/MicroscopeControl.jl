# Methods required by the camera interface

"""
    CameraInterface.getlastframe(camera::DCAM4Camera)

Wait for the next frame for at most `capture_timeout_ms(exposure, readout)`, with the readout cached by
`readout_time` (refreshed by `live`, `sequence` and `capture`), and return it. On a timeout or a failed wait it logs,
sets `last_error` and returns `nothing`. A frame that cannot be copied returns `nothing` with `last_error` set.

It is safe to call from a thread while another task calls `abort`, `live`, `sequence` or `capture`. The wait is
registered with the camera (see `DCAM4Camera`), and a stop aborts it and waits for it to end before the buffer is
released. When the capture it waited on has been stopped or replaced meanwhile it returns `nothing`, reads no frame
and leaves `last_error` as it was, with one warning per session. With no live view or sequence running (`is_running`),
or while a stop is under way, it returns `nothing` at once, with the same warning and no wait.
"""
function CameraInterface.getlastframe(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    # Register the wait under the lock, with the generation it waits on; the wait itself runs with the lock released.
    gen, hwait, timeout_ms = @lock camera.acquisition_lock begin
        if !camera.is_running || camera.draining > 0
            @warn "DCAM4Camera $(camera.unique_id): getlastframe found no live view or sequence running (or one being stopped); returning nothing" maxlog = 1
            return nothing
        end
        timeout_ms = capture_timeout_ms(camera.exposure_time, cached_readout_time(camera))
        err, hwait = open_wait!(camera)
        if is_failed(err)
            @error "Failed to open a frame wait: $err"
            camera.last_error = err
            return nothing
        end
        camera.capture_generation, hwait, timeout_ms
    end
    try
        err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_ms)
        # Read only while this is still the capture that was waited on, and under the lock, so no stop or
        # start can release or replace the buffer meanwhile. A stop aborts the wait and bumps the generation.
        @lock camera.acquisition_lock begin
            if camera.capture_generation != gen || err == DCAMERR_ABORT  # aborted by a stop that has not yet moved the generation on
                @warn "DCAM4Camera $(camera.unique_id): getlastframe found its capture stopped or replaced (abort, live, sequence or capture); returning nothing" maxlog = 1
                return nothing
            end
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
        end
    finally
        finish_wait!(camera, hwait)
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
Another task's `abort`, `live`, `sequence` or `capture` during the frame wait aborts the wait (see `DCAM4Camera`).
`capture` then returns `nothing` after one warning, reads no frame, leaves `last_error` as it was, and stops
and releases nothing, since the camera is the other task's now.
"""
function CameraInterface.capture(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    hwait = C_NULL
    gen = 0  # the generation of the capture this call owns, recorded under the lock once the leftovers are gone
    current() = camera.capture_generation == gen
    # Held from the refusal through the start, so no other start or stop interleaves; released
    # before the frame wait (see `DCAM4Camera`).
    lock(camera.acquisition_lock)
    held = true
    cleanup = false  # set once the leftovers are gone: from the allocation on, every exit stops and releases
    try
        # Never stop or release a capture another task may be waiting on: a live view's
        # getlastframe loop crashes the process if its buffer is released under the wait.
        camera.is_running && error("DCAM4Camera $(camera.unique_id): capture refused while a live view or " *
            "sequence is running (is_running). Stop the live view or sequence first (abort(camera), or " *
            "getdata after a sequence).")
        camera.capture_mode = SINGLE_FRAME
        # Only leftovers get here (a failed capture, or a sequence that ended and was never read):
        # properties cannot change while a buffer is attached.
        stop_and_release!(camera)
        gen = camera.capture_generation
        setexposuretime!(camera)
        settriggermode!(camera)
        setroi!(camera)
        readout_s = readout_time(camera)
        timeout_ms = capture_timeout_ms(camera.exposure_time, readout_s)

        cleanup = true
        err = dcambuf_alloc(hdcam, Int32(1))
        if is_failed(err)
            camera.last_error = err
            return nothing
        end
        # Arm the wait BEFORE the start, so a frame that is ready early cannot be missed. It is registered
        # with the camera, so another task's stop aborts it and joins it before it releases the buffer.
        err, hwait = open_wait!(camera)
        if is_failed(err)
            camera.last_error = err
            error("DCAM4Camera $(camera.unique_id): capture could not open a frame wait ($(err)).")
        end
        err = dcamcap_start(hdcam, Int32(DCAMCAP_START_SNAP))
        if is_failed(err)
            camera.last_error = err
            return nothing
        end
        held = false
        unlock(camera.acquisition_lock)  # never held across the frame wait
        err, _ = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_ms)
        # Back under the lock: read and clean up only while this is still the capture started above.
        lock(camera.acquisition_lock)
        held = true
        finish_wait!(camera, hwait)
        if !current() || err == DCAMERR_ABORT  # a stop that has not yet moved the generation on aborts the wait too
            cleanup = false  # another task's stop or start has the camera
            @warn "DCAM4Camera $(camera.unique_id): capture found its capture stopped or replaced (abort, live, sequence or capture); returning nothing and leaving the camera alone"
            return nothing
        end
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
        # On every exit from the allocation on, so the camera is usable afterwards, while it is still this
        # capture's. A failure here is logged, never thrown, so it cannot replace the error that got us here.
        try
            # Leave the frame wait first: `stop_and_release!` waits for every registered wait to end.
            hwait == C_NULL || finish_wait!(camera, hwait)
            cleanup && stop_and_release!(camera; current = current)
        catch e
            @error "DCAM4Camera $(camera.unique_id): cleanup after capture failed" exception = e
        end
        held && unlock(camera.acquisition_lock)
        hwait == C_NULL || dcamwait_close(hwait)
    end
end

"""
    CameraInterface.live(camera::DCAM4Camera; nframes=10)

# Keyword Arguments
- `nframes::Int = 10`: The number of frames to capture
"""
function CameraInterface.live(camera::DCAM4Camera; nframes=10)
    # Start a live view, with no other start or stop interleaving (see `DCAM4Camera`)
    @lock camera.acquisition_lock begin
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
            stop_and_release!(camera)  # free the buffer now rather than at the next start; before last_error, which it may overwrite
            camera.last_error = err
            return
        end

        camera.is_running = 1
    end
end

"""
    CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)

Start a sequence of `nframes` and return. A task marks `is_running` false when the sequence ends, or after
`capture_timeout_ms(N * exposure, N * readout)`, when it stops a capture still running (logged, with `last_error`
set). The task acts only while the sequence is current (no `abort`, `live`, `sequence`, `capture` or `getdata`
since); it always ends, and a throw inside it still clears `is_running` for its own sequence.
"""
function CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)
    # Start collection of a sequence, with no other start or stop interleaving (see `DCAM4Camera`)
    gen, timeout_ms = @lock camera.acquisition_lock begin
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
            stop_and_release!(camera)
            camera.last_error = err
            return
        end
        camera.is_running = 1
        camera.capture_generation, timeout_ms  # this sequence's generation (abort, above, already moved it on if it stopped anything)
    end
    # Started after the lock is released; it takes the lock only around its check-and-act.
    @async begin
        println("Starting sequence")
        current() = camera.capture_generation == gen
        try
            # Bounded like getdata, and polled with the lock released. A capture stuck BUSY is stopped,
            # but only while it is still this sequence: a newer live view or sequence must never be
            # stopped by a stale poller, so the check and the stop are one hold of the lock.
            if !wait_not_busy(camera, timeout_ms, "sequence"; current = current)
                @lock camera.acquisition_lock (current() && dcamcap_stop(camera.camera_handle))
            end
        finally
            # Only this sequence's poller may clear is_running; a newer capture owns it now.
            @lock camera.acquisition_lock (current() && (camera.is_running = false))
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
`last_error` set to `DCAMERR_LOSTFRAME`. Outside LIVE mode every exit then stops the capture and releases the
buffer, except when a newer capture (`abort`, `live`, `sequence` or `capture`, from another task) has replaced the
one it reads: it then logs one warning and returns `nothing`, reading no frame, leaving `last_error` as it was and
the newer capture's buffer alone. The replacement check, the reads and the cleanup hold the camera's acquisition
lock; the status poll does not. The cleanup first aborts and joins any frame wait in progress (a `getlastframe` on
another thread; see `stop_and_release!`), and is skipped if the capture was replaced meanwhile.
"""
function CameraInterface.getdata(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    # Read together under the lock, so a start in progress on another task is never seen half done.
    mode, n, gen = @lock camera.acquisition_lock (camera.capture_mode, camera.sequence_length, camera.capture_generation)
    current() = camera.capture_generation == gen  # a newer capture moves this on; this call then leaves its frames and buffer alone
    if mode == LIVE
        # Leave the live view running, with no stop and no release: a threaded live reader
        # crashes the process if its buffer is released under it.
        return @lock camera.acquisition_lock begin
            err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
            frame === nothing && (camera.last_error = err)
            frame
        end
    end
    try
        ended = true
        if mode == SEQUENCE
            # 2 x N x (exposure + readout) + 1 s, inside the try so a throw here still cleans up.
            timeout_ms = capture_timeout_ms(camera.exposure_time * n, cached_readout_time(camera) * n)
            # Poll the status against that deadline rather than wait for the end-of-cycle event:
            # a sequence that has already ended cannot be missed, and an interrupt can land. The
            # lock is released while it polls.
            ended = wait_not_busy(camera, timeout_ms, "getdata"; current = current)
        end
        # Recheck after the poll and before any read, under the lock: until the reads are done no
        # other start or stop can replace the capture.
        @lock camera.acquisition_lock begin
            if !current()
                @warn "DCAM4Camera $(camera.unique_id): getdata found its capture replaced by a newer one (abort, live, sequence or capture); returning nothing and leaving the newer capture alone"
                return nothing
            end
            ended || return nothing  # timed out: wait_not_busy logged it and set last_error
            if mode == SEQUENCE
                # READY also describes a buffer that was allocated but never ran: check the frame count.
                terr, info = dcamcap_transferinfo(hdcam)
                is_failed(terr) && (camera.last_error = terr; return nothing)
                if info.nFrameCount < n
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
            elseif mode == SINGLE_FRAME
                # No cycle to wait for: read the newest frame now.
                err, frame = dcambuf_getframe_err(hdcam, Int32(-1))
                frame === nothing && (camera.last_error = err)
                return frame
            end
        end
    finally
        # On every exit: stop the capture and release the buffer, while it is still this call's
        # capture (checked and acted on in one hold of the lock). A failure here is logged, never
        # thrown, so it cannot replace the error or the data that got us here.
        try
            stop_and_release!(camera; current = current)
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

"""
    shutdown(camera::DCAM4Camera)

Close the camera and give back its count of the DCAM API (`api_acquire!`). The API is uninitialized only when the
last holder gives its count back, so shutting one camera down leaves another one in the process working. Calling
it again is safe and does nothing.
"""
function shutdown(camera::DCAM4Camera)
    hdcam = @lock camera.acquisition_lock begin
        h = camera.camera_handle
        camera.camera_handle = C_NULL  # a second shutdown must not close the device again
        h
    end
    hdcam isa Ptr && hdcam != C_NULL && dcamdev_close(hdcam)
    held = @lock DCAM_API_LOCK begin
        h = camera.api_held
        camera.api_held = false
        h
    end
    held && api_release!()
    return nothing
end

function initialize(camera::DCAM4Camera)
    return nothing
end