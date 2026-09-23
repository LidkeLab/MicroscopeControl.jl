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
| **Background tasks** | **[limitation]** a driver may start a task the caller never receives: `sequence(::DCAM4Camera)` spawns a poller on the camera handle and discards it with an explicit `return` (traced); `sequence(::SimCamera)` and `sequence(::ThorcamDCXCamera)` return theirs only because the `@async` is the last expression, and the interface promises `nothing`. Those tasks read mutable device state as they run: the Sim's timer rereads `camera.exposure_time` every iteration and writes `is_running`; DCAM4's and DCx's pollers reread `camera.camera_handle` through the SDK every iteration (DCAM4 writes `is_running = 0` once at the end; neither reads it). | **[policy]** treat the camera as single-owner and single-acquisition: one blocking acquisition at a time on one task, no cancellation, no configuration change in flight, and a process restart rather than recovery when an abort fails. This is a restriction the drivers impose, not a design preference (worked example, Decision 3). |
| **State** | the device's own fields (`exposure_time`, `roi`, `targ_x`, `properties.power`) are the configuration the driver pushes to hardware; **[guarantee]** shared code reads those fields by name (see Principle 2). | the instrument-level configuration (`AbstractSystemState`), when it is captured, and which fields are requested values versus measured ones (see "Three kinds of state"). |
| **Failure recovery** | **[guarantee]** since v0.1.0 the stubs of the five `AbstractInstrument` interfaces (`Camera`, `Stage`, `LightSource`, `DAQ`, `Attenuator`) and the `AbstractInstrument` lifecycle stubs throw `ErrorException("... not implemented for T")` instead of returning `nothing`. **[limitation]** `SLM`'s `displayimage(::SLM)` has an empty body and returns `nothing`, and `SLM`/`TRIG` devices get `MethodError`, not the stub, for lifecycle calls (`references/driver-caveats.md`). Drivers mostly `@warn`/`@error` and return on hardware errors. **[limitation]** the `AbstractSystem` fallbacks still `@error` and return `nothing`. | **[policy]** rollback on partial initialization, a shutdown that reports what it could not close, and a saved record that says what is missing. All three are in the worked example below; none is provided by MC. |
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
   `NIdaq()` and hard-wire which device and channel they use: Crysta and Vortran
   take the **first** discovered device (`devs[1]`); `DaqTrLight` takes
   `devs[device_index]` with `device_index` a constructor keyword defaulting to
   **2**; Crysta and DaqTr write **AO channel 1** (`channelsAO[1]`), Vortran
   writes **AO channel 2** (`channelsAO[2]`). Those are wiring assumptions baked
   into reusable implementations (traced from each driver's `types.jl` and
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
   `(attributes, data, children)`; children are further tuples keyed by name; `save_h5` walks the tree recursively under a root group
   `Main` without knowing any device class (`src/h5_file_saving.jl`). That is a
   strong boundary: drivers describe themselves, the system assembles a
   meaningful record, the writer persists it. It does **not** make
   `export_state` an inverse of `set_state`, promise a hardware readback, or
   produce an atomic snapshot: `save_h5` is `@async` and opens the file with
   `"w"`. **[policy]** decide when you snapshot and mark what is missing, and
   build your own dictionaries as `Dict{String,Any}`: the tuple and tree shape
   is the guarantee, the concrete `Dict` parameters are not (`export_state(NIdaq())`
   returns `Dict{String,String}` attributes and `Dict{Any,Any}` children;
   `save_h5` accepts both).

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
| **Requested configuration** | device fields the driver pushes to hardware, and your `AbstractSystemState` | `cam.exposure_time = 0.02`; `stage.targ_z`; `light.properties.power` | what you asked for. **[limitation]** `properties.power` is only updated by `setpower` on `SimLight` and `TCubeLaser` (which converts from current); `CrystaLaser`, `VortranLaser` and `DaqTrLight` write the voltage to the DAQ and leave the field at its constructor value (traced). Where the driver does not track it, the system must record the requested power itself: `Bench` below retains the last `BenchState` in `sys.requested`, `get_state` returns that, and `measured_power` reads the field (executed against a DAQ-like fake: requested `3.5`, measured `0.0`). |
| **Measured hardware state** | whatever the driver reads back | `stage.real_x` after `getposition`; a frame; `connectionstatus` | what the hardware said, at the moment you asked. **[limitation]** the Sim stages copy `targ_*` into `real_*`, so measured equals requested there by construction. |
| **Saved metadata** | the `export_state` tree in the HDF5 file | `attrs["Main/camera"]["exposure_time"]` | a record of the above at snapshot time, plus whatever the system adds (which is missing, which is requested versus measured). |

**[policy]** name attributes so the reader can tell the kinds apart
(`power_requested` versus `power_measured`), snapshot after the blocking acquisition call
has returned, and never let a missing child look like an empty one.

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
cam = DCAM4Camera(0)   # throws (since 0.2.1) on either SDK failure path; catch and handle if you need to fall back
# From here the camera is CLAIMED even though initialize(cam) has not run (it is a no-op for this driver).
# If anything below fails before the system is built, shutdown(cam) is owed NOW.
```

Forced decision: construction is part of the lifecycle for this driver, so
ownership acquired in the constructor must survive into the system's rollback.
The executed `Bench` below keeps one `owned` list of every device currently
holding hardware; a constructor-claimed device is passed in as
`claimed_at_construction=(cam,)` so it is owned before `initialize` runs, is
skipped by `initialize`, and is closed by the same `release!` that closes
everything else. **Fixed in 0.2.1:** `DCAM4Camera()` used to return a
`DCAMERR` code or `nothing` on failure (a `nothing` return additionally left
the DCAM SDK initialized, so you had to call
`MC.HardwareImplementations.DCAM4.dcamapi_uninit()` yourself before the next
open); it now throws on both failure paths, and each of those two paths
calls `dcamapi_uninit()` before it throws. That is not a general guarantee:
an exception raised after `dcamdev_open` succeeds (e.g. reading sensor size
or exposure) has no cleanup guard, and on the two paths that do clean up the
cleanup is only *attempted* -- `dcamapi_uninit()` checks its own SDK result
and logs an `@error` when it fails, but the constructor ignores that return
and throws either way, so a failed uninitialize shows up in the log and
nowhere else. If you're on an installed copy older
than 0.2.1, guard the return value yourself --
`cam isa DCAM4Camera || error("DCAM4 open failed: $(repr(cam))")` -- and on
a `nothing` return call
`MC.HardwareImplementations.DCAM4.dcamapi_uninit()` yourself before the
next open (caveats file).

### Decisions 3 and 4, executed: manual control versus acquisition, and a failed export

Everything in this block was executed against MC v0.2.0 under `xvfb-run -a`.
`BrokenLight` stands in for any device whose lifecycle or export throws;
`ClaimedAtConstruction` for `DCAM4Camera`; `DaqLikeLight` for the three
DAQ-backed lights whose `setpower` does not cache the request.

**[limitation]** The camera drivers spawn background tasks that the caller
never receives, and those tasks read mutable device fields as they run. Per
driver: `sequence(::DCAM4Camera)` spawns a poller on the camera handle and
**discards** it with an explicit `return` (traced); `sequence(::SimCamera)` and
`sequence(::ThorcamDCXCamera)` return their poller only because the `@async` is
the function's last expression (Sim executed, DCX traced), while the interface
docstring promises `nothing`, so a test that joins the Sim's task passes where
`DCAM4Camera` never can; `ThorCamCSCCamera` spawns none. Each task reads
mutable device state as it runs, and which state differs per driver: the Sim's
timer rereads `camera.exposure_time` on every iteration and writes
`is_running` at the end (executed: with 20 frames at 0.01 s remaining, raising
`exposure_time` to 0.05 s after the start made the task run 0.93 s more);
DCAM4's poller rereads `camera.camera_handle` through `dcamcap_status` every
iteration and writes `is_running = 0` once when the SDK reports idle; DCx's
poller rereads `camera.camera_handle` through `is_CameraStatus` and stops live
video at the end; neither hardware poller reads `is_running` (traced). The
exposure measurement is Sim-only; the general point is not. Consequently a
system **cannot prove that a previous acquisition has stopped**, and **no wait
computed at the caller fixes it**: any deadline derived when the acquisition
started depends on state the driver's task may read again later. Two reproduced consequences of earlier versions of this example that
tried a caller-side quiescence deadline: a caller admitted during `shutdown`'s
wait had its driver task alive when the camera closed, about 0.7 s before the
deadline recorded for it, in five of five runs; and a `set_state` lengthening
the exposure after a cancel extended the old task past its deadline, so
`shutdown` waited the full deadline and still closed the camera under a live
task. Earlier still, without any wait, a cancelled acquisition's driver task
cleared the next acquisition's `is_running`: a nominal 2.0 s acquisition
returned in 0.167 s.

**[policy]** What a system should do today, as a restriction the drivers
impose rather than a design preference: treat the camera as **single-owner
and single-acquisition**. One blocking acquisition at a time, on the task that
called it; **no cancellation**; no configuration change while an acquisition is
in flight; and when a failed acquisition cannot be aborted, mark the camera
unavailable and **restart the process** (or reconstruct the camera and the
system) rather than attempt in-place recovery, since no lifecycle call can
verify that the driver's task is gone or that `initialize` did more than return.

**[policy]** The upstream fix is concrete: the camera interface should require
`sequence` (and `live`) to **return the task it spawns**, or expose a join, so a
system can establish quiescence instead of guessing at it. `SimCamera` and
`ThorcamDCXCamera` already return one by accident; `DCAM4Camera` discards its
poller; `ThorCamCSCCamera` spawns none. Until then, the restriction above stands.

The example is therefore modest on purpose: `acquire!` runs start to finish on
the calling task; an `in_flight` flag guards `set_state`, `acquire!` and
`shutdown` against misuse from another task; a failed acquisition aborts the
camera before returning it, and if that abort fails the camera is unavailable
until the system is rebuilt. `BenchState` is an **immutable** struct: a
requested configuration is a value, `get_state` hands back the retained record,
and only another `set_state` can change it.

```julia
using MicroscopeControl
const MC = MicroscopeControl

struct BrokenLight <: LightSource end            # no methods: every generic hits the throwing stub

mutable struct ClaimedAtConstruction <: Camera   # stands in for DCAM4Camera: holds hardware from the constructor
    open::Bool
end
ClaimedAtConstruction() = ClaimedAtConstruction(true)
MC.initialize(::ClaimedAtConstruction) = nothing               # like DCAM4: initialize is a no-op
MC.shutdown(c::ClaimedAtConstruction) = (c.open = false; nothing)

mutable struct DaqLikeLight <: LightSource       # stands in for CrystaLaser/VortranLaser/DaqTrLight: setpower does not cache
    properties::LightSourceProperties
end
DaqLikeLight() = DaqLikeLight(LightSourceProperties("V", 0.0, false, 0.0, 5.0))
MC.initialize(::DaqLikeLight) = nothing
MC.shutdown(::DaqLikeLight) = nothing
MC.setpower(::DaqLikeLight, v::Float64) = nothing              # writes the DAQ, leaves properties.power alone

struct BenchState <: AbstractSystemState          # REQUESTED configuration, nothing measured. IMMUTABLE: a request is a
    exposure_time::Float64                        # value; get_state hands it back and nobody can edit the record in place
    z::Float64
    laser_power::Float64
end

mutable struct Bench <: AbstractSystem
    cam::Camera                                   # interface-typed: Sim in tests, hardware on the rig
    stage::Stage
    laser::LightSource
    owned::Vector{AbstractInstrument}             # every device currently holding hardware, in acquisition order
    requested::Union{Nothing,BenchState}          # the last configuration asked for; the drivers do not all keep it
    in_flight::Bool                               # an acquisition is running on the calling task; nothing else may touch the camera
    cam_unavailable::Bool                         # set when a failed acquisition could not abort the camera
end
Bench(cam, stage, laser; claimed_at_construction=()) =
    Bench(cam, stage, laser, AbstractInstrument[claimed_at_construction...], nothing, false, false)

function MC.initialize(sys::Bench)                # MC. prefix: extend the generic, do not shadow it
    for dev in (sys.laser, sys.stage, sys.cam)   # cheapest-to-abort first
        any(d -> d === dev, sys.owned) && continue   # already holding hardware since construction
        try
            initialize(dev)
            push!(sys.owned, dev)
        catch e
            @warn "initialize failed; releasing everything held" device=typeof(dev) exception=e
            release!(sys)                         # closes what was opened, INCLUDING constructor-claimed devices
            rethrow()
        end
    end
    return sys
end

function release!(sys::Bench)                     # shut down everything owned, newest first; report what stayed open
    failed = Pair{DataType,Exception}[]
    for dev in reverse(sys.owned)
        try
            shutdown(dev)
        catch e
            push!(failed, typeof(dev) => e)       # keep going: one stuck device must not leave the rest open
        end
    end
    empty!(sys.owned)
    isempty(failed) || error("shutdown left devices open: " * join(string.(first.(failed)), ", "))
    return nothing
end

function MC.shutdown(sys::Bench)
    sys.in_flight && error("an acquisition is in flight on another task; this system is single-owner, wait for it")
    release!(sys)
end

# get_state returns what was REQUESTED; measured values are read from device fields separately.
MC.get_state(sys::Bench) = sys.requested === nothing ? error("no configuration has been requested yet") : sys.requested
measured_power(sys::Bench) = sys.laser.properties.power          # cached by SimLight/TCube only; stale on the DAQ lights

function MC.set_state(sys::Bench, st::BenchState)
    sys.in_flight && error("refusing to change configuration while an acquisition is in flight")
    sys.cam.exposure_time = st.exposure_time      # requested; the driver pushes it on the next acquisition call
    move(sys.stage, sys.stage.targ_x, sys.stage.targ_y, st.z)
    setpower(sys.laser, st.laser_power)
    sys.requested = st                            # retained here because the light driver may not keep it
    return sys
end

function MC.export_state(sys::Bench)
    attributes = Dict{String,Any}("system" => "Bench", "julia" => string(VERSION),
        "laser_power_requested" => sys.requested === nothing ? NaN : sys.requested.laser_power)
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

# --- Acquisition: ONE call, on the calling task, start to finish. No cancellation, no concurrent callers. ---
# [limitation] the camera drivers spawn tasks the caller never receives (DCAM4 discards its poller; Sim and
# DCX return theirs only by accident; the interface promises `nothing`), and those tasks read mutable device
# state as they run (Sim: `exposure_time` each iteration; DCAM4/DCx: `camera_handle` via the SDK). So this system cannot prove a previous
# acquisition has stopped, and no wait computed here could. It therefore does not try: one acquisition at
# a time, blocking, and a camera that could not be aborted is unavailable until the process is rebuilt.
function acquire!(sys::Bench, n::Int)
    sys.in_flight && error("acquisition already in flight")
    sys.cam_unavailable && error("camera unavailable: a failed acquisition could not be aborted; shut down and reconstruct")
    sys.in_flight = true
    try
        sys.cam.sequence_length = n
        sequence(sys.cam)
        while sys.cam.is_running == 1             # SimCamera: is_running is a Bool, == 1 works
            sleep(0.01)
        end
        return getdata(sys.cam)                   # (H, W, N): the driver reports completion; we take its word
    catch e
        try                                       # failure: abort BEFORE giving the camera back
            abort(sys.cam)
        catch abort_error
            sys.cam_unavailable = true            # could not even abort: refuse further acquisitions until rebuilt
            @error "abort failed after a failed acquisition; camera marked unavailable" exception=abort_error
        end
        rethrow()
    finally
        sys.in_flight = false
    end
end
```

What the run showed (`SimCamera(roi=CameraROI(1,1,64,32), exposure_time=0.01)`,
`SimStage3d()`, `SimLight()` unless stated):

| Path | Result |
|---|---|
| **Rollback, first device fails**, camera claimed at construction | threw `initialize not implemented for BrokenLight`; `cam.open == false` afterwards, `owned` empty. |
| **Rollback, last device fails** (`BrokenCam` third) | stage back to `connectionstatus == false`, laser back to `is_on == false`, `owned` empty. |
| **Requested versus measured** with `DaqLikeLight`: `set_state(sys, BenchState(0.02, 1.0, 3.5))` | `get_state(sys).laser_power == 3.5`, `measured_power(sys) == 0.0`, export attribute `laser_power_requested == 3.5`. |
| **Immutable requested state**: `get_state(sys).laser_power = 4.5` | refused: `setfield!: immutable struct of type BenchState cannot be changed`. |
| **Sequential acquisitions**: `acquire!(sys, 5)` then `acquire!(sys, 3)` | `(32, 64, 5)` in 0.15 s, `in_flight == false` after; then `(32, 64, 3)`. |
| **In-flight guards** (flag set by hand; the example never runs two tasks) | `set_state`, `acquire!` and `shutdown` each refused with a message naming the in-flight acquisition. |
| **Failing acquisition** (`acquire!(sys, -1)` makes `getdata` throw) | rethrew `ArgumentError`; `abort` had run (`is_running == false`), `in_flight == false`, camera still available; the next acquisition returned `(32, 64, 2)`. |
| **Failing acquisition whose `abort` also fails** (`ArmThenThrowCam`) | rethrew `SDK: arm failed after start`; the next `acquire!` refused `camera unavailable ...`; `shutdown(sys); initialize(sys)` still refused; **reconstruction** (new `Bench`, new camera, stage and laser reused) acquired `(32, 64, 3)`. |
| **Export with a failed child** | `complete == false`, `missing_children == "laser"`; through `save_h5` and back: groups `camera, data, laser, stage`, attr `missing_children == "laser"`. |
| **Observable shutdown failure** (a device whose `shutdown` throws in `owned`) | threw `shutdown left devices open: BrokenLight` after finishing the loop; the stage was already disconnected. |
| **Evidence for the limitation** | `sequence(SimCamera)` returned a `Task`; raising `exposure_time` mid-run stretched that task from ~0.2 s remaining to 0.93 s. |

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

- **Fixed in 0.2.1.** `gui(::LightSource)` used to call `setpower(light, 0.5)`
  the moment the panel opened: the slider's `lift` fired on creation with its
  start value (traced from `lightsource_interface/gui.jl`; executed against a
  fake-transport light, which threw from inside `gui`). The slider and toggle
  are now wired with `on` (fires only on a later change) and initialised from
  the device's current `properties.power`/`properties.is_on`, so constructing
  the panel is observably read-only. **Caveat:** what `properties.power`
  holds after a `setpower` differs by driver (traced). `SimLight` stores the
  argument it was given. `TCubeLaser` stores a *calculated* power
  (`current * max_power / max_current`) while its `setpower` takes current in
  milliamps, so the units on display and on the wire differ. `CrystaLaser`,
  `VortranLaser` and `DaqTrLight` never write the field at all, so the slider
  can display a stale cached value on those three. This is not a new opening-time write -- it is
  about what the widget shows. If you're on an installed copy older
  than 0.2.1, this was a real hazard on a laser, and a reason a system may
  want its own panel, or to open the shared one only with the shutter closed
  or the laser off.
- **[limitation]** `getposition(::SimStage3d)` returns a scalar (`3.0` after
  `move(s, 1.0, 2.0, 3.0)`), the value of its last assignment, while the
  interface docstring promises an `(x, y, z)` tuple (executed). A system must
  not trust a return shape it has not checked on the device it holds; read the
  `real_*` fields, or wrap `getposition` in a per-device adapter that returns
  what you documented.
