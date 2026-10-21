function show_error()
    error_msg = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_last_error()::Ptr{UInt8}

    message = Vector{UInt8}(undef, 128)
    for i in 1:128
        message[i] = unsafe_load(error_msg, i)
    end
    
    message = reinterpret(UInt8, message)
    str = String(message)
    println(str)
end

# The camera always delivers the full sensor, (H, W), whatever `roi` says: the driver never sends `roi` to the SDK.
sensor_size(camera::ThorCamCSCCamera) = (camera.camera_format.y_pixels, camera.camera_format.x_pixels)

# The (H, W) of the frame the driver returns: `roi`, applied in software to the full-sensor frame.
frame_size(camera::ThorCamCSCCamera) = (camera.roi.height, camera.roi.width)

# Throws an ArgumentError, before any copy from the SDK, unless `roi` is non-empty and inside the sensor.
function validate_roi(camera::ThorCamCSCCamera)
    roi = camera.roi
    sensor_height, sensor_width = sensor_size(camera)
    if roi.x_start < 1 || roi.y_start < 1 || roi.width < 1 || roi.height < 1 ||
       roi.x_start + roi.width - 1 > sensor_width || roi.y_start + roi.height - 1 > sensor_height
        throw(ArgumentError("ThorCamCSCCamera roi (x_start = $(roi.x_start), y_start = $(roi.y_start), " *
                            "width = $(roi.width), height = $(roi.height)) is not inside the $sensor_width x " *
                            "$sensor_height sensor (1-based, inclusive)"))
    end
    return nothing
end
