---
name: mc-api-map
description: Points at the generated per-version list of which methods each MicroscopeControl.jl device type actually implements, which it inherits, and which resolve but throw; activates for "what methods does X have", "does this device support", "what can I call on this stage/camera", or "api map".
---

# mc-api-map

The file `references/api-map.md`, in this skill's directory, is the authoritative
answer to "what can I call on this device". It is not hand-written. `install_skills`
generates it by introspecting the MicroscopeControl.jl version installed in the
downstream environment at install time, so it matches the pinned tag, not `main`
and not this skill's prose. When the two disagree, the map wins. Read it before
calling anything on a device you have not used in this session.

## What bites first

Every generic in the package resolves for every device of its interface. A stage
always has a `move` method, a camera always has a `getdata`, every instrument has
`initialize`, `shutdown`, `export_state` and `gui`. Resolving is not implementing.
The interface files define fallback stubs that `error("... not implemented for
<Type>")`, so `hasmethod` says true and the call raises at runtime. The map exists
so you find out before the call, not on the rig.

## The three groups

Each device section (`### SimCamera`, `### DCAM4Camera`, ...) under its interface
heading (`## Camera`, `## Stage`, `## LightSource`, `## DAQ`, `## Attenuator`,
`## SLM`, `## TRIG`) lists exported generics in up to three groups:

| Group | Meaning | Example (SimCamera, v0.2.0) |
|---|---|---|
| **Device-specific** | A method whose first argument is this concrete type. Real driver code. Each signature is listed, so `sequence(DCAM4Camera, Real)` and `sequence(DCAM4Camera)` both appear. | `getdata(SimCamera)`, `initialize(SimCamera)` |
| **Inherited (shared implementation)** | Dispatch lands on a method written against the interface type that does real work for every device. Today that is the interface `gui` and the camera GUI helpers. | `gui(Camera)`, `start_live(Camera)` |
| **Not implemented for this device (throws)** | Dispatch lands on an interface contract stub in `interface_functions.jl`. The name resolves and then raises an error naming the type. | `setexposuretime!(Camera)`, `setroi!(Camera)` |

The third group is the reason the map exists: `setroi!(cam)` on a `SimCamera`
compiles, dispatches and throws. On a `DCAM4Camera` the same name is device-specific
and pushes the ROI to the hardware. Same call, different group, different outcome.

## What the map does not show

The throws group only covers stubs defined at the interface level (`Camera`,
`Stage`, ...). The lifecycle generics `initialize`, `shutdown`, `export_state` and
`gui` have their throwing stubs one level up, on `AbstractInstrument`, and those are
**not listed anywhere** in a device's section. So read absence as failure: if
`initialize` does not appear under a device, `initialize(dev)` throws. As of v0.2.0
that is the case for `ThorCamCSCCamera` (no `initialize`, no 1-arg `export_state`),
`TCubeLaser` (only `export_state(TCubeLaser, Any)` is listed, so the 1-arg call
throws), `Triggerscope4` (no `export_state`) and `MLSLM` (no lifecycle methods at
all). `MLSLM` and `Triggerscope4` sit outside the `AbstractInstrument` hierarchy
entirely (`SLM` and `TRIG` are `abstract type ... end` with no supertype), so they
never had fallbacks to begin with.

One known mislabel: the SLM interface file contains no `error` calls. Its 1-arg
`displayimage(::SLM)` is an empty no-op and its 2-arg form assigns to the abstract
type name rather than the instance. The map still files `displayimage(SLM)` under the
throws group because the classification is by file, not by behaviour. Treat SLM
interface calls as "silently does nothing", not "throws".

## Checking at the REPL

The map is a snapshot. To check a specific call against the loaded package, ask
where dispatch lands and whether that is the concrete type:

```julia
using MicroscopeControl

# true for every LightSource, because the interface stub exists
hasmethod(export_state, Tuple{TCubeLaser})
# -> true

# where the call actually goes
which(export_state, Tuple{TCubeLaser}).sig
# -> Tuple{typeof(export_state), AbstractInstrument}   (the throwing stub)

which(getdata, Tuple{SimCamera}).sig
# -> Tuple{typeof(getdata), SimCamera}                 (real driver code)

which(gui, Tuple{SimCamera}).sig
# -> Tuple{typeof(gui), Camera}                        (shared implementation)
```

A one-line predicate for "implemented on this type", the same one `test/contract.jl`
in the upstream repo uses:

```julia
has_specific(f, T, args...) =
    hasmethod(f, Tuple{T, args...}) && which(f, Tuple{T, args...}).sig.parameters[2] === T

has_specific(initialize, SimCamera)          # true
has_specific(initialize, ThorCamCSCCamera)   # false
has_specific(setpower, SimLight, Float64)    # true
```

For `gui` the right question is "does dispatch avoid the `AbstractInstrument`
stub", since the interface-level `gui` is the intended shared implementation:
`which(gui, Tuple{T}).sig.parameters[2] !== AbstractInstrument`.

## The `gui` alias line

The map header states that `gui` is also exported as `attenuator_gui`,
`laser_488_gui`, `laser_561_gui`, `nidaq_gui`, `red_laser_gui` and `tr_light_gui`.
These are the same `Function` object, imported under a second name by individual
drivers so the name is exported alongside the driver. They add no methods. Call
`gui(dev)`; the aliases exist for backwards compatibility only and are not listed
per device.

## Arity traps the map makes visible

- `light_on` is declared `light_on(::LightSource, ipower::Float64)` at the interface
  and implemented as `light_on(::T)` by all five drivers. The 2-arg call throws for
  every light source. The map lists `light_on(TCubeLaser)` etc. as device-specific;
  a 2-arg form never appears.
- `move` takes `Float64` positions. `move(stage, 1, 2, 3)` with integers is a
  `MethodError`, not a stub error.
- The SmarAct `MCS2Stage` has `move(MCS2Stage, Float64, Float64[, Float64])` in
  micrometres in the map. Its `move!` (picometres, `Vector{Int64}`) is no longer
  exported and is reachable only as
  `MicroscopeControl.HardwareImplementations.MCS2Stage_mod.move!`.

## Refreshing

The map is regenerated on every `install_skills()` call. After moving the pinned
tag in your `Project.toml`/`Manifest.toml`, run `install_skills()` again from the
downstream repo root. The manifest hash check will refuse to overwrite a locally
edited map; pass `install_skills(force=true)` if you edited it and want the
regenerated one. Do not hand-edit the map; edit the pin and reinstall.
