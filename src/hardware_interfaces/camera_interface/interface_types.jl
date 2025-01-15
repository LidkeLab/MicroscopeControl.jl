


# mutable struct GenericCamera <: CameraInterface.Camera
#     unique_id::String
#     camera_format::CameraFormat
#     camera_handle
#     exposure_time::Float64
#     frame_rate
#     roi::CameraROI
#     capture_mode::CaptureMode_Generic
#     trigger_mode::TriggerMode_Generic
#     sequence_length
#     last_error
#     camerastate
# end


abstract type Camera <: AbstractInstrument end

mutable struct CameraROI
    x_start::Int
    y_start::Int
    width::Int
    height::Int
end

struct CameraFormat
    x_pixels::Int
    y_pixels::Int
    pixelsize::Float64
    gain::Float64
    sensortype
end