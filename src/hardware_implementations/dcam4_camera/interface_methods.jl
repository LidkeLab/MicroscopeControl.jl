# Methods required by the camera interface

"""
    CameraInterface.getlastframe(camera::DCAM4Camera)

Wait for the next frame for at most `capture_timeout_ms(exposure, readout)`, with the readout cached by
`readout_time` (refreshed by `live`, `sequence` and `capture`), and return it. On a timeout or a failed wait it logs,
sets `last_error` and returns `nothing`. A frame that cannot be copied returns `nothing` with `last_error` set.

It is safe to call from a thread while another task calls `abort`, `live`, `sequence`, `capture` or `shutdown`. The
wait is registered with the camera (see `DCAM4Camera`), and a stop aborts it and waits for it to end before the buffer
is released or the device closed. When the capture it waited on has been stopped or replaced meanwhile it returns
`nothing`, reads no frame and leaves `last_error` as it was, with one warning per session. While a stop is under way, or
after `shutdown`, it returns `nothing` at once with the same warning, makes no DCAM call and opens no wait.

Image layout: a frame is `(height, width)`, indexed `[y, x]` with `[1, 1]` at the top left, and a stack is
`(height, width, N)`. `dcambuf_readframe` converts the SDK's row-major buffer once, dropping any row padding, with
`CameraInterface.rowmajor_to_yx`; see `docs/src/conventions.md` (lab decision 0040).
"""
function CameraInterface.getlastframe(camera::DCAM4Camera)
    hwait = C_NULL
    try  # from here every exit ends the wait; `hwait` is set under the lock, in the one statement that registers it
        # Register the wait under the lock, with the generation it waits on; the wait itself runs with the lock released.
        gen, timeout_ms = @lock camera.acquisition_lock begin
            if camera.draining > 0 || camera.closing != 0
                @warn "DCAM4Camera $(camera.unique_id): getlastframe found the camera being stopped or shut down; returning nothing" maxlog = 1
                return nothing
            end
            timeout_ms = capture_timeout_ms(camera.exposure_time, cached_readout_time(camera))
            err, hwait = open_wait!(camera)
            if is_failed(err)
                @error "Failed to open a frame wait: $err"
                camera.last_error = err
                return nothing
            end
            camera.capture_generation, timeout_ms
        end
        err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_ms)
        # Read only while this is still the capture that was waited on, and under the lock, so no stop or
        # start can release or replace the buffer meanwhile. A stop aborts the wait and bumps the generation.
        @lock camera.acquisition_lock begin
            if camera.capture_generation != gen || err == DCAMERR_ABORT  # aborted by a stop that has not yet moved the generation on
                @warn "DCAM4Camera $(camera.unique_id): getlastframe found its capture stopped or replaced (abort, live, sequence, capture or shutdown); returning nothing" maxlog = 1
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
            err, frame = dcambuf_getframe_err(camera.camera_handle, Int32(-1))
            frame === nothing && (camera.last_error = err)
            return frame
        end
    finally
        hwait == C_NULL || finish_wait!(camera, hwait)
    end
end

"""
    CameraInterface.capture(camera::DCAM4Camera)

`capture` refuses (throws) while a live view or sequence is running (`is_running`) and after `shutdown`; otherwise it
first stops and releases any leftover from an earlier call. It waits at most
`capture_timeout_ms(exposure, readout)` (2 x (exposure + readout) + 1 s, with the readout read from the camera).
A timeout or a failed wait logs, sets `last_error` and throws, after the capture is stopped and the buffer
released. A failed buffer allocation or start returns `nothing` with `last_error` set, as before. A frame that cannot be copied returns `nothing` with `last_error` set.
It waits, with the lock released, for any stop in progress to finish before it starts, so a loop of captures cannot
keep a stop from ending. Another task's `abort`, `live`, `sequence`, `capture` or `shutdown` during the frame wait aborts the wait (see
`DCAM4Camera`). `capture` then returns `nothing` after one warning, reads no frame, leaves `last_error` as it was,
and stops and releases nothing: the camera is the other task's now, and the stopper owns the capture. If that stop
failed, the capture stays as a leftover (`last_error` says so) that the next `capture`, start or `abort` stops and
releases, as after any failed capture.

Image layout: a frame is `(height, width)`, indexed `[y, x]` with `[1, 1]` at the top left, and a stack is
`(height, width, N)`. `dcambuf_readframe` converts the SDK's row-major buffer once, dropping any row padding, with
`CameraInterface.rowmajor_to_yx`; see `docs/src/conventions.md` (lab decision 0040).
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
        refused() = camera.closing != 0 ? "capture refused: the camera has been shut down" :
            camera.is_running ? "capture refused while a live view or sequence is running (is_running). " *
            "Stop the live view or sequence first (abort(camera), or getdata after a sequence)." : nothing
        # Never stop or release a capture another task may be waiting on: a live view's
        # getlastframe loop crashes the process if its buffer is released under the wait. The refusal is
        # decided first, so a refused call disturbs no one's wait; it is decided again after the drain.
        why = refused()
        why === nothing || error("DCAM4Camera $(camera.unique_id): $why")
        drain_before_registering!(camera)  # first, then one continuous hold (see `DCAM4Camera`)
        hdcam = camera.camera_handle
        why = refused()
        why === nothing || error("DCAM4Camera $(camera.unique_id): $why")
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
        # with the camera, so a drain aborts it and joins it before it releases the buffer.
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
        if !current() || err == DCAMERR_ABORT  # a stop that has not yet moved the generation on aborts the wait too
            cleanup = false  # another task's stop or start has the camera, and owns the capture
            @warn "DCAM4Camera $(camera.unique_id): capture found its capture stopped or replaced (abort, live, sequence, capture or shutdown); returning nothing and leaving the camera alone"
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
            # End the frame wait first: `stop_and_release!` waits for every registered wait to end.
            hwait == C_NULL || finish_wait!(camera, hwait)
            cleanup && stop_and_release!(camera; current = current)
        catch e
            @error "DCAM4Camera $(camera.unique_id): cleanup after capture failed" exception = e
        end
        held && unlock(camera.acquisition_lock)
    end
end

# The first thing every start does, with the acquisition lock held: refuse on a camera that has been shut down,
# then drain the frame waits, and refuse again if `shutdown` began during the drain. After it returns true the caller
# holds the lock continuously, so nothing registers and nothing interleaves until the start is whole (see `DCAM4Camera`).
function begin_start!(camera::DCAM4Camera, what::AbstractString)
    for drained in (false, true)
        if camera.closing != 0
            camera.last_error = DCAMERR_INVALIDHANDLE
            @error "DCAM4Camera $(camera.unique_id): $(what) refused: the camera has been shut down"
            return false
        end
        drained || drain_waits!(camera)
    end
    return true
end

# The timeout of `getdata`'s sequence poll, or `nothing` (with one warning) if the capture was replaced or the camera
# shut down meanwhile. The cached readout can miss, which reads the camera, so it is all done under the lock with the
# check: no DCAM call is made on a closed handle.
function sequence_timeout_ms(camera::DCAM4Camera, n::Integer, current::Function)
    @lock camera.acquisition_lock begin
        if !current() || camera.closing != 0
            @warn "DCAM4Camera $(camera.unique_id): getdata found its capture replaced by a newer one (abort, live, sequence, capture or shutdown); returning nothing and leaving the newer capture alone"
            return nothing
        end
        return capture_timeout_ms(camera.exposure_time * n, cached_readout_time(camera) * n)
    end
end

# `getdata`'s LIVE read: the newest frame, with no stop and no release, only while the generation `current` watches is
# still the camera's, checked inside the hold of the lock that reads the frame.
function read_live_frame(camera::DCAM4Camera, current::Function)
    @lock camera.acquisition_lock begin
        if !current() || camera.closing != 0
            @warn "DCAM4Camera $(camera.unique_id): getdata found its capture replaced by a newer one (abort, live, sequence or capture); returning nothing and leaving the newer capture alone"
            return nothing
        end
        err, frame = dcambuf_getframe_err(camera.camera_handle, Int32(-1))
        frame === nothing && (camera.last_error = err)
        return frame
    end
end

"""
    CameraInterface.live(camera::DCAM4Camera; nframes=10)

# Keyword Arguments
- `nframes::Int = 10`: The number of frames to capture

Frames are read with `getlastframe` or `getdata`; their layout is `(height, width)` indexed `[y, x]` (lab decision
0040; see `docs/src/conventions.md`).
"""
function CameraInterface.live(camera::DCAM4Camera; nframes=10)
    # Start a live view, with no other start or stop interleaving (see `DCAM4Camera`)
    @lock camera.acquisition_lock begin
        begin_start!(camera, "live") || return
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

The stack is read with `getdata`, `(height, width, N)` indexed `[y, x, frame]` (lab decision 0040; see
`docs/src/conventions.md`).
"""
function CameraInterface.sequence(camera::DCAM4Camera, nframes::Real)
    # Start collection of a sequence, with no other start or stop interleaving (see `DCAM4Camera`)
    gen, timeout_ms = @lock camera.acquisition_lock begin
        begin_start!(camera, "sequence") || return
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

`sequence(camera, camera.sequence_length)`; the stack is read with `getdata`, `(height, width, N)` indexed
`[y, x, frame]` (lab decision 0040; see `docs/src/conventions.md`).
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
lock, and so does each status read of the poll; the sleep between reads does not. After `shutdown` it returns `nothing`
with `last_error` set to `DCAMERR_INVALIDHANDLE`. The cleanup first aborts and joins any frame wait in progress (a `getlastframe` on
another thread; see `stop_and_release!`), and is skipped if the capture was replaced meanwhile.

Image layout: a frame is `(height, width)`, indexed `[y, x]` with `[1, 1]` at the top left, and a stack is
`(height, width, N)`. `dcambuf_readframe` converts the SDK's row-major buffer once, dropping any row padding, with
`CameraInterface.rowmajor_to_yx`; see `docs/src/conventions.md` (lab decision 0040).
"""
function CameraInterface.getdata(camera::DCAM4Camera)
    # Read together under the lock, so a start in progress on another task is never seen half done.
    mode, n, gen = @lock camera.acquisition_lock begin
        if camera.closing != 0
            camera.last_error = DCAMERR_INVALIDHANDLE
            @error "DCAM4Camera $(camera.unique_id): getdata refused: the camera has been shut down"
            return nothing
        end
        (camera.capture_mode, camera.sequence_length, camera.capture_generation)
    end
    current() = camera.capture_generation == gen  # a newer capture moves this on; this call then leaves its frames and buffer alone
    if mode == LIVE
        # Leave the live view running, with no stop and no release: a threaded live reader
        # crashes the process if its buffer is released under it.
        return read_live_frame(camera, current)
    end
    try
        ended = true
        if mode == SEQUENCE
            # 2 x N x (exposure + readout) + 1 s, inside the try so a throw here still cleans up. The readout
            # may need a camera read, so it is resolved under the lock, with the shutdown and currency check.
            timeout_ms = sequence_timeout_ms(camera, n, current)
            timeout_ms === nothing && return nothing
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
                terr, info = dcamcap_transferinfo(camera.camera_handle)
                is_failed(terr) && (camera.last_error = terr; return nothing)
                if info.nFrameCount < n
                    camera.last_error = DCAMERR_LOSTFRAME
                    @error "DCAM4Camera $(camera.unique_id): getdata found $(info.nFrameCount) of $(n) frames transferred"
                    return nothing
                end
                im_width, im_height = dcamprop_getsize(camera.camera_handle)
                data = zeros(UInt16, im_height, im_width, n)  # (H, W, N) convention
                for i in 1:n
                    err, frame = dcambuf_getframe_err(camera.camera_handle, Int32(i - 1))
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
                err, frame = dcambuf_getframe_err(camera.camera_handle, Int32(-1))
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

Settings only: `data` is `nothing`, so the state holds no image. A driver that puts frames there follows the image
layout, `(height, width[, N])` indexed `[y, x]`, unpermuted (lab decision 0040; see `docs/src/conventions.md`).
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

Shut the camera down in one step, under its acquisition lock: aborts and joins every frame wait in progress (a
`getlastframe` loop on another thread needs no `abort` first), stops and releases any capture, makes every
`sequence` poller and `getdata` in progress stale, closes the device, and only then gives back this camera's count
of the DCAM API. The API is uninitialized when the last holder gives its count back, and never before the device close
has returned, so shutting one camera down leaves another one in the process working. Returns the `DCAMERR` of
`dcamapi_uninit` when it uninitialized the API, and `DCAMERR_SUCCESS` when another holder keeps it up. A second
`shutdown`, concurrent or later, waits for the first to finish, touches nothing and returns `DCAMERR_SUCCESS`. A
`shutdown` that is interrupted before it finishes is resumed by the next one, including a concurrent one that was waiting
for it: a step that never began runs, a finished step is skipped, and a step interrupted mid-call (the device close, or
`dcamapi_uninit`) is logged once as of unknown outcome and not repeated. After
`shutdown`, `getlastframe` and `getdata` return `nothing` and `capture` throws; `live` and `sequence` log an error and
return, and set `last_error` to `DCAMERR_INVALIDHANDLE` where they set it at all; none of them makes a DCAM call.
"""
function shutdown(camera::DCAM4Camera)
    @lock camera.acquisition_lock begin
        while camera.closing == 1
            wait(camera.acquisition_changed)  # releases the lock until the first shutdown finishes or fails
        end
        camera.closing == 2 && camera.close_step == 2 && camera.api_step == 2 && return DCAMERR_SUCCESS  # all done
        camera.closing = 1  # from here no frame wait registers and no start proceeds
        err = DCAMERR_SUCCESS
        try
            drain_waits!(camera)
            hdcam = camera.camera_handle
            camera.close_step == 0 && hdcam isa Ptr && hdcam != C_NULL && stop_and_release!(camera)  # a failure is in last_error; the device is closed regardless
            camera.capture_generation += 1  # pollers and getdata in progress go stale whether or not the stop worked
            camera.is_running = false
            # The two native steps, each recorded before it runs and cleared only after it returns, so a retry after an
            # interrupt runs a step that never began, skips one that finished, and does not repeat one interrupted
            # mid-call (a second `dcamdev_close` on a freed handle, or `dcamapi_uninit`, can crash).
            if camera.close_step == 1
                @error "DCAM4Camera $(camera.unique_id): a device close was interrupted and its outcome is unknown; not repeating it"
                camera.camera_handle = C_NULL
                camera.close_step = 2
            elseif camera.close_step == 0
                if hdcam isa Ptr && hdcam != C_NULL
                    camera.close_step = 1
                    dcamdev_close(hdcam)
                end
                camera.camera_handle = C_NULL
                camera.close_step = 2
            end
            if camera.api_held
                err = api_release!(camera)
            elseif camera.api_step == 1
                @error "DCAM4Camera $(camera.unique_id): dcamapi_uninit was interrupted and its outcome is unknown; not repeating it"
                camera.api_step = 2
            end
        finally
            # Closed once the device close has begun (the camera is unusable); open again if nothing was done, for a retry.
            camera.closing = camera.close_step == 0 ? 0 : 2
            notify(camera.acquisition_changed; all = true)
        end
        return err
    end
end

function initialize(camera::DCAM4Camera)
    return nothing
end