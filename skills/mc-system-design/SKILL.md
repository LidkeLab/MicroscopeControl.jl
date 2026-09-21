---
name: mc-system-design
description: Entry point for building an instrument control system out of MicroscopeControl.jl components -- the driver/system responsibility split, the upstream/downstream boundary test, the decision rule for driver vs interface vs system code, the six design principles the source actually expresses, the three kinds of state, and a worked composition example with rollback, acquisition ownership and provenance; activates for "design the system", "system struct", "add a device", "wire up a stage/camera/laser", "instrument setup", "who owns", or "architecture".
---

# mc-system-design

Start here. This skill teaches how to decide, not how to call; the other
skills carry the procedures and this one routes to them. It is written for a
downstream repo that composes MicroscopeControl.jl (MC) devices into one
instrument and cannot see MC's source. Where it cites upstream files it is
giving provenance, not asking you to go and read them.

## How to read this skill

Every architectural statement carries one of three labels. Do not let one be
read as another.

- **[guarantee]** the current code does this; verified against MC v0.2.0
  (executed against the Sim devices, or traced in the driver source and marked
  so).
- **[limitation]** the current code falls short of its own design here; work
  around it, never copy it.
- **[policy]** a recommendation for the system you are building. MC does not
  enforce it and nothing breaks if you ignore it, except your instrument.

## Where to go

| You want to | Skill |
|---|---|
| know which methods a device type actually has at the pinned version | `mc-api-map` |
| capture, sequence, live view, z-stacks, array conventions | `mc-acquire` |
| validate the composed system without hardware, then list what hardware acceptance must establish | `mc-testing` |
| a driver misbehaves on hardware; report it and work around it; implement an existing interface for a new device; define a new device class | `mc-extend` (in that order of commitment) |
| per-driver constructor side effects, ownership, missing lifecycle methods, GUI and HDF5 facts | `references/driver-caveats.md` beside this file |

## The responsibility split

This is the spine. A driver adapts one device to MC's generics. The system
gives the assembled instrument its meaning. Neither can do the other's job.

| Concern | The driver guarantees | The system must own or verify |
|---|---|---|
| **Physical connection** | which object holds the handle, and whether the constructor or `initialize` opens it. **[limitation]** this differs per driver: DCAM4 and ThorCam CSC open in the constructor; PI, MCL, N472, SmarAct, DCx, TCube and the Sims open in `initialize`; see `references/driver-caveats.md`. | one owner per physical port or SDK session; every other holder borrows. Construct the shared object once and pass it in. |
| **Readiness** | `initialize` returns without throwing when its own steps ran. **[limitation]** a normal return is not readiness: `initialize(::CrystaLaser)` only sets `is_on = false` and succeeds with an empty channel list; `initialize(::DCAM4Camera)` is a no-op because the constructor did the work. | **[policy]** verify after `initialize`: read a position, check `connectionstatus`, inspect channel lists, or take one frame. Decide what "ready" means for each device and check it. |
| **Background tasks** | a driver may start one (`sequence(::SimCamera)` spawns an `@async` task that flips `is_running` back to `false`). | **[policy]** exactly one system-level task owns the camera while an acquisition runs; manual controls and `set_state` ask it or are refused. The system also joins that task before `shutdown` and before changing configuration. |
| **State** | the device's own fields (`exposure_time`, `roi`, `targ_x`, `properties.power`) are the configuration the driver pushes to hardware; **[guarantee]** shared code reads those fields by name (see Principle 2). | the instrument-level configuration (`AbstractSystemState`), when it is captured, and which fields are requested values versus measured ones (see "Three kinds of state"). |
| **Failure recovery** | **[guarantee]** since v0.1.0 the interface stubs throw `ErrorException("... not implemented for T")` instead of returning `nothing`; drivers mostly `@warn`/`@error` and return on hardware errors. **[limitation]** the `AbstractSystem` fallbacks still `@error` and return `nothing`. | **[policy]** rollback on partial initialization, a shutdown that reports what it could not close, and a saved record that says what is missing. All three are in the worked example below; none is provided by MC. |
| **Units, axes, conventions** | its own: PI in millimetres, MCL in micrometres, Sim stages unitless (0..100); cameras return `(H, W)` / `(H, W, N)` arrays **[guarantee]** for Sim and DCAM4 (executed / traced). | **[policy]** one normalisation layer in the system (a function per device, not a conversion at every call site). |
| **Persistence** | a one-argument `export_state` returning `(attributes, data, children)` **[guarantee]** for every device except those in the caveats file **[limitation]**. | assembling the tree, choosing the child names, deciding when to snapshot, and recording incomplete exports (see Principle 5 and the worked example). |

## The boundary test: upstream or downstream?

Ask: **would this code still make sense on another microscope using the same
device?** If yes, it is reusable hardware support and its destination is
upstream (a driver or an interface). If it names relationships between the
components of *this* instrument (which DAC channel, which COM port, which laser
sits behind which attenuator, the acquisition order), it is system policy and
belongs in your repo.

Two qualifications:

1. **Composition alone does not make something glue.** `LCC1620` is a reusable
   attenuator driver even though it is composed with a `Triggerscope4`: its
   drive-voltage behaviour belongs upstream. "This rig's SLM-path attenuator is
   on DAC 3 of the scope on COM5" belongs downstream. Likewise a calibration
   table and its interpolation (`set_calibration!`, `settransmission`) are
   driver behaviour; the measurement procedure and the measured numbers are the
   rig's.
2. **Current upstream drivers already cross this boundary. [limitation]**
   `CrystaLaser()`, `VortranLaser()` and `DaqTrLight()` each construct their own
   `NIdaq()`, take the **first** discovered device and write the **first** AO
   channel (`light.channelsAO[1]`). Those are wiring assumptions baked into a
   reusable implementation (traced from `crysta_laser_561/types.jl` and
   `interface_methods.jl`). Work around them (they cannot share a DAQ object and
   you cannot choose the channel) and do **not** copy the pattern into a new
   driver: take the dependency as a keyword argument and the channel as a field,
   as `LCC1620(; scope, dac_channel)` and `TCubeLaser(serialNo; daq)` do.

Writing a driver downstream for a device you own, and extending MC's generics
for **your own type**, is legitimate and is not type piracy. `mc-extend`
draws the line: piracy is redefining a method for a type MC owns.

## The decision rule

| The code | It is a | Example | Go to |
|---|---|---|---|
| translates an operation that an existing interface already names (`move`, `capture`, `setpower`, `settransmission`) into one controller's SDK or protocol, including its units, conversions and connection handling | **new driver** (implementation of an existing interface) | a new camera model: a `Camera` subtype with `capture`/`getdata`/... over its vendor SDK | `mc-extend`, section 3 |
| defines operations and semantics for a device class none of `Camera`, `Stage`, `LightSource`, `DAQ`, `Attenuator` can reasonably express, and at least one concrete device plus a simulated one will implement them | **new interface** | a mechanical shutter with `open_shutter!`/`close_shutter!`/`is_open` and a switching time | `mc-extend`, section 4 |
| chooses this rig's devices, ports, channels, calibration values, optical relationships, acquisition order, coordination or user workflow | **system code** in your repo | "laser off, then stage, then camera; refuse `set_state` during an acquisition; attenuator on DAC 3" | this skill |

The bar for a new interface is high: forcing a device into a nearby interface
(a shutter as a `LightSource` with `light_on`/`light_off`) is often the right
call, because a shared interface is what gives you the Sim substitution and the
GUI for free. Define a new one only when the nearest interface would lie about
what the device does.

## Six design principles the source expresses

Each is stated as what the code does today; the label says how far to trust it.

1. **Category interfaces, then device implementations, then downstream
   composition. [guarantee]** `src/MicroscopeControl.jl` defines
   `AbstractInstrument` and the five generics (`initialize`, `shutdown`,
   `export_state`, `gui`, plus `get_state`/`set_state` for systems), then
   `@reexport`s `HardwareInterfaces` (abstract types and throwing stubs) and
   `HardwareImplementations` (concrete drivers). Interfaces are
   `interface_types.jl` / `interface_functions.jl` / `gui.jl`; drivers are
   `types.jl` / `interface_methods.jl`. There is no registration framework:
   adding a method to the shared generic *is* the registration.

2. **Devices carry state in FIELDS and shared code depends on those field
   names, not only on methods. [guarantee]** `gui(::Stage)`
   (`stage_interface/gui.jl`) reads `dimensions`, `connectionstatus`,
   `targ_x/y/z`, `real_x/y/z`, `range_x/y/z`, `stagelabel`; `gui(::Camera)`
   (`camera_interface/gui.jl`) reads `unique_id`, `exposure_time`, `roi`,
   `capture_mode`, `trigger_mode`, `sequence_length`, `is_running`; the light
   and attenuator panels read `unique_id` and `properties`. A device that
   satisfies the method contract but lacks a field cannot use the inherited
   panel. **[limitation]** the Sim stages have `label` where the GUI wants
   `stagelabel`, so `gui(SimStage3d())` throws a `FieldError` (executed at
   v0.2.0). Full field lists are in `mc-api-map`'s `references/gui-fields.md`.

3. **`AbstractSystem`/`AbstractSystemState` are separate from
   `AbstractInstrument`, with no automatic traversal. [guarantee]**
   `src/instrument.jl` declares both abstract types and five generics whose
   fallbacks `@error` and return `nothing`. Nothing walks your struct's fields,
   initializes them in order, applies a state, or unwinds a failure. Lifecycle
   and configuration policy are therefore **downstream by design**: subtyping
   `AbstractSystem` gives you the verbs (so `initialize(sys)` and
   `initialize(sys.cam)` read the same) and nothing else. **[limitation]**
   because the system fallbacks do not throw, forgetting to define
   `MC.initialize(::MySystem)` logs and continues. Define all five.

4. **Hardware dependencies compose, and connection ownership is explicit in the
   driver's docstring. [guarantee]** `LCC1620` holds `scope::Triggerscope4`;
   `initialize(att)` opens the scope's port only if it is not already open and
   `shutdown(att)` drives its channel to `min_voltage` but leaves the port open
   for the other attenuator (traced, `lcc1620_attenuator/interface_methods.jl`).
   So the caller owns the scope's closure. **[policy]** make ownership a field
   (`owns_port::Bool`) or a system rule, never an assumption.
   **[limitation]** the three DAQ-backed lights build their own dependency and
   cannot share it (Boundary test, qualification 2).

5. **Persistence mirrors composition. [guarantee]** `export_state` returns
   `(attributes::Dict{String,Any}, data, children::Dict{String,Any})`; children
   are further tuples; `save_h5` walks the tree recursively under a root group
   `Main` without knowing any device class (`src/h5_file_saving.jl`). That is a
   strong boundary: drivers describe themselves, the system assembles a
   meaningful record, the writer persists it. It does **not** make
   `export_state` an inverse of `set_state`, promise a hardware readback, or
   produce an atomic snapshot: `save_h5` is `@async` and opens the file with
   `"w"`. **[policy]** decide when you snapshot and mark what is missing.

6. **Common operations enable reuse; they do not establish interchangeability.
   [guarantee, and the limitation is the point]** Two devices of one interface
   dispatch the same names, and that is all the type system checks. `capture`
   returns an enum on `SimCamera` and a frame on `DCAM4Camera`; `getposition`
   returns a tuple on some stages, a scalar on the Sims and an SDK success code
   on `N472`; `move` arity follows `dimensions`; units differ per stage
   (executed / traced, `references/driver-caveats.md`). Upstream's
   `test/contract.jl` checks dispatch and binding identity, not behaviour.
   **[policy]** put a small adaptation layer in your system for the devices you
   actually use, and test it against the Sim and the hardware separately.

## Three kinds of state, kept distinct

| Kind | Lives in | Example | Trust |
|---|---|---|---|
| **Requested configuration** | device fields the driver pushes to hardware, and your `AbstractSystemState` | `cam.exposure_time = 0.02`; `stage.targ_z`; `light.properties.power` | what you asked for. **[limitation]** on most drivers `properties.power` is the last value *sent*, not a readback. |
| **Measured hardware state** | whatever the driver reads back | `stage.real_x` after `getposition`; a frame; `connectionstatus` | what the hardware said, at the moment you asked. **[limitation]** the Sim stages copy `targ_*` into `real_*`, so measured equals requested there by construction. |
| **Saved metadata** | the `export_state` tree in the HDF5 file | `attrs["Main/camera"]["exposure_time"]` | a record of the above at snapshot time, plus whatever the system adds (which is missing, which is requested versus measured). |

**[policy]** name attributes so the reader can tell the kinds apart
(`power_requested` versus `power_measured`), snapshot after the acquisition
task has joined, and never let a missing child look like an empty one.

## Worked example: a bench that forces four decisions

The rig: one camera, one stage, one laser, two liquid-crystal attenuators on one
Triggerscope. Four things in it force design decisions that "construct, then
initialize, then shut down in reverse" does not cover.

### Decision 1: two attenuators share one controller (traced)

```julia
ts   = Triggerscope4(portname="COM5")            # ONE object for the physical port; constructor does not open it
att1 = LCC1620(scope=ts, dac_channel=1)          # borrows the scope
att2 = LCC1620(scope=ts, dac_channel=3)          # LCC1620() alone would build a SECOND Triggerscope4 on COM3
initialize(att1)                                 # opens the port (it was closed), sets DAC 1 range, drives min_voltage
initialize(att2)                                 # port already open: only configures DAC 3
shutdown(att2); shutdown(att1)                   # each drives its channel to min_voltage; the port stays OPEN
shutdown(ts)                                     # the system, as owner, closes the port last
```

Signatures traced from `lcc1620_attenuator/types.jl`, `triggerscope/types.jl`;
not executed (no serial port here). Two decisions are forced: the system owns
`ts` and must shut it down itself, and `shutdown(att)` means **0 V = full
transmission** on the LCC1620 (traced from the shutdown docstring), so "shut
down the attenuators" is an optical decision. **[policy]** turn the laser off
before the attenuators open up; reverse order of `initialize` is not, by itself,
a safe instrument.

### Decision 2: a camera whose constructor opens hardware (traced)

```julia
cam = DCAM4Camera(0)
cam isa DCAM4Camera || error("DCAM4 open failed: $(repr(cam))")   # returns a DCAMERR code, or `nothing`
# From here the camera is CLAIMED even though initialize(cam) has not run (it is a no-op for this driver).
# If anything below fails before the system is built, shutdown(cam) is owed NOW.
```

Forced decision: construction is part of the lifecycle for this driver, so the
system's rollback must cover constructed-but-not-initialized devices. The
executed `Bench` below does this by recording what it brought up in
`initialized`; for DCAM4 you push the camera onto that list at construction.
On a `nothing` return, call `MC.HardwareImplementations.DCAM4.dcamapi_uninit()`
yourself (caveats file).

### Decisions 3 and 4, executed: manual control versus an acquisition task, and a failed export

Everything in this block was executed against MC v0.2.0 under `xvfb-run -a`.
`BrokenLight` stands in for any device whose lifecycle or export throws (a
`ThorCamCSCCamera` on `initialize`, a `Triggerscope4` on `export_state`).

```julia
using MicroscopeControl
const MC = MicroscopeControl

struct BrokenLight <: LightSource end            # no methods: every generic hits the throwing stub

mutable struct BenchState <: AbstractSystemState  # requested configuration, nothing measured
    exposure_time::Float64
    z::Float64
    laser_power::Float64
end

mutable struct Bench <: AbstractSystem
    cam::Camera                                   # interface-typed: Sim in tests, hardware on the rig
    stage::Stage
    laser::LightSource
    initialized::Vector{AbstractInstrument}       # what initialize() actually brought up, in order
    acq::Union{Nothing,Task}                      # the ONE task that owns the camera while it runs
end
Bench(cam, stage, laser) = Bench(cam, stage, laser, AbstractInstrument[], nothing)

function MC.initialize(sys::Bench)                # MC. prefix: extend the generic, do not shadow it
    empty!(sys.initialized)
    for dev in (sys.laser, sys.stage, sys.cam)   # cheapest-to-abort first
        try
            initialize(dev)
            push!(sys.initialized, dev)
        catch e
            @warn "initialize failed; rolling back" device=typeof(dev) exception=e
            MC.shutdown(sys)                      # closes only what was opened
            rethrow()
        end
    end
    return sys
end

function MC.shutdown(sys::Bench)
    if sys.acq !== nothing                        # an acquisition owns the camera: stop it and JOIN it first
        abort(sys.cam)
        try wait(sys.acq) catch end
        sys.acq = nothing
    end
    failed = Pair{DataType,Exception}[]
    for dev in reverse(sys.initialized)
        try
            shutdown(dev)
        catch e
            push!(failed, typeof(dev) => e)       # keep going: one stuck device must not leave the rest open
        end
    end
    empty!(sys.initialized)
    isempty(failed) || error("shutdown left devices open: " * join(string.(first.(failed)), ", "))
    return nothing                                # observable: the caller learns WHAT stayed open
end

MC.get_state(sys::Bench) = BenchState(sys.cam.exposure_time, sys.stage.targ_z, sys.laser.properties.power)

function MC.set_state(sys::Bench, st::BenchState)
    sys.acq === nothing || error("refusing to change configuration while an acquisition owns the camera")
    sys.cam.exposure_time = st.exposure_time      # requested; the driver pushes it on the next capture
    move(sys.stage, sys.stage.targ_x, sys.stage.targ_y, st.z)
    setpower(sys.laser, st.laser_power)
    return sys
end

function MC.export_state(sys::Bench)
    attributes = Dict{String,Any}("system" => "Bench", "julia" => string(VERSION))
    children = Dict{String,Any}()
    missing = String[]
    for (name, dev) in ("camera" => sys.cam, "stage" => sys.stage, "laser" => sys.laser)
        try
            children[name] = export_state(dev)
        catch e
            push!(missing, name)                  # never silently omit: the record must say what is absent
            children[name] = (Dict{String,Any}("export_failed" => string(typeof(dev)),
                                               "error" => sprint(showerror, e)), nothing, Dict{String,Any}())
        end
    end
    attributes["missing_children"] = join(missing, ",")
    attributes["complete"] = isempty(missing)
    return attributes, nothing, children
end

function acquire!(sys::Bench, n::Int)             # the only code path that starts the camera
    sys.acq === nothing || error("acquisition already running")
    sys.cam.sequence_length = n
    sys.acq = @async begin
        sequence(sys.cam)
        while sys.cam.is_running == 1; sleep(0.01); end   # SimCamera: is_running is a Bool, == 1 works
        getdata(sys.cam)                          # (H, W, N)
    end
end
```

What the run showed (`SimCamera(roi=CameraROI(1,1,64,32))`, `SimStage3d()`,
`SimLight()`):

| Step | Result |
|---|---|
| `initialize(Bench(cam, stage, BrokenLight()))` | threw `initialize not implemented for BrokenLight`; `initialized` empty afterwards, `stage.connectionstatus == false` (nothing had opened yet, laser is first). |
| same with a `BrokenCam` **last** | threw; stage rolled back to `connectionstatus == false`, laser back to `is_on == false`, `initialized` empty. Rollback closed exactly what had opened. |
| `set_state` then `get_state` | `BenchState(0.02, 7.5, 12.0)` round-trips. |
| `set_state` while `acquire!` runs | refused: `refusing to change configuration while an acquisition owns the camera`. |
| `fetch(acquire!(sys, 5))` | `(32, 64, 5)`, `is_running == false` after. |
| `export_state` with the laser swapped for `BrokenLight()` | `complete == false`, `missing_children == "laser"`, `children["laser"]` carries `export_failed = "BrokenLight"` and the error text. |
| `wait(save_h5(f, (attrs, data, children)))` then read back | groups `camera, data, laser, stage` under `Main`; `missing_children` attr `"laser"`; `complete` attr `0.0` (Bool saved as Float64); `Main/laser` has `export_failed`; `Main/data` is `(32, 64, 5)`. |
| `shutdown` with a device whose `shutdown` throws | threw `shutdown left devices open: BrokenLight`, **and** the stage was still closed (`connectionstatus == false`): the loop finished before reporting. |
| clean `shutdown(sys)` | `initialized` empty, stage disconnected. |

Provenance rule this example enforces **[policy]**: a saved record must
identify what is missing. Catching a failed `export_state` and dropping that
child produces a file that looks complete and is not.

## Four claims this skill must never make

If you find yourself writing any of these into system code or documentation,
stop; each is false at v0.2.0.

1. *"Any `Camera` (or `Stage`, or `LightSource`) can be swapped for any other."*
   Dispatch is shared; return values, arity, units and constructor side effects
   are not (Principle 6).
2. *"`AbstractSystem` initializes, configures and shuts down my devices."* It
   declares five generics whose fallbacks log and return `nothing` (Principle 3).
3. *"`initialize` returned, so the device is ready."* See the Readiness row:
   verify something the hardware had to answer.
4. *"Shutdown in reverse order, so the instrument is safe."* Reverse order is a
   default, not a safety argument. Ownership (who closes the shared port) and
   optics (0 V on an LCC1620 is full transmission) decide the order.

## Notes carried over

- `AbstractSystem`, `AbstractSystemState`, `get_state`, `set_state` are exported.
  Extend the generics with the `MC.` prefix or `import MicroscopeControl: initialize`;
  an unqualified `function initialize(sys::Bench)` after a bare `using` creates a
  new local function, and `MC.initialize(sys)` from other code hits the fallback
  (executed for `gui` and `setpower` in `mc-extend`).
- `move` takes `Float64`s. `move(stage, 1, 2, 3)` is a `MethodError`.
- `gui(dev)` is one generic that dispatches to the interface panel or a driver
  override (`N472`); a system menu is a list of `gui(sys.<field>)` calls. Each
  opens a GLMakie window (see `mc-testing` for `xvfb-run`). See the caveats
  file for which devices' panels open today.

## Two more limitations that bear on design

- **[limitation]** `gui(::LightSource)` calls `setpower(light, 0.5)` the moment
  the panel opens: the slider's `lift` fires on creation with its start value
  (traced from `lightsource_interface/gui.jl`; executed against a fake-transport
  light, which threw from inside `gui`). On a laser that is a real hazard, and a
  reason a system may want its own panel, or to open the shared one only with
  the shutter closed or the laser off.
- **[limitation]** `getposition(::SimStage3d)` returns a scalar (`3.0` after
  `move(s, 1.0, 2.0, 3.0)`), the value of its last assignment, while the
  interface docstring promises an `(x, y, z)` tuple (executed). A system must
  not trust a return shape it has not checked on the device it holds; read the
  `real_*` fields, or wrap `getposition` in a per-device adapter that returns
  what you documented.
