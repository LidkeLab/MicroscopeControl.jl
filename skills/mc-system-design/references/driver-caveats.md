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
| `TCubeLaser(serialNo; daq=NIdaq(), daq_device=nothing, ao_channel=nothing)` | pure; stores the Kinesis serial number, a DAQ handle and (from v0.3.0) the DAQ device/AO channel names `setupIO` should use | none until `initialize` | traced |
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
| `TCubeLaser` | `daq::NIdaq` for the modulation channel | keyword `daq=` | none, as above. `TCubeLaserControl.setupIO(laser)` creates the AO task and picks the **second** discovered device and its **second** AO channel unless you pass `daq_device=`/`ao_channel=` (those keywords, and a validating error message in place of a bare `BoundsError`, are v0.3.0) |
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
`export_state(laser)` fell through to the throwing stub. **v0.3.0** drops the
argument and removes the type from upstream's `no_export_state` exception set.

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
- `capture` returns the `SINGLE_FRAME` enum on `SimCamera` and the frame on the
  hardware cameras, and `getdata` after `capture` is valid **only** on
  `SimCamera` (DCAM4 and DCX release their buffers before `capture` returns).
  `mc-acquire` owns this rule and the per-driver table; use its `snap` adapter
  (`snap(::SimCamera)` versus `snap(::Camera)`) rather than a blanket call
  order.
- `light_on(light, power::Float64)` exists only as a throwing interface stub;
  every driver implements the 1-arg `light_on(light)`. Upstream tracks this as
  `@test_broken` (executed: the `light_on` method table has only 1-arg driver
  methods).

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
`showchannels` at construction.

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
