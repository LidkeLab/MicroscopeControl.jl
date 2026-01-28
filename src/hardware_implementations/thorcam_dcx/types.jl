
@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

mutable struct ThorcamDCXCamera <: Camera
    unique_id::String
    camera_format::CameraFormat
    camera_handle
    exposure_time::Float64
    frame_rate
    roi::CameraROI
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    sequence_length
    is_running::Bool
    camerastate
    bits_pixel::Int32
    bytes_pixel::Int32
    data::Array{UInt8}
    pImage_Mem::Vector
    pImage_Id::Vector
end

function ThorcamDCXCamera(
    unique_id::String="ThorcamDCXCamera",
    camera_format::CameraFormat=CameraFormat(1280, 1024, 5.2, 1, "CMOS"),
    camera_handle=0,
    exposure_time::Float64=0.01,
    frame_rate=20.0,
    roi=CameraROI(0, 0, 1280, 1024),
    capture_mode::CaptureMode=LIVE,
    trigger_mode::TriggerMode=AUTO,
    sequence_length=10,
    is_running::Bool=false,
    camerastate=0)

    data = zeros(UInt8, camera_format.x_pixels, camera_format.y_pixels, 4) # RGBA format
    bits_pixel = 0
    bytes_pixel = 0
    pImage_Mem = Vector{Any}(undef, 1)
    pImage_Id = Vector{Any}(undef, 1)

    ThorcamDCXCamera(unique_id, camera_format, camera_handle, exposure_time, frame_rate,roi,capture_mode,trigger_mode, sequence_length, is_running, camerastate,bits_pixel,bytes_pixel,data, pImage_Mem, pImage_Id)
end