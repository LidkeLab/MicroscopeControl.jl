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
    # `stop_and_release!` (and so `abort`), and covers `getdata`'s generation check, its frame reads
    # and its final cleanup, a frame wait's registration and its read afterwards (`getlastframe`,
    # `capture`), and the `sequence` poller's check-and-act (its stop, and clearing `is_running`).
    # Reentrant: `stop_and_release!` runs inside the starts and inside `getdata`'s cleanup.
    #
    # Invariant: a holder makes only non-blocking DCAM calls and waits for no other task, with one
    # exception, `stop_and_release!`, which waits for the registered frame waits to end, and does so
    # with the lock RELEASED (`wait` on `acquisition_changed`, a Condition on this lock, releases a
    # reentrant lock at every depth, and takes it back before it returns). The blocking DCAM waits
    # (`dcamwait_event`, in `getlastframe` and `capture`) and `wait_not_busy`'s poll and sleep run with the
    # lock released. A frame wait is registered in `waits` under the lock, before it starts, and
    # unregistered under the lock when it ends, so `stop_and_release!` can abort it and join it
    # before it stops the capture and releases the buffer.
    #
    # Every wait is bounded. A frame wait ends when `stop_and_release!` aborts it (it repeats the abort
    # every `DRAIN_POLL_S`, so an abort that reached a wait before it entered `dcamwait_start` is not
    # lost) or at its own `capture_timeout_ms`. While a drain runs (`draining > 0`) no new frame wait
    # registers, so a polling loop cannot keep the drain from ending. A task that holds the lock
    # while it waits for a frame (a caller that locked it and then called `getlastframe`) delays a
    # stop by at most that wait's timeout. So the drain ends, and every other hold ends in bounded time.
    acquisition_lock::ReentrantLock
    acquisition_changed::Threads.Condition  # on `acquisition_lock`; notified when a frame wait unregisters
    waits::Vector{Ptr{Cvoid}}               # the DCAM wait handles of the frame waits in progress
    draining::Int                           # the `stop_and_release!` calls that are joining waits
    api_held::Bool                          # whether this camera holds a count of the DCAM API (see `api_acquire!`)
end

# The fields before the lock, positionally; the lock and what goes with it are always new. A camera built
# this way holds no count of the DCAM API: only the keyword constructor, which initializes it, does.
function DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                     sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation)
    lock = ReentrantLock()
    return DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                       sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation,
                       lock, Threads.Condition(lock), Ptr{Cvoid}[], 0, false)
end

"""
    DCAM_API_USERS

The number of holders of the DCAM API in this process: every `DCAM4Camera` made by its keyword constructor, until
its `shutdown`, and every `showdevicelist` while it runs. The library is initialized (`dcamapi_init`) when the first
one arrives and uninitialized (`dcamapi_uninit`) when the last leaves, so shutting one camera down leaves the API
up under another. Guarded by `DCAM_API_LOCK`.
"""
const DCAM_API_USERS = Ref(0)
const DCAM_API_LOCK = ReentrantLock()
const DCAM_API_DEVICE_COUNT = Ref(0)  # the device count the last `dcamapi_init` reported

"""
    api_acquire!() -> (err, device_count)

Take a count of the DCAM API, initializing it if this is the first. If `dcamapi_init` fails, it calls `dcamapi_uninit`
(as the constructor always did), takes no count, and returns the error. The device count is the one the library
reported when it was initialized.
"""
function api_acquire!()
    @lock DCAM_API_LOCK begin
        if DCAM_API_USERS[] == 0
            err, dci = dcamapi_init()
            if is_failed(err)
                dcamapi_uninit()
                return err, 0
            end
            DCAM_API_DEVICE_COUNT[] = dci.iDeviceCount
        end
        DCAM_API_USERS[] += 1
        return DCAMERR_SUCCESS, DCAM_API_DEVICE_COUNT[]
    end
end

"""
    api_release!()

Give back a count taken by `api_acquire!`; the last one uninitializes the API.
"""
function api_release!()
    @lock DCAM_API_LOCK begin
        DCAM_API_USERS[] > 0 || return nothing
        DCAM_API_USERS[] -= 1
        DCAM_API_USERS[] == 0 && dcamapi_uninit()
    end
    return nothing
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

    err, _ = api_acquire!()
    if is_failed(err)
        error("DCAM4Camera(dev_id=$dev_id): dcamapi_init failed with $err. " *
              "The DCAM API may already be held by another process (only one process " *
              "can hold the DCAM SDK at a time).")
    end

    # From here, a failure gives back this camera's own count of the API, and nothing else's.
    hdcam = C_NULL
    try
        err, dco = dcamdev_open(dev_id::Int)
        if err != DCAMERR_SUCCESS
            error("DCAM4Camera(dev_id=$dev_id): dcamdev_open failed with $err. " *
                  "The camera may already be held open by another process (only one process " *
                  "can hold a given DCAM device at a time).")
        end
        hdcam = dco.hdcam

        im_width, im_height = dcamprop_getsize(hdcam)
        camera_format = CameraFormat(im_width, im_height, 1, 1, "SCMOS")
        err, exposure_time = dcamprop_getvalue(hdcam, DCAM_IDPROP_EXPOSURETIME)
        data = zeros(UInt16, im_width, im_height)

        camera = DCAM4Camera(unique_id, camera_format, hdcam, exposure_time, frame_rate, roi, capture_mode, trigger_mode, sequence_length, last_error, is_running, camerastate, data, NaN, 0)
        camera.api_held = true
        return camera
    catch
        hdcam == C_NULL || dcamdev_close(hdcam)
        api_release!()
        rethrow()
    end
end
