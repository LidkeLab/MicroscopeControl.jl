---
name: mc-acquire
description: Acquisition patterns for MicroscopeControl.jl cameras and stages -- capture/sequence/live and what getdata/getlastframe return, the live-view stop order that avoids a hard crash, ordered sequences, z-stacks, and the (H, W, N) array convention; activates for "capture", "acquire", "live view", "z-stack", "sequence", or "frame".
---

# mc-acquire

Shapes and return values below were executed against `SimCamera` and `SimStage3d`
on MicroscopeControl.jl v0.2.0. Hamamatsu (`DCAM4Camera`) behaviour is traced from
the driver source, not executed here; it is marked as such.

## Stopping live view: stop and join every reader before `abort`

`live(cam)` starts a continuous acquisition and sets `cam.is_running = 1`. Whatever
is displaying frames, the package GUI or your own loop, polls with

```julia
while cam.is_running == 1
    frame = getlastframe(cam)      # (H, W)
    ...
    sleep(1 / fps)
end
```

`abort(cam)` on the Hamamatsu driver calls `dcamcap_stop`, then `dcambuf_release`,
and only **then** clears `is_running` (traced from `dcam4_camera/interface_methods.jl`,
not executed). A reader that is inside `getlastframe` when you call `abort` is
therefore waiting on, or copying from, an acquisition that is being torn down.
`getlastframe` on DCAM4 blocks in `dcamwait_event` for up to
`max(1 s, 1.5 * exposure_time)` per call, so a fixed sleep cannot guarantee the
reader has left. The driver's copy path (`dcambuf_copyframe`) checks the SDK return
code and returns `nothing` with an `@error` on failure; whether the vendor DLL
survives a copy against released buffers in every case is **not** established by
the source. Treat a hard crash of the Julia process as a possible outcome, not a
certainty, and do not rely on either.

The requirement, on every driver:

1. Clear `cam.is_running` so every reader loop exits at its next check.
2. **Join** every reader task you own (`wait(task)`), so no SDK call is in flight.
3. Only then call `abort(cam)`.
4. Never let two tasks call into the same camera SDK concurrently. One task owns
   the camera; everything else asks it.

```julia
cam.is_running = 1
reader = @async while cam.is_running == 1        # the ONLY task that touches cam
    frame = getlastframe(cam)
    frame === nothing || (latest[] = frame)      # getlastframe returns nothing on timeout
    sleep(1 / fps)
end
# ... later, to stop:
cam.is_running = 0
wait(reader)                                     # join: no SDK call in flight after this
abort(cam)
```

This ran clean against `SimCamera` (which cannot exhibit the hazard, since it does
not call an SDK). The package GUI (`gui(cam)` / `start_live`) runs its polling loop
in an `@async` task you cannot join from outside, and registers `abort` on window
close. On hardware, prefer your own reader task over the GUI's for anything you need
to stop programmatically.

Two consequences of the same mechanism on `DCAM4Camera` (traced):

- `live` itself calls `abort` first. Calling `live` while a reader is running is the
  same hazard. Stop and join first.
- `getdata` in `LIVE` mode waits for a cycle-end event, sets `is_running = false`,
  copies the last frame and releases the buffer. It ends the live view. Grab frames
  during live view with `getlastframe`; use `getdata` only where the driver's
  contract says it is valid (next section).

## The three modes

| Call | Sets `capture_mode` | SimCamera (executed) |
|---|---|---|
| `capture(cam)` | `SINGLE_FRAME` | returns the enum `SINGLE_FRAME`; the frame comes from `getdata(cam)`, `(H, W)` `Matrix{UInt16}` |
| `sequence(cam)` | `SEQUENCE`, `is_running = 1`, cleared by an `@async` timer after `sequence_length` exposures | `getdata(cam)` returns `(H, W, N)` `Array{UInt16,3}`, `N = cam.sequence_length` |
| `live(cam)` | `LIVE`, `is_running = 1` | `getlastframe(cam)` `(H, W)` per call; stop as above |

`getlastframe(cam)` is `(H, W)` in every mode. With `roi = CameraROI(1, 1, 64, 32)`
(width 64, height 32) the Sim camera returns `(32, 64)` and `(32, 64, N)`.

### The capture contract differs per driver

Where the frame comes from after `capture` is **not** part of the interface. Traced
from each driver's `interface_methods.jl`; only the Sim row was executed.

| Driver | `capture(cam)` returns | `getdata(cam)` after `capture` |
|---|---|---|
| `SimCamera` | the enum, not a frame | the frame. This is the only driver where this is the right call. |
| `DCAM4Camera` | the frame `(H, W)`, after allocating one buffer, snapping, reading, and **releasing** the buffer | waits on a cycle-end event for an acquisition that no longer exists, then copies from released buffers. Do not call it. |
| `ThorcamDCXCamera` | the frame, then frees the image memory | in any mode reads `sequence_length` frames from `pImage_Mem` and calls `abort`; only valid after `sequence`. |
| `ThorCamCSCCamera` | the frame (arm, software trigger, `getlastframe`) | `SINGLE_FRAME` branch calls `getlastframe` again, which polls `tl_camera_get_pending_frame_or_null`: whatever frame is pending at that moment, or the zero-filled placeholder below if none is. Not the captured frame, and not guaranteed to be any frame. The `SEQUENCE` branch references an undefined variable `sequence_frames` and hard-codes 1080 x 1440; it will error. |

So on every hardware driver in the package, the frame is the **return value of
`capture`**, and `getdata` is for sequences. Put the difference in one place in your
system rather than at every call site:

```julia
snap(cam::SimCamera) = (capture(cam); getdata(cam))     # executed
snap(cam::Camera)    = capture(cam)                     # DCAM4, DCX, CSC: frame is the return value (traced)
```

Check the result before indexing, and check it **per driver**, because the failure
value differs:

| Driver | `capture` on SDK failure |
|---|---|
| `DCAM4Camera` | logs `@error`, sets `cam.last_error`, returns `nothing` (or the copy step returns `nothing` with `@error "DCAM Failed to Copy Frame"`) |
| `ThorcamDCXCamera` | logs `@error`, returns `nothing` |
| `ThorCamCSCCamera` | **returns `zeros(UInt16, 1080, 1440)`**. `getlastframe` substitutes an all-zero image whenever the frame fetch yields nothing, and that happens on two paths (`thorcamcsc_camcontrol.jl`): the SDK call fails (logged, `@error "Frame not collected"`), or the SDK call succeeds but hands back a null buffer (**not logged at all**). So the placeholder can arrive silently. A `=== nothing` check passes it as valid data, and the log cannot be relied on. The only detection is `all(iszero, frame)`, and that is a heuristic: a genuinely black frame is indistinguishable from the placeholder. Treat an all-zero CSC frame as suspect, not as data. |
| `SimCamera` | cannot fail |

A zero-filled frame in a z-stack is a worse failure than a thrown error, because it
saves cleanly.

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
| `DCAM4Camera` | `Float64`, read from `DCAM_IDPROP_EXPOSURETIME` at construction | seconds (DCAM property) | `setexposuretime!(cam)`, `setroi!(cam)`, `settriggermode!(cam)` implemented, and called by `capture`/`live`/`sequence` themselves, so assigning the field before the acquisition call suffices | `x_start`/`y_start` forwarded unchanged to `DCAM_IDPROP_SUBARRAYHPOS`/`VPOS`; the SDK's origin convention applies, and the driver `@warn`s if the SDK rounds them |
| `ThorcamDCXCamera` | `Float64`, default `0.01` | seconds in the field, multiplied by `1e3` to milliseconds at the SDK | `setexposuretime!`, `setroi!` implemented; `capture` calls both | `x_start` forwarded unchanged to `s32X`; SDK convention applies |
| `ThorCamCSCCamera` | `Clonglong`, default `40` | forwarded to the SDK **unconverted**; the SDK's own unit applies | `setexposuretime!(cam, ::Int)` only; `capture` calls the internal setter | not forwarded by the driver |

Consequences: `cam.exposure_time = 0.02` is correct for Sim, DCAM4 and DCX and is an
`InexactError` on `ThorCamCSCCamera`, whose field is an integer. Do not write
"seconds" into shared code without checking `typeof(cam.exposure_time)` or the
driver row above.

```julia
cam.exposure_time = 0.02                  # Sim / DCAM4 / DCX
cam.roi = CameraROI(1, 1, 512, 256)       # x_start, y_start, width, height
```

`CameraROI(x_start, y_start, width, height)`. The returned frame is `(H, W)`
column-major on every driver, but **whether `H, W` equal `roi.height, roi.width`
is per driver**:

| Driver | Frame size returned |
|---|---|
| `SimCamera` | `(roi.height, roi.width)` (executed) |
| `DCAM4Camera` | the SDK's current sub-array, `(height, width)` from `dcamprop_getsize`, which is the ROI as the SDK accepted it (the driver `@warn`s if the SDK rounded your offsets) |
| `ThorcamDCXCamera` | `(roi.height, roi.width)`; `capture` allocates image memory of exactly that size |
| `ThorCamCSCCamera` | **always `(1080, 1440)`**. The driver never forwards `roi` to the SDK and hard-codes the full sensor in `getlastframe`, so `cam.roi = CameraROI(1, 1, 512, 256)` changes nothing and preallocation sized from `roi` fails on assignment. |

Preallocate from the first returned frame (`similar(frame, size(frame)..., N)`)
rather than from `roi`, or the CSC path breaks. Whether `x_start = 1` means the
first column or the second depends on the SDK the driver forwards it to; the
interface does not define a 1-based origin. Keep the `(H, W[, N])` storage convention (below) separate
from SDK coordinate conventions: the first is enforced by the drivers at the DLL
boundary, the second is not.

## Finite ordered sequence

```julia
cam.sequence_length = 5
sequence(cam)                       # returns immediately; is_running == true
stack = getdata(cam)                # (32, 64, 5); blocks until frames are available on hardware
cam.is_running                      # false once the sequence has completed
```

Why order matters on the Hamamatsu path (traced): `DCAM4Camera.getdata` in
`SEQUENCE` mode allocates `zeros(UInt16, H, W, sequence_length)` and copies frame
`i` from the SDK ring buffer into `data[:, :, i]` with `dcambuf_getframe(handle,
i - 1)`, then releases the buffer. The frame index is the position in the ring,
so the in-order copy is what makes `stack[:, :, i]` the i-th exposure. If you
write your own readout, copy by frame index in order and release only after the
last copy; the buffer is a ring of `sequence_length` slots, and there is no
per-frame timestamp in the returned array. `getdata` waits on a cycle-end event
with a timeout of `max(1 s, 1.5 * exposure_time * sequence_length)`; on timeout it
sets `cam.last_error` and returns `nothing`, so check the result before indexing.

## Z-stack over stage and camera

Executed against `SimStage3d` + `SimCamera` (`roi = CameraROI(1, 1, 64, 32)`). A
fresh frame is acquired at every z, after the move; do not capture once and call
`getdata` repeatedly, which on hardware reads a released acquisition (see the
capture contract above).

```julia
using MicroscopeControl
cam   = SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32))
stage = SimStage3d()
initialize(stage)

snap(cam::SimCamera) = (capture(cam); getdata(cam))    # see "capture contract" for hardware

zs = 0.0:2.0:8.0                                # in the STAGE'S units, see table below
stack = Array{UInt16}(undef, cam.roi.height, cam.roi.width, length(zs))   # (32, 64, 5)

for (i, z) in enumerate(zs)
    move(stage, stage.targ_x, stage.targ_y, z)  # Float64 only; 3-arg for a 3-D stage
    getposition(stage)                          # Sim: copies targ_* into real_*; hardware: reads back
    # hardware: wait or poll here until real_z is within tolerance of targ_z
    stack[:, :, i] = snap(cam)                  # (H, W) into slice i
end
size(stack)          # (32, 64, 5)
stage.real_z         # 8.0
```

### Stage units and signatures are per driver

`move` passes the numbers you give it straight to the SDK. The `units` field on the
hardware stages is a **label**, not a conversion, and the drivers disagree. A z-stack
written in micrometres against a `PIStage` moves in millimetres, a factor of 1000.
From each driver's `types.jl` and `move` method; only `SimStage3d` was executed:

| Stage | `move` signature | Unit passed to the SDK | Position fields | Range |
|---|---|---|---|---|
| `SimStage3d` / `2d` / `1d` | `(stage, x, y, z)` / `(x, y)` / `(x)` | none; there is no `units` field | `real_x/y/z`, `targ_x/y/z` | `getrange` returns one `(min, max)` tuple per axis, default `(0, 100)` |
| `PIStage` (C-867) | `(stage, x, y)`, 2-D only | **millimetres** (`units = "Milimeters"`; values go to `PI_MOV` unchanged) | `real_x`, `real_y`, `targ_x`, `targ_y` | `getrange` implemented; `range_x`, `range_y` |
| `MCLStage` (Mad City Labs) | `(stage, x, y, z)` | **micrometres** (`units = "Microns"`) | `real_x/y/z`, `targ_x/y/z` | `getrange`; default `(0, 300)` per axis |
| `N472` (PI N-472) | `(stage, pos::Vector{Float64})`, not x/y/z | **millimetres** (`units = "mm"`) | `stage.pos::Vector`, not `real_*` | no `getrange`; `minpos`/`maxpos` vectors |
| `MCS2Stage` (SmarAct) | `(stage, x, y[, z])` | **micrometres**, converted to picometres for the SDK | `real_x/y/z`, `targ_x/y/z` | `range_x/y/z` set by `initialize` from the controller |

`move(stage, 1, 2, 3)` with integers is a `MethodError` on every stage. Only
`PIStage`, `MCLStage` and `N472` carry a `units` field; `SimStage*` and `MCS2Stage`
do not, and `stage.units` on them throws. Guard the check, and hard-code the
SmarAct unit from the table (micrometres), which is fixed by its bridge code:

```julia
expected = Dict(PIStage => "Milimeters", MCLStage => "Microns", N472 => "mm")   # spelled as the drivers spell them
if hasfield(typeof(stage), :units)
    stage.units == expected[typeof(stage)] || error("stage units are $(stage.units); code assumes $(expected[typeof(stage)])")
end
```

Executed against the constructed (unconnected) stage objects: `PIStage().units ==
"Milimeters"`, `MCLStage().units == "Microns"`, `N472().units == "mm"`,
`hasfield(MCS2Stage, :units) == false`, `hasfield(SimStage3d, :units) == false`.
Do the check before the first move on a new rig. Settling time is the driver's business; the Sim stage moves
instantly, so on hardware poll `getposition` until the position field is within
tolerance before exposing.

## Array conventions

Restated from the upstream `CLAUDE.md`, which is authoritative. These are storage
conventions enforced by the drivers at the DLL boundary; they say nothing about SDK
coordinate origins or exposure units (see above).

- **Storage:** frames are column-major `(H, W)`; stacks are `(H, W, N)`.
  `data[row, col] == data[y, x]`. `save_h5` writes `(H, W, N)` directly and tags
  the dataset `dimension_order = "HWN"`.
- **DLL boundary:** C SDKs hand back row-major buffers. The driver reshapes to
  `(W, H)` and permutes: `permutedims(reshape(buffer, (W, H)), (2, 1))` gives
  `(H, W)`. `reshape(buffer, (W, H))` alone is transposed. If you read raw buffers
  in your own code, apply the same rule.
- **Display:** Makie `image` and `heatmap` map dim 1 to x and dim 2 to y, so pass
  the transpose and flip y for a top-left origin:

  ```julia
  image(permutedims(frame); axis=(yreversed=true,))
  heatmap(permutedims(frame); axis=(yreversed=true,))
  ```

- **SLM is the exception:** `MLSLM` holds `phase::Array{Float64,2}` allocated as
  `zeros(width, height)`, so for SLM patterns dim 1 is x. Do not feed a camera
  `(H, W)` frame to the SLM without `permutedims`.
