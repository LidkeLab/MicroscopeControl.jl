# Quick start

This page runs on the simulated devices, so it needs no hardware; the docs build runs every block on it. Code
written this way runs on a hardware driver of the same class by changing the constructor, with the differences
each driver's docstring states. `using MicroscopeControl` loads GLMakie, so it needs a display (run it under
`xvfb-run` on a headless machine).

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

`SimCamera`'s frames are random `UInt16` noise; only their shape means anything. A hardware driver's `getdata`
waits for the sequence to finish, within a timeout its docstring gives.

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
TCube driver, `TCubeLaser`, and takes the same keywords:

```@example quickstart
laser = SimDiodeLaser(mode = ConstantCurrent())
initialize(laser)
setcurrent!(laser, 80.0)    # mA
light_on(laser)
measured_current(laser)
```

[`lights_off`](@ref) switches off every light it is given, even when one of them fails, and then reports every
failure together:

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

Each device also has a control panel, `gui(device)`, which opens a GLMakie window, and a camera has
[`start_live`](@ref) for a live view.
