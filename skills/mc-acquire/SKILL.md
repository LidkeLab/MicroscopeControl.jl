---
name: mc-acquire
description: Acquisition patterns for MicroscopeControl.jl cameras and stages -- capture/sequence/live and what getdata/getlastframe return, the live-view stop order that avoids a hard crash, ordered sequences, z-stacks, and the (H, W, N) array convention; activates for "capture", "acquire", "live view", "z-stack", "sequence", or "frame".
---

# mc-acquire

Shapes and return values below were executed against `SimCamera` and `SimStage3d`
on MicroscopeControl.jl v0.2.0. Hamamatsu (`DCAM4Camera`) behaviour is traced from
the driver source, not executed here; it is marked as such.

## Stopping live view: do this or the process dies

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
and only **then** clears `is_running`. If the display loop is between checks when
you call `abort`, its next `getlastframe` hands the SDK a released buffer. That is a
segfault inside the vendor DLL, not a Julia exception, and it takes the whole
session with it. The Sim camera does not crash, so tests will not catch this.

The order that is safe on every driver:

```julia
cam.is_running = 0                 # 1. tell every poller to stop
sleep(2 * max(cam.exposure_time, 1 / 60))   # 2. let the loop finish its current frame
abort(cam)                         # 3. now release the SDK buffers
```

Two consequences of the same mechanism:

- On `DCAM4Camera`, `live` itself calls `abort` first. Calling `live` while a
  display loop is running is the same hazard. Stop the old view with the order
  above before starting a new one.
- On `DCAM4Camera`, `getdata` in `LIVE` mode waits for a cycle-end event, sets
  `is_running = false`, copies the last frame and releases the buffer. It ends the
  live view. Grab frames during live view with `getlastframe`; use `getdata` only
  after a `capture` or `sequence`.

The package GUI (`gui(cam)` / `start_live`) registers `abort` on window close and
runs the polling loop above in an `@async` task. Closing the window fast is exactly
the race described; prefer stopping through code.

## The three modes

| Call | Sets `capture_mode` | Then | Returns (Sim, executed) |
|---|---|---|---|
| `capture(cam)` | `SINGLE_FRAME` | `getdata(cam)` | `(H, W)` `Matrix{UInt16}` |
| `sequence(cam)` | `SEQUENCE`, `is_running = 1`, clears it when `sequence_length` frames elapse (`@async`) | `getdata(cam)` | `(H, W, N)` `Array{UInt16,3}`, `N = cam.sequence_length` |
| `live(cam)` | `LIVE`, `is_running = 1` | `getlastframe(cam)` repeatedly, stop as above | `(H, W)` per call |

`getlastframe(cam)` is `(H, W)` in every mode. With `roi = CameraROI(1, 1, 64, 32)`
(width 64, height 32) the Sim camera returns `(32, 64)` and `(32, 64, N)`.

The return value of `capture` itself is driver-specific. `SimCamera.capture` returns
the enum it assigned (`SINGLE_FRAME`); `DCAM4Camera.capture` allocates one buffer,
snaps, and returns the frame directly, then releases the buffer (traced, not
executed). Portable code should not depend on `capture`'s return value across
drivers; check the driver or the API map for the camera in hand. On the Sim camera
the frame comes from `getdata` after `capture`.

## Exposure and ROI are fields

At the interface level there is no setter call. `cam.exposure_time::Float64`
(seconds) and `cam.roi::CameraROI` are mutable fields you assign:

```julia
cam.exposure_time = 0.02
cam.roi = CameraROI(1, 1, 512, 256)      # x_start, y_start, width, height (1-based)
```

`CameraROI(x_start, y_start, width, height)`: the returned frame is
`(height, width)`. The Sim camera reads these fields on every call, so assignment
is enough. Hardware drivers need the field pushed to the device. The interface
declares `setexposuretime!(cam)`, `setroi!(cam)`, `settriggermode!(cam)` for that,
all as throwing stubs; the API map (`mc-api-map`) tells you which drivers implement
them. `DCAM4Camera` implements all three (plus argument-taking forms) and calls them
itself at the start of `capture`, `live` and `sequence`, so assigning the field
before the acquisition call is sufficient there. `SimCamera` implements none; calling
`setroi!(SimCamera())` throws. `ThorCamCSCCamera` has `setexposuretime!(cam, ::Int)`
only.

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

Executed against `SimStage3d` + `SimCamera` (`roi = CameraROI(1, 1, 64, 32)`):

```julia
using MicroscopeControl
cam   = SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32))
stage = SimStage3d()
initialize(stage)

zs = 0.0:2.0:8.0                                # micrometres, Float64
capture(cam)
stack = similar(getdata(cam), cam.roi.height, cam.roi.width, length(zs))   # (32, 64, 5)

for (i, z) in enumerate(zs)
    move(stage, stage.targ_x, stage.targ_y, z)  # move is Float64-only; 3-arg for a 3D stage
    getposition(stage)                          # Sim: copies targ_* into real_*; hardware: reads back
    stack[:, :, i] = getdata(cam)               # (H, W) into slice i
end
size(stack)          # (32, 64, 5)
stage.real_z         # 8.0
```

Stage facts used here: `move(stage, x, y, z)` for 3-D, `move(stage, x, y)` for 2-D,
`move(stage, x)` for 1-D, all `Float64`, micrometres, absolute. `getposition` on
the Sim stage returns nothing useful and updates `real_x/real_y/real_z`; read the
fields. `getrange(stage)` returns one `(min, max)` tuple per axis. Settling time is
the driver's business; the Sim stage moves instantly. On hardware, insert a wait or
poll `getposition` until `real_z` is within tolerance of `targ_z` before exposing.

## Array conventions

Restated from the upstream `CLAUDE.md`, which is authoritative.

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
