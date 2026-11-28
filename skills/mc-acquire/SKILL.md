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
   SDK call) must leave the camera alone and out of service.
3. Only then stop the camera, with `stop_camera!` (`abort`, prepared per driver,
   through `with_stop`, which marks the camera unknown when the stop throws or
   leaves it not known stopped; a camera marked unknown is out of service until
   it is rebuilt). Both are in "Finite ordered sequence". Do 1 to 3 in a `finally` around the start, so they run
   whatever your program, the start or the reader did: `live_view!` below.
   `stop_reader!` logs a stop the driver does not confirm. Rethrow an
   `InterruptException`, never log it. Start the camera only through
   `with_camera`, as `start_reader!` does, so a camera marked unknown is never
   restarted.
4. Never let two tasks call into the same camera SDK concurrently. One task owns
   the camera; everything else asks it.
   **[limitation, 0.2.7-DEV]** the drivers spawn tasks of their own that the
   interface does not promise to return: DCAM4's poller, which `sequence` discards,
   and Sim's and DCx's, which `sequence` returns only by accident (the table in
   "Finite ordered sequence"). So "one task" is a rule for *your* code, not a
   property you can establish of the process; `mc-system-design`, Decision 3, gives
   the evidence, the resulting single-owner restriction, and the upstream fix.

A live view reserves its camera for its whole run, in a set of its own, `CAMERA_LIVE`, kept apart from the failure mark
`CAMERA_UNKNOWN` ("Finite ordered sequence"): **from `start_reader!` until its own confirmed stop, the camera is
reserved.** `start_reader!` refuses a camera that is marked or reserved, reserves it, and only then calls `live`;
`stop_reader!` removes the reservation only when its own stop is confirmed by `camera_ok`. So a Ctrl-C at any instant
leaves the camera unstarted (before the reservation), reserved or marked (after it), or confirmed stopped: never running
and in service. A guarded acquisition on the camera during its live view is refused, as it should be, since the camera
is busy. What marks a camera unknown, during a live view and otherwise, and what does not, is listed once, beside the
two sets ("Finite ordered sequence"); nothing removes that mark, so it outlasts the live view's own confirmed stop. In
the examples only the functions that own the two sets refer to them (suite: statements), and each set is defined once,
so evaluating the definitions again keeps every mark (suite: camera).

**[limitation, 0.2.7-DEV]** A Ctrl-C from the terminal lands in whichever task is running when it arrives. In the
caller's own task (the live-view body, or the task running `acquire!`) it unwinds that task directly. In the reader (the
usual place, since it wakes every frame) or the Sim timer, it reaches the caller only at the join, where `join_task`
rethrows it, so the body runs on until then; a body that must stop at once needs the reader to pass it on, for example
through a flag the body checks. On DCAM4 it can be lost in the driver: in the sequence poller nobody joins, in the
`catch` in the cleanup of `getdata` and `capture`, and, with the driver's SDK tracing enabled, in `trace_line`, which
turns anything thrown while it builds a trace record, an interrupt included, into a note (all three in "Finite ordered
sequence"). A Ctrl-C can also end the Julia process: when it arrives as a task is finishing, Julia has no handler there
and exits (`fatal: error thrown and no exception handler available`; seen with real signals in a test process, not
traced to a fix). And Julia's logging can lose one, for a logger whose `catch_exceptions` is true, as the default
`ConsoleLogger`'s is (`SimpleLogger` and `TestLogger` by default do not catch): on every version, an exception raised
while a log message is being built, an interrupt included, is reported as a logging error instead (`logging_error` in
Julia's `logging.jl`, the same code in 1.11 and 1.13); and from Julia 1.12, so is one the logger throws while it writes
the record (`handle_message_nothrow`; on 1.11 that one reaches the caller). So a Ctrl-C that lands while `attempt_stop!`
logs a failed stop can be lost, and the camera stays marked unknown (suite: camera: an interrupt while the message is
built, on every version, and one from a logger that throws once, per version).

<!-- mc-test: acquire-reader -->
```julia
"""
    ReaderHandle(cam)

One live view and its reader: the camera, the reader task (`nothing` until one is launched), the reader's own stop
flag, and the live view's `state`:

- `:new`: not started; `stop_reader!` has nothing to stop;
- `:starting`: `start_reader!` is reserving the camera and calling `live`; the start is not yet confirmed;
- `:live`: `live_started` confirmed the start;
- `:done`: `stop_reader!` has set it, just before it attempts the stop (if the start began), whether or not that
  stop then works; an interrupt between the two leaves the camera reserved, so it is still refused. A confirmed stop
  ends the reservation; a start that was not confirmed, or a reader that failed, marks the camera unknown.

A handle runs one live view: `start_reader!` refuses one that is not `:new`, and a call to `stop_reader!` on a `:done`
handle does nothing. A handle left `:live` by an interrupted wait (case 1 of `stop_reader!`) still owes its stop: the
next `stop_reader!` on it, such as the `finally` of a refused second `live_view!`, joins the reader and stops the
camera.
"""
mutable struct ReaderHandle
    const cam::Camera
    reader::Union{Task,Nothing}
    const stop::Threads.Atomic{Bool}              # the reader's flag, not cam.is_running
    state::Symbol
end
ReaderHandle(cam::Camera) = ReaderHandle(cam, nothing, Threads.Atomic{Bool}(false), :new)

"""
    stop_reader!(h) -> (; reader_error, stop_error, camera_ok)

Set the reader's flag, join the reader if one was launched, then, if the start began, attempt the stop, once; the handle
ends `:done`, and a call on a `:done` handle does nothing. A confirmed stop ends the reservation; a start that was not
confirmed, or a reader that failed, marks the camera unknown. `reader_error` is the reader's own failure (the camera is
then marked unknown, as for any acquisition that threw) or `nothing`; `stop_error` is the ordinary error the stop threw,
or `nothing`; `camera_ok` is whether the camera is in service afterwards (`in_service`). A stop the driver does not
confirm is logged (`attempt_stop!`) before anything is thrown. It throws in four cases:

1. the wait ends with any exception while the reader still runs: the camera is left untouched, reserved, the handle
   keeps its state, and that exception is rethrown;
2. an interrupt, in the reader or in the wait, once the reader has ended: after the stop was attempted, whether or
   not it worked, as a plain `InterruptException`;
3. any other exception in the wait, once the reader has ended: after the stop was attempted, that exception;
4. an interrupt in the stop itself: rethrown, not logged, with the camera marked unknown.
"""
function stop_reader!(h::ReaderHandle)
    h.state === :done && return (; reader_error = nothing, stop_error = nothing, camera_ok = in_service(h.cam))
    h.stop[] = true
    reader_error, pending = nothing, nothing
    if h.reader !== nothing
        try
            join_task(h.reader)                  # a reader that died of a Ctrl-C comes out as a plain interrupt
        catch e
            istaskdone(h.reader) || rethrow()    # case 1: it still runs: leave the camera alone, reserved
            if e isa TaskFailedException && e.task === h.reader
                reader_error = e                 # the reader's own failure: an acquisition that threw
                mark_unknown!(h.cam)
            else
                pending = e                      # cases 2 and 3: rethrown after the stop
            end
        end
    end
    stop_error = nothing
    began = h.state                              # :new, :starting or :live
    h.state = :done                              # a handle stops once
    if began !== :new
        began === :live || mark_unknown!(h.cam)  # a start that was not confirmed is a failure
        (; stop_error, stopped) = attempt_stop!(h.cam, "the live-view stop")   # case 4: rethrown, marked unknown
        stopped && delete!(CAMERA_LIVE, h.cam)   # a confirmed stop ends the reservation; a failure is marked above
    end
    pending === nothing || throw(pending)
    return (; reader_error, stop_error, camera_ok = in_service(h.cam))
end

# The reader loop, and the one getlastframe outside a wrapper: only start_reader! launches it, after its guard.
function read_frames!(h::ReaderHandle, latest, fps)
    while !h.stop[]
        frame = getlastframe(h.cam)
        frame === nothing || (latest[] = frame)  # getlastframe returns nothing on timeout
        sleep(1 / fps)
    end
end

"""
    start_reader!(h, latest, fps) -> h

Start the live view of `h.cam` and launch its reader into `h`. Refuse a handle that is not `:new`, and a camera that
is marked unknown or reserved, before any call reaches it; then set `:starting`, reserve the camera, and only then
call `live`. A start that throws, or that `live_started` does not confirm, launches no reader and leaves the camera
reserved; the cleanup `stop_reader!(h)` attempts the stop and marks the camera unknown. Only `live_view!` calls it,
inside the `try` whose `finally` calls `stop_reader!(h)`.
"""
function start_reader!(h::ReaderHandle, latest, fps)   # the reader is then the ONLY task that touches the camera
    h.state === :new || error("start_reader!: this handle has run a live view; make a new ReaderHandle")
    started = with_camera(h.cam; ok = Returns(true)) do   # refuses a marked or reserved camera
        h.state = :starting                  # from here stop_reader!(h) attempts the stop
        push!(CAMERA_LIVE, h.cam)            # reserved from before live until a confirmed stop
        reset_error!(h.cam)                  # live_started judges what live does from here
        live(h.cam)                          # cam.is_running == 1 from here
        live_started(h.cam)
    end
    started || error("$(nameof(typeof(h.cam))): the live view did not start; no reader was launched, the camera " *
                     "stays reserved, and the cleanup stop_reader!(h) attempts the stop and marks it unknown")
    h.state = :live                          # confirmed; an unconfirmed start is marked unknown at its stop
    h.reader = @async read_frames!(h, latest, fps)
    return h
end

"""
    live_view!(body, h, latest, fps) -> (; reader_error, stop_error, camera_ok)

The live view as one call, and the recipe: start it inside a `try`, run `body(h)`, and stop it in the `finally`,
whatever happened. Returns the stop's outcome, or rethrows what was thrown. The only caller of `start_reader!` and
`stop_reader!` (suite: statements).
"""
function live_view!(body, h::ReaderHandle, latest, fps)
    local outcome
    try
        start_reader!(h, latest, fps)        # inside the try: a start that throws is stopped too
        body(h)
    finally
        outcome = stop_reader!(h)            # runs whatever happened above, or in the reader; logs a failed stop
    end
    return outcome
end

h = ReaderHandle(cam)
outcome = live_view!(h, latest, fps) do h
    sleep(0.2)                               # ... the rest of your program runs, until it is time to stop
end
outcome.reader_error === nothing || throw(outcome.reader_error)
```

**[guarantee, suite: acquire-reader]** The checks call `live_view!` itself, so a change to the recipe is a change to
what they run. This runs clean against `SimCamera` (which cannot exhibit the hazard, since it does not call an SDK): the
reader reads frames until its flag is set, the join returns, the outcome is `camera_ok` with no error, and the handle
ends `:done`. During the live view the camera is reserved, and a `read_sequence` on it is refused; after the confirmed
stop it is in service. On a camera that records its calls: `live` is called on a camera already reserved; a second
`live_view!` on a `:done` handle is refused with "make a new ReaderHandle" before any call reaches the camera, also when
its reader had died of an interrupt (a `:live` handle left by an interrupted wait is refused too, and makes the stop it
still owes: below); a camera marked unknown is refused before any call reaches it, the stop then calls nothing either,
and the handle ends `:done`; an interrupt before the reservation (in the refusal) leaves the camera unstarted and in
service. A live start that throws (an ordinary error, or an interrupt inside `live`), that `live_started` does not
confirm, or whose `live_started` throws an interrupt launches no reader, has its stop attempted, and ends with the
camera marked unknown, a confirmed stop included, and out of `CAMERA_LIVE` after that confirmed stop; the caller gets
the start's own exception, or the message that the start was not confirmed. Without the `finally`, such a start leaves
the camera reserved and unstopped. A stop on that path that the driver does not confirm is logged, and an interrupt
thrown by it reaches the caller. A handle that is `:live` with no reader, as an interrupt just after `h.state = :live`
leaves it, is stopped and its reservation ended; an interrupt between the confirmation and that line leaves it
`:starting`, so the camera ends marked unknown. After a confirmed start, a stop the driver does not confirm leaves the
camera marked unknown and still in `CAMERA_LIVE`, and a guarded read on it is refused. On `DCAM4Camera` over the fake
DCAM SDK the same holds when `live` reports a failed allocation, and when it reports an error while the capture went
ahead: the stop then leaves the camera stopped, and when that stop fails too, `is_running` stays set and the stop is
logged. And on DCAM4, when the owner ends the reader and calls `stop_camera!` itself and the driver reports a failed
release, the camera stays refused after the recipe's later stop succeeds. A reader that throws an ordinary error is
still joined, the camera is still stopped, the outcome carries the reader's error, and the camera is marked unknown, as
for any acquisition that threw (the list beside the two sets says what marks a camera and what does not). A stop that
throws an ordinary error gives an outcome with that error and `camera_ok == false`, is logged, and marks the camera
unknown; a stop that throws an interrupt, there or before `with_stop` is reached, marks the camera unknown and is
rethrown, with nothing logged at warning level or above, and a guarded read on the camera is refused after it. An
interrupt delivered into the reader itself, where a Ctrl-C usually lands, reaches the caller as a plain
`InterruptException`, after the camera was stopped, the camera in service when that stop was confirmed, and a stop that
failed on that path is still logged. An interrupt, or any other exception, delivered to the task waiting on a reader
that is still running leaves the camera running and reserved, and reaches the caller; the handle stays `:live`, and a
second `live_view!` on it is refused, and its `finally` then joins the reader and makes the stop it owed.

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
`getlastframe`, `abort`) makes those calls inside one of two wrappers, defined below. `with_camera(f, cam; ok)` starts,
reads or snaps: it refuses a camera marked unknown, or reserved by a live view, before `f` runs, and nothing turns that
refusal off. `with_stop(f, cam; ok)` is the same without the refusal, for a stop, which must reach a camera that may
still be running. Both mark the camera unknown when `f` throws (any exception, an interrupt included) and rethrow, and
after a normal return mark it when the postcondition `ok(cam)` is false, running the postcondition inside the region
that marks on a throw. `with_camera` returns `f`'s value either way, so the caller still gets the stack and the mark
stops the next use; `with_stop` returns `ok(cam)`. The suite checks the rule on the code of every function in these
skills' marked examples, including default arguments and the eagerly evaluated arguments of the wrappers
(suite: statements), and confines its two exceptions by name: `with_stop` is accepted only inside a `stop_camera!`
method, and any other reference to it, called, passed or bound to a name, fails; and a `getlastframe` outside a wrapper
is accepted only inside `read_frames!`, the reader loop, which starts no task of its own (no `@async`, `@spawn`, `@task`
or `@threads`, bare or qualified, and no `Task`, `schedule` or `Timer`) and which only `start_reader!` may launch, as a
task, after a `with_camera` that every path to the launch runs (one executed as a top-level statement of
`start_reader!`, not inside an `if`, a loop, a `try` or a local function). One reference rule covers the rest:
`with_stop` is named only in `stop_camera!` methods, `CAMERA_UNKNOWN` only in `mark_unknown!`, `refuse_unknown` and
`in_service`, `CAMERA_LIVE` only there and in `start_reader!` and `stop_reader!`, `start_reader!` and `stop_reader!`
only in `live_view!`, and `read_frames!` only in `start_reader!`; anywhere else, in a body or a signature (parameter
types included) or at the top level of a fence, any reference fails, called, passed, qualified or bound to a name. Each
set has one definition, the guarded one, and each function that owns a set, and `live_view!` and `read_frames!`, has one
method, across all the examples. That `start_reader!` launches the reader only after `live_started` confirmed the start,
and that `stop_reader!` joins it before it stops the camera, are checked by running them (suite: acquire-reader).

Through them, one function per driver, chosen by dispatch as `snap` is: `read_sequence(cam, n)` returns the stack or
throws; `stop_camera!(cam)` stops the camera after a failure or at the end of live view, and returns whether the driver
reports it stopped; and the postconditions, `camera_ok(cam)` (after an acquisition or stop, is the camera known stopped
with its buffers released, as far as its driver reports?) and `live_started(cam)` (after `live`, is the live view known
to be running?). A camera without a method gets the fallback, which refuses to read and never says the camera stopped or
started. Two shared pieces go with them: `join_task`, the one way the examples wait on a task, and `attempt_stop!`, the
one way they stop a camera after a failure or at the end of live view, which logs a stop the driver does not confirm and
passes an interrupt on. A camera is in service exactly while it is in neither set (`in_service`): every read, snap,
start and stop marks it unknown when its postcondition fails, and a live view reserves it for its whole run (above).
Covered here: `SimCamera` (run by the suite) and `DCAM4Camera` (run against the fake DCAM SDK in `test/`). Not covered:
`ThorcamDCXCamera` and `ThorCamCSCCamera` (below). `mc-system-design`'s `Bench` uses these functions; write the methods
for a camera you add.

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

# Two sets, kept apart. CAMERA_UNKNOWN is the out-of-service mark: a camera in it is never started or read again (a
# stop is still let through), and nothing removes it from the set: rebuild the camera. The one list of what marks it:
# - any exception, an interrupt included, thrown inside `with_camera` or `with_stop`, or by their postcondition;
# - a postcondition that is false: `camera_ok` after a read, a snap or a stop (`attempt_stop!` logs that stop);
# - an interrupt anywhere in a stop made through `attempt_stop!`;
# - a live start that `live_started` did not confirm, marked at its stop;
# - a live view's reader that threw an ordinary error (`reader_error`).
# What does not mark it:
# - a live view's reader that died of an interrupt: it is passed on, and the camera is judged by its stop;
# - a DCAM4 frame read that the driver reports failed (`getlastframe` returns `nothing` and sets `last_error`): the
#   reader skips the frame, and the stop clears `last_error` to judge its own abort;
# - a wait for a reader that still runs, interrupted: the camera stays reserved instead, its stop still owed.
# CAMERA_LIVE holds a camera reserved by a live view, from before `live` until that live view's confirmed stop. Each
# set is defined once, so evaluating this fence again (a second `include` of a script holding it) keeps every mark and
# every reservation (suite: camera). Only the functions below and `start_reader!` and `stop_reader!` refer to either
# set, and each set has one definition (suite: statements).
if !@isdefined(CAMERA_UNKNOWN)                   # defined once: evaluating this fence again keeps every mark
    const CAMERA_UNKNOWN = Base.IdSet{Camera}()
end
if !@isdefined(CAMERA_LIVE)
    const CAMERA_LIVE = Base.IdSet{Camera}()
end
mark_unknown!(cam::Camera) = (push!(CAMERA_UNKNOWN, cam); nothing)
function refuse_unknown(cam::Camera)             # refuse a camera marked unknown, or one a live view holds
    cam in CAMERA_UNKNOWN && error("camera unavailable: it is marked unknown (not known stopped after an " *
                                   "acquisition or a stop); shut down and reconstruct")
    cam in CAMERA_LIVE && error("camera unavailable: a live view holds it; stop that live view first, or, if its " *
                                "stop did not finish, shut down and reconstruct")
    return nothing
end
in_service(cam::Camera) = !(cam in CAMERA_UNKNOWN) && !(cam in CAMERA_LIVE)

"""
    with_camera(f, cam; ok = camera_ok)

The way these examples start, read or snap a camera. Refuse a camera marked unknown, run `f()`, mark the camera
unknown when `f` or `ok(cam)` throws, an interrupt included, and rethrow; after a normal return, mark it when
`ok(cam)` is false. Returns `f()`'s value either way. Nothing turns the refusal off: a stop uses `with_stop`.
"""
function with_camera(f, cam::Camera; ok = camera_ok)
    refuse_unknown(cam)
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
    with_stop(f, cam; ok = camera_ok) -> Bool

The way a `stop_camera!` method stops a camera, and only those (the suite fails any other use): `with_camera` without
the refusal, since a camera marked unknown may still be running and must still be stopped. Returns `ok(cam)`, whether
the driver reports the camera stopped; the camera is marked when it is false, or when `f` or `ok(cam)` throws.
"""
function with_stop(f, cam::Camera; ok = camera_ok)
    try
        f()
        stopped = ok(cam)
        stopped || mark_unknown!(cam)
        return stopped
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
    stop_camera!(cam) -> Bool

Stop the camera after a failure, or at the end of live view, through `with_stop`, which lets a stop through on a
camera marked unknown: a throw, or `camera_ok` false afterwards, marks the camera unknown. Returns whether the driver
reports the camera stopped.
"""
stop_camera!(cam::Camera) = with_stop(cam) do    # the fallback: abort, judged by camera_ok (false for a camera
                                                 # without a method, so it marks one)
    abort(cam)
end

"""
    attempt_stop!(cam, what) -> (; stop_error, stopped)

Stop the camera with `stop_camera!`, after a failure or at the end of live view, and log a stop the driver does not
confirm, one that threw an ordinary error or returned with `camera_ok` false, under `what` (`stop_camera!` has
marked the camera either way). An interrupt is rethrown, not logged, with the camera marked, wherever in the stop
it landed. Returns the ordinary error or `nothing`, and whether the driver confirmed the stop.
"""
function attempt_stop!(cam::Camera, what)
    stopped, stop_error = false, nothing
    try
        stopped = stop_camera!(cam) === true
    catch e
        e isa InterruptException && (mark_unknown!(cam); rethrow())   # a Ctrl-C stays one, never logged and dropped
        stop_error = e
    end
    stopped || @error("$what: the camera is not known stopped; it is marked unknown",
                      camera = nameof(typeof(cam)), exception = stop_error)
    return (; stop_error, stopped)
end

if !@isdefined(SIM_TIMER)                        # each Sim camera's last sequence timer, kept through any teardown
    const SIM_TIMER = IdDict{SimCamera,Task}()   # and, defined once, through a second evaluation of this fence
end

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
    with_stop(cam) do
        abort(cam)                               # clears is_running; a timer still running keeps sleeping, and would
        t = get(SIM_TIMER, cam, nothing)         # clear a later sequence's flag: wait for it, bounded
        if t !== nothing
            timedwait(() -> istaskdone(t), cam.sequence_length * cam.exposure_time + 1) === :ok ||
                error("SimCamera: its sequence timer did not end")
            join_task(t)                         # a Ctrl-C that landed in the timer meanwhile is passed on
            delete!(SIM_TIMER, cam)
        end
    end
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
    with_stop(cam) do
        reset_error!(cam)                        # judge this abort alone
        abort(cam)
    end
end
camera_ok(cam::DCAM4Camera) = cam.last_error == DCAM4.DCAMERR_SUCCESS && !cam.is_running
live_started(cam::DCAM4Camera) = cam.last_error == DCAM4.DCAMERR_SUCCESS && cam.is_running
```

**[guarantee, suite: camera]** for `SimCamera`, the fallback, `join_task`, the two wrappers, `attempt_stop!` and the
unknown mark: `read_sequence(SimCamera(...), 5)` takes at least five exposures and returns `(32, 64, 5)` with
`camera_ok` true; two reads of one finished sequence differ, and so do two sequences; while the timer still runs,
`getdata` returns at once and two reads differ; `abort` clears `is_running` and leaves the timer running, and
`camera_ok` is true only with `is_running` clear and no timer entry left (a camera with `is_running` set and no timer
entry is not `camera_ok`), which `stop_camera!`'s wait (or the read's own join) removes, and the stop then returns true;
that wait is bounded (a timer that never ends makes `stop_camera!` throw within its bound), and that throw marks the
camera, so a `read_sequence` on the same camera is refused and leaves it unstarted; a read that throws (a negative
length, an `ArgumentError`) marks the camera; a camera type with no method is refused with the message above and is
never `camera_ok`; `join_task` turns a task that died of an interrupt into a plain `InterruptException` and leaves any
other failure a `TaskFailedException`; `read_sequence` refuses a camera marked unknown, here on Sim and on DCAM4 (the
other entries' refusals are asserted in their own groups: `snap`, suite: acquire-snap; `start_reader!`,
suite: acquire-reader; `acquire!`, suite: bench); `with_camera` has no keyword that turns the refusal off (passing one
is a `MethodError`, and `f` does not run); `with_stop` runs `f` on a marked camera, which stays marked; a standalone
stop that returns with `camera_ok` false marks the camera and returns false; `attempt_stop!` logs a stop that returned
unconfirmed or threw an ordinary error, returns that error and whether the stop was confirmed, and rethrows an interrupt
with the camera marked, one thrown before `with_stop` is reached included; under a logger whose `catch_exceptions` is
true, an interrupt raised while the failed stop's message is built is lost and the camera stays marked, on every
version, and one the logger throws as it writes the record is lost from Julia 1.12 and reaches the caller on 1.11, the
camera marked either way (the Ctrl-C limitation above); a camera a live view holds is refused with its own message;
evaluating this fence again keeps a camera marked unknown, one reserved and the Sim timer table; a postcondition that
throws marks the camera too, so a read on it is refused; and `live_started` holds after `live` on a Sim camera, not
before. For `DCAM4Camera`, against the fake DCAM SDK (`test/dcam4_fake_sdk.jl`, not a camera): a clean read returns the
stack and leaves the camera in service; a read whose buffer release fails after the frames were read returns the stack
and marks the camera, and the next `read_sequence` on it is refused before the driver starts anything; a stop on the
marked camera still runs; a standalone stop on a fresh camera whose release the driver reports failed marks it and
returns false; and `live_started` holds after a clean `live`, and not after one whose allocation failed, and the stop
after the clean one returns true. Per driver:

| Driver | `sequence(cam)` returns | `getdata(cam)` in `SEQUENCE` mode | `abort(cam)` | The methods above | Source |
|---|---|---|---|---|---|
| `SimCamera` | its timer `Task`, which sleeps `sequence_length` exposures, reading `exposure_time` again for each (traced; one change while it runs, suite: bench), then clears `is_running` | fresh random frames at any time, the timer running or not; it keeps nothing, so joining the timer is what makes a read take the sequence's time | clears `is_running`; the timer keeps running | through `with_camera` (the stop through `with_stop`): keep the timer and join it with `join_task`, then read; `stop_camera!` aborts and waits for the timer, bounded; `camera_ok`: `is_running` clear and no timer left to join; `live_started`: `is_running` set | suite: camera |
| `DCAM4Camera` | `nothing`, with `last_error` set when the allocation or start failed; its poller is discarded (and can swallow a Ctrl-C, below). The poller stops a capture still running at its deadline, ignoring that stop's result, and clears `is_running` while its sequence is current, whether or not the stop worked | polls the capture status until the sequence ends (below), reads the `N` frames, then stops and releases; `nothing` on a timeout, a failed frame-count query or lost frames. An exception thrown by that stop and release is logged and swallowed (below) | `stop_and_release!`: a stop or release that fails records `last_error` and leaves `is_running` as it was; on a stopped camera it does nothing and clears `is_running`; an exception inside it (an interrupt in its status read, say) propagates | through `with_camera` (the stop through `with_stop`): clear `last_error` before the sequence, a stop or a `live`, and turn an error from `sequence` or a `nothing` from `getdata` into a throw; `camera_ok`: `last_error` still success, `is_running` clear; `live_started`: `last_error` still success, `is_running` set | the driver traced; the methods run against the fake DCAM SDK (suite: camera) |
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
