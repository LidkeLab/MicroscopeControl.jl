# Fields the shared GUI panels read (MicroscopeControl.jl v0.2.0)

The generated `api-map.md` beside this file lists methods only. The interface
`gui` panels are real shared implementations that also read **fields by name**,
so a device can satisfy every method and still throw `FieldError` when its panel
opens. Enumerated from `stage_interface/gui.jl` and `camera_interface/gui.jl`,
then checked with `hasfield` against every device type and by opening the
panels under `xvfb-run -a` (executed). `[guarantee]`/`[limitation]` as in
`mc-system-design`.

## `gui(::Stage)`

Dispatches on `stage.dimensions` (1, 2 or 3; anything else throws) to
`gui1d`/`gui2d`/`gui3d`.

| Field | Read by | Required |
|---|---|---|
| `dimensions::Int` | the dispatch | always |
| `connectionstatus::Bool` | connect/disconnect toggle and status text | always |
| `stagelabel::String` | `GLMakie.activate!(title=stage.stagelabel)` at the end of each panel | always, **unguarded** |
| `targ_x`, `real_x`, `range_x` | 1d, 2d, 3d panels | always |
| `targ_y`, `real_y`, `range_y` | 2d, 3d panels | `dimensions >= 2` |
| `targ_z`, `real_z`, `range_z` | 3d panel | `dimensions == 3` |
| `servostatus` | servo toggle | optional, guarded by `hasfield(typeof(stage), :servostatus)` |
| `driftcorrectionstatus` | drift toggle | optional, guarded by `hasfield` |

Methods called (arity follows `dimensions`): `initialize`, `shutdown`,
`move(stage, targ_x[, targ_y[, targ_z]])`, `getposition`, `home`, `stopmotion`,
`servo(stage, b[, b[, b]])`, `driftcorrection(stage, b[, b[, b]])`. Field types
follow `StageFormat` in `stage_interface/interface_types.jl`: positions
`Float64`, ranges `Tuple{Float64,Float64}`.

| Device | Missing GUI fields | Panel opens (no hardware)? |
|---|---|---|
| `SimStage1d/2d/3d` | `stagelabel` (they have `label`) | **no: `FieldError` [limitation]** |
| `PIStage` (2d) | `driftcorrectionstatus` (guarded); z fields unused | yes |
| `MCLStage` | `servostatus`, `driftcorrectionstatus` (both guarded) | yes |
| `MCS2Stage` | `driftcorrectionstatus` (guarded) | yes |
| `N472` | `targ_*`, `real_*`, `range_*`, `driftcorrectionstatus` | has its own `gui(::N472)` override |

## `gui(::Camera)`

| Field | Read by | Notes |
|---|---|---|
| `unique_id` | `"Unique ID: " * camera.unique_id` and the window title | must be a `String`: `ThorCamCSCCamera` has `unique_id::Vector{UInt8}`, so the concatenation throws |
| `exposure_time` | textbox, `parse(Float64, text)` assigned back | `Float64` on Sim, DCAM4, DCX; `Clonglong` on `ThorCamCSCCamera`, where assigning a non-integer parsed value is an `InexactError` |
| `roi::CameraROI` | textbox reads and assigns `roi.x_start, roi.y_start, roi.width, roi.height`; display sized from `roi.height`, `roi.width` | MC's `CameraROI`, or a type with those four `Int` fields |
| `capture_mode` | dropdown built from `instances(typeof(camera.capture_mode))` | must be an `Enum` |
| `trigger_mode` | same | must be an `Enum` |
| `sequence_length` | textbox, `parse(Int, text)` | |
| `is_running` | live loop `while camera.is_running == 1` | `Bool` or `Int` |

Methods called: `capture` (**its return value is used as the frame**),
`getlastframe` (live loop), `abort`, `live`/`sequence` via
`start_live`/`start_sequence`. `DCAM4Camera`, `SimCamera`, `ThorCamCSCCamera`,
`ThorcamDCXCamera` all carry every field (executed), but **presence is
necessary, not sufficient**: the CSC types above break the panel even though
`hasfield` passes for all seven. Check types, not just names. `[limitation]` the
mode-dropdown callback assigns to a `camera` name outside its scope
(`create_menu`), so the dropdowns are not a reliable way to change mode; and
because `capture(::SimCamera)` returns an enum, "Start Capture" only works for
cameras whose `capture` returns the frame.

## `gui(::LightSource)` and `gui(::Attenuator)`

Read `unique_id` and `properties` (`LightSourceProperties.min_power`,
`max_power`, `power`; `AttenuatorProperties`). Every current light and the
`LCC1620` carry both (executed). `[limitation]` the light panel's slider `lift`
fires on creation, so opening it calls `setpower(light, 0.5)` immediately, then
on every change: opening a GUI is a hardware write.

`gui(::TRIG)` exists for `Triggerscope4`; `MLSLM` has no `gui` at all.
