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
    readout_s::Float64
    capture_generation::Int
    # The per-camera acquisition lock. It serializes every start (`live`, `sequence`, `capture`) with
    # `stop_and_release!` (and so `abort`), and covers `getdata`'s generation check, its frame reads and
    # its final cleanup, and the `sequence` poller's check-and-act (its stop, and clearing `is_running`).
    # Every holder makes only non-blocking DCAM calls (status, stop, release, alloc, start, property
    # get/set, transferinfo, frame copy, and `capture`'s `dcamwait_open`). The blocking parts run with it
    # released: `wait_not_busy`'s poll and sleep (in `getdata` and the poller) and `capture`'s
    # `dcamwait_event`; so does `capture`'s `dcamwait_close`, and `getlastframe` never takes it. No holder
    # waits for the poller, for `is_running`, or for another task, so each hold ends in bounded time and
    # the poller, which takes it last and only around a check-and-act, cannot block forever. Reentrant:
    # `stop_and_release!` runs inside the starts and inside `getdata`'s cleanup.
    acquisition_lock::ReentrantLock
end

# The fields before the lock, positionally; the lock is always a new one.
DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
            sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation) =
    DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation, ReentrantLock())

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
        error("DCAM4Camera(dev_id=$dev_id): dcamapi_init failed with $err. " *
              "The DCAM API may already be held by another process (only one process " *
              "can hold the DCAM SDK at a time).")
    end

    err, dco = dcamdev_open(dev_id::Int)
    if err != DCAMERR_SUCCESS
        dcamapi_uninit()
        error("DCAM4Camera(dev_id=$dev_id): dcamdev_open failed with $err. " *
              "The camera may already be held open by another process (only one process " *
              "can hold a given DCAM device at a time).")
    end

    im_width, im_height = dcamprop_getsize(dco.hdcam)
    camera_format = CameraFormat(im_width, im_height, 1, 1, "SCMOS")
    err, exposure_time = dcamprop_getvalue(dco.hdcam, DCAM_IDPROP_EXPOSURETIME)
    data = zeros(UInt16, im_width, im_height)

    DCAM4Camera(unique_id, camera_format, dco.hdcam, exposure_time, frame_rate, roi, capture_mode, trigger_mode, sequence_length, last_error, is_running, camerastate, data, NaN, 0)
end