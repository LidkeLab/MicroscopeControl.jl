---
name: mc-extend
description: Extending MicroscopeControl.jl or working around it, in order of increasing commitment -- diagnose a misbehaving driver (it is usually the rig), report upstream against the pinned tag and work around locally without type piracy, implement an existing interface (Camera, Stage, LightSource, DAQ, Attenuator) for a new device downstream or as an upstream contribution, and define a new device class with its interface, simulated implementation and hand-registration; activates for "driver bug", "not working on hardware", "report", "new driver", "implement Camera/Stage/LightSource", "support this device", "SDK wrapper", "new interface", "new device class", or "MC has no interface for".
---

# mc-extend

Decide first with the decision rule in `mc-system-design`: driver, interface, or
system code. This skill covers the first two and what to do before either. It is
ordered by increasing commitment; start at step 1 even if you think you need
step 3. Labels as in `mc-system-design`: **[guarantee]** verified at MC v0.2.0,
**[limitation]** current shortfall to work around, **[policy]** recommended.
*Executed* means run under `xvfb-run -a` against v0.2.0; *traced* means read from
the upstream driver source and not run.

## The line that runs through this skill

**[guarantee]** MC has no registration API. Every driver is a concrete subtype of
an interface type plus methods added to MC's existing generic functions
(`initialize`, `CameraInterface.capture`, ...) **for that subtype**. Adding
methods for a type you own is the intended extension mechanism, whether the
type lives in your rig repo or upstream, and it is not type piracy.

Type piracy is defining a method on an MC generic for a type MC owns
(`MicroscopeControl.servo(::PIStage, ...)` from your package). You own neither
the function nor the type; the method installs when your package loads and
every caller that goes through the generic (the shared GUI, other downstream
code, the REPL) gets your behaviour, while callers that bypass it do not (PI's
`initialize_original` calls PI's private `servo` directly, traced). The
deviation is invisible in `Manifest.toml`, and when the pinned tag moves and
upstream ships its own fix the two methods collide or diverge silently. So:
your own type, extend freely (steps 3 and 4); an MC type, report and work
around from outside (step 2).

**[limitation]** The collision is worse than "diverge silently", and this has
happened. A rig repo defined `export_state(::TCubeLaser)` itself, because
v0.2.1 shipped only a 2-argument form and the 1-argument call fell through to
the throwing stub. When v0.2.3 added that method upstream, Julia failed
**precompilation** on the overwrite; in the environment that reported it the
package then did not load at all -- not a wrong answer, a dead package,
appearing the moment the pin moves. (The precompilation failure is certain; the
loader can fall back to source in some configurations, so do not count on
either outcome.) Note the direction: the risk is not only that you shadow
upstream, but that upstream later defines the same method, so the *fix* is what
breaks you.

If you must install such a shim while waiting, **guard it**, and guard it with
`which`, not `hasmethod`. `hasmethod(export_state, Tuple{TCubeLaser})` is
`true` both before and after the upstream fix, because before it matches the
throwing `export_state(::AbstractInstrument)` stub -- concrete argument types
do not make `hasmethod` an exact-signature test, so that guard suppresses the
shim exactly when it is needed. Install only while `which` still resolves to
the known abstract stub:

```julia
if which(MC.export_state, Tuple{MC.TCubeLaser}).sig.parameters[2] === MC.AbstractInstrument
    MC.export_state(l::MC.TCubeLaser) = ...   # stands aside once upstream defines it
end
```

and delete it when you next move the pin. This is the same distinction
`test/contract.jl`'s `has_specific_method` exists to make: "a method exists"
and "a method exists *for this type*" are different questions, and the
abstract fallbacks in this package make the first one useless.

## 1. Diagnose first: it is usually not the driver

Before reporting or writing anything, rule out the rig. The full symptom table
is in `references/rig-causes.md`; the short form:

| Symptom | Usually | Check |
|---|---|---|
| `initialize(::PIStage)` logs `@error` and returns, `connectionstatus` stays `false` (it does not throw) | controller unpowered, USB, or **held by another process** (PIMikroMove, a second Julia) | close the others; re-run; if it connects it was contention |
| `MLSLM` does nothing | board claimed elsewhere, or SDK found 0 boards (`n_boards_found` is a default of 0 and never updated) | read what `initializesdk()` prints; close the vendor GUI; reboot if a dead process holds it |
| serial timeouts / "port busy" (`Triggerscope4`, and `LCC1620` through it) | wrong COM number (Windows renumbers), or port open elsewhere; **two `Triggerscope4` objects on one port** | `LibSerialPort.list_ports()`; one scope object per port, shared (`mc-system-design`) |
| `CrystaLaser`/`VortranLaser`/`DaqTrLight` `@warn` at construction, then `setpower` does nothing | NI-DAQ discovery picked the wrong device (`devs[1]`, or `device_index`), runtime missing, or partial AO/DO discovery | inspect `light.channelsAO`/`channelsDO` after construction; `NIDAQcard.showdevices(NIdaq())` |
| a method throws `not implemented for <Type>` or does nothing | a contract stub, not a broken `ccall` (`mc-api-map`: resolving is not implementing) | `which(f, Tuple{typeof(dev)}).sig` names the interface or `AbstractInstrument` |

A defect is what remains: a wrong argument type or size in a `ccall`, a wrong
constant, a value read from the wrong place, a released buffer, an off-by-one.
v0.1.1's `PI_SVO` fix is the model case: flags packed as `UInt8` instead of
32-bit `BOOL`, so axis 2's servo read garbage (traced from the changelog and
`pi_stage/config_methods.jl`). The Sim devices cannot reproduce hardware
defects; a report needs the rig, in a fresh session with nothing else attached.

## 2. Report against the pinned tag, and work around from outside

The rig pins a tag (`Pkg.add(url=..., rev="v0.2.0")`) and the fix ships as a new
tag, so the report must say which tag, from the environment:
`pkgversion(MicroscopeControl)`, `VERSION`, `Sys.KERNEL`. Template:

```markdown
**Device**: <driver type> / <model and controller>
**MicroscopeControl.jl tag**: v0.2.0   **Julia**: 1.13.0   **OS**: Windows 11   **SDK/DLL**: <name, version>
**Call path**: `servo(stage, true, true)` -> `PI.servo` -> `PI_SVO`
**ccall involved** (driver file and line, pasted): ...
**Observed** (exact text; `stage.last_error`/`cam.last_error` if set) / **Expected** (SDK manual section)
**Reproduce**: minimal sequence from `initialize` to the failure
**Ruled out**: other process holding the device (Y/N, how); COM assignment (Y/N); fresh Julia (Y/N)
**Local workaround in use**: <link or "none">
```

```bash
gh issue create --repo LidkeLab/MicroscopeControl.jl --title "PIStage: <symptom> (v0.2.0, Windows)" --body-file report.md
```

Upstream tags every merge to `main`, so a merged fix is pinnable the same day;
offer a PR if you have the fix. Two honest workarounds while you wait:

- **Re-bind the C call under your own name** in your repo, with the corrected
  signature, and call that from your system code. MC is untouched:

  ```julia
  # RIG-LOCAL WORKAROUND for MicroscopeControl.jl issue #NN; remove when pinned tag >= the fixing release
  const PI = MicroscopeControl.HardwareImplementations.PI
  rig_servo_on(stage::PIStage, x::Bool, y::Bool) =
      @ccall PI.gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, Cint[x, y]::Ptr{Cint})::Cint
  ```

  (the corrected binding as it stands in `pi_stage/config_methods.jl`; traced,
  needs the PI DLL).
- **A fork pinned by `rev`**: `Pkg.add(url="https://github.com/<you>/MicroscopeControl.jl.git", rev="fix-pi-svo")`.
  The Manifest records the deviation; returning to upstream is one `Pkg.add`.

**[policy]** make workarounds obviously temporary: `rig_` prefix, one file
(`src/workarounds.jl`), the issue URL and fixing tag in a comment, and a test
that fails when the fix lands (`@test pkgversion(MicroscopeControl) < v"0.2.1"`).
After moving the pin, delete the workaround and rerun `install_skills()`.

## 3. Implement an existing interface for a new device

### Two arrangements, same code

| | Downstream-owned type (prototype, or a device only your rig has) | Upstream contribution |
|---|---|---|
| Location | a module in your repo | `src/hardware_implementations/<device>/` with `<Device>.jl`, `types.jl`, `interface_methods.jl`, SDK helpers |
| Imports | `using MicroscopeControl`; `import MicroscopeControl: initialize, shutdown, export_state, gui`; `import MicroscopeControl.LightSourceInterface` (or `CameraInterface`, `StageInterface`, ...) | `using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface`; `import ...MicroscopeControl: export_state, initialize, shutdown` (three dots: two module levels below `MicroscopeControl`) |
| Registration | none; `using .MyDrivers` in your system code | `include` + `@reexport` in `HardwareImplementations.jl` (section 5) |
| Tests | your suite, with the checks in section 6 | `test/contract.jl` runs the specificity, identity and `gui`-dispatch checks (section 6, items 1 to 3) on every subtype automatically; unsupported-operation throws, behaviour and serialisation (items 4 to 6) are a testset you add |

The complete scaffold, a serial LED as a `LightSource` over a fake transport,
with its executed results and the 23-assertion contract testset, is in
`references/driver-scaffold.md`. Its shape: transport helpers that **throw on a
closed link** (no silent no-op); a **pure constructor**; `initialize` that opens
the link only if it is not already open; `shutdown` that closes it only if
`owns_port`; interface operations that range-check and cache the *requested*
value; a 1-arg `export_state` whose attribute names say which kind of state
they hold (`power_requested`). **[limitation]** the interface also declares
`light_on(::LightSource, ipower::Float64)`, which no driver implements and
upstream tracks as `@test_broken`; implement the 1-arg form.

### Binding identity: import to extend, never rely on `using`

**[guarantee]** `using MicroscopeControl` brings the *name* `gui` into scope.
`function gui(::MyType)` after that creates a new `MyModule.gui`; nothing
errors; `MC.gui(dev)` silently dispatches to the inherited panel or the throwing
stub and your method is dead code. Two real instances existed in MC's own
drivers before v0.2.0 (traced from the `test/contract.jl` comments), which is why
upstream now asserts every generic a submodule defines `=== getfield(MicroscopeControl, g)`.

Executed:

```julia
module ShadowDriver
    using MicroscopeControl                 # NAME only
    struct ShadowLED <: LightSource end
    gui(::ShadowLED) = :my_custom_panel     # creates ShadowDriver.gui, a NEW function
    setpower(::ShadowLED, p::Float64) = :never_called
end
ShadowDriver.gui === MicroscopeControl.gui                              # false
which(MicroscopeControl.gui, Tuple{ShadowDriver.ShadowLED}).sig.parameters[2]   # LightSource: the shared panel
MicroscopeControl.setpower(ShadowDriver.ShadowLED(), 1.0)               # throws "setpower not implemented for ShadowLED"
hasmethod(MicroscopeControl.setpower, Tuple{ShadowDriver.ShadowLED,Float64})   # true!  resolves to the throwing stub
```

`hasmethod` cannot detect the bug; `which(f, Tuple{T,...}).sig.parameters[2] === T`
can, and so can checking `MyModule.setpower === MicroscopeControl.setpower`.
Two correct idioms; use one consistently:

| Idiom | Looks like | MC's own drivers use it for |
|---|---|---|
| import the generic, define unqualified | `import MicroscopeControl: initialize, shutdown, export_state, gui` then `function initialize(::T)` | the lifecycle generics |
| qualify the definition | `function CameraInterface.capture(::T)`, `StageInterface.move(::T, x, y)` | the interface operations |

**[limitation]**, traced: the PI stage driver names its private `ccall`
wrappers `move`, `getposition`, `getrange`, `stopmotion`, `servo` and its
qualified `StageInterface.move(::PIStage, ...)` methods call them unqualified;
importing those names would make each wrapper recurse forever, so upstream's
identity guard exempts exactly those five names in exactly that module. Name
your private helpers differently (`sdk_move`, `port_write!`).

### The implicit structural contract: fields the shared GUIs read

**[guarantee]** The interface `gui` methods are real shared panels that read
fields by name; a device lacking one gets a `FieldError` when its panel opens
even though every method dispatches. The full catalogue, per field and per
device, is `mc-api-map`'s `references/gui-fields.md`. What a new driver must
carry:

- **Stage**: `dimensions` (1, 2 or 3; drives the dispatch), `connectionstatus`,
  `stagelabel` (window title, **unguarded**), `targ_*`/`real_*`/`range_*` for
  each axis it has; `servostatus`/`driftcorrectionstatus` optional (guarded by
  `hasfield`). **[limitation]** the Sim stages carry `label`, so
  `gui(SimStage3d())` throws (executed); `N472` lacks the position fields and
  ships its own `gui(::N472)` override, which is the alternative route.
- **Camera**: `unique_id`, `exposure_time::Float64`, `roi::CameraROI`,
  `capture_mode` and `trigger_mode` as `Enum`s (the menus call `instances`),
  `sequence_length`, `is_running` (compared `== 1`). The panel uses the return
  value of `capture` as the frame. All four upstream cameras carry every field
  (executed).
- **LightSource / Attenuator**: `unique_id` and `properties`
  (`LightSourceProperties` / `AttenuatorProperties`). **Fixed in 0.2.1:** the
  light panel used to call `setpower(light, 0.5)` the moment it opened (the
  slider `lift` fired at creation), so opening a panel was a hardware write;
  a driver whose `setpower` correctly throws on a closed link would throw
  from inside `gui` (executed against a fake-transport light before the fix).
  The slider and toggle are now wired with `on`, which fires only on a later
  change, and initialised from the device's current `properties.power`/
  `properties.is_on`.

**[policy]** carry the fields rather than writing your own panel: the fields are
what make the Sim-for-hardware swap in `mc-testing` work.

### Behavioural obligations beyond method names

**[policy]** for a new driver; the third column names the upstream driver that
shows the failure mode as a **[limitation]** (traced unless marked).

| Obligation | Do this | Because |
|---|---|---|
| Constructor side effects | construct pure; open in `initialize` | `DCAM4Camera()` and `ThorCamCSCCamera()` open hardware in the constructor; **fixed in 0.2.1:** DCAM4 used to return an error code or `nothing` on failure, leaving the SDK initialized — it now throws on both failure paths, and each of those two checked paths *attempts* to uninitialize the SDK first (`dcamapi_uninit()` logs an `@error` if that fails, but the constructor ignores its return and throws anyway); an exception after a successful open has no such guard |
| Connection ownership | take shared dependencies as keyword arguments; record who closes (`owns_port`) | `CrystaLaser()` builds its own `NIdaq()`, first device, first channel; cannot be shared or configured |
| Partial-failure cleanup | if `initialize` opens A then fails on B, close A before rethrowing | nothing upstream does this for you |
| Failure visibility | throw, or set `last_error` and return `nothing`, and document which | the DAQ-backed lights `@warn` and return on an empty channel list: "initialized" and inert |
| Buffer lifetime | copy out of SDK buffers before releasing them | `DCAM4Camera.getdata` releases its buffers; `getlastframe` afterwards reads released memory (`mc-acquire`) |
| Acquisition completion | expose a completion signal (`is_running`, a `Task`, or a blocking call) | `sequence(::SimCamera)` spawns an `@async` task that flips `is_running`; DCAM4 blocks in `dcamwait_event` |
| Units | a `units`/`power_unit` field and the docstring; convert at the SDK boundary | PI millimetres, MCL micrometres, Sims unitless 0..100 |
| Calibration | table in the device (`AttenuatorProperties.cal_*`); values from the rig | `LCC1620.settransmission` `@error`s and returns when uncalibrated |
| Cached versus measured | name it (`power_requested`); update `real_*` only from a readback | Sim stages copy `targ_*` into `real_*`; `getposition(::SimStage3d)` returns a scalar, not the documented tuple (executed) |
| Image axis convention | `(H, W)` per frame, `(H, W, N)` per stack; at a row-major SDK boundary `permutedims(reshape(buf, (W, H)), (2, 1))` | DCAM4 does this in `dcambuf.jl`; `SimCamera` returns `(roi.height, roi.width[, N])` (executed); `save_h5` stamps `dimension_order` assuming it |
| `export_state` | 1-arg, `(Dict{String,Any}, data_or_nothing, Dict{String,Any})`; HDF5-safe values (`collect` tuples, `string` enums, `copy` vectors); children are named tuples | `Triggerscope4` has none (`MethodError`). `TCubeLaser` had only a 2-arg method until **v0.2.3**, so the contract call threw; the 1-arg method was added there and the 2-arg one kept as a deprecated forwarder |
| Unsupported operations | do not define the method; let the throwing stub answer | `stopmotion(::MCLStage)` is a concrete method whose body is `@error "STOP MOTION NOT IMPLEMENTED"` (executed), so `hasmethod` and the API map count it as implemented |

## 4. Define a new interface (rare, consequential)

You are writing a contract every future driver must satisfy and every system
will assume. Add one only when **all** hold: no existing interface can name the
operations without lying (a shutter as a `LightSource` is a defensible stretch,
a spectrometer as a `Camera` is not); at least two implementations are in view,
one real and the simulated one you ship with it; and someone will write system
code against the *interface* (Sim swap, shared panel, interface-typed field).
Otherwise write a driver and, if the fit is poor, a small adapter in your system.

**[guarantee]** An interface is `abstract type X <: AbstractInstrument end`, an
optional property struct, one generic per operation whose only method is a
stub that **throws** `error("<op> not implemented for $(typeof(x))")`, and an
optional shared `gui(::X)`. That is true of the five `AbstractInstrument`
interfaces; **[limitation]** `SLMInterface`'s `displayimage(::SLM)` has an empty
body and returns `nothing`, the one interface stub that does not throw. The lifecycle generics come from
`AbstractInstrument` and need no redeclaration. **[limitation]** `SLM` and `TRIG`
are **not** the template: they sit outside `AbstractInstrument`, so `MLSLM` has
no `initialize`/`shutdown`/`export_state`/`gui` at all (`MethodError`, not the
"not implemented" error), `Triggerscope4` has no `export_state`, neither can sit
in an `AbstractInstrument`-typed field or rollback list, and Meadowlark never
`include`s its `interface_functions.jl` so `displayimage(::MLSLM)` resolves to
an empty-bodied `displayimage(::SLM)` (executed). Full table, the executed
`Shutter` scaffold with its Sim implementation, and the rules for writing each
stub's docstring (signature and units, return, state update, failure behaviour,
completion, required versus optional) are in `references/interface-scaffold.md`.

**[policy]** the simulated implementation is mandatory and ships with the
interface: the stubs all throw (write them so), so nothing exercises the contract without it;
upstream's contract test iterates `subtypes`; downstream tests put it in the
interface-typed field; a shared panel is developed against it. Make it honest
about what it does not model. **[limitation]** upstream CLAUDE.md calls interface
GUIs optional while `test/contract.jl` requires every non-exempt device to
dispatch `gui` somewhere other than the `AbstractInstrument` stub; decide for
your interface and write it down.

## 5. Registration and exports (upstream)

**[guarantee]** Both container modules are flat include lists, and the root
already `@reexport`s each, so a name your module exports is callable unqualified
after `using MicroscopeControl` with no further edit:

```julia
# src/hardware_implementations/HardwareImplementations.jl   (a driver; after any module whose TYPE it references)
include("my_device/MyDevice.jl")
@reexport using .MyDevice
# src/hardware_interfaces/HardwareInterfaces.jl             (a new interface; its Sim implementation goes in the line above)
include("shutter_interface/ShutterInterface.jl")
@reexport using .ShutterInterface
```

Include order is module load order only, not a runtime rule. Export discipline,
enforced by upstream's "No ambiguous top-level exports" test (`names(MC)` all
`isdefined`): export your type and the operations users call; re-exporting `gui`,
`move`, `setpower` is fine **only** because they are the same objects as MC's;
never export a *different* function under a generic's name (two modules each
exporting their own `move` breaks every stage); keep SDK helpers private and
differently named; do not add `laser_488_gui`-style aliases. A new interface's
exported names land in the same flat namespace: prefer `open_shutter!` to
`open`; `TrigInterface` extends `Base.reset` rather than exporting its own for
exactly this reason (traced).

**A new interface must also be hand-registered in two literal tuples;
neither file walks `subtypes(AbstractInstrument)` [guarantee]**, verified in
both files at v0.2.0:

```julia
# test/contract.jl, "Interface Contract" testset          # src/skills.jl, API-map generator (~line 251)
interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG, MC.Shutter)
```

plus, in `test/contract.jl`, your operations appended to the `generics` tuple of
"No shadowed generics in submodules" and a per-interface testset
(`@testset "Shutter contract" ... has_specific_method(MC.open_shutter!, T)`).
An interface missing from either tuple loads fine and is invisible to both gates.

## 6. Tests a new device must satisfy

What upstream's `test/contract.jl` runs for **every** subtype: items 1 to 3
(method specificity for the lifecycle and the interface operations, function
identity for every generic a submodule defines, and `gui` dispatch off the
`AbstractInstrument` stub), plus, per `LightSource` subtype, a `@test_broken` on
the 2-arg `light_on`. Item 4 is **not** run per subtype: the only stub-throws
checks are three assertions on two test fixture types (`_ContractDummyStage`,
`_ContractDummyInstrument`), so write your own
`@test_throws` for the operations you leave unimplemented. Items 5 and 6 are
never automatic anywhere (full testset in `references/driver-scaffold.md`, 23
assertions, executed):

1. exact signatures: `which(f, Tuple{T,...}).sig.parameters[2] === T` for the
   lifecycle and every required operation;
2. shared-function identity: every generic your module defines
   `=== getfield(MicroscopeControl, g)`;
3. inherited `gui` lands on the interface panel, not the `AbstractInstrument` stub;
4. unsupported operations fail loudly (`@test_throws ErrorException`);
5. lifecycle and behaviour through a fake transport (pure constructor, opens on
   `initialize`, closed link is an error, failed open leaves nothing to clean);
6. `export_state` serialises: write it with `save_attributes_and_data` and read
   the attributes back.

| Simulation or fake transport establishes | Only hardware acceptance establishes |
|---|---|
| dispatch reaches your methods; no shadow bindings | the SDK does what the command says |
| lifecycle ordering and cleanup logic | timing, settling, buffer sizes, timeouts |
| range checks and error paths you coded | vendor error codes you have not seen |
| the export tree serialises | units and sign conventions on the real axis |
| GUI field compatibility (`hasfield`, or open the panel under `xvfb-run -a`) | that the panel's actions do the right physical thing |

**[policy]** record hardware acceptance (device, firmware, pinned tag, what was
checked) in the rig repo; upstream's CLAUDE.md says it is not tracked in MC.

## 7. Workflow

1. **Prototype downstream** as a module in your repo; type the system's field
   by the interface so the Sim device and yours are interchangeable in tests
   (`mc-testing`).
2. **Decide the destination** with the boundary test in `mc-system-design`: if
   it would make sense on another microscope, contribute it.
3. **Contribute from a source checkout**, never by editing the depot copy:
   `Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")`
   (or `path=` on a clone), a branch, the three-dot imports, registration
   (section 5, both tuples for an interface), a behavioural testset, full suite
   under `xvfb-run -a`.
4. **Docs**: docstrings on the type and every method (the stubs' docstrings are
   the template), a CHANGELOG entry under `[Unreleased]`, and a hardware
   verification line.
5. **Version** (traced from upstream CLAUDE.md): minor bump for an interface
   change (signature, export or dispatch contract), patch for everything else;
   every merge to `main` is tagged. A new driver adds exports and a new
   interface is an interface change, so expect a minor bump. Pin a tag, never
   `main`.
6. **Refresh the installed skills** after moving the pin: `install_skills()`
   again regenerates `mc-api-map`'s `references/api-map.md`, the only place your
   new type's method list appears automatically.
