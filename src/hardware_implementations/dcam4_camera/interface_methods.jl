# Methods required by the camera interface

"""
    CameraInterface.getlastframe(camera::DCAM4Camera)
"""
function CameraInterface.getlastframe(camera::DCAM4Camera)
    # Get the last image frame from the camera
    hdcam = camera.camera_handle

    # check if camera is busy, if so setup a wait
    err, status = DCAM4.dcamcap_status(hdcam)

    if true #status == DCAM_STATUS_BUSY
        err, hwait = dcamwait_open(hdcam)
        timeout_milisec = Int32(max(1000, round(1000 * camera.exposure_time * 1.5)))
        err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_milisec)
        if is_failed(err)
            @error "Failed to get last frame on event $event: $err"
            camera.last_error = err
            err, hwait = dcamwait_close(hwait)
            return
        end
        if is_timeout(err)
            @error "Timeout to get last frame on event $event: $err"
            camera.last_error = err
            err, hwait = dcamwait_close(hwait)
            return
        end

        framedata = dcambuf_getlastframe(hdcam)
        err = dcamwait_close(hwait)

    else
        framedata = dcambuf_getlastframe(hdcam)
    end

    return framedata
end

"""
    CameraInterface.capture(camera::DCAM4Camera)
"""
function CameraInterface.capture(camera::DCAM4Camera)
    # Start a capture
    camera.capture_mode = SINGLE_FRAME
    setexposuretime!(camera)
    settriggermode!(camera)
    setroi!(camera)

    err = dcambuf_alloc(camera.camera_handle, Int32(1))
    if is_failed(err)
        camera.last_error = err
        return
    end

    err = dcamcap_start(camera.camera_handle, Int32(DCAMCAP_START_SNAP))
    if is_failed(err)
        camera.last_error = err
        return
    end

    data = getlastframe(camera)
    err = dcambuf_release(camera.camera_handle)

    return data
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
"""
function CameraInterface.getdata(camera::DCAM4Camera)
    # Get the data from the camera

    err, hwait = dcamwait_open(camera.camera_handle)
    timeout_milisec = Int32(max(1000, round(1000 * camera.exposure_time * camera.sequence_length * 1.5)))
    err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_CYCLEEND), timeout_milisec)

    camera.is_running = false
    display(timeout_milisec)
    if is_timeout(err)
        display(event)
        camera.last_error = err
        err, hwait = dcamwait_close(hwait)
        return
    end
    err = dcamwait_close(hwait)

    if camera.capture_mode == SEQUENCE
        display("Getting sequence data")
        im_width, im_height = dcamprop_getsize(camera.camera_handle)
        data = zeros(UInt16, im_height, im_width, camera.sequence_length)
        for i in 1:camera.sequence_length
            data[:, :, i] = dcambuf_getframe(camera.camera_handle, Int32(i - 1))
        end
        dcambuf_release(camera.camera_handle)
        return data

    elseif camera.capture_mode == SINGLE_FRAME
        data = dcambuf_getlastframe(camera.camera_handle)
        dcambuf_release(camera.camera_handle)
        return data

    elseif camera.capture_mode == LIVE
        data = dcambuf_getlastframe(camera.camera_handle)
        dcambuf_release(camera.camera_handle)
        return data
    end
end

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

Export the state of the camera to a dictionary.

# Arguments
- `camera::DCAM4Camera`: A DCAM4Camera type.

# Returns
- `attributes::Dict`: A dictionary of attributes.
- `data`: The data of the camera.
- `children::Dict`: A dictionary of children.
"""
function export_state(camera::DCAM4Camera)
    attributes = Dict(
        "device_id" => camera.dev_id, 
        "unique_id" => camera.unique_id,  
        "camera_format_x_pixels" => camera.camera_format.x_pixels,
        "camera_format_y_pixels" => camera.camera_format.y_pixels, 
        "camera_format_pixelsize" => camera.camera_format.pixelsize,
        "camera_format_gain" => camera.camera_format.gain, 
        "camera_handle" => camera.camera_handle, 
        "exposure_time" => camera.exposure_time,
        "frame_rate" => camera.frame_rate, 
        "roi_x" => camera.roi.x, 
        "roi_y" => camera.roi.y, 
        "roi_width" => camera.roi.width,
        "roi_height" => camera.roi.height, 
        "capture_mode" => camera.capture_mode, 
        "trigger_mode" => camera.trigger_mode,
        "sequence_length" => camera.sequence_length, 
        "last_error" => camera.last_error, 
        "is_running" => camera.is_running,
        "camerastate" => camera.camerastate
    )

    # Get camera properties and merge with base attributes
    camera_properties = extract_properties(camera)
    merge!(attributes, Dict("camera_extracted_properties" => camera_properties))

    data = nothing
    children = Dict()
    return attributes, data, children
end
