@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

mutable struct SimCamera <: Camera
    unique_id::String
    camera_format::CameraFormat
    camera_handle
    exposure_time::Float64
    frame_rate
    roi::CameraROI
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    sequence_length
    last_error
    camerastate
    is_running::Bool
end

function SimCamera(;
    unique_id::String="SimCamera",
    camera_format::CameraFormat=CameraFormat(1024, 1024, 6, 2, "SCMOS"),
    camera_handle=0,
    exposure_time::Float64=0.1,
    frame_rate=10.0,
    roi=CameraROI(1, 1, 1024, 1024),
    capture_mode::CaptureMode=LIVE,
    trigger_mode::TriggerMode=AUTO,
    sequence_length=10,
    last_error=0,
    camerastate=0,
    is_running::Bool=false)
    SimCamera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode, sequence_length, last_error, camerastate, is_running)
end

"""
    export_state(camera::SimCamera)
"""
function export_state(camera::SimCamera)
    attributes = Dict{String, Any}(
        "unique_id" => camera.unique_id,
        # Camera format
        "sensor_width" => camera.camera_format.width,
        "sensor_height" => camera.camera_format.height,
        "bit_depth" => camera.camera_format.bit_depth,
        "bytes_per_pixel" => camera.camera_format.bytes_per_pixel,
        "sensor_type" => camera.camera_format.sensor_type,
        # Camera settings
        "exposure_time" => camera.exposure_time,
        "frame_rate" => camera.frame_rate,
        # ROI
        "roi_origin_x" => camera.roi.origin_x,
        "roi_origin_y" => camera.roi.origin_y,
        "roi_width" => camera.roi.width,
        "roi_height" => camera.roi.height,
        # Capture settings
        "capture_mode" => string(camera.capture_mode),
        "trigger_mode" => string(camera.trigger_mode),
        "sequence_length" => camera.sequence_length,
        "is_running" => camera.is_running,
        # Status
        "last_error" => camera.last_error,
        "camera_state" => camera.camerastate
    )
    
    data = nothing
    
    children = Dict{String, Any}()

    return attributes, data, children
end