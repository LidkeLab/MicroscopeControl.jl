@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

"""
    SimCamera(; unique_id="SimCamera", exposure_time=0.1, roi=CameraROI(1, 1, 1024, 1024),
              sequence_length=10, kwargs...)

A simulated camera that returns random `UInt16` frames, for tests, examples and system code run without hardware.
Every frame is `(roi.height, roi.width)` indexed `[y, x]`, and a sequence's stack is
`(roi.height, roi.width, sequence_length)` (see `docs/src/conventions.md`); the values are noise.

# Keywords
- `unique_id::String = "SimCamera"`
- `camera_format::CameraFormat = CameraFormat(1024, 1024, 6, 2, "SCMOS")`: reported by `export_state` only.
- `exposure_time::Float64 = 0.1`: seconds. `getlastframe` sleeps this long, and a sequence runs
  `sequence_length * exposure_time`.
- `roi = CameraROI(1, 1, 1024, 1024)`: `width` and `height` set the frame size. Not checked against
  `camera_format`.
- `sequence_length = 10`: frames per `sequence`.
- `frame_rate`, `capture_mode::CaptureMode = LIVE`, `trigger_mode::TriggerMode = AUTO`, `camera_handle`,
  `last_error`, `camerastate`, `is_running::Bool = false`: stored and exported; nothing else reads them.

# Behavior
- `initialize` and `shutdown` do nothing.
- `live` and `sequence` set `is_running`; a sequence clears it after `sequence_length * exposure_time` on an
  `@async` task, and `abort` clears it at once.
- `getdata` returns at once, without waiting for a running sequence: a stack in `SEQUENCE` mode, one frame
  otherwise.
- `[limitation]` `capture` only switches to `SINGLE_FRAME` mode and returns no frame, unlike the hardware drivers;
  read the frame with `getdata`.
- `[limitation]` `setexposuretime!` and `setroi!` are not implemented; set the `exposure_time` and `roi` fields
  directly.
"""
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

Settings only: `data` is `nothing`, so the state holds no image. A driver that puts frames there follows the image
layout, `(height, width[, N])` indexed `[y, x]`, unpermuted (lab decision 0040; see `docs/src/conventions.md`).
"""
function export_state(camera::SimCamera)
    attributes = Dict{String, Any}(
        "unique_id" => camera.unique_id,
        # Camera format
        "sensor_width" => camera.camera_format.x_pixels,
        "sensor_height" => camera.camera_format.y_pixels,
        "pixel_size" => camera.camera_format.pixelsize,
        "gain" => camera.camera_format.gain,
        "sensor_type" => camera.camera_format.sensortype,
        # Camera settings
        "exposure_time" => camera.exposure_time,
        "frame_rate" => camera.frame_rate,
        # ROI
        "roi_x_start" => camera.roi.x_start,
        "roi_y_start" => camera.roi.y_start,
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