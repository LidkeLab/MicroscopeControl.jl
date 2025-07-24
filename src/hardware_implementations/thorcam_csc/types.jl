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


mutable struct ThorCamCSCCamera <: Camera
    camera_handle::Ptr{Cvoid}
    exposure_time::Clonglong # time in micro seconds
    poll_timeout::Cint
    unique_id::Vector{UInt8}
    max_id_length::Cint
    camera_format::CameraFormat
    number_of_frames_to_buffer::Cint
    operation_mode::Cint
    frames_per_trigger_zero_for_unlimited::Cint
    frame_rate::Cdouble
    roi::CameraROI
    sequence_length::Int
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    last_error::Cint
    camera_state::Cint  #TODO: Enums for these
    is_running::Int
    gain::Cint
end

function ThorCamCSCCamera(;
    camera_handle::Ptr{Cvoid} = C_NULL,
    unique_id::Vector{UInt8} = Vector{UInt8}(undef, 5),
    max_id_length::Cint = Cint(5),
    exposure_time::Clonglong = 10000,
    poll_timeout::Cint = Cint(1000),
    camera_format::CameraFormat = CameraFormat(1440, 1080,1, 0, "CMOS"),
    number_of_frames_to_buffer::Cint = Cint(2),
    operation_mode::Cint = Cint(0),
    frames_per_trigger_zero_for_unlimited::Cint = Cint(1),
    frame_rate::Cint = Cint(30),
    roi::CameraROI = CameraROI(0, 0, 1440, 1080),
    sequence_length::Int = 10,
    capture_mode::CaptureMode = SINGLE_FRAME,
    trigger_mode::TriggerMode = SOFTWARE_TRIGGER,
    last_error::Cint = Cint(0),
    camera_state::Cint = Cint(0),
    is_running::Int = 0,
    gain::Cint = Cint(1)
)
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
    ThorCamCSCCamera(camera_handle, exposure_time, poll_timeout, unique_id, max_id_length, camera_format, number_of_frames_to_buffer, operation_mode, frames_per_trigger_zero_for_unlimited, frame_rate, roi, sequence_length, capture_mode,trigger_mode, last_error, camera_state, is_running, gain)
end