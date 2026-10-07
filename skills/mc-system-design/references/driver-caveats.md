# Driver-specific caveats (MicroscopeControl.jl v0.2.0)

Companion to `mc-system-design`. Everything here is a **current limitation** of a
specific driver: something a system must work around today, not a pattern to
copy into new code. Rows marked *executed* were run against the Sim devices;
rows marked *traced* were read from the driver source (`types.jl`,
`interface_methods.jl`) and not run, because the hardware is not present.
Re-check this file against `mc-api-map`'s generated `references/api-map.md`
after moving the pinned tag; the map wins on method existence, this file on
behaviour.

## Constructor side effects

"Pure" means the constructor assembles the struct and calls no SDK. The
recommended system policy is that a constructor is pure and `initialize` opens
the connection; the table shows which drivers currently follow it.

| Constructor | Side effect at construction | Cleanup the caller then owes | Source |
|---|---|---|---|
| `SimCamera()`, `SimStage*()`, `SimLight()` | pure | none | executed |
| `PIStage()`, `N472()`, `MCLStage()`, `MCS2Stage()` | pure (`connectionstatus=false`, handle 0) | none until `initialize` | executed (constructors), traced (initialize) |
| `ThorcamDCXCamera()` | pure | none until `initialize` | traced |
| `TCubeLaser(serialNo; daq=NIdaq(), daq_device=nothing, ao_channel=nothing, ...)` | pure; stores the Kinesis serial number, a DAQ handle and (from v0.2.3) the DAQ device/AO channel names `setupIO` should use. `mode` defaults to `ConstantCurrent()` (0.2.x behaviour; closed loop is `mode = ConstantPhotocurrent()`) and the result is a `TCubeLaser{M} <: DiodeLaser` (from 0.2.5). Power mode also requires `max_current` (the clamp `initialize` programs; no default there), `wa_calibration` (W/A at the laser output), `tia_range` (A, the TLD001 DIP switch: `10e-6`, `100e-6`, `1e-3`, `10e-3`), `tec_stabilised` (`Bool` or `missing`) and `properties`, whose `min_power`/`max_power` become enforced mW bounds; the constructor validates them (`max_power` must fit `tia_range * wa_calibration`). `threshold_current` (mA, `NaN` unknown) is optional in both modes. The pre-0.2.5 positional arities still construct, as `ConstantCurrent`. | none until `initialize` | traced |
| `SimDiodeLaser(; mode = ConstantCurrent(), ...)` | pure; the simulated `DiodeLaser`, takes the same keywords with the same requirements as `TCubeLaser`, minus the serial, and its default `properties` are labelled `"mA"` (the same `mode` default, and in `ConstantPhotocurrent` the same required keywords including `max_current`; the ramp and lock keywords are stored, not simulated); every command and read throws before `initialize` and after `shutdown` | none | traced (0.2.5) |
| `Triggerscope4(; portname="COM3")` | creates a `LibSerialPort.SerialPort` object for the port; does not open it | `shutdown`, if `initialize` opened it | traced |
| `LCC1620(; scope=Triggerscope4(), dac_channel=1)` | constructs its own `Triggerscope4` unless you pass `scope`; validates `dac_channel` against `scope.dacoutputs` with `@error` (does not throw) | as for the scope it holds | traced |
| **`DCAM4Camera(dev_id=0)`** | **calls `dcamapi_init` and `dcamdev_open`, reads sensor size and exposure.** The camera is claimed before `initialize`; `initialize(::DCAM4Camera)` is then a no-op. **Fixed in 0.2.1:** both failure paths now throw an `ErrorException` naming the device id and the `DCAMERR` code, instead of returning a non-camera value; on each of those two checked paths the constructor calls `dcamapi_uninit()` before it throws. That is not a general guarantee: an exception raised after `dcamdev_open` succeeds has no cleanup guard, and on the two paths that do clean up the cleanup is only *attempted*: `dcamapi_uninit()` checks its own SDK result and logs an `@error` when it fails, but the constructor ignores that return and throws either way, so a failed uninitialize is visible in the log and nowhere else. (Before 0.2.1, neither failure path returned a camera: if `dcamapi_init` failed the constructor called `dcamapi_uninit` itself and returned the `DCAMERR` code; if init succeeded but `dcamdev_open` failed it `@error`d "Could not open camera" and returned `nothing`, **leaving the DCAM API initialized**.) | On success: `shutdown(cam)` (`dcamdev_close` + `dcamapi_uninit`) even if you never called `initialize`. On an installed copy older than 0.2.1, a `nothing` return needs a manual `MicroscopeControl.HardwareImplementations.DCAM4.dcamapi_uninit()` call, or the next `DCAM4Camera()` in the session starts from a half-initialized SDK; check `cam isa DCAM4Camera` before storing it. | traced (hardware verification: NOT DONE for the 0.2.1 fix — no Hamamatsu camera available) |
| **`ThorCamCSCCamera()`** | **initializes the Thorlabs SDK, discovers cameras, and opens the first one.** The camera is claimed at construction. There is no `initialize` method, so a lifecycle loop that calls `initialize(cam)` throws *after* the device is already open. | `shutdown(cam)` (closes the camera and uninitializes the SDK) | traced |
| **`CrystaLaser()`, `VortranLaser()`, `DaqTrLight(; device_index=2)`** | **construct their own `NIdaq()` and run NI-DAQ device and channel discovery** (`showdevices`, then `showchannels` for AO, then for DO) inside one `try`. Construction always succeeds. Discovery can succeed **partially**: if AO discovery returns and DO discovery throws, the constructor `@warn`s, keeps the AO channel list it already had, and leaves DO empty. `initialize` then **returns normally** regardless of channel lists: Crysta's only sets `is_on = false`; Vortran's additionally `@warn`s "insufficient DO channels for initialization" and returns when fewer than 12 DO channels were found. | none for the DAQ (tasks are per-operation). But inspect `light.channelsAO` and `light.channelsDO` after construction: with an empty list the driver's `setpower`/`light_on`/`light_off` `@warn` and return without doing anything, so a laser can be "initialized" and silently inert. | traced |

So "construct all devices, then initialize" is right for the Sim, PI, MCL, N472,
SmarAct, DCx and TCube devices, and wrong for DCAM4, ThorCam CSC and the three
DAQ-backed lights, which have already talked to hardware by the time the
constructor returns.

## Ordering and ownership

The include order in the upstream `HardwareImplementations.jl` (NIDAQcard before
the light sources, Triggerscope before the attenuator, NIDAQcard before the FPGA)
is **module load order**: a dependent module needs the dependency's type defined
before its own file is compiled. It is not a runtime rule about initialization.
The runtime constraints come from object ownership:

| Dependent | Holds | How the dependency gets there | Required order |
|---|---|---|---|
| `LCC1620` | `scope::Triggerscope4` | keyword `scope=`; defaults to a fresh `Triggerscope4()` on `COM3` | construct the scope first if you want to share it. `initialize(att)` calls `initialize(att.scope)` itself when the scope's port is not open, then sets the DAC range and drives to `min_voltage`. `shutdown(att)` drives the channel to `min_voltage` (0 V, which is **full transmission** on the LCC1620) and leaves the port open. |
| `XEM` (module `OK_XEM`) | `daq::NIdaq` | keyword `daq=`; defaults to `NIdaq()` | none: `NIdaq` holds no connection (tasks are created and deleted per operation, `initialize`/`shutdown` are no-ops) |
| `TCubeLaser` | `daq::NIdaq` for the modulation channel | keyword `daq=` | none, as above. `TCubeLaserControl.setupIO(laser)` creates the AO task and picks the **second** discovered device and its **second** AO channel unless you pass `daq_device=`/`ao_channel=` (those keywords, and a validating error message in place of a bare `BoundsError`, are v0.2.3). **[guarantee]** (0.2.5, traced) `initialize` in `ConstantPhotocurrent` mode is a protected sequence and never enables the output: it requires key switch and interlock; requires the controller's TIA range bits to match `tia_range`; zeroes the setpoint and disables the output first, in both modes and before the mode command (the TLD001 ignores setpoints while the output is off, so `light_on` sends the setpoint right after enabling and `light_off` zeroes it before disabling); leaves the max-current potentiometer at the highest position whose controller-reported limit is `<= max_current` and records that limit in `pd.max_current_clamp`; enters closed loop and verifies the status bit; writes and reads back the W/A factor. Any failed step throws and closes the handle. `light_on` and `setoutputpower!` refuse until the clamp is verified, and re-read the closed-loop bit and the controller's limit before emitting (not yet run on hardware). Both modes start Kinesis polling (50 ms), so the readbacks are cache reads. Hardware-verified on the 642 nm rig (2026-09-28, output off and on): polling refreshes the setpoint cache, the pot needs adjust mode, setpoints only take with the output on. Closed loop verified at 1-70 mW with single-write setpoints; an optional ramp (`RAMP_STEP_mW[]`) is kept because a jump from 0 once locked the controller's loop at ~21 mW, intermittently; see `mc-extend/references/rig-causes.md` |
| `CrystaLaser`, `VortranLaser`, `DaqTrLight` | `daq::NIdaq` | **built internally**; no keyword, cannot be shared | none; each constructor does its own discovery (see side effects) |

Because `NIdaq` is a stateless handle, several devices each holding their own
`NIdaq()` is fine. The only shared *connection* in the package is the
Triggerscope's serial port, so it is the only place where sharing one instance
matters. Two `Triggerscope4` objects for one physical port fight over the COM
port; that is a wiring error, not a driver bug.

## Devices that throw on the lifecycle calls

Each is confirmed by the exception sets in upstream `test/contract.jl`
(`no_initialize`, `no_export_state`, `no_core_methods`):

| Device | Missing | What the call does |
|---|---|---|
| `ThorCamCSCCamera` | `initialize`, `export_state` | throws (`AbstractInstrument`/`Camera` stub, `ErrorException("... not implemented ...")`) |
| `Triggerscope4` | `export_state` | `TRIG` is outside `AbstractInstrument`, so there is no fallback at all: plain `MethodError` (executed: `hasmethod(export_state, Tuple{Triggerscope4})` is `false`) |
| `MLSLM` | `initialize`, `shutdown`, `export_state`, `gui` | `MethodError` for all four (executed) |

`TCubeLaser` was in this table up to v0.2.2: its only `export_state` was
`export_state(::TCubeLaser, sth)`, with an unused second positional argument, so
`export_state(laser)` fell through to the throwing stub. **v0.2.3** adds the
1-argument method — which is the whole fix — and removes the type from
upstream's `no_export_state` exception set. v0.2.3 kept the 2-argument form as a
deprecated forwarder; **[guarantee]** 0.2.5 keeps it, still deprecated and removed
at the next breaking release. The 0.2.5 export ADDS attribute names and keeps
0.2.4's (`min_current`, `max_current`, `power_unit`, `power`, `min_power`,
`max_power`): every mode writes `regulation_mode`, `setpoint_unit` (`"mA"`/`"mW"`), `min_current_mA`,
`max_current_mA`, `controller_max_current`, `threshold_current_mA`,
`drive_current`, `is_on` and the identifiers and DAQ names; `ConstantPhotocurrent`
adds `power_reference` (`"laser output"`), `min_output_power_mW`,
`max_output_power_mW`, `wa_calibration_W_per_A`, `tia_range_A`, `tec_stabilised`
(`"true"`/`"false"`/`"unknown"`), `max_current_clamp_mA`,
`output_power_requested_mW` and `photocurrent_requested_A`. `power` and
`power_unit` are no longer written; a reader of older files must expect either
set.

`XEM` (Opal Kelly FPGA, module `OK_XEM`) is not an `AbstractInstrument` and so
is absent from the API map, but it **does** extend the shared `initialize`
(constructs the FrontPanel handle and opens the board) and `shutdown`
(destructs the handle). It has no `export_state` or `gui`. Absence from the map
means the generator did not walk that type, not that the methods do not exist;
check with `hasmethod`.

## Interface stubs that resolve but do nothing useful

Resolving to a device-specific method is not the same as the operation working:

- `stopmotion(::MCLStage)` is a concrete method whose body is
  `@error "STOP MOTION NOT IMPLEMENTED"` (traced).
- `stopmotion(::SimStage*)` prints a line and does nothing (executed).
- `getposition(::SimStage3d)` returns the last assignment, a single `Float64`
  (`real_z`), not the `(x, y, z)` tuple the interface docstring promises
  (executed: returned `3.0` after `move(s, 1.0, 2.0, 3.0)`). Read `real_*`
  fields instead of the return value on the Sim stages.
- `getposition(::N472)` returns the SDK success code and stores positions in
  `stage.pos`; `move(::N472, pos::Vector{Float64})` takes a vector, not
  `x, y, z` (traced).
- `stopmotion(::N472)` **[fixed in v0.3.0]**: before that release it passed
  `stage.axes` (a `Vector{String}`) where the DLL wants one space-separated
  string, so the halt never reached the controller (traced).
- `initialize(::N472)` / `shutdown(::N472)` **[fixed in v0.3.0]**: `initialize`
  sets `connectionstatus` only after `PI_ConnectUSB` succeeds and leaves the
  object retryable on failure, and throws (after closing the connection) when
  a setup step fails; `shutdown` clears the flag and resets `id` to `-1`.
  Before 0.3.0 a failed connect was reported as "Stage initialized", both a
  retry and a re-initialize after `shutdown` were refused, and a stale `id` of
  `0` could close another object's controller (fake-SDK tests).
- `capture` returns the `SINGLE_FRAME` enum on `SimCamera` and the frame on the
  hardware cameras, and `getdata` after `capture` is valid **only** on
  `SimCamera` (DCAM4 and DCX release their buffers before `capture` returns).
  `mc-acquire` owns this rule and the per-driver table; use its `snap` adapter
  (`snap(::SimCamera)` versus `snap(::Camera)`) rather than a blanket call
  order.
- `light_on(light, power::Float64)` existed up to v0.2.x only as a throwing
  interface stub, tracked upstream as `@test_broken`. **[guarantee]** 0.2.5
  removed it: the stub is now the 1-arg `light_on(light)` every driver
  implements, and the 2-arg call is a `MethodError`.
- `setpower(::DiodeLaser, ::Float64)` (so on `TCubeLaser` and `SimDiodeLaser`)
  resolves: on a `ConstantCurrent` laser it forwards to `setcurrent!` with a
  deprecation warning, on a `ConstantPhotocurrent` laser it throws, naming
  `setoutputpower!` and `setlevel!` (traced, 0.2.5). The mode is fixed at
  construction, so a forwarded call never changes unit. `setlevel!` has methods only for
  `DiodeLaser` **[limitation]**; on the plain lights it is the throwing stub.
- `setlevel!(laser, 0.0)` sets the bottom of the declared range, which is not
  off (in `ConstantCurrent` it is `min_current`, which may be above threshold).
  Use `light_off`.

## Shared GUI facts

Owned by `mc-api-map`'s `references/gui-fields.md` (fields each panel reads,
their types, per-device status). The two that still bite a system author:
`gui(SimStage*())` throws `FieldError` on `stagelabel` (executed);
`gui(::Camera)` uses `capture`'s return value as the frame, so "Start Capture"
misbehaves on `SimCamera`. `MLSLM` has no `gui`; `gui(::TRIG)` exists for
`Triggerscope4`. **Fixed in 0.2.1:** `gui(::LightSource)` used to call
`setpower(light, 0.5)` on open (executed against a fake-transport light);
opening **the shared light panel** is now observably read-only. That is the
whole scope of the fix -- `gui(::DAQ)` still queries `showdevices` and
`showchannels` at construction. From 0.2.5 a `DiodeLaser` opens its own panel
(`current_panel` or `power_panel`, by mode), which issues no command and no read
on open **[guarantee]**.

## `save_h5` facts

- The root group is always `Main`. Device groups take the `children` keys you chose.
- `save_h5(filename, state_tuple)` takes the **tuple**, not the device, and
  returns a `Task` (`@async`). `wait` it before reading the file or exiting.
  `save_attributes_and_data(filename, "Main", attributes, data, children)` is
  the synchronous form.
- The file is opened with `"w"`, so each save overwrites.
- `data` goes to a dataset named `data` in the node's group. For 2-D and 3-D
  arrays it gets attributes `dimension_order` (`"HW"` or `"HWN"`),
  `dimension_labels` and `memory_layout = "column_major_julia"`. Save
  `(H, W, N)` arrays directly.
- `Bool` attributes are written as `Float64` (`is_on` reads back as `0.0`); executed.
- `Tuple` attributes fail in HDF5; the Sim stages `collect` their range tuples.
  Do the same in your own `attributes`.
- A `children` value must be an `(attributes, data, children)` tuple, never a
  device object: `save_group_recursive` destructures it.
