@enum TL_CAMERA_OPERATION_MODE begin    #Enumerator in C library
    TL_CAMERA_OPERATION_MODE_SOFTWARE_TRIGGERED = Cint(0) 
    TL_CAMERA_OPERATION_MODE_HARDWARE_TRIGGERED = Cint(1)
    TL_CAMERA_OPERATION_MODE_BULB = Cint(2)
    TL_CAMERA_OPERATION_MODE_RESERVED1 = Cint(3)
    TL_CAMERA_OPERATION_MODE_RESERVED2 = Cint(4)
    TL_CAMERA_OPERATION_MODE_MAX = Cint(5)
end

@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
@enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER


"""
    ThorCamCSCCamera(; exposure_time=40, camera_format=CameraFormat(1440, 1080, 1, 0, "CMOS"),
                     roi=CameraROI(1, 1, 1440, 1080), sequence_length=10, poll_timeout=nothing, kwargs...)

A Thorlabs scientific camera (CS-series) driven through the Thorlabs TSI camera SDK
(`thorlabs_tsi_camera_sdk.dll`, so Windows only).

**The keyword constructor opens the camera.** It initializes the SDK, has the SDK write the available camera ids
into the `unique_id` buffer (5 bytes by default), and passes that buffer to the open call. A failed SDK step prints
or logs an error and does not throw. A missing DLL still throws, and so does a negative exposure when
`poll_timeout` is left to follow it (the default). `[limitation]` After a
failed discovery, `camera_handle` keeps the keyword's value (`C_NULL` by default); after a failed open it holds
whatever the SDK left in an uninitialized reference. So a non-null handle does not prove the camera opened. `[limitation]` There is no `initialize` method for this type, so
`initialize(camera)` throws `"initialize not implemented"`. `shutdown` closes the camera and uninitializes the
SDK for the whole process, and returns both SDK codes. `[limitation]` `abort` calls `shutdown`, so after an `abort` (including closing a
[`start_live`](@ref) window) the object cannot be used again; construct a new one.

# Keywords and fields
- `exposure_time::Clonglong = 40`: microseconds. `capture`, `live` and `sequence` write it to the camera before
  they start; `setexposuretime!(camera, t::Clonglong)` writes it at once. (`setexposuretime!(camera)` with no
  value is not implemented for this type.)
- `poll_timeout::Union{Nothing,Cint} = nothing`: frame poll timeout in milliseconds. `nothing` follows the
  exposure (two exposures plus one second); a value, or `setpolltimeout!`, fixes it.
- `camera_format::CameraFormat`: must state the sensor size the camera delivers. The driver copies
  `x_pixels * y_pixels` pixels from the SDK buffer on every frame, so a larger value reads past the buffer and a
  smaller one shears the image.
- `roi::CameraROI`: 1-based offsets; the full sensor frame is cropped to it in Julia.
- `sequence_length::Int = 10`: frames per `sequence`.
- `operation_mode`, `number_of_frames_to_buffer`: written when `capture`, `live` and `sequence` set up and arm
  the camera. `frames_per_trigger_zero_for_unlimited` is written by `capture`; `live` and `sequence` set it to 0
  (unlimited).
- `frame_rate`: stored only. `trigger_mode`: stored and exported.
"""
mutable struct ThorCamCSCCamera <: Camera
    camera_handle::Ptr{Cvoid}
    exposure_time::Clonglong
    poll_timeout::Cint
    unique_id::Vector{UInt8}
    max_id_length::Cint
    # The sensor the camera delivers, in pixels. The driver does not ask the SDK for the image size: it copies
    # `x_pixels * y_pixels` pixels from the SDK's buffer on every frame, so a value larger than the sensor reads past
    # that buffer, and a smaller one returns a sheared image.
    camera_format::CameraFormat
    number_of_frames_to_buffer::Cint
    operation_mode::Cint
    frames_per_trigger_zero_for_unlimited::Cint
    frame_rate::Cint
    roi::CameraROI
    sequence_length::Int
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    last_error::Cint
    camera_state::Cint  #TODO: Enums for these
    is_running::Int
    poll_timeout_explicit::Bool # Constructor, setter or field assignment; otherwise follow exposure.
end

# Field assignment is part of the existing camera API. Mark a caller's timeout
# explicit; the driver's automatic SDK write bypasses this method with setfield!.
function Base.setproperty!(camera::ThorCamCSCCamera, name::Symbol, value)
    converted = convert(fieldtype(ThorCamCSCCamera, name), value)
    setfield!(camera, name, converted)
    name === :poll_timeout && setfield!(camera, :poll_timeout_explicit, true)
    return converted
end

# Preserve the original positional arity; its supplied timeout is explicit.
function ThorCamCSCCamera(camera_handle, exposure_time, poll_timeout, unique_id, max_id_length,
        camera_format, number_of_frames_to_buffer, operation_mode, frames_per_trigger_zero_for_unlimited,
        frame_rate, roi, sequence_length, capture_mode, trigger_mode, last_error, camera_state, is_running)
    return ThorCamCSCCamera(camera_handle, exposure_time, poll_timeout, unique_id, max_id_length,
        camera_format, number_of_frames_to_buffer, operation_mode, frames_per_trigger_zero_for_unlimited,
        frame_rate, roi, sequence_length, capture_mode, trigger_mode, last_error, camera_state, is_running, true)
end

function ThorCamCSCCamera(;
    camera_handle::Ptr{Cvoid} = C_NULL,
    unique_id::Vector{UInt8} = Vector{UInt8}(undef, 5),
    max_id_length::Cint = Cint(5),
    exposure_time::Clonglong = 40,
    poll_timeout::Union{Nothing,Cint} = nothing,
    camera_format::CameraFormat = CameraFormat(1440, 1080,1, 0, "CMOS"),
    number_of_frames_to_buffer::Cint = Cint(2),
    operation_mode::Cint = Cint(0),
    frames_per_trigger_zero_for_unlimited::Cint = Cint(1),
    frame_rate::Cint = Cint(30),
    roi::CameraROI = CameraROI(1, 1, 1440, 1080),
    sequence_length::Int = 10,
    capture_mode::CaptureMode = SINGLE_FRAME,
    trigger_mode::TriggerMode = SOFTWARE_TRIGGER,
    last_error::Cint = Cint(0),
    camera_state::Cint = Cint(0),
    is_running::Int = 0
)
    timeout = poll_timeout === nothing ? exposure_poll_timeout(exposure_time) : poll_timeout
    is_init = thorcamsdkinit()

    if is_init != 0
        println("SDK not Initialized")
    end

    is_discovered = discoveravaliablecameras!(unique_id, max_id_length)

    if is_discovered == 0
        is_opened, camera_handle = opencamera(unique_id)
    else
        println("No cameras found")
    end

    #TODO: Open camera here, so that it doesn not need to be opened in other functions
    ThorCamCSCCamera(camera_handle, exposure_time, timeout, unique_id, max_id_length, camera_format, number_of_frames_to_buffer, operation_mode, frames_per_trigger_zero_for_unlimited, frame_rate, roi, sequence_length, capture_mode,trigger_mode, last_error, camera_state, is_running, poll_timeout !== nothing)
end
