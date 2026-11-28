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
2. **Join** every reader task you own, so no SDK call is in flight, with `join_task`
   ("Finite ordered sequence"), which turns a reader that died of a Ctrl-C back into
   a plain `InterruptException`. Touch the camera only once `istaskdone(reader)`: a
   wait that ends with any exception while the reader still runs (perhaps inside an
   SDK call) must leave the camera alone and mark it unknown.
3. Only then stop the camera, with `stop_camera!` (`abort`, prepared per driver,
   through `with_camera`, which marks the camera unknown when the stop throws or
   leaves it not known stopped; a marked camera is out of service until it is
   rebuilt). Both are in "Finite ordered sequence". Do 1 to 3 in a `finally`, so
   they run whatever your program or the reader did; `stop_reader!` logs a failed
   stop itself. Rethrow an `InterruptException`, never log it. Start the camera
   only through `with_camera`, as `start_reader!` does, so a camera marked unknown
   is never restarted.
4. Never let two tasks call into the same camera SDK concurrently. One task owns
   the camera; everything else asks it.
   **[limitation, 0.2.7-DEV]** the drivers spawn tasks of their own that the
   interface does not promise to return: DCAM4's poller, which `sequence` discards,
   and Sim's and DCx's, which `sequence` returns only by accident (the table in
   "Finite ordered sequence"). So "one task" is a rule for *your* code, not a
   property you can establish of the process; `mc-system-design`, Decision 3, gives
   the evidence, the resulting single-owner restriction, and the upstream fix.

**[limitation, 0.2.7-DEV]** A Ctrl-C from the terminal lands in whichever task is running when it arrives. In the
caller's own task (the live-view body, or the task running `acquire!`) it unwinds that task directly. In the reader
(the usual place, since it wakes every frame) or the Sim timer, it reaches the caller only at the join, where
`join_task` rethrows it, so the body runs on until then; a body that must stop at once needs the reader to pass it on,
for example through a flag the body checks. On DCAM4 it can be lost in the driver: in the sequence poller nobody
joins, in the `catch` in the cleanup of `getdata` and `capture`, and, with the driver's SDK tracing enabled, in
`trace_line`, which turns anything thrown while it builds a trace record, an interrupt included, into a note (all
three in "Finite ordered sequence").

<!-- mc-test: acquire-reader -->
```julia
"""
    stop_reader!(cam, reader, stop) -> (; reader_error, stop_error, camera_ok)

Set the reader's flag, join it, then stop the camera. It returns both outcomes: `reader_error` is the reader's own
failure or `nothing`; `stop_error` is the ordinary error `stop_camera!` threw, or `nothing`; `camera_ok` is whether
the camera is still not marked afterwards, false whenever `stop_error` is set (`stop_camera!` has then marked it). A
stop that threw an ordinary error, or left the camera not known stopped, is logged here, before anything is thrown.
It throws in four cases:

1. the wait ends with any exception while the reader still runs: the camera is left untouched and marked unknown,
   and that exception is rethrown;
2. an interrupt, in the reader or in the wait, once the reader has ended: after the stop was attempted, whether or
   not it worked, as a plain `InterruptException`;
3. any other exception in the wait, once the reader has ended: after the stop was attempted, that exception;
4. an interrupt in the stop itself: the camera is marked unknown and the interrupt rethrown, not logged.
"""
function stop_reader!(cam, reader, stop)
    stop[] = true                                # the reader's flag, not cam.is_running
    reader_error, pending = nothing, nothing
    try
        join_task(reader)                        # a reader that died of a Ctrl-C comes out as a plain interrupt
    catch e
        istaskdone(reader) || (mark_unknown!(cam); rethrow())   # case 1: still running, leave the camera alone
        if e isa TaskFailedException && e.task === reader
            reader_error = e                     # the reader's own failure
        else
            pending = e                          # cases 2 and 3: rethrown after the stop
        end
    end
    stop_error = nothing
    try
        stop_camera!(cam)                        # abort, prepared per driver ("Finite ordered sequence")
    catch e
        stop_error = e
    end
    ok = !(cam in CAMERA_UNKNOWN)                # stop_camera!'s with_camera marks it on a throw or camera_ok false
    if stop_error isa InterruptException
        throw(stop_error)                        # case 4
    elseif !ok                                   # logged here, so no throw below can lose it
        @error "the camera is not known stopped; it is marked unknown" camera = nameof(typeof(cam)) exception = stop_error
    end
    pending === nothing || throw(pending)
    return (; reader_error, stop_error, camera_ok = ok)
end

# After a live start that threw or did not start: the camera is marked; stop what may have started. A stop is let
# through on the marked camera; an interrupt from it is rethrown, any other failure logged.
function stop_failed_start!(cam)
    try
        stop_camera!(cam)
    catch e
        e isa InterruptException && rethrow()
        @error "the stop after a failed live start threw; the camera stays marked unknown" exception = e
    end
end

function start_reader!(cam, latest, fps)        # the live view and its reader; the ONLY task that touches cam
    refuse_unknown(cam)                          # a camera marked unknown receives no call
    try
        with_camera(cam; ok = live_started) do   # marks a camera whose live start threw or did not start
            reset_error!(cam)                    # live_started judges what live does from here
            live(cam)                            # cam.is_running == 1 from here
        end
    catch
        stop_failed_start!(cam)                  # live threw: it may have half started
        rethrow()
    end
    if cam in CAMERA_UNKNOWN                     # live returned, but the live view is not known to be running
        stop_failed_start!(cam)
        error("$(nameof(typeof(cam))): the live view did not start; it was stopped, the camera is marked unknown, " *
              "and no reader was launched")
    end
    stop = Threads.Atomic{Bool}(false)           # the reader's own stop flag
    reader = @async while !stop[]
        frame = getlastframe(cam)
        frame === nothing || (latest[] = frame)  # getlastframe returns nothing on timeout
        sleep(1 / fps)
    end
    return reader, stop
end

reader, stop = start_reader!(cam, latest, fps)
outcome = Ref{Any}(nothing)
try
    sleep(0.2)                                   # ... the rest of your program runs, until it is time to stop
finally
    outcome[] = stop_reader!(cam, reader, stop)  # runs whatever happened above, or in the reader; logs a failed stop
end
outcome[].reader_error === nothing || throw(outcome[].reader_error)
```

**[guarantee, suite: acquire-reader]** This runs clean against `SimCamera` (which cannot exhibit the hazard, since it
does not call an SDK): the reader reads frames until its flag is set, the join returns, and the outcome is `camera_ok`
with no error. `start_reader!` refuses a camera marked unknown before any call reaches it (a camera that records its
calls). A live start that did not start marks the camera, stops it and launches no reader: on a recording camera, and
on `DCAM4Camera` over the fake DCAM SDK, both when `live` reports a failed allocation and when it reports an error
while the capture went ahead, which leaves the camera stopped. A reader that throws is still joined, the camera is
still stopped, and the outcome carries the reader's error. A stop that throws an ordinary error gives an outcome with
that error and `camera_ok == false`, is logged, and marks the camera; a stop that throws an interrupt marks the camera
and is rethrown, with nothing logged at warning level or above. An interrupt delivered into the reader itself, where a
Ctrl-C usually lands, reaches the caller as a plain `InterruptException`, after the camera was stopped, and a stop
that failed on that path is still logged. An interrupt, or any other exception, delivered to the task waiting on a
reader that is still running leaves the camera running, marks it unknown, and reaches the caller.

**[guarantee, 0.2.7-DEV]** (since 0.2.7) The package GUI (`gui(cam)` / `start_live`) runs its
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
function snap(cam::SimCamera)                   # executed; the other skills use this one
    with_camera(cam) do                          # with_camera: "Finite ordered sequence"; it refuses a marked camera
        capture(cam)
        getdata(cam)
    end
end
function snap(cam::Camera)                      # DCAM4, DCX, CSC: frame is the return value
    with_camera(cam) do                          # camera_ok afterwards: DCAM4's last_error still success; never on DCx,
        reset_error!(cam)                        # CSC, so a snap there marks the camera (not covered)
        capture(cam)
    end
end
```

**[guarantee, suite: acquire-snap]** `snap` returns an `(H, W)` frame from `SimCamera`, and from `DCAM4Camera` run
against the fake DCAM SDK (not a camera), whose frame there is non-square, so a transposed frame would fail. On a
camera marked unknown it is refused before any call reaches the camera: a camera that records its calls sees none, a
Sim camera is left uncaptured, and on DCAM4 no capture starts. A DCAM4 snap that the driver reports as failed (a
failed allocation: `capture` returns `nothing` with `last_error` set) marks the camera.

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

**[policy]** Every function in these skills that calls a camera (`live`, `sequence`, `capture`, `getdata`,
`getlastframe`, `abort`) makes those calls inside one wrapper, `with_camera(f, cam; ok)`, defined below. It refuses a
camera marked unknown before `f` runs; it marks the camera unknown when `f` throws (any exception, an interrupt
included) and rethrows; and after a normal return it marks the camera unknown when the postcondition `ok(cam)` is
false, returning `f`'s value either way, so the caller still gets the stack and the mark stops the next use. It runs
the postcondition inside the region that marks on a throw. The suite checks the rule on the code of every function in
these skills' marked examples, including default arguments and the eagerly evaluated arguments of `with_camera` itself
(suite: statements), with two exceptions, both named there: the `getlastframe` of the reader loop that `start_reader!`
launches, which `stop_reader!` joins before it stops the camera; and `refuse = false`, which lets a stop through on a
marked camera and is accepted only inside a `stop_camera!` method.

Through it, one function per driver, chosen by dispatch as `snap` is: `read_sequence(cam, n)` returns the stack or
throws; `stop_camera!(cam)` stops the camera after a failure or at the end of live view; and the postconditions,
`camera_ok(cam)` (after an acquisition or stop, is the camera known stopped with its buffers released, as far as its
driver reports?) and `live_started(cam)` (after `live`, is the live view known to be running?). A camera without a
method gets the fallback, which refuses to read and never says the camera stopped or started. One shared piece goes
with them: `join_task`, the one way the examples wait on a task. A camera is in service exactly while it is not
marked: every read, snap, start and stop marks it when its postcondition fails. Covered here: `SimCamera` (run by the
suite) and `DCAM4Camera` (run against the fake DCAM SDK in `test/`). Not covered: `ThorcamDCXCamera` and
`ThorCamCSCCamera` (below). `mc-system-design`'s `Bench` uses these functions; write the methods for a camera you add.

<!-- mc-test: camera -->
```julia
using MicroscopeControl
const DCAM4 = MicroscopeControl.HardwareImplementations.DCAM4

"""
    join_task(t)

Wait for `t`. A task that died of an `InterruptException`, where a Ctrl-C usually lands, rethrows the plain
interrupt; any other failure is the usual `TaskFailedException`.
"""
function join_task(t::Task)
    try
        wait(t)
    catch e
        e isa TaskFailedException && e.task.exception isa InterruptException && throw(e.task.exception)
        rethrow()
    end
end

# The one out-of-service mark: a camera that threw while in use, that failed its postcondition after a stop, a start or
# an acquisition, or whose reader was left running, is never started or read again (a stop is still let through).
# Rebuild it.
const CAMERA_UNKNOWN = Base.IdSet{Camera}()
mark_unknown!(cam::Camera) = (push!(CAMERA_UNKNOWN, cam); nothing)
refuse_unknown(cam::Camera) =
    cam in CAMERA_UNKNOWN ? error("camera unavailable: it is marked unknown (not known stopped after an " *
                                  "acquisition or a stop); shut down and reconstruct") : nothing

"""
    with_camera(f, cam; ok = camera_ok, refuse = true)

The one way these examples touch a camera. Refuse a camera marked unknown (unless `refuse = false`, for a stop), run
`f()`, mark the camera unknown when `f` or `ok(cam)` throws, an interrupt included, and rethrow; after a normal
return, mark it when `ok(cam)` is false. Returns `f()`'s value either way. Only `stop_camera!` passes `refuse =
false`; the suite fails any other use.
"""
function with_camera(f, cam::Camera; ok = camera_ok, refuse::Bool = true)
    refuse && refuse_unknown(cam)
    try
        result = f()
        ok(cam) || mark_unknown!(cam)            # the postcondition runs inside the region that marks on a throw
        return result
    catch
        mark_unknown!(cam)
        rethrow()
    end
end

"""
    camera_ok(cam) -> Bool

After the last acquisition or stop: is the camera known stopped, with its buffers released, as far as its driver
reports? `false` for a camera without a method.
"""
camera_ok(::Camera) = false

"""
    live_started(cam) -> Bool

After `live`: is the live view known to be running, as far as the driver reports? `false` for a camera without a
method, so `start_reader!` launches no reader on it.
"""
live_started(::Camera) = false

# Before a call whose outcome the postcondition judges: clear what the driver reports into. Nothing for most drivers.
reset_error!(::Camera) = nothing

"""
    read_sequence(cam, n) -> stack

A finished sequence of `n` frames, `(H, W, n)`, or a throw. The fallback refuses every camera without a method.
"""
read_sequence(cam::Camera, n::Integer) = error("no sequence reader for $(nameof(typeof(cam))); write one (see mc-acquire)")

"""
    stop_camera!(cam)

Stop the camera after a failure, or at the end of live view, through `with_camera`, which lets a stop through on a
camera marked unknown: a throw, or `camera_ok` false afterwards, marks the camera unknown.
"""
stop_camera!(cam::Camera) = with_camera(cam; refuse = false) do   # the fallback: never camera_ok, so it always marks
    abort(cam)
end

const SIM_TIMER = IdDict{SimCamera,Task}()       # each Sim camera's last sequence timer, kept through any teardown

function read_sequence(cam::SimCamera, n::Integer)
    with_camera(cam) do
        cam.sequence_length = n
        t = SIM_TIMER[cam] = sequence(cam)       # its timer Task: the sequence's own duration
        try
            join_task(t)                         # a Ctrl-C in the timer, or in this wait, comes out as a plain interrupt
        finally
            istaskdone(t) && delete!(SIM_TIMER, cam)   # joined, or died: nothing left for stop_camera! to wait for
        end
        getdata(cam)                             # (H, W, n), fresh random frames; an ArgumentError for n < 0
    end
end
function stop_camera!(cam::SimCamera)
    with_camera(cam; refuse = false) do
        abort(cam)                               # clears is_running; a timer still running keeps sleeping, and would
        t = get(SIM_TIMER, cam, nothing)         # clear a later sequence's flag: wait for it, bounded
        if t !== nothing
            timedwait(() -> istaskdone(t), cam.sequence_length * cam.exposure_time + 1) === :ok ||
                error("SimCamera: its sequence timer did not end")
            join_task(t)                         # a Ctrl-C that landed in the timer meanwhile is passed on
            delete!(SIM_TIMER, cam)
        end
    end
    return nothing
end
camera_ok(cam::SimCamera) = cam.is_running == false && !haskey(SIM_TIMER, cam)   # no timer left to join
live_started(cam::SimCamera) = cam.is_running == true

reset_error!(cam::DCAM4Camera) = (cam.last_error = DCAM4.DCAMERR_SUCCESS; nothing)
function read_sequence(cam::DCAM4Camera, n::Integer)
    with_camera(cam) do                          # camera_ok afterwards: a release that failed after the read marks
        reset_error!(cam)                        # the camera, and the stack still comes back
        cam.sequence_length = n
        sequence(cam)                            # returns nothing; its poller is discarded
        cam.last_error == DCAM4.DCAMERR_SUCCESS || error("DCAM4Camera: sequence reported $(cam.last_error)")
        stack = getdata(cam)                     # polls until the sequence ends, reads, then stops and releases
        stack === nothing && error("DCAM4Camera: no stack (last_error = $(cam.last_error))")
        stack
    end
end
function stop_camera!(cam::DCAM4Camera)
    with_camera(cam; refuse = false) do
        reset_error!(cam)                        # judge this abort alone
        abort(cam)
    end
    return nothing
end
camera_ok(cam::DCAM4Camera) = cam.last_error == DCAM4.DCAMERR_SUCCESS && !cam.is_running
live_started(cam::DCAM4Camera) = cam.last_error == DCAM4.DCAMERR_SUCCESS && cam.is_running
```

**[guarantee, suite: camera]** for `SimCamera`, the fallback, `join_task`, `with_camera` and the unknown mark:
`read_sequence(SimCamera(...), 5)` takes at least five exposures and returns `(32, 64, 5)` with `camera_ok` true; two
reads of one finished sequence differ, and so do two sequences; while the timer still runs, `getdata` returns at once
and two reads differ; `abort` clears `is_running` and leaves the timer running, and `camera_ok` is true only with
`is_running` clear and no timer entry left (a camera with `is_running` set and no timer entry is not `camera_ok`),
which `stop_camera!`'s wait (or the read's own join) removes; that wait is bounded (a timer that never ends makes
`stop_camera!` throw within its bound), and that throw marks the camera, so a `read_sequence` on the same camera is
refused and leaves it unstarted; a read that throws (a negative length, an `ArgumentError`) marks the camera; a camera
type with no method is refused with the message above and is never `camera_ok`; `join_task` turns a task that died of
an interrupt into a plain `InterruptException` and leaves any other failure a `TaskFailedException`; a camera marked
unknown is refused by every entry; a standalone stop that returns with `camera_ok` false marks the camera; a
postcondition that throws marks the camera too, so a read on it is refused; and `live_started` holds after `live` on a
Sim camera, not before. For `DCAM4Camera`, against the fake DCAM SDK (`test/dcam4_fake_sdk.jl`, not a camera): a clean
read returns the stack and leaves the camera in service; a read whose buffer release fails after the frames were read
returns the stack and marks the camera, and the next `read_sequence` on it is refused before the driver starts
anything; a stop on the marked camera still runs; a standalone stop on a fresh camera whose release the driver reports
failed marks it; and `live_started` holds after a clean `live`, and not after one whose allocation failed. Per driver:

| Driver | `sequence(cam)` returns | `getdata(cam)` in `SEQUENCE` mode | `abort(cam)` | The methods above | Source |
|---|---|---|---|---|---|
| `SimCamera` | its timer `Task`, which sleeps `sequence_length` exposures, reading `exposure_time` again for each (traced; one change while it runs, suite: bench), then clears `is_running` | fresh random frames at any time, the timer running or not; it keeps nothing, so joining the timer is what makes a read take the sequence's time | clears `is_running`; the timer keeps running | through `with_camera`: keep the timer and join it with `join_task`, then read; `stop_camera!` aborts and waits for the timer, bounded; `camera_ok`: `is_running` clear and no timer left to join; `live_started`: `is_running` set | suite: camera |
| `DCAM4Camera` | `nothing`, with `last_error` set when the allocation or start failed; its poller is discarded (and can swallow a Ctrl-C, below). The poller stops a capture still running at its deadline, ignoring that stop's result, and clears `is_running` while its sequence is current, whether or not the stop worked | polls the capture status until the sequence ends (below), reads the `N` frames, then stops and releases; `nothing` on a timeout, a failed frame-count query or lost frames. An exception thrown by that stop and release is logged and swallowed (below) | `stop_and_release!`: a stop or release that fails records `last_error` and leaves `is_running` as it was; on a stopped camera it does nothing and clears `is_running`; an exception inside it (an interrupt in its status read, say) propagates | through `with_camera`: clear `last_error` before the sequence, a stop or a `live`, and turn an error from `sequence` or a `nothing` from `getdata` into a throw; `camera_ok`: `last_error` still success, `is_running` clear; `live_started`: `last_error` still success, `is_running` set | the driver traced; the methods run against the fake DCAM SDK (suite: camera) |
| `ThorcamDCXCamera` | its polling `Task` when the capture starts: it stops live video once `sequence_length` frames are counted, has no deadline (after a stop that came first, nothing ends it), and leaves `is_running` set; `nothing`, after an `@error`, when allocation or the start fails (a failed allocation returns without freeing the buffers it allocated) | copies the buffers at once, ignoring each copy's status, then calls `abort` | stops live video and frees each buffer in `pImage_Mem`, ignoring every status, and clears `is_running`; on a camera that never acquired it throws an `UndefRefError` (the list starts with an unset element) | none: the fallback (not covered, below) | traced |
| `ThorCamCSCCamera` | `nothing`, and no task: it sets frames per trigger to 0 (unlimited), arms, triggers and sets `is_running`; nothing disarms it | reads `N` pending frames one at a time, each waiting up to the poll timeout, and throws on a missing one (since 0.2.7); the camera stays armed and streaming, and `is_running` stays set | is `shutdown`: closes the camera and the SDK and returns their two status codes, throwing on neither; `is_running` stays set | none: the fallback (not covered, below) | traced |

**[limitation, 0.2.7-DEV]** `ThorcamDCXCamera` and `ThorCamCSCCamera` are not covered: they have no methods here, so
the fallback refuses to read them and never says they stopped, because their drivers do not report what such a
method would have to check (traced).

- DCx: `abort` ignores the status of the stop and of every free, and clears `is_running` regardless; a failed
  allocation in `sequence` returns without freeing the buffers it had allocated; its poller has no deadline, and
  after a stop that came first nothing ends it, while it keeps calling the SDK on the camera's handle; `getdata`
  ignores each copy's status, and after a failed start copies buffers no frame was written to.
- CSC: `sequence` never disarms, so a later `sequence` re-arms a streaming camera and its `getdata` can return frames
  queued before the request; `abort` is its `shutdown`, so stopping it closes it; and the close reports a failure
  only through the two status codes it returns.

A system that uses either camera must treat it as not known stopped after every acquisition, until the driver fixes
land: write its own reader, check what it can, and rebuild the camera (or restart the process) after every
acquisition, or accept reuse it cannot verify.

**[limitation, 0.2.7-DEV]** `camera_ok(::DCAM4Camera)` reports what the driver reports, and one case goes unreported:
`getdata` and `capture` run their stop and release in a `finally` that catches any exception from them (an interrupt
included), log it, and return the stack, the frame or `nothing` as before. Such an exception records nothing in
`last_error`, and `with_camera` never sees it. When `last_error` is still success (the read worked) and `is_running`
is clear (the sequence poller cleared it, or it was never set for `capture`), `camera_ok` is true while the buffer may
still be attached; after a read whose failure set `last_error` (lost frames, say), it stays false (traced from
`getdata` and `capture` in `dcam4_camera/interface_methods.jl`). Watch the log for `cleanup after getdata failed` and
`cleanup after capture failed`, and treat the camera as not stopped when either appears.

**[limitation, 0.2.7-DEV]** On DCAM4 a Ctrl-C can be lost. `sequence` starts a poller that nothing joins and that has
no `catch`, and it polls the capture status as often as `getdata` does, so a Ctrl-C can land in it rather than in the
task calling `getdata`. It then ends the poller silently, and the acquisition runs to the end of its sequence and
returns normally, with nothing logged or marked: press Ctrl-C again (traced from `sequence` in
`dcam4_camera/interface_methods.jl`, and reproduced with real signals over the fake DCAM SDK). The upstream fix is
the one `mc-system-design`'s Decision 3 names: `sequence` returning its task, for `read_sequence` to join.

**[limitation, 0.2.7-DEV]** With the DCAM4 driver's SDK tracing enabled, a Ctrl-C can also be lost in `trace_line`,
which runs on the caller's task around each traced DCAM call: whatever its record builder throws, an
`InterruptException` included, it turns into a note in the trace and carries on (traced from `trace_line` in
`dcam4_camera/dcam_trace.jl`). With tracing off, the default, this path does not run.

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
where every plane differs; against a stage that puts the Sim camera back in `SEQUENCE` mode at every move, so a plane
is a frame only when `snap`'s `capture` ran after that move; and against a recording camera whose `capture` notes
the stage's z at the moment it is called, which shows one capture per plane, each after its move and read-back. Do
not capture once and call `getdata` repeatedly: after `capture` on DCAM4 that reads a released acquisition, and on
CSC another pending frame (see the capture contract above).

<!-- mc-test: acquire-zstack -->
```julia
using MicroscopeControl
# snap: the one definition, in "The capture contract differs per driver" above

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
  tries to disable the output and then to write 0 V, each whatever the other did, and throws. When the disable
  fails, the driver logs that the output may still be on; when only the 0 V write fails, it logs that the output is
  disabled and that the write failed (traced from `disable_after_failure_modulated`). Either way a throw from
  `light_on` does not tell your code which happened: treat the output as unknown, and call `light_off`, then
  `shutdown`, until one returns without throwing (traced).
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
