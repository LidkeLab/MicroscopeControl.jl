# Quick start

This page runs on the simulated devices, so it needs no hardware; the docs build runs every block on it. It
documents the `main` branch: if a call is missing from the release you installed (`lights_off`, say), install with
`rev="main"` to run the page as written. `using MicroscopeControl` loads GLMakie, so it
needs a display (run it under `xvfb-run` on a headless machine), and the HDF5 read-back at the end needs `HDF5` in
your environment.

The hardware drivers have the same functions, but not the same behavior: their constructors, region-of-interest
offsets, what blocks and what throws all differ, and some functions are not implemented on every driver. Read a
driver's docstring before running this code on it.

## Make and connect the devices

```@example quickstart
using MicroscopeControl

camera = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 48), sequence_length = 5)
stage = SimStage3d()
light = SimLight()

initialize(camera)
initialize(stage)
initialize(light)
nothing # hide
```

`CameraROI(x_start, y_start, width, height)` sets the frame size: 64 pixels wide and 48 high here. The simulated
stage prints a line for every call.

## Acquire images

A frame is a `(height, width)` array indexed `[y, x]`, with `[1, 1]` at the top left; a sequence is
`(height, width, frames)` (see [Image layout](@ref)). On the hardware drivers `capture` returns the frame;
`SimCamera`'s `capture` only selects single-frame mode, so the simulated frame is read with `getdata`:

```@example quickstart
capture(camera)
frame = getdata(camera)
size(frame)
```

`sequence` starts `sequence_length` frames, and `getdata` returns the stack:

```@example quickstart
sequence(camera)
stack = getdata(camera)
size(stack)
```

`SimCamera`'s frames are random `UInt16` noise; only their shape means anything. `SimCamera`'s `getdata` returns at
once. On the hardware drivers this step differs: `DCAM4Camera`'s `getdata` waits for the sequence within a timeout,
`ThorCamCSCCamera`'s polls the frames one by one and throws when a poll fails or times out, and
`ThorcamDCXCamera`'s copies its buffers without waiting for the sequence to finish (see its docstring).

## Move a stage

```@example quickstart
move(stage, 10.0, 20.0, 5.0)
getposition(stage)
(stage.real_x, stage.real_y, stage.real_z)
```

`move` takes `Float64` positions. `getposition` reads the position into the stage's `real_x`, `real_y` and
`real_z` fields, which is where this example reads it.

## Set a light source

A `SimLight` without a modulator is on after `initialize`. `setpower` records the level in the light's unit (mW
by default), and `light_off` switches it off:

```@example quickstart
setpower(light, 25.0)
light.properties
```

A regulated laser diode is set in the unit its controller regulates. `SimDiodeLaser` is the simulated twin of the
TCube driver, `TCubeLaser`: it shares the mode and diode keywords, but not the serial number or the controller and
DAQ settings, and adds simulation keywords of its own (its docstring lists both):

```@example quickstart
laser = SimDiodeLaser(mode = ConstantCurrent())
initialize(laser)
setcurrent!(laser, 80.0)    # mA
light_on(laser)
measured_current(laser)
```

[`lights_off`](@ref) calls `light_off` on every light it is given, even after one of them fails. If any failed, it
then throws one `LightsOffError` naming every light that failed, and a light whose switch-off failed may still be
on; otherwise it returns `nothing`.

```@example quickstart
lights_off(light, laser)
light.properties.is_on, laser.properties.is_on
```

## Save the state to HDF5

`export_state` returns each device's `(attributes, data, children)`. A system's state is the same tuple with the
devices as children, and [`save_h5`](@ref) writes it as nested groups under `Main`. It runs on a task; `wait` for
it before reading the file.

```@example quickstart
state = (Dict{String,Any}("description" => "quick start"),
         stack,
         Dict{String,Any}("camera" => export_state(camera),
                          "stage" => export_state(stage),
                          "light" => export_state(light)))

path = joinpath(mktempdir(), "quickstart.h5")
wait(save_h5(path, state))
nothing # hide
```

The image stack is written as it is, `(y, x, frame)`, and labeled:

```@example quickstart
using HDF5
h5open(path) do file
    main = file["Main"]
    (groups = keys(main),
     data_size = size(main["data"]),
     dimension_order = read(attributes(main["data"])["dimension_order"]),
     stage_x = read(attributes(main["stage"])["position_x"]))
end
```

## Shut down

```@example quickstart
shutdown(laser)
shutdown(light)
shutdown(stage)
shutdown(camera)
nothing # hide
```

Most devices also have a control panel, `gui(device)`, which opens a GLMakie window, and a camera has
[`start_live`](@ref) for a live view. `[limitation]` The stage panel reads a `stagelabel` field that the simulated
stages do not have, so `gui(SimStage3d())` throws.
