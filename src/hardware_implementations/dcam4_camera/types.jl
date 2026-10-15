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
    # `stop_and_release!` (and so `abort`) and `shutdown`, and covers `getdata`'s generation check, its frame
    # reads and its final cleanup, a frame wait's registration, its read and its end (`getlastframe`,
    # `capture`), the capture status poll, and the `sequence` poller's check-and-act. Reentrant:
    # `stop_and_release!` runs inside the starts, inside `shutdown` and inside `getdata`'s cleanup.
    #
    # Invariant: a holder makes only non-blocking DCAM calls and waits for no other task, except in two
    # places, where the wait releases the lock (`wait` on `acquisition_changed`, a Condition on this
    # lock, releases a reentrant lock at every depth and takes it back before it returns): `drain_waits!`,
    # which waits for the registered frame waits to end, and a second `shutdown`, which waits for the first.
    # Every start, every stop and `shutdown` calls `drain_waits!` FIRST, before it reads or writes any
    # camera state, and holds the lock continuously from then on. A frame wait registers under the lock
    # and nothing registers while it is held, so once the drain returns nothing in the start or stop
    # releases the lock: the nested `stop_and_release!`'s drain is empty, and no other task sees or
    # changes the camera until the start is whole. The blocking DCAM waits (`dcamwait_event`, in
    # `getlastframe` and `capture`) and `wait_not_busy`'s sleep run with the lock released. A frame wait is
    # registered in `waits` under the lock, before it starts, and its handle is closed and unregistered
    # in one hold of the lock when it ends (`finish_wait!`), so a drain that ends leaves no handle open.
    #
    # Every wait is bounded. A frame wait ends when a drain aborts it (it repeats the abort every
    # `DRAIN_POLL_S`, so an abort that reached a wait before it entered `dcamwait_start` is not lost) or
    # at its own `capture_timeout_ms`. While a drain runs (`draining > 0`) and once `shutdown` has begun
    # (`closing > 0`) no new frame wait registers, so a polling loop cannot keep a drain from ending. A
    # task that holds the lock while it waits for a frame (a caller that locked it and then called
    # `getlastframe`) delays a stop by at most that wait's timeout. So every drain ends, and every other
    # hold ends in bounded time.
    acquisition_lock::ReentrantLock
    acquisition_changed::Threads.Condition  # on `acquisition_lock`; notified when a frame wait ends or `shutdown` finishes
    waits::Vector{Ptr{Cvoid}}               # the DCAM wait handles of the frame waits in progress
    draining::Int                           # the drains in progress (`drain_waits!`)
    closing::Int                            # 0 open, 1 `shutdown` under way, 2 shut down: the device is closed
    api_held::Bool                          # whether this camera holds a count of the DCAM API (see `api_acquire!`)
end

# Assemble a camera with its lock and what goes with it, all new.
assemble_camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation, api_held) =
    (lock = ReentrantLock();
     DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                 sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation,
                 lock, Threads.Condition(lock), Ptr{Cvoid}[], 0, 0, api_held))

# The fields before the lock, positionally; the lock and what goes with it are always new. The caller
# initialized the DCAM API and opened the device, so the camera adopts a count of the API without
# initializing it (`api_adopt!`), and its `shutdown` uninitializes when it is the last holder, as on 0.2.6.
function DCAM4Camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                     sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation)
    api_adopt!()
    return assemble_camera(unique_id, camera_format, camera_handle, exposure_time, frame_rate, roi, capture_mode, trigger_mode,
                           sequence_length, last_error, is_running, camerastate, data, readout_s, capture_generation, true)
end

"""
    DCAM_API_USERS

The number of holders of the DCAM API in this process: every `DCAM4Camera` (the keyword constructor initializes the
API; the positional one adopts the caller's initialization), until its `shutdown`, and every `showdevicelist` while it
runs. The library is initialized (`dcamapi_init`) when the first
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
    api_adopt!()

Take a count of the DCAM API without initializing it, for a camera whose caller did.
"""
api_adopt!() = (@lock DCAM_API_LOCK (DCAM_API_USERS[] += 1); nothing)

"""
    api_release!() -> err

Give back a count taken by `api_acquire!` or `api_adopt!`. The last one uninitializes the API and returns the
`DCAMERR` of `dcamapi_uninit`; every other call returns `DCAMERR_SUCCESS`.
"""
function api_release!()
    @lock DCAM_API_LOCK begin
        DCAM_API_USERS[] > 0 || return DCAMERR_SUCCESS
        DCAM_API_USERS[] -= 1
        DCAM_API_USERS[] == 0 && return dcamapi_uninit()
        return DCAMERR_SUCCESS
    end
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

        # The count taken above is this camera's own: `assemble_camera`, not the positional constructor, which adopts one.
        return assemble_camera(unique_id, camera_format, hdcam, exposure_time, frame_rate, roi, capture_mode, trigger_mode, sequence_length, last_error, is_running, camerastate, data, NaN, 0, true)
    catch
        hdcam == C_NULL || dcamdev_close(hdcam)
        api_release!()
        rethrow()
    end
end
