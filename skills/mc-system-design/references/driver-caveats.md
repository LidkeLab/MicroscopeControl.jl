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
| `TCubeLaser(serialNo; daq=NIdaq())` | pure; stores the Kinesis serial number and a DAQ handle | none until `initialize` | traced |
| `Triggerscope4(; portname="COM3")` | creates a `LibSerialPort.SerialPort` object for the port; does not open it | `shutdown`, if `initialize` opened it | traced |
| `LCC1620(; scope=Triggerscope4(), dac_channel=1)` | constructs its own `Triggerscope4` unless you pass `scope`; validates `dac_channel` against `scope.dacoutputs` with `@error` (does not throw) | as for the scope it holds | traced |
| **`DCAM4Camera(dev_id=0)`** | **calls `dcamapi_init` and `dcamdev_open`, reads sensor size and exposure.** The camera is claimed before `initialize`; `initialize(::DCAM4Camera)` is then a no-op. Two failure paths, neither returns a camera: if `dcamapi_init` fails the constructor calls `dcamapi_uninit` itself and returns the `DCAMERR` code; if init succeeds but `dcamdev_open` fails it `@error`s "Could not open camera" and returns **`nothing`, leaving the DCAM API initialized**. | On success: `shutdown(cam)` (`dcamdev_close` + `dcamapi_uninit`) even if you never called `initialize`. On a `nothing` return: call `MicroscopeControl.HardwareImplementations.DCAM4.dcamapi_uninit()` yourself, or the next `DCAM4Camera()` in the session starts from a half-initialized SDK. Check `cam isa DCAM4Camera` before storing it. | traced |
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
| `TCubeLaser` | `daq::NIdaq` for the modulation channel | keyword `daq=` | none, as above |
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
| `TCubeLaser` | 1-arg `export_state` | defined as `export_state(::TCubeLaser, sth)`; `export_state(laser)` falls through and throws |
| `Triggerscope4` | `export_state` | `TRIG` is outside `AbstractInstrument`, so there is no fallback at all: plain `MethodError` (executed: `hasmethod(export_state, Tuple{Triggerscope4})` is `false`) |
| `MLSLM` | `initialize`, `shutdown`, `export_state`, `gui` | `MethodError` for all four (executed) |

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
- `capture(::SimCamera)` returns the `SINGLE_FRAME` enum value (the result of
  the assignment); `capture(::DCAM4Camera)` returns the frame it read via
  `getlastframe` (executed / traced). Code that does `frame = capture(cam)`
  works on one and not the other; use `capture` then `getlastframe`/`getdata`.
- `light_on(light, power::Float64)` exists only as a throwing interface stub;
  every driver implements the 1-arg `light_on(light)`. Upstream tracks this as
  `@test_broken` (executed: the `light_on` method table has only 1-arg driver
  methods).

## Shared GUI facts that bite a system author

- `gui(::Stage)` dispatches on `stage.dimensions` to `gui1d`/`gui2d`/`gui3d`
  and reads the `targ_*`, `real_*`, `range_*` fields for those dimensions, and
  **`stagelabel`** for the window title (unguarded). The Sim stages carry
  `label`, not `stagelabel`, so **`gui(SimStage1d/2d/3d())` throws a
  `FieldError` at v0.2.0** (executed). `gui(PIStage())`, `gui(MCLStage())`
  and `gui(MCS2Stage())` open without hardware (executed; they are pure
  constructors). `servostatus`/`driftcorrectionstatus` are read behind
  `hasfield` checks, so their absence is fine.
- `gui(::LightSource)` calls `setpower(light, 0.5)` as soon as the window
  opens (the slider `lift` fires on creation with the start value 0.5), then
  `setpower`/`light_on`/`light_off` on every widget change. Opening a panel
  is a hardware write, not a read (traced from `lightsource_interface/gui.jl`;
  executed against a downstream light whose transport was closed, which threw
  from inside `gui`).
- `gui(::Camera)`'s capture-mode/trigger-mode menus are built from
  `instances(typeof(camera.capture_mode))`, so those fields must be `Enum`s.
  The menu callback assigns to a `camera` name that is not in its scope
  (traced from `camera_interface/gui.jl`, `create_menu`); selecting a menu
  entry is not a reliable way to change mode.
- `gui` for `MLSLM` does not exist; `gui(::TRIG)` exists for `Triggerscope4`.

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
