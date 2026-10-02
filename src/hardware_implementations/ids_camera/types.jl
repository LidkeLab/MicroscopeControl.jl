@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

"""A camera controlled through the IDS Peak Comfort C API."""
mutable struct IDSCamera <: Camera
    unique_id::String
    camera_format::CameraFormat
    camera_handle::peak_camera_handle
    exposure_time::Float64             # seconds
    frame_rate::Float64                 # frames per second
    roi::CameraROI
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    sequence_length::Int
    is_running::Bool
    last_error::peak_status
    library_initialized::Bool
    data::Array{UInt8,3}               # (height, width, frames)
end

function IDSCamera(;
    unique_id::String="IDSCamera",
    camera_format::CameraFormat=CameraFormat(0, 0, 0.0, 1.0, "IDS Peak"),
    camera_handle::peak_camera_handle=Ptr{peak_camera}(C_NULL),
    exposure_time::Real=0.01,
    frame_rate::Real=20.0,
    roi::CameraROI=CameraROI(0, 0, 0, 0),
    capture_mode::CaptureMode=LIVE,
    trigger_mode::TriggerMode=AUTO,
    sequence_length::Integer=10,
    is_running::Bool=false,
    last_error::peak_status=PEAK_STATUS_SUCCESS,
    library_initialized::Bool=false)

    data = zeros(UInt8, 0, 0, 0)
    IDSCamera(unique_id, camera_format, camera_handle, Float64(exposure_time),
        Float64(frame_rate), roi, capture_mode, trigger_mode, Int(sequence_length),
        is_running, last_error, library_initialized, data)
end
