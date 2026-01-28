


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

"""
`Camera` is an abstract type that defines the interface for a camera.
"""
abstract type Camera <: AbstractInstrument end

"""
    CameraROI

A mutable struct that represents the region of interest of a camera.

# Fields
- `x_start::Int`: The x coordinate of the start of the ROI.
- `y_start::Int`: The y coordinate of the start of the ROI.
- `width::Int`: The width of the ROI.
- `height::Int`: The height of the ROI.
"""
mutable struct CameraROI
    x_start::Int
    y_start::Int
    width::Int
    height::Int
end

"""
    CameraFormat

A mutable struct that represents the format of a camera.

# Fields
- `x_pixels::Int`: The number of pixels in the x dimension.
- `y_pixels::Int`: The number of pixels in the y dimension.
- `pixelsize::Float64`: The size of a pixel in microns.
- `gain::Float64`: The gain of the camera.
- `sensortype`: The type of sensor used in the camera.
"""
struct CameraFormat
    x_pixels::Int
    y_pixels::Int
    pixelsize::Float64
    gain::Float64
    sensortype
end