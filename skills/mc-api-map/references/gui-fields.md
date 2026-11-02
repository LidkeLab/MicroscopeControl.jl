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
`hasfield` passes for all seven. Check types, not just names. **[guarantee]**
the capture dropdown changes `capture_mode` and the trigger dropdown changes
`trigger_mode`; each callback receives the camera and updates only its selected field.
**[limitation]** because `capture(::SimCamera)` returns an enum, "Start Capture"
only works for cameras whose `capture` returns the frame.

## `gui(::LightSource)` and `gui(::Attenuator)`

**[guarantee]** (0.2.7) The light panel reads `unique_id` and
`properties.is_on`; plain lights use `properties.min_power`, `max_power`,
`power` and `power_unit`. `CrystaLaser`, `VortranLaser` and `DaqTrLight` use
`min_voltage`, `max_voltage`, `level_requested` and unit `V`, independent of
`properties.power`. The attenuator panel continues to read `unique_id` and
`AttenuatorProperties`.

**[guarantee]** Opening the light panel issues no command. The slider spans
the full native range; a NaN or out-of-range start falls back to the bottom.
The textbox accepts only numbers within those bounds. Each submission issues
one guarded command, including repeats of the displayed value and retries after
failure; slider synchronization does not issue a second command. The textbox
follows slider changes. A refusal or transport failure appears in the panel,
with the output toggle corrected to the driver's state after level and output
commands. The requested line refreshes after toggle commands, including when
an unstaged single-line light enables at the clamped 1.0 V default.
**[guarantee]** Generic `gui(::LightSource)` returns the displayed
`GLMakie.Screen`; the diode panels return their figure. **[limitation]** closing a panel leaves its light as it was.
**[policy]** call `lights_off(lights)` during teardown and report every named
failure from `MicroscopeControl.LightsOffError.failures`.

**[guarantee]** This panel serves the lights that are not a `DiodeLaser`
(`CrystaLaser`, `VortranLaser`, `DaqTrLight`, `SimLight`); a `DiodeLaser` has its
own panel below. `gui(::DAQ)` still queries `showdevices`/`showchannels` at
construction **[limitation]**.

## `gui(::DiodeLaser)` (0.2.5)

Dispatches on `regulation_mode(laser)` to `current_panel` (`ConstantCurrent`:
slider in mA over `min_current .. effective_max_current(laser)`, calling
`setcurrent!`) or `power_panel` (`ConstantPhotocurrent`: slider in mW **at the
laser output** over `properties.min_power .. max_power`, calling
`setoutputpower!`, with a basis line naming `wa_calibration`, the TIA range and
the TEC state; the range is printed as `[lo mW - hi mW]`). Enumerated from
`lightsource_interface/diode_laser_gui.jl`; `TCubeLaser` and `SimDiodeLaser`
carry every field.

| Field | Read by | Notes |
|---|---|---|
| `unique_id::String` | header label and window title | both panels |
| `properties.is_on` | initial state of the on/off toggle | both panels; the toggle, not the slider's bottom, is "off" |
| `properties.min_power`, `max_power` | slider range and textbox bounds | `power_panel` only; mW at the laser output |
| `min_current` | slider floor | `current_panel` only |
| `effective_max_current(laser)` (a method) | slider ceiling | `current_panel` only; falls back to `max_current`, `TCubeLaser` takes the smallest of `max_current`, `controller_max_current`, `max_setcurrent` |
| `threshold_current` | header text (`"unknown"` when `NaN`) | `current_panel`; also `loop_status`'s `below_threshold` |
| `drive_current` | slider start and "commanded" line | `current_panel` only |
| `pd.wa_calibration`, `pd.tia_range`, `pd.tec_stabilised` | basis line; `wa_calibration` also for the readout's indicated power | `power_panel` only |
| `pd.output_power_requested`, `pd.photocurrent_requested` | slider start and "commanded" line | `power_panel` only |

`properties.power` is **not** read by either panel.

Methods called, each only on a user action: `setcurrent!`/`setoutputpower!` (slider
or textbox), `light_on`/`light_off` (toggle), `loop_status` (the Read button, or
the Poll toggle at 2 Hz, which stops when turned off or the window closes).

`[guarantee]` Opening either panel issues **no command and no read**: the readout
shows "not read yet" until Read is pressed or Poll (off at construction) is
turned on. On a `SimDiodeLaser` this is checkable: `laser.log` gains nothing when
the panel opens. `[guarantee]` The textbox accepts only a number within the
slider's range, the same bounds the driver enforces; anything else is not
applied and the border turns red. Each submission issues exactly one guarded
command, including when the slider position stays the same; the textbox follows
slider changes. The "commanded" line is refreshed from the device's fields only after
the command returns, and a refusal is shown in the panel as `refused: <message>`,
not thrown out of the callback.

`gui(::TRIG)` exists for `Triggerscope4`; `MLSLM` has no `gui` at all.
