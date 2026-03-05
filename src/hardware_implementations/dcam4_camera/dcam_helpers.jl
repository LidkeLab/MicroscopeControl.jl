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
    camera.roi.x_start = hpos
    camera.roi.width = hsize
    camera.roi.y_start = vpos
    camera.roi.height = vsize
end

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



