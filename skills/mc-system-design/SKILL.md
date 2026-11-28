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

- **[guarantee, V]** the code does this, and the statement was checked at
  version `V`. `V` is a version, such as `0.2.7-DEV` (the `main` these skills
  were checked against), or `suite: GROUP`: the package's own tests assert it,
  in the group `GROUP` of `test/skill_examples.jl`, which runs the marked
  examples in these files and checks the values they state on every run of the
  package's tests, so the statement fails the suite when the code stops doing
  what its checks cover. A statement can say *executed* (run on the Sim devices
  or a fake SDK), *traced* (read from the driver source, because it needs
  hardware or a vendor library), *tested against a fake SDK* (a test in
  `test/`), *checked once* (run once, outside the suite), or *observed on
  hardware; not re-run* (seen on an instrument, with the release whose code it
  describes); nothing here is verified on hardware unless it says so. A label
  with a version and not `suite` was checked once, at that version, and can go
  stale. `test/skills.jl` fails on a label that names no version and no group,
  a group the harness does not have, or a version later than the package's.
  `since X` names the release that introduced a behavior, for a reader on an
  older tag; while `main` carries `X-DEV`, that behavior is on `main` and in
  no tag yet.
- **[limitation, V]** the code falls short of its own design here, as of
  version `V`; work around it, never copy it. `fixed in X` marks one that is
  gone from `X` on and stays only for a reader on an older tag.
- **[policy]** a recommendation for the system you are building. MC does not
  enforce it and nothing breaks if you ignore it, except your instrument.

A fence preceded by `<!-- mc-test: NAME -->` is an example the suite runs, in
group `NAME`; the comment does not render, and a `# -> VALUE` comment in such a
fence states a value the suite asserts. Fences without the marker need hardware
or are illustrations. Inside a statement under a version label, `(suite: GROUP)`
marks the one fact that group checks.

## Before anything: depending on MicroscopeControl

**[limitation, reported on an instrument PC before 0.2.4; not checked in an empty depot]** Pinning
MicroscopeControl is not enough. It depends on the unregistered `DAQmx.jl`, and whether Pkg reads MicroscopeControl's
own `[sources]` entry for it depends on the Julia version and on how MicroscopeControl was added (traced from Pkg's
`Operations.jl` in 1.11.9, 1.12.7 and 1.13.0). On 1.11 and 1.12, a package added by URL has its `[sources]` ignored
(CHANGELOG 0.2.4), so on an environment that has never resolved `DAQmx` a `Pkg.instantiate` can fail with `DAQmx has
no known versions`; a package developed by path has its own environment loaded (`collect_developed!`), and its URL
and path sources with it. On 1.13, adding a package by URL or path also collects its dependencies' `[sources]`
(`collect_fixed!`, and the `toml-files` documentation). Where MicroscopeControl's entry is used, it follows `DAQmx`'s
`main`; a source in the active project wins over it (1.13). Either way, add `DAQmx` by URL, pinned, **before**
MicroscopeControl, with the instrument's own project active (`julia --project` in its repo, or `Pkg.activate` on
it):

```julia
using Pkg
Pkg.add(url="https://github.com/LidkeLab/DAQmx.jl.git", rev="039003306bf34047678e9dc229b6dc035c880fe6")
Pkg.add(url="https://github.com/LidkeLab/MicroscopeControl.jl.git", rev="<the tag or commit, below>")
```

Pin both. `DAQmx.jl` has no tags, so its pin is a commit: the one above was the
head of its `main` (version 0.1.0) when these skills were checked.
Which pin MicroscopeControl takes depends on the `Installed from` line at the end
of this file, which carries the version only:

- `vX.Y.Z`: pin that tag, `rev="vX.Y.Z"`.
- `vX.Y.Z-DEV`: these skills came from a commit between releases (on `main`,
  a branch or a local checkout), and no tag carries what they describe. Pin the
  commit the instrument was tested with, `rev="<the 40-character commit>"`:
  - from a checkout it ran (`Pkg.develop`, or a path in `[sources]`): `git rev-parse HEAD` there, with
    `git status` clean;
  - from its `Manifest.toml`, for a package added by URL: the entry's `repo-rev` when that is a commit; when it
    names a branch, the entry's `git-tree-sha1` is the tree, and `git log --all --format='%H %T' | grep <that sha>`
    in a clone of the repository names the commits that have it.

  To choose a new commit to test, `git ls-remote https://github.com/LidkeLab/MicroscopeControl.jl.git main` gives
  `main`'s current head; test the instrument against it before pinning it.

Without a `rev`, `Pkg.add` follows the default branch, and the next
`Pkg.update` moves the instrument to whatever was pushed since.

What `Pkg.add(url=...)` writes depends on the Julia version (traced from Pkg's
`write_env` in Julia 1.11.9, 1.12.7 and 1.13.0): on 1.13 it writes both the
`[deps]` and the `[sources]` entry; on 1.11 and 1.12 it writes the `[deps]`
entry and records the URL and revision in `Manifest.toml` only, so commit the
Manifest or write `[sources]` by hand. By hand, both entries are needed:
`[sources]` alone is rejected with `Sources for DAQmx not listed in deps or
extras section`:

```toml
[deps]
DAQmx = "bc903ccc-f951-4f60-9748-ff64248ad6aa"

[sources]
DAQmx = {url = "https://github.com/LidkeLab/DAQmx.jl.git", rev = "039003306bf34047678e9dc229b6dc035c880fe6"}
```

It surfaces on an environment that has not already resolved `DAQmx`, which is
why it appears on a fresh instrument PC rather than on the box where the system
was written.

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
| **Physical connection** | which object holds the handle, and whether the constructor or `initialize` opens it. **[limitation, 0.2.7-DEV]** this differs per driver: DCAM4 and ThorCam CSC open in the constructor; PI, MCL, N472, SmarAct, DCx, TCube and the Sims open in `initialize` (their constructors are pure); see `references/driver-caveats.md`. | one owner per physical port or SDK session; every other holder borrows. Construct the shared object once and pass it in. |
| **Readiness** | **[guarantee, 0.2.7-DEV]** (since 0.2.7) a DAQ voltage light writes its off output before recording off, and throws on missing channels or failed writes (`references/driver-caveats.md`, "DAQ voltage-light state"). **[limitation, 0.2.7-DEV]** a normal return does not establish general readiness: `initialize(::DCAM4Camera)` is a no-op because its constructor did the work. | **[policy]** verify after `initialize`: read a position, check `connectionstatus`, inspect channel lists, or take one frame. Decide what "ready" means for each device and check it. |
| **Background tasks** | **[limitation, 0.2.7-DEV]** a driver may start a task the caller never receives, or receives only by accident (the interface promises `nothing`), and those tasks read mutable device state as they run. What each camera driver's `sequence` returns, what its `getdata` waits for and what its `abort` does, including how a failed stop is reported, is in `mc-acquire`'s table ("Finite ordered sequence"), the one statement of those facts. | **[policy]** treat the camera as single-owner and single-acquisition: one blocking acquisition at a time on one task, no cancellation, no configuration change in flight, and a process restart rather than recovery when the driver's `camera_ok` (`mc-acquire`) does not say the camera stopped. This is a restriction the drivers impose, not a design preference (worked example, Decision 3). |
| **State** | the device's own fields (`exposure_time`, `roi`, `targ_x`, `level_requested` on a DAQ light) are the configuration the driver pushes to hardware; **[guarantee, 0.2.7-DEV]** shared code reads those fields by name (see Principle 2). | the instrument-level configuration (`AbstractSystemState`), when it is captured, and which fields are requested values versus measured ones (see "Three kinds of state"). |
| **Failure recovery** | **[guarantee, 0.2.7-DEV]** since v0.1.0 the stubs of the five `AbstractInstrument` interfaces (`Camera`, `Stage`, `LightSource`, `DAQ`, `Attenuator`) and the `AbstractInstrument` lifecycle stubs throw `ErrorException("... not implemented for T")` instead of returning `nothing`. **[limitation, 0.2.7-DEV]** `SLM`'s `displayimage(::SLM)` has an empty body and returns `nothing`, and `SLM`/`TRIG` devices get `MethodError`, not the stub, for lifecycle calls (`references/driver-caveats.md`). Drivers mostly `@warn`/`@error` and return on hardware errors. **[limitation, 0.2.7-DEV]** the `AbstractSystem` fallbacks still `@error` and return `nothing`. | **[policy]** rollback on partial initialization, a shutdown that reports what it could not close, and a saved record that says what is missing. All three are in the worked example below; none is provided by MC. |
| **Units, axes, conventions** | its own: PI in millimeters, MCL in micrometers, Sim stages unitless (0..100); cameras return `(H, W)` / `(H, W, N)` arrays, `[y, x]` with `[1, 1]` top left (lab decision 0040, `docs/src/conventions.md`) **[guarantee, 0.2.7-DEV]** for Sim, DCAM4, DCx and CSC (executed, through fakes for the drivers). | **[policy]** one normalization layer in the system (a function per device, not a conversion at every call site). |
| **Optical power at the sample** | **[guarantee, 0.2.7-DEV]** (since 0.2.5, traced) a `DiodeLaser` in `ConstantPhotocurrent` mode commands and reports mW **at the laser output**, the plane its `wa_calibration` was measured at (`setoutputpower!`, `indicated_output_power`); no driver holds a field describing splitters, attenuators, fibers or objectives. In `ConstantCurrent` mode the driver has no optical number at all. | **[policy]** the path transmission from laser output to sample, its measurement and its drift belong to the system; convert in one place, and label saved values with the plane they refer to (the TCube export already writes `power_reference = "laser output"`). |
| **Persistence** | a one-argument `export_state` returning `(attributes, data, children)`: **[guarantee, suite: statements]** for these devices, each built without touching hardware, exported, and written with `save_attributes_and_data`: the Sims, `PIStage`, `MCLStage`, `MCS2Stage`, `N472`, `ThorcamDCXCamera`, `MLSLM`, `NIdaq`, `TCubeLaser(serial)`, and `CrystaLaser`, `DaqTrLight` and `VortranLaser` with named outputs; **[guarantee, 0.2.7-DEV]** traced for the other drivers (the cameras that open in their constructor), whose methods `test/contract.jl` checks exist on each type without calling them; **[limitation, 0.2.7-DEV]** missing for the devices in the caveats file. | assembling the tree, choosing the child names, deciding when to snapshot, and recording incomplete exports (see Principle 5 and the worked example). |

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
   drive-voltage behavior belongs upstream. "This instrument's SLM-path attenuator is
   on DAC 3 of the scope on COM5" belongs downstream. Likewise a calibration
   table and its interpolation (`set_calibration!`, `settransmission`) are
   driver behavior; the measurement procedure and the measured numbers are the
   instrument's.
2. **[guarantee, 0.2.7-DEV]** (since 0.2.7) `CrystaLaser`, `VortranLaser` and `DaqTrLight`
   accept `daq::DAQ` (default `NIdaq()`) and named channels: `channel` for the
   single-line lights, `ao_channel` and `do_channel` for Vortran. Named outputs
   skip discovery. **[limitation, 0.2.7-DEV]** without names the legacy enumeration still
   applies: device 1 for Crysta/Vortran, `device_index=2` for DaqTrLight; AO
   index 1 for the single-line lights, AO index 2 and DO index 12 for Vortran.
   **[policy]** pass physical channel names and a shared dependency explicitly;
   verify the instrument's wiring before enabling a light.

Writing a driver downstream for a device you own, and extending MC's generics
for **your own type**, is legitimate and is not type piracy. `mc-extend`
draws the line: piracy is redefining a method for a type MC owns.

## The decision rule

| The code | It is a | Example | Go to |
|---|---|---|---|
| translates an operation that an existing interface already names (`move`, `capture`, `setpower`, `settransmission`) into one controller's SDK or protocol, including its units, conversions and connection handling | **new driver** (implementation of an existing interface) | a new camera model: a `Camera` subtype with `capture`/`getdata`/... over its vendor SDK | `mc-extend`, section 3 |
| defines operations and semantics for a device class none of `Camera`, `Stage`, `LightSource`, `DAQ`, `Attenuator` can reasonably express, and at least one concrete device plus a simulated one will implement them | **new interface** | a mechanical shutter with `open_shutter!`/`close_shutter!`/`is_open` and a switching time | `mc-extend`, section 4 |
| chooses this instrument's devices, ports, channels, calibration values, optical relationships, acquisition order, coordination or user workflow | **system code** in your repo | "laser off, then stage, then camera; refuse `set_state` during an acquisition; attenuator on DAC 3" | this skill |

The bar for a new interface is high: forcing a device into a nearby interface
(a shutter as a `LightSource` with `light_on`/`light_off`) is often the right
call, because a shared interface is what gives you the Sim substitution and the
GUI for free. Define a new one only when the nearest interface would lie about
what the device does.

Within lights **[guarantee, 0.2.7-DEV]** (since 0.2.5): a laser on a controller that *regulates*
something (drive current, or monitor photocurrent under photodiode feedback) is a
`DiodeLaser <: LightSource`, parametric in a `RegulationMode` fixed at
construction (`TCubeLaser{ConstantCurrent}`, `TCubeLaser{ConstantPhotocurrent}`,
and the simulated `SimDiodeLaser{M}`); a light that is only on/off or modulated by
a voltage (`CrystaLaser`, `VortranLaser`, `DaqTrLight`, `SimLight`) is a plain
`LightSource`. The two take different setters: `setpower` on a plain light;
`setcurrent!` (mA), `setoutputpower!` (mW at the laser output) or the unit-free
`setlevel!` on a `DiodeLaser`, where `setpower` is a deprecated mA forwarder in open loop and throws in closed loop. **[policy]** type a system
field `::DiodeLaser` when the system needs readback (`loop_status`,
`measured_current`) and `::LightSource` when on/off is all it uses; test
`isa DiodeLaser`, not a driver name, to choose the setter.

**[guarantee, 0.2.7-DEV]** (since 0.2.7) The DAQ voltage lights (`CrystaLaser`,
`VortranLaser`, `DaqTrLight`) take volts in `setpower` and keep the request in
`level_requested`; the two single-line lights stage a request made while off
for the next `light_on`, writing nothing. What each command writes, records and
throws, including what a failed off or `shutdown` leaves in `is_on`, is in
`references/driver-caveats.md`, "DAQ voltage-light state", and only there.

## Six design principles the source expresses

Each is stated as what the code does today; the label says how far to trust it.

1. **Category interfaces, then device implementations, then downstream
   composition. [guarantee, 0.2.7-DEV]** `src/instrument.jl` (included by
   `src/MicroscopeControl.jl`) defines `AbstractInstrument` and its four
   generics (`initialize`, `shutdown`, `export_state`, `gui`) plus
   `get_state`/`set_state` for systems, then `src/MicroscopeControl.jl`
   `@reexport`s `HardwareInterfaces` (abstract types and throwing stubs) and
   `HardwareImplementations` (concrete drivers). Interfaces are
   `interface_types.jl` / `interface_functions.jl` / `gui.jl`; drivers are
   `types.jl` / `interface_methods.jl`. There is no registration framework:
   adding a method to the shared generic *is* the registration.

2. **Devices carry state in FIELDS and shared code depends on those field
   names, not only on methods. [guarantee, 0.2.7-DEV]** `gui(::Stage)`
   (`stage_interface/gui.jl`) reads `dimensions`, `connectionstatus`,
   `targ_x/y/z`, `real_x/y/z`, `range_x/y/z`, `stagelabel`; `gui(::Camera)`
   (`camera_interface/gui.jl`) reads `unique_id`, `exposure_time`, `roi`,
   `capture_mode`, `trigger_mode`, `sequence_length`, `is_running`; the light
   and attenuator panels read `unique_id` and `properties`; from 0.2.5 the
   `DiodeLaser` panels and `setlevel!` also read `min_current`, `max_current`,
   `threshold_current`, `drive_current` and `pd`. A device that
   satisfies the method contract but lacks a field cannot use the inherited
   panel. **[limitation, 0.2.7-DEV]** the Sim stages have `label` where the GUI wants
   `stagelabel`, so `gui(SimStage3d())` throws (a `FieldError` on Julia 1.12 and later, an `ErrorException`
   on 1.11; suite: testing). Full field lists are in `mc-api-map`'s `references/gui-fields.md`.

3. **`AbstractSystem`/`AbstractSystemState` are separate from
   `AbstractInstrument`, with no automatic traversal. [guarantee, 0.2.7-DEV]**
   `src/instrument.jl` declares both abstract types and five generics whose
   fallbacks `@error` and return `nothing`. Nothing walks your struct's fields,
   initializes them in order, applies a state, or unwinds a failure. Lifecycle
   and configuration policy are therefore **downstream by design**: subtyping
   `AbstractSystem` gives you the verbs (so `initialize(sys)` and
   `initialize(sys.cam)` read the same) and nothing else. **[limitation, 0.2.7-DEV]**
   because the system fallbacks do not throw, forgetting to define
   `MC.initialize(::MySystem)` logs and continues. Define all five.

4. **Hardware dependencies compose, and connection ownership is explicit in the
   driver's docstring. [guarantee, 0.2.7-DEV]** `LCC1620` holds `scope::Triggerscope4`;
   `initialize(att)` opens the scope's port only if it is not already open and
   `shutdown(att)` drives its channel to `min_voltage` but leaves the port open
   for the other attenuator (traced, `lcc1620_attenuator/interface_methods.jl`).
   So the caller owns the scope's closure. **[policy]** make ownership a field
   (`owns_port::Bool`) or a system rule, never an assumption.
   **[guarantee, 0.2.7-DEV]** (since 0.2.7) the three DAQ voltage lights accept a shared `daq::DAQ`
   and named outputs (Boundary test, qualification 2).

5. **Persistence mirrors composition. [guarantee, 0.2.7-DEV]** `export_state` returns
   `(attributes, data, children)`; children are further tuples keyed by name; `save_h5` walks the tree recursively under a root group
   `Main` without knowing any device class (`src/h5_file_saving.jl`). That is a
   strong boundary: drivers describe themselves, the system assembles a
   meaningful record, the writer persists it. **[guarantee, 0.2.7-DEV]** (since 0.2.7) `save_h5` copies the state tree before
   returning its asynchronous task and writes the given path in place with HDF5's `"w"` open, following symlinks.
   It records whether the file the write lands on (a symlink's target) exists before writing. Every task failure,
   including an interrupt, logs once and rethrows; a new target is removed (the link's target for a symlink, keeping
   the link), and an existing file is truncated
   to zero bytes in place, keeping its inode, owner, mode, ACLs and hard links. Cleanup failures log separately
   without hiding the original error. **[limitation, 0.2.7-DEV]** saves overwrite in place and are not atomic.
   Since 0.2.7, stage exports refresh position without motion and record `position_fresh`; on a disconnected
   stage or failed read they warn once and keep the last-read position. **[limitation, 0.2.7-DEV]** assembling `export_state`
   across instruments is not an atomic snapshot, and it is not an inverse of `set_state`.
   **[policy]** decide when you export and mark what is missing, and
   build your own dictionaries as `Dict{String,Any}`: the tuple and tree shape
   is the guarantee, the concrete `Dict` parameters are not (`export_state(NIdaq())`
   returns `Dict{String,String}` attributes and `Dict{Any,Any}` children;
   `save_h5` accepts both).

6. **Common operations enable reuse; they do not establish interchangeability.
   [guarantee, 0.2.7-DEV; and the limitation is the point]** Two devices of one interface
   dispatch the same names, and that is all the type system checks. `capture`
   returns an enum on `SimCamera` and a frame on `DCAM4Camera`; `getposition`
   returns a tuple on some stages, a scalar on the Sims and an SDK success code
   on `N472`; `move` arity follows `dimensions`; units differ per stage
   (executed / traced, `references/driver-caveats.md`). Upstream's
   `test/contract.jl` checks dispatch and binding identity, not behavior.
   **[policy]** put a small adaptation layer in your system for the devices you
   actually use, and test it against the Sim and the hardware separately.

## Three kinds of state, kept distinct

| Kind | Lives in | Example | Trust |
|---|---|---|---|
| **Requested configuration** | device fields the driver pushes to hardware, and your `AbstractSystemState` | `cam.exposure_time = 0.02`; `stage.targ_z`; `light.level_requested` (DAQ volts) | what you asked for. **[guarantee, 0.2.7-DEV]** (since 0.2.7) `CrystaLaser`, `VortranLaser` and `DaqTrLight` retain accepted volts in `level_requested` and export it as `power_requested` in V; no command reads `properties.power` (`references/driver-caveats.md`, "DAQ voltage-light state"). These are requests, not optical measurements. **[guarantee, 0.2.7-DEV]** (since 0.2.5) `properties.power` is deprecated on a `DiodeLaser`: `SimDiodeLaser` and any `ConstantPhotocurrent` laser never write it, and an open-loop `TCubeLaser` still writes 0.2.4's uncalibrated linear guess (not in `power_unit`'s unit; read `drive_current` instead). Its requested state splits by mode: in `ConstantCurrent`, `laser.drive_current` is the mA `setcurrent!` last accepted (`NaN` before the first); in `ConstantPhotocurrent`, `drive_current` stays `NaN` for the life of the laser (the loop owns the current) and the request lives in `laser.pd.output_power_requested` (mW at the laser output) and `laser.pd.photocurrent_requested` (A, the decoded setpoint the loop was given). What the controller reports is measured state, next row. **[policy]** retain the instrument request separately: `Bench` below keeps its last `BenchState` in `sys.requested`; `get_state` returns that. `measured_power` returns `NaN` for a plain light, which has no optical readback, including the `CrystaLaser` in the example. |
| **Measured hardware state** | whatever the driver reads back | `stage.real_x` after `getposition`; a frame; `connectionstatus` | what the hardware said, at the moment you asked. **[limitation, 0.2.7-DEV]** the Sim stages copy `targ_*` into `real_*`, so measured equals requested there by construction. On a `DiodeLaser`: `measured_current` (mA), `measured_photocurrent` (A) and `loop_status` are readings; `indicated_output_power` (mW, `ConstantPhotocurrent` only) is a conversion of the photocurrent reading through a bench calibration, not a measurement of light. **[limitation, 0.2.7-DEV]** on `TCubeLaser` these three read the Kinesis readings and status caches that `initialize` sets polling (50 ms), with no request of their own (traced); that polling refreshes those caches is not hardware-verified (`tcube_get_current` requests a fresh reading instead). The setpoint read-back is a different cache, and the one that polling was seen to refresh (`references/driver-caveats.md`, `TCubeLaser` row). |
| **Saved metadata** | the `export_state` tree in the HDF5 file | `attrs["Main/camera"]["exposure_time"]` | a record of the above at snapshot time, plus whatever the system adds (which is missing, which is requested versus measured). |

**[policy]** name attributes so the reader can tell the kinds apart
(`power_requested` versus `power_measured`), snapshot after the blocking acquisition call
has returned, and never let a missing child look like an empty one.

## Worked example: a bench that forces four decisions

The instrument: one camera, one stage, one laser, two liquid-crystal attenuators on one
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

Forced decision: construction is part of the lifecycle for this driver, so ownership acquired in the constructor must
survive into the system's rollback. The executed `Bench` below keeps an `owned` list of every device known to hold
hardware; a constructor-claimed device is passed in as `claimed_at_construction=(cam,)` so it is owned before
`initialize` runs, is skipped by `initialize`, and is closed by the same `release!` that closes everything else. It is
also kept in `claimed`: once a rollback or `shutdown(sys)` has closed it, `initialize(sys)` refuses, because its no-op
`initialize` cannot open it again; reconstruct it and the system. What the constructor does on failure, how the DCAM
API is reference-counted across cameras in one process (since 0.2.7), and what an installed copy older than 0.2.1
needs instead, are in `references/driver-caveats.md`, the `DCAM4Camera` row, and only there.

### Decisions 3 and 4, executed: manual control versus acquisition, and a failed export

**[guarantee, suite: bench]** The suite runs the example below, and the fixtures after it, under `xvfb-run -a`, and
asserts the table that follows. The example reads the camera through `read_sequence` and judges it with `camera_ok`,
through `with_camera`, and after a failure stops it with `attempt_stop!` (`stop_camera!`, through `with_stop`): the
per-driver functions and shared pieces in `mc-acquire`, "Finite ordered sequence", which the suite runs first in the
same group. `BrokenLight` stands in for a device whose lifecycle or export throws; `ClaimedAtConstruction` for
`DCAM4Camera`; `FlakyLight` for a device whose `shutdown` fails once; `FailingCam` for a camera whose read or cleanup
fails, reporting the way `DCAM4Camera` does (`last_error` and `is_running`). The laser in the requested-versus-measured
and failed-initialize rows is the real `CrystaLaser` driver over `LineDAQ`, a `DAQ` that records each write instead of
driving a line and can be told to fail some.

**[limitation, 0.2.7-DEV]** The camera drivers spawn background tasks that the caller never receives, or
receives only by accident, and those tasks read mutable device fields as they run. What each driver's `sequence`
returns, what its `getdata` waits for and what its `abort` does is in `mc-acquire`'s table ("Finite ordered
sequence"), the one statement of those facts. The Sim's timer is the executed evidence (suite: bench): with 20 frames
at 0.01 s, raising `exposure_time` to 0.05 s after about five frames, while the timer runs, makes it run for more than
0.5 s, where a timer that read the exposure once would end at about 0.2 s. Consequently a system **cannot prove that a
previous acquisition has stopped** from timing, and **no wait computed at the caller fixes it**: any deadline derived
when the acquisition started depends on state the driver's task may read again later.

**[policy]** What a system should do today, as a restriction the drivers impose rather than a design preference: treat
the camera as **single-owner and single-acquisition**. One blocking acquisition at a time, on the task that called it;
**no cancellation**; no configuration change while an acquisition is in flight; and after every acquisition, successful
or not, ask the driver's `camera_ok` whether the camera is known to be stopped with its buffers released, as far as the
driver reports. When it is not, or when the stop after a failure threw, mark the camera unknown (`mc-acquire`'s mark:
every function in these skills that calls a camera does so through `with_camera`, which refuses a camera marked unknown,
or reserved by a live view, first and cannot be told not to, or, in a `stop_camera!` method only, through `with_stop`,
which lets a stop through; the one other exception is the `getlastframe` in `read_frames!`, the reader loop
`start_reader!` launches; and the suite checks the rule on the code) and **restart the process** (or reconstruct the
camera and the system) rather than attempt in-place recovery, since no lifecycle call can verify that the driver's task
is gone or that `initialize` did more than return. A camera with no `read_sequence` method is refused before anything
touches it; `ThorcamDCXCamera` and `ThorCamCSCCamera` have none, for the reasons `mc-acquire` gives. An
`InterruptException` is never logged and dropped by the example's own code: one that lands in the caller's own task
unwinds it, one that lands in a task the example joins is rethrown at the join, and `release!` first finishes shutting
down the other devices. The DCAM4 driver can lose one: in the sequence poller nobody joins, in the `catch` in the
cleanup of `getdata` and `capture`, and, with its SDK tracing enabled, in `trace_line`. And Julia's logging can lose
one while a record is logged, such as the failed stop `acquire!` logs, for a logger that catches exceptions, as the
default console logger does: on every version while the message is built, and from Julia 1.12 also while the logger
writes the record (`mc-acquire`'s limitations).

**[policy]** The upstream fix is concrete: the camera interface should require `sequence` (and `live`) to **return
the task it spawns**, or expose a join, and report a failed stop or release as a failure, so a system can establish
quiescence instead of guessing at it.

The example is therefore modest on purpose: `acquire!` runs start to finish on the calling task, reads through
`read_sequence`, and asks `camera_ok` afterwards, through `with_camera`, with no loop on `is_running`; an `in_flight`
flag guards `set_state`, `acquire!` and `shutdown` against misuse from another task; `acquire!` refuses a camera the
system does not hold, or any camera while a device is stuck, and runs through `with_camera`, which refuses a camera
marked unknown and marks the camera after any throw or when it is not known stopped; a failed acquisition attempts a
stop before returning the camera, logs and marks a stop the driver does not confirm, and leaves the camera marked either
way, since the read threw. Three lists track the devices: `claimed` holds those passed as `claimed_at_construction`;
`owned` holds the devices known to hold hardware; `stuck` holds each device whose `initialize` or `shutdown` threw, with
its error, because its state is unknown. Every `release!` retries the stuck devices, newest first, and `initialize`
refuses while any device is stuck, or while a claimed device is no longer owned: that one was closed and must be
reconstructed. `BenchState` is an **immutable** struct: a requested configuration is a value, `get_state` hands back the
retained record, and only another `set_state` can change it.

**[limitation, 0.2.7-DEV]** What the example covers. Cameras: `SimCamera` (run) and `DCAM4Camera` (its methods run
against the fake DCAM SDK); any other camera, `ThorcamDCXCamera` and `ThorCamCSCCamera` included, is refused by
`acquire!`, and for DCAM4 `camera_ok` reports only what the driver reports (`mc-acquire`'s limitation on `getdata`'s
cleanup), and a Ctrl-C reaches the caller directly in its own task or through a join, and can be lost in the driver's
places, and in Julia's logging while a failed stop is logged (while its message is built, on every version; while the
logger writes it, from Julia 1.12) (`mc-acquire`'s limitations on the sequence poller, the cleanup, SDK tracing and
logging). Lights and stages: those whose `initialize` and `shutdown` throw when they fail. The shutdown rule is a floor,
not knowledge of the drivers: `release!` treats a `shutdown` that returns as a close that worked, and some drivers
report a failed close through a return value instead (`shutdown(::ThorCamCSCCamera)` returns the two SDK status codes;
`shutdown(::DCAM4Camera)` returns the `dcamapi_uninit` code, and closes the device whether or not its stop worked,
recording that in `last_error`), which `release!` discards. A driver's `shutdown` can also close its handle even when it
throws (`TCubeLaser` without a modulator: a failed disable throws after the connection is closed, and the driver's
docstring has the caller reconnect with `initialize` to retry the disable, which this example refuses while the laser is
stuck, so rebuild instead) (traced). Check the drivers you hold, and record what their `shutdown` reports.

<!-- mc-test: bench -->
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

# A DAQ that records each write instead of driving a line, so the example runs the real CrystaLaser driver.
mutable struct LineDAQ <: DAQ
    writes::Vector{Pair{String,Float64}}
    failures::Int                                 # how many of the next writes fail, after reaching the line
end
LineDAQ(; failures = 0) = LineDAQ(Pair{String,Float64}[], failures)
MC.createtask(::LineDAQ, kind::String, channel::String; kw...) = channel   # the driver opens one task per command
function MC.setvoltage(d::LineDAQ, channel::String, v::Float64)
    push!(d.writes, channel => v)
    d.failures > 0 && (d.failures -= 1; error("LineDAQ: write failed"))
    return 1
end
MC.deletetask(::LineDAQ, channel::String) = nothing
MC.export_state(::LineDAQ) = (Dict{String,Any}("unique_id" => "LineDAQ"), nothing, Dict{String,Any}())

Base.@kwdef struct BenchState <: AbstractSystemState  # REQUESTED configuration, nothing measured; built by keyword
                                                  # (lab decision 0035). IMMUTABLE: a request is a value; get_state
    exposure_time::Float64                        # hands it back and nobody can edit the record in place
    z::Float64
    laser_power::Float64
end

mutable struct Bench <: AbstractSystem
    cam::Camera                                   # interface-typed: Sim in tests, hardware on the instrument
    stage::Stage
    laser::LightSource
    claimed::Vector{AbstractInstrument}           # devices that held hardware from their constructor
    owned::Vector{AbstractInstrument}             # devices known to hold hardware, in acquisition order
    stuck::Vector{Pair{AbstractInstrument,Any}}   # device => error: its initialize or shutdown threw, state unknown
    requested::Union{Nothing,BenchState}          # the last configuration asked for; the drivers do not all keep it
    in_flight::Bool                               # an acquisition is running on the calling task; nothing else may touch the camera
end                                               # (a camera out of service carries mc-acquire's unknown mark)
Bench(cam, stage, laser; claimed_at_construction=()) =
    Bench(cam, stage, laser, AbstractInstrument[claimed_at_construction...], AbstractInstrument[claimed_at_construction...],
          Pair{AbstractInstrument,Any}[], nothing, false)

holds(list, dev) = any(d -> d === dev, list)
stuck_report(sys::Bench) = join(("$(nameof(typeof(d))): $(sprint(showerror, e))" for (d, e) in sys.stuck), "; ")

function MC.initialize(sys::Bench)                # MC. prefix: extend the generic, do not shadow it
    isempty(sys.stuck) || error("devices in an unknown state ($(stuck_report(sys))); " *
                                "call shutdown(sys) until it succeeds, or rebuild the system")
    for dev in sys.claimed
        holds(sys.owned, dev) || error("$(nameof(typeof(dev))) was claimed at construction and has been shut down; " *
                                       "reconstruct it and rebuild the system")
    end
    for dev in (sys.laser, sys.stage, sys.cam)   # cheapest-to-abort first
        holds(sys.owned, dev) && continue        # known to hold hardware: claimed at construction, or initialized
        try
            initialize(dev)
            push!(sys.owned, dev)
        catch e
            push!(sys.stuck, dev => e)           # state unknown: a DAQ light whose 0 V write failed records is_on = true
            @warn "initialize failed; releasing everything held" device=typeof(dev) exception=e
            try
                release!(sys)                     # retries dev too, and closes constructor-claimed devices
            catch release_error                   # what it could not close stays in sys.stuck, and initialize refuses
                release_error isa InterruptException && rethrow()   # a Ctrl-C is never logged and dropped
                @error "the rollback left devices in an unknown state" exception=release_error
            end
            rethrow()                             # the caller sees why initialize failed, not the rollback's error
        end
    end
    return sys
end

# Shut down everything stuck or owned, newest first. A stuck device is newer than every owned one: initialize stops
# at the device that failed, and refuses to run while any device is stuck.
function release!(sys::Bench)
    todo = [reverse(first.(sys.stuck)); reverse(sys.owned)]
    failed = Pair{AbstractInstrument,Any}[]
    for dev in todo
        try
            shutdown(dev)
        catch e                                   # keep going: one stuck device must not leave the rest open
            pushfirst!(failed, dev => e)          # so `stuck` stays in acquisition order
        end
    end
    empty!(sys.owned)                             # each device is now shut down or stuck
    sys.stuck = failed
    any(p -> p.second isa InterruptException, failed) && throw(InterruptException())   # a Ctrl-C stays one
    isempty(failed) || error("shutdown failed, state unknown: " * stuck_report(sys))
    return nothing
end

function MC.shutdown(sys::Bench)
    sys.in_flight && error("an acquisition is in flight on another task; this system is single-owner, wait for it")
    release!(sys)
end

# get_state returns what was REQUESTED; measured values are read from device fields separately.
MC.get_state(sys::Bench) = sys.requested === nothing ? error("no configuration has been requested yet") : sys.requested
measured_power(sys::Bench) = laser_reading(sys.laser)
laser_reading(l::LightSource) = NaN                              # no optical readback; cached requests are not measurements
laser_reading(l::DiodeLaser) =                                   # since 0.2.5 properties.power is deprecated on a DiodeLaser
    regulation_mode(l) isa ConstantPhotocurrent ?
        indicated_output_power(l) :                              # mW at the laser OUTPUT: a conversion, not a meter
        NaN                                                      # ConstantCurrent has no optical number; log measured_current(l) (mA)

# The light's setter depends on its kind. On a DiodeLaser `setpower` is deprecated (throws in closed loop); setlevel! is the
# mode-agnostic call, taking a fraction 0..1 of the device's declared range (0 is not off).
set_laser!(l::LightSource, p::Float64) = setpower(l, p)          # plain light: the driver's own unit
set_laser!(l::DiodeLaser, frac::Float64) = setlevel!(l, frac)    # so BenchState.laser_power is a fraction here
laser_unit(l::LightSource) =                                     # the DAQ lights take volts whatever their properties say
    hasfield(typeof(l), :level_requested) ? "V" :
    hasfield(typeof(l), :properties) ? l.properties.power_unit : "unknown"
laser_unit(::DiodeLaser) = "fraction of the declared range"

function MC.set_state(sys::Bench, st::BenchState)
    sys.in_flight && error("refusing to change configuration while an acquisition is in flight")
    sys.cam.exposure_time = st.exposure_time      # requested; the driver pushes it on the next acquisition call
    move(sys.stage, sys.stage.targ_x, sys.stage.targ_y, st.z)
    set_laser!(sys.laser, st.laser_power)
    sys.requested = st                            # retained here because the light driver may not keep it
    return sys
end

function MC.export_state(sys::Bench)
    attributes = Dict{String,Any}("system" => "Bench", "julia" => string(VERSION),
        "laser_power_requested" => sys.requested === nothing ? NaN : sys.requested.laser_power,
        "laser_power_unit" => laser_unit(sys.laser))
    children = Dict{String,Any}()
    missing = String[]
    for (name, dev) in ("camera" => sys.cam, "stage" => sys.stage, "laser" => sys.laser)
        try
            children[name] = export_state(dev)
        catch e
            e isa InterruptException && rethrow()
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
# The driver-specific parts are read_sequence, stop_camera! and camera_ok (mc-acquire). A camera with only the
# fallback read_sequence is refused before anything touches it: its abort could be anything (CSC's is its shutdown).
has_reader(cam::Camera, n::Integer) =           # the call acquire! makes, with the length's own type
    which(read_sequence, Tuple{typeof(cam),typeof(n)}) !== which(read_sequence, Tuple{Camera,Integer})

function acquire!(sys::Bench, n::Integer)
    sys.in_flight && error("acquisition already in flight")
    isempty(sys.stuck) || error("devices in an unknown state ($(stuck_report(sys))); " *
                                "call shutdown(sys) until it succeeds, or rebuild the system")
    holds(sys.owned, sys.cam) || error("the camera is not held: initialize(sys) first")
    has_reader(sys.cam, n) || error("no sequence reader for $(nameof(typeof(sys.cam))); write one (see mc-acquire)")
    sys.in_flight = true
    try
        return with_camera(sys.cam) do            # mc-acquire's wrapper: it refuses a camera marked unknown, and marks
            try                                   # the camera on any throw or when it is not known stopped afterwards
                read_sequence(sys.cam, n)         # the (H, W, N) stack, or a throw
            catch
                attempt_stop!(sys.cam, "the stop after a failed acquisition")   # attempt the stop BEFORE giving
                rethrow()                         # the camera back; then the read's error (a Ctrl-C in the read, too)
            end
        end
    finally
        sys.in_flight = false
    end
end
```

The failure paths below also use these fixtures. They are part of the same run:

<!-- mc-test: bench -->
```julia
struct BrokenCam <: Camera end                   # initialize throws; shutdown works
MC.initialize(::BrokenCam) = error("BrokenCam: no device")
MC.shutdown(::BrokenCam) = nothing

mutable struct FlakyLight <: LightSource         # shutdown fails once (a transient write error), then works
    failures_left::Int
end
FlakyLight() = FlakyLight(1)
MC.initialize(::FlakyLight) = nothing
MC.shutdown(l::FlakyLight) = l.failures_left > 0 ? (l.failures_left -= 1; error("FlakyLight: write timed out")) : nothing

Base.@kwdef mutable struct FailingCam <: Camera  # its read or cleanup fails as chosen; it reports the way DCAM4 does
    read_fails::Bool = true                      # read_sequence throws after the sequence started
    cleanup_fails::Bool = false                  # a read that works still records an error: its buffer release failed
    abort_mode::Symbol = :works                  # :works; :throws; :keeps_running (returns, still running, error
                                                 # recorded); :clears_flag (returns, is_running cleared, error recorded,
                                                 # as after DCAM4's poller ran out its deadline on a stop that failed);
                                                 # :clears_then_throws (is_running cleared, no error recorded, then a
                                                 # throw); :interrupted (the same, then an InterruptException)
    is_running::Bool = false
    last_error::Int = 0                          # 0 is success
    aborts::Int = 0
end
MC.initialize(::FailingCam) = nothing
MC.shutdown(::FailingCam) = nothing
function read_sequence(c::FailingCam, n::Integer)
    c.last_error = 0                             # as the DCAM4 method does: judged from here
    c.is_running = true
    c.read_fails && error("SDK: read failed")
    c.is_running = false
    c.cleanup_fails && (c.last_error = 1)
    return zeros(UInt16, 2, 3, n)
end
camera_ok(c::FailingCam) = c.last_error == 0 && !c.is_running
function MC.CameraInterface.abort(c::FailingCam)
    c.aborts += 1
    c.abort_mode === :throws && error("SDK: abort refused")
    c.abort_mode in (:clears_then_throws, :interrupted) && (c.is_running = false)
    c.abort_mode === :clears_then_throws && error("SDK: abort failed after the flag was cleared")
    c.abort_mode === :interrupted && throw(InterruptException())
    c.abort_mode === :works || (c.last_error = 1)
    c.abort_mode === :keeps_running || (c.is_running = false)
    return nothing
end
```

**[guarantee, suite: bench]** What the run showed. The suite runs the code above and asserts every row of this table
with `SimCamera(roi=CameraROI(1,1,64,32), exposure_time=0.01)`, `SimStage3d()` and `SimLight()` unless stated, so a
change to the package that makes a row false fails the package's suite. The two `DiodeLaser` methods of
`laser_reading`, `set_laser!` and `laser_unit` (since 0.2.5) are in the last rows.

| Path | Result |
|---|---|
| **Rollback, first device fails**, camera claimed at construction | threw `initialize not implemented for BrokenLight`; `cam.open == false` afterwards, `owned` empty, and `stuck` held the `BrokenLight` (its `shutdown` throws too). |
| **Rollback, last device fails** (`BrokenCam` third) | threw `BrokenCam: no device`; stage back to `connectionstatus == false`, laser back to `is_on == false`; the rollback shut `BrokenCam` down as well, so `owned` and `stuck` were empty. |
| **Rollback whose own shutdown fails** (`FlakyLight` first, `BrokenCam` third) | threw `BrokenCam: no device`, the cause, not the rollback's error; `stuck` held only the light; the next `initialize(sys)` refused, naming `FlakyLight: write timed out`; `shutdown(sys)` then retried the light, which shut down, and `stuck` was empty. |
| **A light whose `initialize` fails** (`CrystaLaser` over `LineDAQ(failures = 2)`) | threw `LineDAQ: write failed`; the light went to `stuck` with `is_on == true`, the rollback retried its 0 V write, which failed too; `shutdown(sys)` then wrote 0 V, recorded `is_on == false` and left `stuck` empty: three 0 V writes in all. |
| **A claimed device that was shut down** | after `initialize(sys)` and `shutdown(sys)`, the next `initialize(sys)` refused (`ClaimedAtConstruction was claimed at construction and has been shut down; reconstruct it and rebuild the system`), and the camera stayed closed. |
| **Retry order** (two stuck and two owned devices, set by hand; then two owned devices whose shutdowns both fail once) | the next `shutdown(sys)` shut the stuck devices down newest first, then the owned ones newest first; the two that failed stayed in `stuck` in acquisition order, so their retry was newest first too. |
| **Requested versus measured**, `CrystaLaser(daq = LineDAQ(), channel = "Dev1/ao0")`: `initialize(sys)`, then `set_state(sys, BenchState(exposure_time=0.02, z=1.0, laser_power=2.5))` | `initialize` wrote 0 V; `get_state(sys).laser_power == 2.5`, `laser.level_requested == 2.5`, `laser.level_staged`, and nothing written while off; the camera's `exposure_time` was the requested 0.02 s; `isnan(measured_power(sys))`; export attributes `laser_power_requested == 2.5`, `laser_power_unit == "V"`; `light_on(laser)` then wrote the staged 2.5 V. |
| **Immutable requested state**: `get_state(sys).laser_power = 4.5` | refused: `setfield!: immutable struct of type BenchState cannot be changed`. |
| **Sequential acquisitions**: `acquire!(sys, 5)` then `acquire!(sys, 3)` | `(32, 64, 5)`, taking at least five of the requested 0.02 s exposures, `in_flight == false` and the camera not marked after; then `(32, 64, 3)`. |
| **In-flight guards** (flag set by hand; the example never runs two tasks) | `set_state`, `acquire!` and `shutdown` each refused with a message naming the in-flight acquisition. |
| **A camera the system does not hold, or marked unknown** (a camera that records every call made to it: `acquire!` before `initialize(sys)`, after `shutdown(sys)`, while a device is stuck, once the camera is marked unknown, and after a standalone `stop_camera!` that returned with `camera_ok` false) | each refused with no call reaching the camera: `the camera is not held: initialize(sys) first` for the first two, `devices in an unknown state ...` for the third, `camera unavailable: it is marked unknown ...` for the last two. |
| **A camera with no reader** (a recording camera with no `read_sequence` method, held from construction) | `acquire!` refused (`no sequence reader for NoReaderCam; write one (see mc-acquire)`) with no call reaching the camera, and the camera not marked. |
| **Readers `has_reader` sees** (`read_sequence(cam::ParamCam{T}, n::Int) where {T}`, and a method taking `n::Integer`) | both count for an `Int` length; for an `Int16` length the `ParamCam` method does not apply, so `acquire!` refuses it before touching the camera, as it would reach the fallback. |
| **Failing acquisition** (`FailingCam()`: the read fails, `abort` works) | rethrew `SDK: read failed`; `abort` had run once and `camera_ok` said yes, but the read threw, so the camera was marked unknown, with `in_flight == false`: the next `acquire!` refused it without reaching the camera. |
| **Failing acquisition whose `abort` throws** (`FailingCam(abort_mode = :throws)`) | rethrew `SDK: read failed`; the next `acquire!` refused `camera unavailable ...`; after `shutdown(sys)`, `initialize(sys)` succeeded and the `acquire!` after it still refused `camera unavailable ...`; **reconstruction** (new `Bench`, new camera, stage and laser reused) acquired `(32, 64, 3)`. |
| **A stop that throws after clearing the flag** (`:clears_then_throws`: `camera_ok` itself would say yes) | rethrew `SDK: read failed`, after logging the stop's error; the camera was marked unknown. |
| **An interrupt in the stop** (`:interrupted`) | `acquire!` threw the `InterruptException`, not the read's error, and the camera was marked unknown. |
| **A Ctrl-C in the Sim's timer** (`acquire!(sys, 20)` with 0.02 s exposures on its own task; after about 0.1 s the interrupt is scheduled into the timer task, where a Ctrl-C usually lands) | `join_task` on the acquisition threw a plain `InterruptException`; the camera was stopped and, the read having thrown, marked unknown, with `in_flight == false`. |
| **A Ctrl-C in the waiting task** (the same, with the interrupt scheduled into the task running `acquire!`) | a plain `InterruptException` again; the stop waited for the Sim's timer, so the camera was stopped, and it was marked unknown. |
| **`abort` returns with the capture running** (`:keeps_running`), or **returns with `is_running` cleared and an error recorded** (`:clears_flag`) | rethrew `SDK: read failed`; in both cases `camera_ok` said no, the stop was logged as not known stopped, and the camera was marked unknown, the second although `is_running` was clear. |
| **A read that works with a cleanup that fails** (`FailingCam(read_fails = false, cleanup_fails = true)`) | returned the stack, and the camera was marked unknown. |
| **Export with a failed child** | `complete == false`, `missing_children == "laser"`; through `save_h5` and back: groups `camera, laser, stage` (the Bench's `data` is `nothing`, so there is no `data` dataset), attr `missing_children == "laser"`. |
| **Observable shutdown failure** (a `BrokenLight`, whose `shutdown` throws, put in `owned`) | threw `shutdown failed, state unknown: BrokenLight: shutdown not implemented for BrokenLight` after finishing the loop; the stage was already disconnected; `owned` was empty and `stuck` held the `BrokenLight`; `initialize(sys)` then refused (`... call shutdown(sys) until it succeeds, or rebuild the system`) without touching a device, and the next `shutdown(sys)` retried it and threw the same message. |
| **A shutdown that fails once** (`FlakyLight` as the laser) | the first `shutdown(sys)` threw `shutdown failed, state unknown: FlakyLight: FlakyLight: write timed out`; the second returned normally and left `stuck` empty; `initialize(sys)` then brought all three devices up again. |
| **An interrupt during shutdown** (a light whose `shutdown` throws `InterruptException`) | `shutdown(sys)` threw an `InterruptException`, not an `ErrorException`, after finishing the loop, and the light was in `stuck`. |
| **Evidence for the limitation** | `sequence(SimCamera)` returned a `Task`; with 20 frames at 0.01 s, raising `exposure_time` to 0.05 s after about five frames, while the task ran, made it run for more than 0.5 s instead of about 0.2 s. |
| **`DiodeLaser` in the `laser` field**, `SimDiodeLaser()` (`ConstantCurrent`) | `set_state` with `laser_power = 0.5` set the level through `setlevel!` (`laser.drive_current` the middle of `min_current .. max_current`); `isnan(measured_power(sys))`; `laser_power_unit == "fraction of the declared range"`. |
| **`DiodeLaser`, `ConstantPhotocurrent`** (`SimDiodeLaser(mode = ConstantPhotocurrent(), ...)`, with synthetic calibration values) | once the laser is on, `measured_power(sys)` is `indicated_output_power`: the requested half of the power range, in mW, to 0.1 %. |

Provenance rule this example enforces **[policy]**: a saved record must
identify what is missing. Catching a failed `export_state` and dropping that
child produces a file that looks complete and is not.

## Four claims this skill must never make

If you find yourself writing any of these into system code or documentation,
stop; each is false at 0.2.7-DEV.

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
  (suite: extend-shadow, `mc-extend`'s `ShadowDriver` example, for `gui` and `setpower`).
- `move` takes `Float64`s. `move(stage, 1, 2, 3)` is a `MethodError`.
- `gui(dev)` is one generic that dispatches to the interface panel or a driver
  override (`N472`); a system menu is a list of `gui(sys.<field>)` calls. Each
  opens a GLMakie window (see `mc-testing` for `xvfb-run`). See the caveats
  file for which devices' panels open today. **[limitation, 0.2.7-DEV]** the
  camera panel's Start Live, Start Capture and Start Sequence buttons call
  `live`, `capture` and `sequence` directly, not through `mc-acquire`'s
  `with_camera`, so they start a camera marked unknown (traced from
  `camera_interface/gui.jl`). On an instrument whose
  acquisitions use the mark, offer the camera's panel only while the camera is
  not marked.
- **[limitation, 0.2.7-DEV]** `using MicroscopeControl` plus a blanket `using GLMakie`
  makes the name `Camera` ambiguous, so a struct field declared `::Camera`
  fails with `UndefVarError: Camera not defined`. MicroscopeControl loads
  GLMakie for its own panels, so every downstream that builds panels of its
  own hits this. `Camera` is the **only** name the two packages both export
  (suite: testing; the check compares the two export lists and defines the struct
  below in a fresh module), so the fix is narrow: import GLMakie selectively
  (`using GLMakie: Figure, Axis, Colorbar, ...`) or write
  `MicroscopeControl.Camera` where you need the type. Do not rename anything
  upstream to work around it.

  ```julia
  using MicroscopeControl
  using GLMakie                      # both export `Camera`
  struct Rig; cam::Camera; end       # UndefVarError: Camera not defined

  using GLMakie: Figure, Axis        # or: struct Rig; cam::MicroscopeControl.Camera; end
  ```

## Two more limitations that bear on design

- **[guarantee, 0.2.7-DEV]** Opening `gui(::LightSource)` issues no command (since 0.2.1).
  Since 0.2.7 the generic panel uses the light's own unit and bounds (DAQ lights
  their `level_requested` and voltage fields, independent of `properties.power`),
  a textbox entry moves the slider and issues one command, invalid entries stay
  at the box, command errors appear in the panel, and the toggle follows the
  driver after both level and output commands (`mc-api-map`'s
  `references/gui-fields.md`). **[limitation, 0.2.7-DEV]** closing the panel does not
  switch off the light. **[policy]** call `lights_off(lights)` (since 0.2.7)
  during teardown; it attempts every light and raises `MicroscopeControl.LightsOffError`
  with every named failure, interruptions included. A failed DAQ off command
  throws and records `is_on = true`; never infer off from a caught exception.
- **[limitation, 0.2.7-DEV]** `getposition(::SimStage3d)` returns a scalar (`3.0` after
  `move(s, 1.0, 2.0, 3.0)`), the value of its last assignment, while the
  interface docstring promises an `(x, y, z)` tuple (suite: testing). A system must
  not trust a return shape it has not checked on the device it holds; read the
  `real_*` fields, or wrap `getposition` in a per-device adapter that returns
  what you documented.
