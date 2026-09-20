---
name: mc-wire-device
description: Procedure for composing a MicroscopeControl.jl device into a downstream instrument struct -- field, constructor, initialize/shutdown order, dependency constraints, gui entry, export_state children and save_h5; activates for "add a device", "wire up a stage/camera/laser", "system struct", or "instrument setup".
---

# mc-wire-device

Downstream repos compose devices into an instrument; they do not write drivers.
The unit of composition is a mutable struct holding constructed device instances.
Every code block below was executed against the simulated devices on
MicroscopeControl.jl v0.2.0.

## What bites first

1. **Interface fallbacks throw.** Since v0.1.0, `initialize`, `shutdown`,
   `export_state` and the per-interface stubs raise
   `ErrorException("... not implemented for <Type>")` instead of logging and
   returning `nothing`. A `shutdown` loop that hits one unimplemented device
   aborts the rest of the loop and leaves hardware open. Guard every call.
2. **Some constructors open hardware.** Most device constructors only fill a struct
   and touch nothing until `initialize(dev)`, but not all. See "Constructor side
   effects" below before writing a constructor-only setup path.
3. **Some devices own another device.** They take an already-constructed dependency
   as a keyword argument, or build their own. See "Ordering and ownership".

## The composition pattern

```julia
using MicroscopeControl
const MC = MicroscopeControl

mutable struct BenchState <: AbstractSystemState
    exposure_time::Float64
    z::Float64
end

mutable struct Bench <: AbstractSystem
    cam::SimCamera
    stage::SimStage3d
    laser::SimLight
end

# devices constructed here; nothing touches hardware yet
Bench() = Bench(SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32)),
                SimStage3d(),
                SimLight())

function MC.initialize(sys::Bench)
    initialize(sys.laser)
    initialize(sys.stage)
    initialize(sys.cam)
end

function MC.shutdown(sys::Bench)
    for dev in (sys.cam, sys.stage, sys.laser)          # reverse of initialize
        try
            shutdown(dev)
        catch e
            @warn "shutdown failed" typeof(dev) e
        end
    end
end

MC.get_state(sys::Bench) = BenchState(sys.cam.exposure_time, sys.stage.targ_z)

function MC.set_state(sys::Bench, st::BenchState)
    sys.cam.exposure_time = st.exposure_time
    move(sys.stage, sys.stage.targ_x, sys.stage.targ_y, st.z)
end

sys = Bench()
initialize(sys)
set_state(sys, BenchState(0.02, 7.5))
get_state(sys)            # BenchState(0.02, 7.5)
shutdown(sys)
```

Notes on the pattern:

- `AbstractSystem`, `AbstractSystemState`, `get_state`, `set_state` are exported.
  Subtyping `AbstractSystem` is optional but gives you the `initialize`/`shutdown`/
  `export_state`/`get_state`/`set_state` generics to extend, so the same verbs
  work on the instrument and on each device.
- The `AbstractSystem` fallbacks are the one place that still uses `@error` and
  returns `nothing` rather than throwing. Forgetting to define `MC.initialize(::Bench)`
  logs an error and continues silently. Define all five.
- Extend the generics with the `MC.` prefix (or `import MicroscopeControl: initialize`).
  An unqualified `function initialize(sys::Bench)` after a bare `using` creates a
  new local function that shadows the real one; `MC.initialize(sys)` from other
  code then hits the fallback.
- Concrete field types (`cam::SimCamera`) are fine for a fixed rig. Use the interface
  types (`cam::Camera`, `stage::Stage`, `laser::LightSource`) when the same struct must
  hold a Sim device in tests and hardware on the rig (see `mc-sim-testing`).
- `move` takes `Float64`. `move(stage, 1, 2, 3)` is a `MethodError`.

## Constructor side effects

Traced from each driver's `types.jl`; the Sim constructors were executed. "Pure"
means the constructor assembles the struct and calls no SDK.

| Constructor | Side effect at construction | Cleanup the caller then owes |
|---|---|---|
| `SimCamera()`, `SimStage*()`, `SimLight()` | pure | none |
| `PIStage()`, `N472()`, `MCLStage()`, `MCS2Stage()` | pure (`connectionstatus=false`, handle 0) | none until `initialize` |
| `ThorcamDCXCamera()` | pure | none until `initialize` |
| `TCubeLaser(serialNo; daq=NIdaq())` | pure; stores the Kinesis serial number and a DAQ handle | none until `initialize` |
| `Triggerscope4(; portname="COM3")` | creates a `LibSerialPort.SerialPort` object for the port | `shutdown`, if `initialize` opened it |
| `LCC1620(; scope=Triggerscope4(), dac_channel=1)` | constructs its own `Triggerscope4` unless you pass `scope`; validates `dac_channel` against `scope.dacoutputs` | as for the scope it holds |
| **`DCAM4Camera(dev_id=0)`** | **calls `dcamapi_init` and `dcamdev_open`, reads sensor size and exposure.** The camera is claimed before `initialize`. Two failure paths, neither returns a camera: if `dcamapi_init` fails, the constructor calls `dcamapi_uninit` itself and returns the `DCAMERR` code; if init succeeds but `dcamdev_open` fails, it `@error`s "Could not open camera" and returns **`nothing`, leaving the DCAM API initialized**. | On success: `shutdown(cam)` (`dcamdev_close` + `dcamapi_uninit`) even if you never called `initialize`. On a `nothing` return: call `MicroscopeControl.HardwareImplementations.DCAM4.dcamapi_uninit()` yourself, or the next `DCAM4Camera()` in the session starts from a half-initialized SDK. Check `cam isa DCAM4Camera` before storing it. |
| **`ThorCamCSCCamera()`** | **initializes the Thorlabs SDK, discovers cameras, and opens the first one.** The camera is claimed at construction. There is no `initialize` method, so a lifecycle loop that calls `initialize(cam)` throws *after* the device is already open. | `shutdown(cam)` (closes the camera and uninitializes the SDK) |
| **`CrystaLaser()`, `VortranLaser()`, `DaqTrLight(; device_index=2)`** | **construct their own `NIdaq()` and run NI-DAQ device and channel discovery** (`showdevices`, then `showchannels` for AO, then for DO) inside one `try`. Construction always succeeds. Discovery can succeed **partially**: if AO discovery returns and DO discovery throws, the constructor `@warn`s, keeps the AO channel list it already had, and leaves DO empty. `initialize` then **returns normally** regardless of channel lists, which is not the same as leaving the device usable: Crysta's only sets `is_on = false`; Vortran's additionally `@warn`s "insufficient DO channels for initialization" and returns when fewer than 12 DO channels were found. | none for the DAQ (tasks are per-operation). But inspect `light.channelsAO` and `light.channelsDO` after construction: with an empty list the driver's `setpower`/`light_on`/`light_off` `@warn` and return without doing anything, so a laser can be "initialized" and silently inert. |

So "construct all devices, then initialize" is right for the Sim, PI, MCL, N472,
SmarAct, DCx and TCube devices, and wrong for DCAM4, ThorCam CSC and the three
DAQ-backed lights, which have already talked to hardware by the time the constructor
returns. Check the return type of `DCAM4Camera()` before storing it in a typed field.
Guard construction the same way as shutdown if a partially built system must clean
up after a failed constructor.

## Ordering and ownership

The include order in `src/hardware_implementations/HardwareImplementations.jl`
(NIDAQcard before the light sources, Triggerscope before the attenuator, NIDAQcard
before the FPGA) is **module load order**: a dependent module needs the dependency's
type defined before its own file is compiled. It is not a runtime rule about
initialization. The runtime constraints come from object ownership:

| Dependent | Holds | How the dependency gets there | Required order |
|---|---|---|---|
| `LCC1620` | `scope::Triggerscope4` | keyword `scope=`; defaults to a fresh `Triggerscope4()` on `COM3` | construct the scope first if you want to share it. `initialize(att)` calls `initialize(att.scope)` itself when the scope's port is not open, then sets the DAC range and drive voltage. |
| `XEM` (module `OK_XEM`) | `daq::NIdaq` | keyword `daq=`; defaults to `NIdaq()` | none: `NIdaq` holds no connection (tasks are created and deleted per operation, `initialize`/`shutdown` are no-ops) |
| `TCubeLaser` | `daq::NIdaq` for the modulation channel | keyword `daq=` | none, as above |
| `CrystaLaser`, `VortranLaser`, `DaqTrLight` | `daq::NIdaq` | **built internally**; no keyword, cannot be shared | none; each constructor does its own discovery (see side effects) |

Because `NIdaq` is a stateless handle, several devices each holding their own
`NIdaq()` is fine. The only shared *connection* in the package is the Triggerscope's
serial port, so it is the only place where sharing one instance matters:

```julia
ts  = Triggerscope4(portname="COM5")            # one object for the physical port
att = LCC1620(scope=ts, dac_channel=3)          # shares it; LCC1620() alone would build a second Triggerscope4 on COM3
initialize(att)                                 # opens the scope if needed, then configures the DAC channel
```

Signatures traced from `lcc1620_attenuator/types.jl` and `triggerscope/types.jl`;
not executed (no serial port here). Two `Triggerscope4` objects for one physical port
fight over the COM port; that is a wiring error, not a driver bug.

Recommended, not required, order for the rest: light sources off first, then stages,
then cameras, so the failure mode of an aborted setup is cheapest. Shut down in the
reverse order so a dependent releases the shared device before the shared device
closes.

## Devices that throw on the lifecycle calls (v0.2.0)

Wrap every `shutdown`/`export_state` call in `try`/`catch` while these exist. Each
is confirmed in `test/contract.jl` upstream:

| Device | Missing | What the call does |
|---|---|---|
| `ThorCamCSCCamera` | `initialize`, `export_state` | throws (`AbstractInstrument`/`Camera` stub) |
| `TCubeLaser` | 1-arg `export_state` | defined as `export_state(::TCubeLaser, sth)`; `export_state(laser)` falls through and throws |
| `Triggerscope4` | `export_state` | throws (`TRIG` is outside `AbstractInstrument`; no fallback at all, plain `MethodError`) |
| `MLSLM` | `initialize`, `shutdown`, `export_state`, `gui` | `MethodError` for all four |

The Sim devices, `DCAM4Camera`, `PIStage`, `MCLStage`, `N472`, `MCS2Stage`,
`NIdaq`, `LCC1620`, and the four other light sources implement all of
`initialize`/`shutdown`/`export_state`. `XEM` (Opal Kelly FPGA, module `OK_XEM`) is
not an `AbstractInstrument` and so is absent from the API map, but it **does** extend
the shared `initialize` (constructs the FrontPanel handle and opens the board) and
`shutdown` (destructs the handle). Call both. It has no `export_state` or `gui`.
Absence from the map means the generator did not walk that type, not that the
methods do not exist; check with `hasmethod`.

## `gui`

One generic. `gui(dev)` for any device dispatches to the interface-level GUI
(`gui(::Camera)`, `gui(::Stage)` with its dimension switch, `gui(::LightSource)`,
`gui(::DAQ)`, `gui(::Attenuator)`, `gui(::TRIG)`), or to a driver override where one
exists (`N472`). A system menu is therefore a list of `gui(sys.<field>)` calls, one
per device. The aliases `laser_488_gui`, `nidaq_gui`, etc. are the same function
object; do not use them in new code. Each `gui` opens a GLMakie window, so it needs a
display (see `mc-sim-testing` for `xvfb-run`). `MLSLM` has no `gui`.

## `export_state` and `save_h5`

Every device returns `(attributes::Dict{String,Any}, data, children::Dict{String,Any})`.
A system aggregates by putting each device's tuple under a name in `children`;
`save_h5` then walks the tree, one HDF5 group per node.

```julia
function MC.export_state(sys::Bench)
    attributes = Dict{String,Any}("system" => "Bench", "julia" => string(VERSION))
    children = Dict{String,Any}(
        "camera" => export_state(sys.cam),
        "stage"  => export_state(sys.stage),
        "laser"  => export_state(sys.laser))
    return attributes, nothing, children
end

sys = Bench(); initialize(sys)
attributes, data, children = export_state(sys)

# save_h5 takes the TUPLE, not the device, and runs on an @async Task
t = save_h5("bench.h5", (attributes, stack, children))   # stack :: Array{UInt16,3} (H, W, N)
wait(t)                                                   # or the file may not exist yet

MC.HDF5.h5open("bench.h5", "r") do h
    keys(h["Main"])                                       # ["camera", "data", "laser", "stage"]
    MC.HDF5.attrs(h["Main/camera"])["roi_width"]          # 64
    ds = h["Main/data"]
    size(ds)                                              # (32, 64, 5)
    MC.HDF5.attrs(ds)["dimension_order"]                  # "HWN"
end
```

Facts worth knowing before you rely on the file:

- The root group is always `Main`. Device groups take the `children` keys you chose.
- `save_h5(filename, state_tuple)` returns a `Task`. `wait` it before reading or
  before the process exits. `save_attributes_and_data(filename, "Main", attributes,
  data, children)` is the synchronous form.
- The file is opened with `"w"`, so each save overwrites.
- `data` is written to a dataset named `data` in the node's group. For 2-D and 3-D
  arrays the dataset gets attributes `dimension_order` (`"HW"` or `"HWN"`),
  `dimension_labels` and `memory_layout = "column_major_julia"`. Save `(H, W, N)`
  arrays directly; no transform.
- `Bool` attributes are written as `Float64` (`is_running` reads back as `0.0`).
- `Tuple` attributes fail in HDF5; the Sim stage converts its range tuples with
  `collect` before returning them. Do the same in your own `attributes`.
- `export_state` on a device that lacks it throws (table above). Guard the
  aggregation the same way as `shutdown`, or omit that child.
