
@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

"""
    ThorcamDCXCamera(unique_id="ThorcamDCXCamera", camera_format=CameraFormat(1280, 1024, 5.2, 1, "CMOS"),
                     camera_handle=0, exposure_time=0.01, frame_rate=20.0, roi=CameraROI(0, 0, 1280, 1024), ...)

A Thorlabs DCx camera driven through the uc480 SDK (`C:\\Windows\\System32\\uc480_64.dll`, so Windows only).
`[limitation]` The constructor's arguments are positional with defaults, not keywords: `ThorcamDCXCamera()` takes
every default, and changing `roi` means passing the arguments before it.

The constructor does not touch the hardware. `initialize` opens the first camera the SDK finds, reads the sensor
size and pixel size into `camera_format`, sets 8-bit monochrome mode, sets the pixel clock near the top of its
range, and applies `frame_rate` (storing the rate the camera accepted). If no camera is found or the open fails it
logs an error and returns without throwing. `shutdown` closes the camera.

# Fields a caller sets
- `exposure_time::Float64`: seconds; `setexposuretime!(camera)` writes it (the SDK takes milliseconds).
- `roi::CameraROI`: the SDK's area of interest, passed to it unchanged (the default starts at `0, 0`);
  `setroi!(camera)` writes it. `capture` writes both before it acquires.
- `sequence_length`: frames per `sequence`.

Frames are `UInt8`, `(roi.height, roi.width)` indexed `[y, x]`.
"""
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