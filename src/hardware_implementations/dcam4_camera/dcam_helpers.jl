# These are commonly use higher-level methods that call lower-level methods

function showdevicelist()
    err, dci = dcamapi_init()

    n = dci.iDeviceCount
    println("Found $(n) devices")
    
    for i in 0:n-1
        err, dco = dcamdev_open(i)
        if is_failed(err)
            @error "Failed to open device"
            return
        end
        
        output = "#$(i): "
        hdcam = dco.hdcam

        err, model = dcamdev_getstring(hdcam, DCAM_IDSTR_MODEL)
        output *= length(model) == 0 ? "No DCAM_IDSTR.MODEL" : "MODEL=$(model)"

        err, cameraid = dcamdev_getstring(hdcam, DCAM_IDSTR_CAMERAID)
        output *= length(cameraid) == 0 ? ", No DCAM_IDSTR.CAMERAID" : ", CAMERAID=$(cameraid)"

        println(output)
        dcamdev_close(hdcam)
    end
    err = dcamapi_uninit()
end

function showproperties(camera::DCAM4Camera)
    hdcam = camera.camera_handle

    err, idprop = dcamprop_getnextid(hdcam, Int32(0), DCAMPROP_OPTION_SUPPORT)
    while (idprop != 0)
        output = string(idprop) * ' '

        err = dcamprop_getname(hdcam, idprop)
        try 
            output *= ':' * string(DCAM_IDPROP(idprop))
        catch
            output *= " : Unknown ID"
        end
        println(output)

        err, idprop = dcamprop_getnextid(hdcam, idprop, DCAMPROP_OPTION_SUPPORT)
        if is_failed(err)
            display(err)
            println(idprop)
        end

    end
end

function setvalue(camera::DCAM4Camera, iProp::Int32, value::Float64)
    hdcam = camera.camera_handle
    err, dca = dcamprop_getattr(hdcam::Ptr{Cvoid},iProp)

    if !is_writable(dca)
        @error "Property is not writable :$(DCAM_IDPROP(iProp))" 
        return
    end

    if !is_hasrange(dca)
        if value < dca.valuemin
            @warn "Value of $(value) is below the minimum of $(dca.valuemin) for $(DCAM_IDPROP(iProp)). Setting value to $(dca.valuemin)"
            value = dca.valuemin
        end
        if value > dca.valuemax
            @warn "Value of $(value) is above the maximum of $(dca.valuemax) for $(DCAM_IDPROP(iProp)). Setting value to $(dca.valuemax)"
            value = dca.valuemax
        end
    end

    err = dcamprop_setvalue(hdcam, iProp, Float64(value))    
    if is_failed(err)
        @error "Failed to set value"
        camera.last_error = err
    end    

    return err, value 
end

function setvalue(camera::DCAM4Camera, idprop::DCAM_IDPROP, value)
    return setvalue(camera, Int32(idprop), Float64(value))
end

function setexposuretime!(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    exposure_time = camera.exposure_time
    err = dcamprop_setvalue(hdcam, DCAM_IDPROP_EXPOSURETIME, Float64(exposure_time))
    if is_failed(err)
        @error "Failed to set exposure time"
        camera.last_error = err
    end    
    err, value = dcamprop_getvalue(hdcam, DCAM_IDPROP_EXPOSURETIME)
    # Only warn if difference is significant (>1% or >1ms)
    if !isapprox(exposure_time, value; rtol=0.01, atol=0.001)
        @warn "Exposure time set to $(value) instead of $(exposure_time)"
    end
    camera.exposure_time = value
    return err, value
end

function setexposuretime!(camera::DCAM4Camera, exposure_time::Real)
    camera.exposure_time = Float64(exposure_time)
    return setexposuretime!(camera)
end

function setroi!(camera::DCAM4Camera)
    setvalue(camera, DCAM_IDPROP_SUBARRAYMODE, 1) # set subarray mode to off so that the order of setting the ROI would not matter.
    setvalue(camera, DCAM_IDPROP_SUBARRAYHPOS, camera.roi.x_start)
    err, hpos = dcamprop_getvalue(camera.camera_handle, DCAM_IDPROP_SUBARRAYHPOS)
    if hpos != camera.roi.x_start
        @warn "ROI HPOS set to $(hpos) instead of $(camera.roi.x_start)"
    end

    setvalue(camera, DCAM_IDPROP_SUBARRAYHSIZE, camera.roi.width)
    err, hsize = dcamprop_getvalue(camera.camera_handle, DCAM_IDPROP_SUBARRAYHSIZE)
    if hsize != camera.roi.width
        @warn "ROI HSIZE set to $(hsize) instead of $(camera.roi.width)"
    end

    setvalue(camera, DCAM_IDPROP_SUBARRAYVPOS, camera.roi.y_start)
    err, vpos = dcamprop_getvalue(camera.camera_handle, DCAM_IDPROP_SUBARRAYVPOS)
    if vpos != camera.roi.y_start
        @warn "ROI VPOS set to $(vpos) instead of $(camera.roi.y_start)"
    end

    setvalue(camera, DCAM_IDPROP_SUBARRAYVSIZE, camera.roi.height)
    err, vsize = dcamprop_getvalue(camera.camera_handle, DCAM_IDPROP_SUBARRAYVSIZE)
    if vsize != camera.roi.height
        @warn "ROI VSIZE set to $(vsize) instead of $(camera.roi.height)"
    end
    setvalue(camera, DCAM_IDPROP_SUBARRAYMODE, 2) # set subarray mode to on to apply the ROI
    requested = (camera.roi.x_start, camera.roi.width, camera.roi.y_start, camera.roi.height)
    # Write the accepted values back FIRST, so the struct tells the truth about
    # what the camera took even when we are about to throw.
    camera.roi.x_start = hpos
    camera.roi.width = hsize
    camera.roi.y_start = vpos
    camera.roi.height = vsize

    accepted = (hpos, hsize, vpos, vsize)
    if accepted != requested
        names = ("x_start (HPOS)", "width (HSIZE)", "y_start (VPOS)", "height (VSIZE)")
        differing = [ "$(names[i]): asked $(requested[i]), got $(accepted[i])"
                      for i in eachindex(names) if accepted[i] != requested[i] ]
        error("DCAM4Camera $(camera.unique_id): the camera did not accept the requested " *
              "ROI. " * join(differing, "; ") * ". `camera.roi` now holds what the camera " *
              "actually took. Common causes: the ORCA requires subarray positions and sizes " *
              "in multiples of 4, and positions are 0-based; a size that exceeds the sensor " *
              "from the given position is clipped. This used to be four `@warn`s, so a wrong " *
              "ROI went through and the next frame was silently not the region asked for.")
    end
    return camera.roi
end

"""
    setroi!(camera::DCAM4Camera, roi::CameraROI)

Apply `roi` to the camera. **Prefer this over the four-argument form**, whose
positional order is `(hpos, hsize, vpos, vsize)` — that is
`(x, WIDTH, y, HEIGHT)` — while `CameraROI`'s field order is
`(x_start, y_start, width, height)`. Passing a `CameraROI`'s fields
positionally in their own order therefore swaps `y_start` with `width`, and
before v0.2.3 the resulting mismatch was only warned about, so the wrong
region went through. Reported from a rig running an ORCA C11440-22CU.

Positions are **0-based**, and the ORCA wants positions and sizes in multiples
of 4; a value the camera does not accept now throws.
"""
function setroi!(camera::DCAM4Camera, roi::CameraROI)
    camera.roi.x_start = roi.x_start
    camera.roi.y_start = roi.y_start
    camera.roi.width   = roi.width
    camera.roi.height  = roi.height
    return setroi!(camera)
end

"""
    setroi!(camera::DCAM4Camera, hpos, hsize, vpos, vsize)

Apply an ROI given as `(x, WIDTH, y, HEIGHT)` — note that this is **not**
`CameraROI`'s field order, which is `(x_start, y_start, width, height)`. The
`setroi!(camera, ::CameraROI)` method above avoids the confusion and is
preferred.
"""
function setroi!(camera::DCAM4Camera, hpos::Int32, hsize::Int32, vpos::Int32, vsize::Int32)
    camera.roi.x_start = hpos
    camera.roi.width  = hsize
    camera.roi.y_start  = vpos
    camera.roi.height = vsize
    setroi!(camera)
end

function settriggermode!(camera::DCAM4Camera)
    setvalue(camera, DCAM_IDPROP_TRIGGER_MODE, Float64(Int(camera.trigger_mode)))
end

function settriggermode!(camera::DCAM4Camera, trigger_mode::TriggerMode)
    camera.trigger_mode = trigger_mode
    settriggermode!(camera)
end

"""
    capture_timeout_ms(exposure_s, readout_s) -> Int32

The timeout for one frame wait, in milliseconds: `2 * (exposure_s + readout_s)` seconds plus 1 s. The readout term
matters: a full ORCA frame reads out in tens of milliseconds, far longer than a short exposure. Throws for a
negative or non-finite input, and for a result beyond `typemax(Int32)` ms, so a wait is never unbounded
(DCAM reads the negative value `0x80000000` as INFINITE).
"""
function capture_timeout_ms(exposure_s::Real, readout_s::Real)
    (isfinite(exposure_s) && exposure_s >= 0) ||
        error("capture_timeout_ms: exposure $(exposure_s) s must be finite and non-negative")
    (isfinite(readout_s) && readout_s >= 0) ||
        error("capture_timeout_ms: readout $(readout_s) s must be finite and non-negative")
    t = 2000 * (Float64(exposure_s) + Float64(readout_s)) + 1000
    t <= typemax(Int32) || error("capture_timeout_ms: $(t) ms does not fit a DCAM timeout (Int32 ms)")
    return Int32(round(t))
end

"""
    READOUT_FALLBACK_S

The readout time, in seconds, that `readout_time` assumes when the camera does not report
`DCAM_IDPROP_TIMING_READOUTTIME`. It is deliberately generous, since it only lengthens a timeout.
"""
const READOUT_FALLBACK_S = 1.0

"""
    readout_time(camera::DCAM4Camera) -> Float64

The sensor readout time in seconds, read from the camera's `DCAM_IDPROP_TIMING_READOUTTIME`, which depends on the
current ROI and readout speed, so read it after `setroi!`. If the read fails or the value is not a finite,
non-negative number, it warns and returns `READOUT_FALLBACK_S`.
"""
function readout_time(camera::DCAM4Camera)
    err, t = dcamprop_getvalue(camera.camera_handle, DCAM_IDPROP_TIMING_READOUTTIME)
    if is_failed(err) || !isfinite(t) || t < 0
        @warn "DCAM4Camera $(camera.unique_id): the camera did not report its readout time ($(err), $(t)); assuming $(READOUT_FALLBACK_S) s for the frame-wait timeout"
        return READOUT_FALLBACK_S
    end
    return Float64(t)
end

"""
    stop_and_release!(camera::DCAM4Camera)

Leave the camera with no capture running and no buffer attached, whatever an earlier call left behind (a live view,
a sequence, or a capture that failed). It reads the status first, so a camera with nothing to stop logs no error:
BUSY is stopped, then BUSY or READY (a buffer attached) is released, and STABLE needs nothing. If the status read
fails, it tries both. Sets `camera.is_running = false`.
"""
function stop_and_release!(camera::DCAM4Camera)
    hdcam = camera.camera_handle
    err, status = dcamcap_status(hdcam)
    if is_failed(err)
        dcamcap_stop(hdcam)
        dcambuf_release(hdcam)
    else
        status == DCAMCAP_STATUS_BUSY && dcamcap_stop(hdcam)
        (status == DCAMCAP_STATUS_BUSY || status == DCAMCAP_STATUS_READY) && dcambuf_release(hdcam)
    end
    camera.is_running = false
    return nothing
end
