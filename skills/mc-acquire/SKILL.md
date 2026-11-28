---
name: mc-acquire
description: Acquisition patterns for MicroscopeControl.jl cameras and stages -- capture/sequence/live and what getdata/getlastframe return, the live-view stop order that avoids a hard crash, ordered sequences, z-stacks, and the (H, W, N) array convention; activates for "capture", "acquire", "live view", "z-stack", "sequence", or "frame".
---

# mc-acquire

Shapes and return values below were executed against `SimCamera` and `SimStage3d`
by the package's own suite (`test/skill_examples.jl` runs the examples marked
`<!-- mc-test: ... -->`); the other drivers are traced from their source or tested
against fakes in `test/`, as each statement says, and none is run on hardware
here. Labels as in `mc-system-design`: a guarantee names the version it was checked at, or the suite group
that checks it; a limitation is a shortfall as of the version it names; a policy is a recommendation. This skill
owns the camera return-value rules; the other skills point here rather than restating them.

## Stopping live view: stop and join every reader before `abort`

`live(cam)` starts a continuous acquisition and sets `cam.is_running = 1`. Whatever
is displaying frames, the package GUI or your own loop, calls `getlastframe(cam)`
(an `(H, W)` frame, or `nothing`) in a loop until something tells it to stop. The
package GUI's loop runs while `cam.is_running == 1` and its own stop flag is clear;
your own loop should stop on a flag of its own (below), never on the driver's
`is_running`.

**[limitation, fixed in 0.2.7 for DCAM4]** On a DCAM4 driver older than 0.2.7, `abort(cam)` calls `dcamcap_stop`,
then `dcambuf_release`, and only **then** clears `is_running` (traced from `dcam4_camera/interface_methods.jl`),
so a reader that is inside `getlastframe` when you call `abort` is waiting on, or copying from, an acquisition
that is being torn down; `getlastframe` blocks in `dcamwait_event` for a bounded time per call, so a fixed sleep
cannot guarantee the reader has left. Whether the vendor DLL survives a copy against released buffers in every
case is **not** established by the source. Treat a hard crash of the Julia process as a possible outcome, not a
certainty, and do not rely on either.

**[guarantee, 0.2.7-DEV]** (since 0.2.7) The DCAM4 driver registers every frame wait (`getlastframe`, `capture`) with the
camera, and `abort`, every start (`live`, `sequence`, `capture`) and `shutdown` first abort the waits in progress and
wait for them to end before they stop the capture, release the buffer or close the device; a `getlastframe` whose
capture was stopped meanwhile returns `nothing` and reads no frame, and after `shutdown` it returns `nothing` without
a DCAM call. Each wait is bounded by `2 * (exposure_time + readout) + 1` seconds (`capture_timeout_ms`), the readout
read from the camera, or 1 s (`READOUT_FALLBACK_S`) when the camera does not report it. This is tested against a fake SDK (`test/dcam4_fake_paths.jl`), not on a camera. It holds for
DCAM4 only, so the policy below stays the requirement for every driver.

**[policy]** The requirement, on every driver:

1. Set your reader's own stop flag (a `Threads.Atomic{Bool}`), so every reader loop
   exits at its next check. Never clear `cam.is_running` yourself: it is the
   driver's, and what it means after a stop differs per driver (the table in
   "Finite ordered sequence").
2. **Join** every reader task you own (`wait(task)`), so no SDK call is in flight.
3. Only then stop the camera, with `stop_camera!` (`abort`, prepared per driver),
   and ask `camera_ok` whether it is known to be stopped; if not, take it out of
   service. Both are defined, per driver, in "Finite ordered sequence". Do 1 to 3
   in a `finally`, so they run whatever your program or the reader did.
4. Never let two tasks call into the same camera SDK concurrently. One task owns
   the camera; everything else asks it.
   **[limitation, 0.2.7-DEV]** the drivers spawn tasks of their own that your code
   does not hold: DCAM4's poller, which `sequence` discards, and Sim's and DCx's,
   which `sequence` returns only by accident (the table in "Finite ordered
   sequence"). So "one task" is a rule for *your* code, not a property you can
   establish of the process; `mc-system-design`, Decision 3, gives the evidence,
   the resulting single-owner restriction, and the upstream fix.

<!-- mc-test: acquire-reader -->
```julia
function stop_reader!(cam, reader, stop)         # stop, join, stop the camera and check it, whatever the reader did
    stop[] = true                                # the reader's flag, not cam.is_running
    reader_error = try
        wait(reader)                             # join: no SDK call in flight after this
        nothing
    catch e
        e                                        # the reader's own failure (a TaskFailedException), kept
    end
    try
        stop_camera!(cam)                        # abort, prepared per driver ("Finite ordered sequence")
    catch
        reader_error === nothing || @error "the reader had failed before the stop did" exception = reader_error
        rethrow()
    end
    camera_ok(cam) || @error "the camera is not known to be stopped; take it out of service" camera = nameof(typeof(cam))
    reader_error === nothing || throw(reader_error)
    return nothing
end

live(cam)                                        # cam.is_running == 1 from here
stop = Threads.Atomic{Bool}(false)               # the reader's own stop flag
reader = @async while !stop[]                    # the ONLY task that touches cam
    frame = getlastframe(cam)
    frame === nothing || (latest[] = frame)      # getlastframe returns nothing on timeout
    sleep(1 / fps)
end
try
    sleep(0.2)                                   # ... the rest of your program runs, until it is time to stop
finally
    stop_reader!(cam, reader, stop)              # runs whatever happened above, or in the reader
end
```

**[guarantee, suite: acquire-reader]** This runs clean against `SimCamera` (which cannot exhibit the hazard, since
it does not call an SDK): the reader reads frames until its flag is set, the join returns, and the stop leaves
`camera_ok` true. A reader that throws is still joined, the camera is still stopped, and the reader's error is the
one `stop_reader!` throws. **[guarantee, 0.2.7-DEV]** (since 0.2.7) The package GUI (`gui(cam)` / `start_live`) runs its
blocking `getlastframe` reader as a `Threads.@spawn` task, which may run on another thread (no thread is reserved for
it, and with one Julia thread it shares the display's), and hands frames through a one-slot channel to an `@async`
task that alone updates the display. The reader runs while `cam.is_running == 1` and its stop flag is clear; closing
the window sets that flag and calls `abort` without waiting for the reader. `start_live(cam)` returns the display
task, which ends only after the reader has left its loop and closed the channel, so `wait` on it joins both. The
flag is internal, so from code the reader stops only when the window closes or `is_running` goes false, which an
`abort` that works does: on DCAM4 since 0.2.7 that abort is safe during the reader's wait, on another driver it is
the hazard above. `gui(cam)`'s Start Live button discards the task (traced from `camera_interface/gui.jl`). On
hardware, prefer your own reader task over the GUI's for anything you need to stop programmatically.

Two consequences on `DCAM4Camera` (traced):

- `live` itself calls `abort` first. Calling `live` while a reader is running is the
  same hazard on a driver older than 0.2.7; from 0.2.7 the start drains the waits first. Stop and join first
  either way.
- **[guarantee, since 0.2.6; checked 0.2.7-DEV]** `getdata` in `LIVE` mode returns the newest frame at once
  and leaves the live view running: no stop, no buffer release, `is_running`
  unchanged. It returns `nothing` when no frame can be read (with `last_error` set),
  and, since 0.2.7, `nothing` with one warning when a newer capture has replaced the live view.
  Before 0.2.6 it waited for a cycle end, stopped the capture and released the
  buffer, ending the live view; an instrument pinned to an older tag must not call
  it during live view. Grab frames during live view with `getlastframe` either way.

## The three modes

| Call | Sets `capture_mode` | SimCamera (executed) |
|---|---|---|
| `capture(cam)` | `SINGLE_FRAME` | returns the enum `SINGLE_FRAME`; the frame comes from `getdata(cam)`, `(H, W)` `Matrix{UInt16}` |
| `sequence(cam)` | `SEQUENCE`, `is_running = 1`, cleared by an `@async` timer after `sequence_length` exposures | `getdata(cam)` returns `(H, W, N)` `Array{UInt16,3}`, `N = cam.sequence_length` |
| `live(cam)` | `LIVE`, `is_running = 1` | `getlastframe(cam)` `(H, W)` per call; stop as above |

**[guarantee, 0.2.7-DEV]** `getlastframe(cam)` returns an `(H, W)` frame or `nothing` when no frame arrives (on the CSC
camera since 0.2.7); check before indexing.
With `roi = CameraROI(1, 1, 64, 32)`
(width 64, height 32) the Sim camera returns `(32, 64)` and `(32, 64, N)`.

### The capture contract differs per driver

**[limitation, 0.2.7-DEV]** Where the frame comes from after `capture` is **not** part of the interface. Traced
from each driver's `interface_methods.jl`; only the Sim row was executed.

| Driver | `capture(cam)` returns | `getdata(cam)` after `capture` |
|---|---|---|
| `SimCamera` | the enum, not a frame | the frame. This is the only driver where this is the right call. |
| `DCAM4Camera` | the frame `(H, W)`, after allocating one buffer, snapping, reading, and **releasing** the buffer. It throws if a live view or sequence is running (`is_running`) or after `shutdown`. | does not wait: in `SINGLE_FRAME` mode it reads the newest frame at once from a buffer that `capture` already released, so expect `nothing` with `last_error` set; whether the vendor library tolerates the read is not established by the source. Do not call it. |
| `ThorcamDCXCamera` | the frame, then frees the image memory | in any mode reads `sequence_length` frames from `pImage_Mem` and calls `abort`; only valid after `sequence`. |
| `ThorCamCSCCamera` | the frame (arm, software trigger); throws on a timeout or failed read | polls for another pending frame, not the captured frame. **[guarantee, 0.2.7-DEV]** (since 0.2.7) a missing frame throws, including at any index of a sequence; no placeholder enters a stack. |

So on every hardware driver in the package, the frame is the **return value of
`capture`**, and `getdata` is for sequences. **[policy]** Put the difference in one place in your
system rather than at every call site:

<!-- mc-test: acquire-snap -->
```julia
snap(cam::SimCamera) = (capture(cam); getdata(cam))     # executed
snap(cam::Camera)    = capture(cam)                     # DCAM4, DCX, CSC: frame is the return value (traced)
```

Check the result before indexing, and check it **per driver**, because the failure
value differs:

| Driver | `capture` on SDK failure |
|---|---|
| `DCAM4Camera` | **[guarantee, 0.2.7-DEV]** a frame-wait timeout or failure logs, sets `last_error` and throws (after stopping the capture and releasing the buffer); failed exposure/ROI read-backs throw and set `last_error` (since 0.2.7); an ROI the SDK did not accept as requested throws (since v0.2.3). A failed buffer allocation, a failed start and a failed frame copy log and return `nothing`, with `last_error` set. |
| `ThorcamDCXCamera` | logs `@error`, returns `nothing` |
| `ThorCamCSCCamera` | **[guarantee, 0.2.7-DEV]** (since 0.2.7) throws on a failed read or poll timeout. `getlastframe` instead returns `nothing`, setting `last_error` (`-1` for SDK success with a null buffer, the timeout sentinel; the SDK code for a failed read). A genuine all-zero image remains valid data. |
| `SimCamera` | cannot fail |

**[policy]** Treat `nothing` as a missing frame and stop a failed acquisition before saving its stack.

## Exposure and ROI are fields, with driver-specific types and units

The interface declares three setters, `setexposuretime!(cam)`, `setroi!(cam)` and
`settriggermode!(cam)`, each a **push-down** of a field the caller has already
assigned (`camera_interface/interface_functions.jl`; they take no value argument),
with throwing fallbacks; coverage varies by driver (table below), and `SimCamera`
implements none. The configuration itself lives in the fields: `cam.exposure_time`
and `cam.roi::CameraROI` are mutable fields you assign, and the shared panel reads
and writes those fields, not the setters. The interface does not fix the
type or unit of `exposure_time`, nor the ROI origin convention. Per driver (from
`types.jl` and the setter code; only the Sim row executed):

| Driver | `exposure_time` field | Unit at the SDK | Pushing the field to hardware | ROI offsets |
|---|---|---|---|---|
| `SimCamera` | `Float64`, default `0.1` | seconds (used as a `sleep` in `getlastframe`) | not needed; read on every call. `setexposuretime!`/`setroi!`/`settriggermode!` **throw** | `x_start`/`y_start` ignored; only `width`/`height` matter |
| `DCAM4Camera` | `Float64`, read from `DCAM_IDPROP_EXPOSURETIME` at construction | seconds (DCAM property) | `setexposuretime!(cam)`, `setroi!(cam)`, `settriggermode!(cam)` implemented, and called by `capture`/`live`/`sequence` themselves, so assigning the field before the acquisition call suffices | `x_start`/`y_start` forwarded unchanged to `DCAM_IDPROP_SUBARRAYHPOS`/`VPOS`: the SDK's origin is 0-based (the driver's default `roi` starts at `(0, 0)` and its export says `roi_origin = 0`). **[guarantee, 0.2.7-DEV]** (since v0.2.3) when the SDK accepts a different position or size (the ORCA takes multiples of 4), the driver writes the accepted values into `cam.roi` and throws, so the acquisition call that set the ROI throws before it starts; (since 0.2.7) failed exposure/ROI read-backs throw and preserve the requested settings |
| `ThorcamDCXCamera` | `Float64`, default `0.01` | seconds in the field, multiplied by `1e3` to milliseconds at the SDK | `setexposuretime!`, `setroi!` implemented; `capture` calls both | `x_start` forwarded unchanged to `s32X`; SDK convention applies |
| `ThorCamCSCCamera` | `Clonglong`, default `40` | microseconds, forwarded unconverted; by default the poll timeout is rounded up to two exposures plus one second in milliseconds. **[guarantee, 0.2.7-DEV]** (since 0.2.7) an explicit constructor timeout or accepted `setpolltimeout!` is kept across acquisition/exposure changes; a refused timeout write preserves the cache | `setexposuretime!(cam, ::Int)` only; `capture` calls the internal setter | not forwarded by the driver |

Consequences: `cam.exposure_time = 0.02` is correct for Sim, DCAM4 and DCX and is an
`InexactError` on `ThorCamCSCCamera`, whose field is an integer. Do not write
"seconds" into shared code without checking `typeof(cam.exposure_time)` or the
driver row above.

<!-- mc-test: acquire-exposure -->
```julia
cam.exposure_time = 0.02                  # Sim / DCAM4 / DCX
cam.roi = CameraROI(1, 1, 512, 256)       # x_start, y_start, width, height
```

`CameraROI(x_start, y_start, width, height)`. **[guarantee, 0.2.7-DEV]** The returned frame is `(H, W)`
column-major on every driver (Sim executed; DCAM4, DCX, CSC traced), but **[limitation, 0.2.7-DEV]** **whether `H, W` equal `roi.height, roi.width`
is per driver**:

| Driver | Frame size returned |
|---|---|
| `SimCamera` | `(roi.height, roi.width)` (executed) |
| `DCAM4Camera` | the SDK's current sub-array, `(height, width)` from `dcamprop_getsize`. Since v0.2.3 that is the ROI you asked for: an ROI the SDK does not accept as requested throws in the acquisition call, leaving the accepted values in `cam.roi` (traced) |
| `ThorcamDCXCamera` | `(roi.height, roi.width)`; `capture` allocates image memory of exactly that size |
| `ThorCamCSCCamera` | `(roi.height, roi.width)` (tested through a replaced `getlastframeornothing`). **[limitation, 0.2.7-DEV]** The driver never forwards `roi` to the SDK, which always delivers the full sensor (`camera_format`, default 1440 x 1080): the driver converts the full frame and crops it to `roi` in software (`x_start`, `y_start` 1-based), so a small `roi` is no faster, and an `roi` outside the sensor throws an `ArgumentError` before anything is copied. `camera_format` must state the sensor the camera delivers: the driver does not ask the SDK, so a larger value reads past the SDK's buffer. |

Preallocate from the first returned frame (`similar(frame, size(frame)..., N)`)
rather than from `roi` where the driver is not known to honor it. Whether `x_start = 1` means the
first column or the second depends on the SDK the driver forwards it to; the
interface does not define a 1-based origin. Keep the `(H, W[, N])` storage convention (below) separate
from SDK coordinate conventions: the first is enforced by the drivers at the DLL
boundary, the second is not.

## Finite ordered sequence

There is no portable way to read a finished sequence: the drivers disagree on what `sequence` returns, what
`getdata` waits for, and what `abort` does and reports (the table below, the one statement of these facts in the
skills; the other skills point here). Do not wait on `is_running`: the CSC camera never clears it, DCx's poller
leaves it set until `getdata` aborts, and DCAM4's poller clears it at its deadline whether or not its stop worked.

**[policy]** Read through one function per driver, chosen by dispatch as `snap` is: `read_sequence(cam, n)`
returns the stack or throws; `stop_camera!(cam)` stops it after a failure; `camera_ok(cam)` answers whether, after
the last acquisition or stop, the camera is known to be stopped with its buffers released. A camera without a
method gets the fallback, which refuses to read and never says the camera stopped. `mc-system-design`'s `Bench`
uses these functions; write the methods for a camera you add.

<!-- mc-test: camera -->
```julia
using MicroscopeControl
const DCAM4 = MicroscopeControl.HardwareImplementations.DCAM4

# The fallback: an unknown camera is not read, and never known to be stopped.
read_sequence(cam::Camera, n::Int) = error("no sequence reader for $(nameof(typeof(cam))); write one (see mc-acquire)")
stop_camera!(cam::Camera) = abort(cam)
camera_ok(::Camera) = false

function read_sequence(cam::SimCamera, n::Int)
    cam.sequence_length = n
    wait(sequence(cam))                          # its timer Task: the sequence's own duration
    return getdata(cam)                          # (H, W, n), fresh random frames; an ArgumentError for n < 0
end
camera_ok(cam::SimCamera) = cam.is_running == false

function read_sequence(cam::DCAM4Camera, n::Int) # traced: it needs the camera
    cam.last_error = DCAM4.DCAMERR_SUCCESS        # camera_ok judges what happens from here
    cam.sequence_length = n
    sequence(cam)                                # returns nothing; its poller is discarded
    cam.last_error == DCAM4.DCAMERR_SUCCESS || error("DCAM4Camera: sequence reported $(cam.last_error)")
    stack = getdata(cam)                         # polls until the sequence ends, reads, then stops and releases
    stack === nothing && error("DCAM4Camera: no stack (last_error = $(cam.last_error))")
    return stack                                 # a release that failed after the read is still in last_error
end
stop_camera!(cam::DCAM4Camera) = (cam.last_error = DCAM4.DCAMERR_SUCCESS; abort(cam))   # judge this abort alone
camera_ok(cam::DCAM4Camera) = cam.last_error == DCAM4.DCAMERR_SUCCESS && !cam.is_running

const DCX_POLLER = IdDict{ThorcamDCXCamera,Task}()   # each camera's last sequence poller, which has no deadline of its own

function read_sequence(cam::ThorcamDCXCamera, n::Int)   # traced: it needs the camera
    before = cam.pImage_Mem
    cam.sequence_length = n
    t = sequence(cam)                            # its polling Task; nothing, after an @error, when allocation or the start failed
    if !(t isa Task)
        cam.pImage_Mem === before || abort(cam)  # the start failed: free its new buffers. A failed allocation kept the old
        error("ThorcamDCXCamera: the sequence did not start (see the @error before this)")   # list, already freed
    end
    DCX_POLLER[cam] = t
    deadline_s = 2 * n * max(cam.exposure_time, 1 / cam.frame_rate) + 1
    timedwait(() -> istaskdone(t), deadline_s) === :ok ||
        error("ThorcamDCXCamera: the sequence did not end within $(deadline_s) s; its poller is still running")
    wait(t)                                      # rethrows a poller that failed
    return getdata(cam)                          # copies the n buffers, ignoring each copy's status, then abort(cam)
end
stop_camera!(cam::ThorcamDCXCamera) = cam.is_running ? abort(cam) : nothing   # abort only a running camera: no buffer freed twice
camera_ok(cam::ThorcamDCXCamera) =               # abort ran or nothing started, and no poller is left; every SDK status is ignored
    cam.is_running == false && (t = get(DCX_POLLER, cam, nothing); t === nothing || istaskdone(t))
```

**[guarantee, suite: camera]** for `SimCamera` and the fallback: `read_sequence(SimCamera(...), 5)` takes five
exposures and returns `(32, 64, 5)` with `camera_ok` true, a second read returns new frames, a negative length
throws, and a camera type with no method is refused with the message above. **[guarantee, 0.2.7-DEV]** the
`DCAM4Camera` and `ThorcamDCXCamera` methods are traced from their drivers' source and not run here. Per driver:

| Driver | `sequence(cam)` returns | `getdata(cam)` in `SEQUENCE` mode | `abort(cam)` | The methods above | Source |
|---|---|---|---|---|---|
| `SimCamera` | its timer `Task`, which sleeps `sequence_length` exposures, rereading `exposure_time` for each, then clears `is_running` | fresh random frames at any time; it keeps nothing, so joining the task is what makes a read take the sequence's time | clears `is_running` | join the task, then read; `camera_ok`: `is_running` clear | suite: camera (the reread: one change while it runs, suite: bench) |
| `ThorcamDCXCamera` | its polling `Task` when the capture starts: it stops live video once `sequence_length` frames are counted, has no deadline (after a stop that came first, nothing ends it), and leaves `is_running` set; `nothing`, after an `@error`, when allocation or the start fails | copies the buffers at once, ignoring each copy's status, then calls `abort` | stops live video and frees each buffer in `pImage_Mem`, ignoring every status, and clears `is_running`; on a camera that never acquired it throws an `UndefRefError` (the list starts with an unset element) | require the `Task` (else free any new buffers and throw), wait on it with a deadline, then read; `stop_camera!` aborts only while `is_running` is set; `camera_ok`: `is_running` clear and the poller ended, which says only that `abort` ran or nothing started | traced |
| `DCAM4Camera` | `nothing`, with `last_error` set when the allocation or start failed; its poller is discarded. The poller stops a capture still running at its deadline, ignoring that stop's result, and clears `is_running` while its sequence is current, whether or not the stop worked | polls the capture status until the sequence ends (below), reads the `N` frames, then stops and releases; `nothing` on a timeout, a failed frame-count query or lost frames | `stop_and_release!`: a stop or release that fails records `last_error` and leaves `is_running` as it was; on a stopped camera it does nothing and clears `is_running` | clear `last_error` before the sequence and before a stop, and turn an error from `sequence` or a `nothing` from `getdata` into a throw; `camera_ok`: `last_error` still success and `is_running` clear | traced; `getdata` and the stop tested against the fake SDK |
| `ThorCamCSCCamera` | `nothing`, and no task: it sets frames per trigger to 0 (unlimited), arms, triggers and sets `is_running`; nothing disarms it | reads `N` pending frames one at a time, each waiting up to the poll timeout, and throws on a missing one (since 0.2.7); the camera stays armed and streaming, and `is_running` stays set | is `shutdown`: closes the camera and the SDK and returns their two status codes, throwing on neither; `is_running` stays set | none: the fallback (below) | traced |

**[limitation, 0.2.7-DEV]** There is no `read_sequence` or `camera_ok` method for `ThorCamCSCCamera`, so the fallback
refuses it. Its sequence never disarms, so a later `sequence` re-arms a streaming camera and its `getdata` can return
frames queued before the request; its `abort` is its `shutdown`, so stopping it closes it; and its close reports a
failure only through the status codes it returns. A system that uses it needs its own reader, and a rebuild after
every stop. **[limitation, 0.2.7-DEV]** on `ThorcamDCXCamera`, a direct `getdata` after a sequence that failed to start copies
buffers no frame was written to, or, when the allocation failed, the previous sequence's buffers, which its `abort`
already freed (`pImage_Mem` keeps them after they are freed, so a second `abort` frees them again); a failed
allocation also leaks the buffers allocated before it, which nothing reports. The methods above never read or free
those, but `camera_ok` cannot see the leak.

Why order matters on the Hamamatsu path (traced): `DCAM4Camera.getdata` in
`SEQUENCE` mode allocates `zeros(UInt16, H, W, sequence_length)` and copies frame
`i` from the SDK ring buffer into `data[:, :, i]` with `dcambuf_getframe(handle,
i - 1)`, then releases the buffer. The frame index is the position in the ring,
so the in-order copy is what makes `stack[:, :, i]` the i-th exposure. If you
write your own readout, copy by frame index in order and release only after the
last copy; the buffer is a ring of `sequence_length` slots, and there is no
per-frame timestamp in the returned array. **[guarantee, 0.2.7-DEV]** (traced and tested against the fake SDK)
`getdata` polls the capture status every 10 ms against a deadline of `2 * N * (exposure_time + readout) + 1` seconds
(`N = sequence_length`; the readout falls back to 1 s when the camera does not report it). A failed status read is
logged once and retried until the deadline, so a transient one can still end in a full stack. It sets
`cam.last_error` and returns `nothing` at the deadline (with the last status read failed or the capture still
running), when the frame-count query fails (since 0.2.7), or when fewer than `N` frames were transferred
(`last_error = DCAMERR_LOSTFRAME`, since 0.2.6), so check the result before indexing.

## Z-stack over stage and camera

**[guarantee, suite: acquire-zstack]** Run against `SimStage3d` + `SimCamera` (`roi = CameraROI(1, 1, 64, 32)`),
where every plane differs, and against a recording camera whose `capture` notes the stage's z at the moment it is
called, which shows one capture per plane, each after its move and read-back. Do not capture once and call `getdata`
repeatedly, which on hardware reads a released acquisition (see the capture contract above).

<!-- mc-test: acquire-zstack -->
```julia
using MicroscopeControl
snap(cam::SimCamera) = (capture(cam); getdata(cam))    # see "capture contract" for hardware
snap(cam::Camera)    = capture(cam)                    # DCAM4, DCX, CSC: the frame is the return value

function zstack(cam, stage, zs)                         # one new frame per plane, each after its move
    stack = nothing
    for (i, z) in enumerate(zs)
        move(stage, stage.targ_x, stage.targ_y, z)     # Float64 only; 3-arg for a 3-D stage
        getposition(stage)                             # Sim: copies targ_* into real_*; hardware: reads back
        # hardware: wait or poll here until real_z is within tolerance of targ_z
        frame = snap(cam)
        stack === nothing && (stack = similar(frame, size(frame)..., length(zs)))   # sized from the first frame
        stack[:, :, i] = frame                         # (H, W) into slice i
    end
    return stack
end

cam   = SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32))
stage = SimStage3d()
initialize(stage)
zs = 0.0:2.0:8.0                                       # in the STAGE'S units, see table below
stack = zstack(cam, stage, zs)
size(stack)          # -> (32, 64, 5)
stage.real_z         # -> 8.0
```

### Stage units and signatures are per driver

**[limitation, 0.2.7-DEV]** `move` passes the numbers you give it straight to the SDK. The `units` field on the
hardware stages is a **label**, not a conversion, and the drivers disagree. A z-stack
written in micrometers against a `PIStage` moves in millimeters, a factor of 1000.
From each driver's `types.jl` and `move` method; only `SimStage3d` was executed:

| Stage | `move` signature | Unit passed to the SDK | Position fields | Range |
|---|---|---|---|---|
| `SimStage3d` / `2d` / `1d` | `(stage, x, y, z)` / `(x, y)` / `(x)` | none; there is no `units` field | `real_x/y/z`, `targ_x/y/z` | `getrange` returns one `(min, max)` tuple per axis, default `(0, 100)` |
| `PIStage` (C-867) | `(stage, x, y)`, 2-D only | **millimeters** (`units = "Milimeters"`; values go to `PI_MOV` unchanged) | `real_x`, `real_y`, `targ_x`, `targ_y` | `getrange` implemented; `range_x`, `range_y` |
| `MCLStage` (Mad City Labs) | `(stage, x, y, z)` | **micrometers** (`units = "Microns"`) | `real_x/y/z`, `targ_x/y/z` | `getrange`; default `(0, 300)` per axis |
| `N472` (PI N-472) | `(stage, pos::Vector{Float64})`, not x/y/z | **millimeters** (`units = "mm"`) | `stage.pos::Vector`, not `real_*` | no `getrange`; `minpos`/`maxpos` vectors |
| `MCS2Stage` (SmarAct) | `(stage, x, y[, z])` | **micrometers**, converted to picometers for the SDK | `real_x/y/z`, `targ_x/y/z` | `range_x/y/z` set by `initialize` from the controller |

**[guarantee, 0.2.7-DEV]** (since 0.2.7) Stage `export_state` refreshes the connected stage's position through the driver's read,
without motion. `position_fresh` is true only when every exported axis was read (always true on Sim stages). A disconnected stage or
failed read warns once and exports the last-read position with `position_fresh=false`; acquisition saves continue.
MCL negative read/calibration codes throw before replacing cached positions/ranges.

`move(stage, 1, 2, 3)` with integers is a `MethodError` on every stage. Only
`PIStage`, `MCLStage` and `N472` carry a `units` field; `SimStage*` and `MCS2Stage`
do not, and `stage.units` on them throws. Guard the check, and hard-code the
SmarAct unit from the table (micrometers), which is fixed by its bridge code:

<!-- mc-test: acquire-units -->
```julia
expected = Dict(PIStage => "Milimeters", MCLStage => "Microns", N472 => "mm")   # spelled as the drivers spell them
if hasfield(typeof(stage), :units)
    stage.units == expected[typeof(stage)] || error("stage units are $(stage.units); code assumes $(expected[typeof(stage)])")
end
```

**[guarantee, suite: acquire-units]** Run against the constructed (unconnected) stage objects, the fence on a
`PIStage()`: `PIStage().units == "Milimeters"`, `MCLStage().units == "Microns"`, `N472().units == "mm"`,
`hasfield(MCS2Stage, :units) == false`, `hasfield(SimStage3d, :units) == false`, and `stage.units` on the last two
throws (a `FieldError` on Julia 1.12 and later, an `ErrorException` on 1.11). Do the check before the first move on a
new instrument. Settling time is the driver's business; the Sim stage moves
instantly, so on hardware poll `getposition` until the position field is within
tolerance before exposing.

## DAQ voltage lights and teardown

**[guarantee, 0.2.7-DEV]** (since 0.2.7) `CrystaLaser`, `VortranLaser` and `DaqTrLight` take
volts in `setpower`, keep the request in `level_requested` and export it in V; the two single-line lights stage a
level set while off for the next `light_on`. What each command writes and records, and what a failed one leaves in
`is_on`, is in `mc-system-design`'s `references/driver-caveats.md`, "DAQ voltage-light state", and only there.

**[policy]** acquisition teardown calls `lights_off(lights)` in `finally`.
**[guarantee, 0.2.7-DEV]** (since 0.2.7) it tries every light, interruptions included, then throws
`MicroscopeControl.LightsOffError` containing all `light name => exception`
pairs in `failures`, printed one per line. `lights_off(l1, l2, ...)` also works.
A light in `failures` may still be emitting. **[limitation, 0.2.7-DEV]** closing a panel does not switch off the
light.

## Modulated light sources during an acquisition

**[guarantee, 0.2.7-DEV]** (since 0.2.7) A light built with `modulator = ...` (`TCubeLaser`, `SimDiodeLaser`, `SimLight`)
puts its level on an analog input through `setpower(modulator, p)`, `p` in the light's own unit. The calls that cost
time and the calls that do not (traced from `tcube_laser/modulation.jl` and `lightsource_interface/modulation.jl`):

- `light_on` is slow on a `TCubeLaser` with a modulator: it writes 0 V, enables, waits `MOD_SETTLE_S` (1.3 s), puts the
  request on the input and confirms the controller's setpoint register shows it. If the confirm fails, `light_on`
  tries to disable the output and to write 0 V, then throws; either attempt can fail, and the driver then logs that
  the output may still be on. So a throw from `light_on` does not mean the light is off: treat the output as
  unknown, and call `light_off`, then `shutdown`, until one returns without throwing (traced).
  Switch the light on before the acquisition, not between frames. **[limitation, 0.2.7-DEV]** 1.3 s (`MOD_SETTLE_S`) and a read-back
  more per `light_on` than without a modulator.
- A level change while the light is on (`setcurrent!`, `setoutputpower!`, `setlevel!`) is one analog write: no USB
  call, no lock check. **[limitation, 0.2.7-DEV]** Nothing watches the level between `light_on`s; poll `loop_status`.
- While the light is off a level change writes nothing; the output holds 0 V, and `light_on` applies the recorded level.
- `light_off` on a `TCubeLaser` disables the output first, at once, then writes 0 V (a failed 0 V write is logged). A
  failed disable throws, after the 0 V write, and stays pending (`disable_pending`): the output may still be on, and
  `properties.is_on` stays `true`. `SimDiodeLaser` and `SimLight` write 0 V first and then switch off.
- An `ArgumentError` from a level change means the level is out of reach (or out of range) and nothing changed. Any
  other error means the driver tried to switch the light off and then rethrew the level error: a `TCubeLaser`
  disables first, then writes 0 V; if the disable fails it logs that the output may still be on, keeps
  `disable_pending` and leaves `is_on` set. So a thrown level error does not mean the light is off.

**[policy]** A system that sets a level per frame sets it through the unit-true setter with the light on. After a
thrown non-`ArgumentError` it treats the output as unknown: it calls `light_off` again, and `shutdown` if that throws,
and goes on only once one of them returns without throwing. To check a driver or a faked light against the
convention, a test runs
`MicroscopeControl.modulation_violations(light; set! = l -> setpower(l, 2.0), expect = 2.0)` on an initialized light with
`modulator = RecordingModulator()`; an empty result means it keeps the convention (`mc-extend`).

## Array conventions

Restated from the upstream `CLAUDE.md` and `docs/src/conventions.md`; the lab rule is decision 0040
(`conventions/image-layout.md` in the admiral repo). **[guarantee, 0.2.7-DEV]** for `SimCamera` (executed), and for `DCAM4Camera`,
`ThorcamDCXCamera` and `ThorCamCSCCamera` (the conversion `CameraInterface.rowmajor_to_yx`, executed through fakes
for all three); **[policy]** for any driver you write. These are storage
conventions enforced by the drivers at the DLL boundary; they say nothing about SDK
coordinate origins or exposure units (see above).

- **Storage:** an image is column-major `[y, x]`, `(H, W)`; stacks are `(H, W, N)`; `[1, 1]` is the top-left pixel.
  `data[row, col] == data[y, x]`. `save_h5` writes `(H, W, N)` directly, unpermuted, and tags
  the dataset `dimension_order = "y,x,frame"` (`"y,x"` for a frame) and
  `dimension_order_convention = "column-major (Julia/MATLAB); C-order tools list it reversed"`. Files from
  2026-01-29 until this change carry `"HW"` / `"HWN"`; a reader elsewhere keeps accepting both.
- **DLL boundary:** C SDKs hand back row-major buffers, with padded rows on some cameras. The driver converts once,
  with `CameraInterface.rowmajor_to_yx(buffer, W, H; stride)`, which returns `(H, W)` and drops the padding;
  `stride` is the row length in elements (`rowbytes` over the bytes per pixel). `reshape(buffer, (W, H))` alone is
  transposed, and with padding it does not even fit. If you read raw buffers in your own code, apply the same rule.
  These are the only transposes: nothing downstream permutes the frame.
- **Display:** Makie `image` and `heatmap` map dim 1 to x and dim 2 to y, so pass
  the transpose and flip y for a top-left origin:

  ```julia
  image(permutedims(frame); axis=(yreversed=true,))
  heatmap(permutedims(frame); axis=(yreversed=true,))
  ```

- **SLM is the exception:** `MLSLM` holds `phase::Array{Float64,2}` allocated as
  `zeros(width, height)`, so for SLM patterns dim 1 is x. Do not feed a camera
  `(H, W)` frame to the SLM without `permutedims`.
