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
2. **Construction is not connection.** Every device is built with its own
   constructor (keyword arguments, all defaulted for the Sim devices) and does
   nothing to hardware until `initialize(dev)`. Exceptions are noted below.
3. **Some devices own another device.** They must receive an already-constructed
   (and for hardware, already-initialized) dependency. See "Ordering".

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

## Ordering

The include order in `src/hardware_implementations/HardwareImplementations.jl`
encodes real dependencies. The same order applies to constructing and initializing
your devices:

| Construct and initialize first | Then | Why |
|---|---|---|
| `NIdaq` | `DaqTrLight` (field `daq::NIdaq`) | The transmission light drives an analog-output channel on the shared card. `NIdaq` has no-op `initialize`/`shutdown`; DAQmx tasks are created and deleted per operation. |
| `NIdaq` | `XEM` FPGA (module `OK_XEM`, field `daq::NIdaq`, defaults to `NIdaq()`; `XEM` is not an `AbstractInstrument`, so it has no lifecycle generics and is absent from the API map) | The FPGA module uses the card for I/O. |
| `Triggerscope4` | `LCC1620` attenuator (field `scope::Triggerscope4`, `dac_channel::Int`) | The attenuator sets its drive voltage through a Triggerscope DAC channel. |

Pass one shared instance, not a fresh default per dependent. `LCC1620()` with no
`scope` argument constructs its own `Triggerscope4()`, and `Triggerscope4()`
defaults to `portname="COM3"` and builds a `LibSerialPort.SerialPort` for it in the
constructor. Two Triggerscope objects for one physical port is a fight over the COM
port, not a driver bug.

Independent devices (cameras, stages, lasers on their own serial port or SDK) have
no ordering constraint among themselves. Initialize them in the order that makes
the failure mode cheapest: light sources off, then stages, then cameras is a
reasonable default. Shut down in the reverse order so a dependent releases the
shared device before the shared device closes.

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
`initialize`/`shutdown`/`export_state`.

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
