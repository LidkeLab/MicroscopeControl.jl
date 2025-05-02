# The DCAM4Camera type is a mutable struct that contains all the information needed to control the camera.

@enum CaptureMode LIVE SINGLE_FRAME SEQUENCE
# @enum TriggerMode AUTO SOFTWARE_TRIGGER HARDWARE_TRIGGER

@enum TriggerMode begin
    DCAMPROP_TRIGGER_MODE__NORMAL = 1
    DCAMPROP_TRIGGER_MODE__PIV = 3
    DCAMPROP_TRIGGER_MODE__START = 6
    DCAMPROP_TRIGGER_MODE__MULTIGATE = 7
    DCAMPROP_TRIGGER_MODE__MULTIFRAME = 8
end



mutable struct DCAM4Camera <: Camera
    unique_id::String
    camera_format::CameraFormat
    camera_handle
    exposure_time::Float64
    frame_rate
    roi::CameraROI
    capture_mode::CaptureMode
    trigger_mode::TriggerMode
    sequence_length
    last_error::DCAMERR
    is_running::Bool
    camerastate
    data::Array{UInt16}
end

function DCAM4Camera(dev_id::Int = 0;
    unique_id::String="DCAM4Camera",
    camera_format::CameraFormat=CameraFormat(1024, 1024, 6, 2, "SCMOS"),
    camera_handle=0,
    exposure_time::Float64=0.1,
    frame_rate=10.0,
    roi=CameraROI(0, 0, 1024, 1024),
    capture_mode::CaptureMode=LIVE,
    trigger_mode::TriggerMode=DCAMPROP_TRIGGER_MODE__NORMAL,
    sequence_length=10,
    last_error::DCAMERR=DCAMERR_SUCCESS,
    is_running::Bool=false,
    camerastate=0)

    err, dci = dcamapi_init()
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err, dco = dcamdev_open(dev_id::Int)
    if err != DCAMERR_SUCCESS
        @error "Could not open camera"
        return
    end

    im_width, im_height = dcamprop_getsize(dco.hdcam)
    camera_format = CameraFormat(im_width, im_height, 1, 1, "SCMOS")
    err, exposure_time = dcamprop_getvalue(dco.hdcam, DCAM_IDPROP_EXPOSURETIME)
    data = zeros(UInt16, im_width, im_height)

    DCAM4Camera(unique_id, camera_format, dco.hdcam, exposure_time, frame_rate, roi, capture_mode, trigger_mode, sequence_length, last_error, is_running, camerastate,data)
end