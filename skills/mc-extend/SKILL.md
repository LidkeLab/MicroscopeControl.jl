---
name: mc-extend
description: Extending MicroscopeControl.jl or working around it, in order of increasing commitment -- diagnose a misbehaving driver (it is usually the instrument), report upstream against the pinned tag and work around locally without type piracy, implement an existing interface (Camera, Stage, LightSource, DAQ, Attenuator) for a new device downstream or as an upstream contribution, and define a new device class with its interface, simulated implementation and hand-registration; activates for "driver bug", "not working on hardware", "report", "new driver", "implement Camera/Stage/LightSource", "support this device", "SDK wrapper", "new interface", "new device class", or "MC has no interface for".
---

# mc-extend

Decide first with the decision rule in `mc-system-design`: driver, interface, or
system code. This skill covers the first two and what to do before either. It is
ordered by increasing commitment; start at step 1 even if you think you need
step 3. Labels as in `mc-system-design`: a guarantee names the version it was checked
at, or the suite group that checks it; a limitation is a shortfall to work around as of
the version it names; a policy is a recommendation. *Executed* means run under
`xvfb-run -a`, by the package's suite (`test/skill_examples.jl`) where it says *suite*;
*traced* means read from the upstream driver source and not run.

## The line that runs through this skill

**[guarantee, 0.2.7-DEV]** MC has no registration API. Every driver is a concrete subtype of
an interface type plus methods added to MC's existing generic functions
(`initialize`, `CameraInterface.capture`, ...) **for that subtype**. Adding
methods for a type you own is the intended extension mechanism, whether the
type lives in your instrument repo or upstream, and it is not type piracy.

Type piracy is defining a method on an MC generic for a type MC owns
(`MicroscopeControl.servo(::PIStage, ...)` from your package). You own neither
the function nor the type; the method installs when your package loads and
every caller that goes through the generic (the shared GUI, other downstream
code, the REPL) gets your behavior, while callers that bypass it do not (PI's
`initialize_original` calls PI's private `servo` directly, traced). The
deviation is invisible in `Manifest.toml`, and when the pinned tag moves and
upstream ships its own fix the two methods collide or diverge silently. So:
your own type, extend freely (steps 3 and 4); an MC type, report and work
around from outside (step 2).

**[limitation, historical: v0.2.1 to v0.2.3]** The collision is worse than "diverge silently", and this has
happened (the case below is v0.2.1 to v0.2.3; at 0.2.5 the 1-arg
method is upstream and the 2-arg form it replaced is a deprecated forwarder, so an instrument repo still carrying
a shim or a 2-arg call from that period should delete it; the pattern, and the
guard, apply to any future gap). An instrument repo defined `export_state(::TCubeLaser)` itself, because
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

<!-- mc-test: extend-shim -->
```julia
using MicroscopeControl
const MC = MicroscopeControl
# Runs at load. Installs the shim only while dispatch still lands on the
# abstract stub, so it stands aside once upstream defines the method.
if which(MC.export_state, Tuple{MC.TCubeLaser}).sig.parameters[2] === MC.AbstractInstrument
    @eval MC.export_state(l::MC.TCubeLaser) = (Dict{String,Any}("unique_id" => l.unique_id), nothing, Dict{String,Any}())
end
```

and delete it when you next move the pin. This is the same distinction
`test/contract.jl`'s `has_specific_method` exists to make: "a method exists"
and "a method exists *for this type*" are different questions, and the
abstract fallbacks in this package make the first one useless.

## 1. Diagnose first: it is usually not the driver

Before reporting or writing anything, rule out the instrument. The full symptom table
is in `references/rig-causes.md`; the short form:

| Symptom | Usually | Check |
|---|---|---|
| `initialize(::PIStage)` logs `@error` and returns, `connectionstatus` stays `false` (it does not throw) | controller unpowered, USB, or **held by another process** (PIMikroMove, a second Julia) | close the others; re-run; if it connects it was contention |
| `MLSLM` does nothing | board claimed elsewhere, or SDK found 0 boards (`n_boards_found` is a default of 0 and never updated) | read what `initializesdk()` prints or returns (`n_boards_found`, `constructed_ok`); close the vendor GUI; reboot if a dead process holds it |
| serial timeouts / "port busy" (`Triggerscope4`, and `LCC1620` through it) | wrong COM number (Windows renumbers), or port open elsewhere; **two `Triggerscope4` objects on one port** | `LibSerialPort.list_ports()`; one scope object per port, shared (`mc-system-design`) |
| DAQ voltage light warns at discovery or throws on a missing channel/write | **[limitation, 0.2.7-DEV]** unnamed outputs still use enumeration; runtime missing or partial AO/DO discovery can leave channels absent. **[guarantee, 0.2.7-DEV]** (since 0.2.7) commands throw on missing channels; a single-line off `setpower` records only. | **[policy]** inspect selected `channel` or `ao_channel`/`do_channel`; pass named outputs and `daq::DAQ`. |
| a method throws `not implemented for <Type>` or does nothing | a contract stub, not a broken `ccall` (`mc-api-map`: resolving is not implementing) | `which(f, Tuple{typeof(dev)}).sig` names the interface or `AbstractInstrument` |

A defect is what remains: a wrong argument type or size in a `ccall`, a wrong
constant, a value read from the wrong place, a released buffer, an off-by-one.
v0.1.1's `PI_SVO` fix is the model case: flags packed as `UInt8` instead of
32-bit `BOOL`, so axis 2's servo read garbage (traced from the changelog and
`pi_stage/config_methods.jl`). The Sim devices cannot reproduce hardware
defects; a report needs the instrument, in a fresh session with nothing else attached.

## 2. Report against the pinned tag, and work around from outside

The instrument computer pins a tag or a `main` commit (`mc-system-design`, "Before anything") and the fix
ships as a new tag, so the report must say which, from the environment: `pkgversion(MicroscopeControl)`, the
`rev` in the instrument's `Manifest.toml`, `VERSION`, `Sys.KERNEL`. Template:

```markdown
**Device**: <driver type> / <model and controller>
**MicroscopeControl.jl tag or commit**: <vX.Y.Z or the 40-character commit>   **Julia**: <VERSION>   **OS**: <OS>   **SDK/DLL**: <name, version>
**Call path**: `servo(stage, true, true)` -> `PI.servo` -> `PI_SVO`
**ccall involved** (driver file and line, pasted): ...
**Observed** (exact text; `stage.last_error`/`cam.last_error` if set) / **Expected** (SDK manual section)
**Reproduce**: minimal sequence from `initialize` to the failure
**Ruled out**: other process holding the device (Y/N, how); COM assignment (Y/N); fresh Julia (Y/N)
**Local workaround in use**: <link or "none">
```

```bash
gh issue create --repo LidkeLab/MicroscopeControl.jl --title "PIStage: <symptom> (<tag>, <OS>)" --body-file report.md
```

Upstream tags releases, not every merge: between releases `main` carries a
`-DEV` version, so a merged fix is pinnable once the release that carries it is
tested and tagged. Offer a PR if you have the fix. Two honest workarounds while you wait:

- **Re-bind the C call under your own name** in your repo, with the corrected
  signature, and call that from your system code. MC is untouched:

  ```julia
  # RIG-LOCAL WORKAROUND for MicroscopeControl.jl issue #NN; remove when pinned tag >= the fixing release
  const PI = MicroscopeControl.HardwareImplementations.PI
  rig_servo_on(stage::PIStage, x::Bool, y::Bool) =
      @ccall PI.gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, Cint[x, y]::Ptr{Cint})::Cint
  ```

  (the binding is `pi_stage/gcs2.jl`'s `PI_SVO`, and the corrected call, `Cint[xtoggle, ytoggle]`,
  is `servo` in `pi_stage/config_methods.jl`; traced, needs the PI DLL).
- **A fork pinned by `rev`**: `Pkg.add(url="https://github.com/<you>/MicroscopeControl.jl.git", rev="fix-pi-svo")`.
  The Manifest records the deviation; returning to upstream is one `Pkg.add`.

**[policy]** make workarounds obviously temporary: `rig_` prefix, one file
(`src/workarounds.jl`), the issue URL and fixing tag in a comment, and a test
that fails when the fix lands (`@test pkgversion(MicroscopeControl) < v"0.2.1"`).
After moving the pin, delete the workaround and rerun `install_skills()`.

## 3. Implement an existing interface for a new device

### Two arrangements, same code

| | Downstream-owned type (prototype, or a device only your instrument has) | Upstream contribution |
|---|---|---|
| Location | a module in your repo | `src/hardware_implementations/<device>/` with `<Device>.jl`, `types.jl`, `interface_methods.jl`, SDK helpers |
| Imports | `using MicroscopeControl`; `import MicroscopeControl: initialize, shutdown, export_state, gui`; `import MicroscopeControl.LightSourceInterface` (or `CameraInterface`, `StageInterface`, ...) | `using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface`; `import ...MicroscopeControl: export_state, initialize, shutdown` (three dots: two module levels below `MicroscopeControl`) |
| Registration | none; `using .MyDrivers` in your system code | `include` + `@reexport` in `HardwareImplementations.jl` (section 5) |
| Tests | your suite, with the checks in section 6 | `test/contract.jl` runs the specificity, identity and `gui`-dispatch checks (section 6, items 1 to 3) on every subtype automatically; unsupported-operation throws, behavior and serialization (items 4 to 6) are a testset you add |

The complete scaffold, a serial LED as a `LightSource` over a fake transport,
with its executed results and the 23-assertion contract testset, is in
`references/driver-scaffold.md`. Its shape: transport helpers that **throw on a
closed link** (no silent no-op); a **pure constructor**; `initialize` that opens
the link only if it is not already open; `shutdown` that closes it only if
`owns_port`; interface operations that range-check and cache the *requested*
value; a 1-arg `export_state` whose attribute names say which kind of state
they hold (`power_requested`). **[guarantee, 0.2.7-DEV]** the interface declares
`light_on(::LightSource)` only; implement that. (Up to v0.2.4 it declared a 2-arg
`light_on(::LightSource, ipower::Float64)` that no driver implemented; 0.2.5
removed it, so a 2-arg call is a `MethodError`.)

### Binding identity: import to extend, never rely on `using`

**[guarantee, 0.2.7-DEV]** `using MicroscopeControl` brings the *name* `gui` into scope.
`function gui(::MyType)` after that creates a new `MyModule.gui`; nothing
errors; `MC.gui(dev)` silently dispatches to the inherited panel or the throwing
stub and your method is dead code. Two real instances existed in MC's own
drivers before v0.2.0 (traced from the `test/contract.jl` comments), which is why
upstream now asserts every generic a submodule defines `=== getfield(MicroscopeControl, g)`.

**[guarantee, suite: extend-shadow]** The suite runs this and asserts each `# -> ` value, and the stub's message:

<!-- mc-test: extend-shadow -->
```julia
using MicroscopeControl
module ShadowDriver
    using MicroscopeControl                 # NAME only
    struct ShadowLED <: LightSource end
    gui(::ShadowLED) = :my_custom_panel     # creates ShadowDriver.gui, a NEW function
    setpower(::ShadowLED, p::Float64) = :never_called
end
ShadowDriver.gui === MicroscopeControl.gui                                         # -> false
which(MicroscopeControl.gui, Tuple{ShadowDriver.ShadowLED}).sig.parameters[2]      # -> LightSource   # the shared panel
try MicroscopeControl.setpower(ShadowDriver.ShadowLED(), 1.0) catch e; sprint(showerror, e) end   # "setpower not implemented for ...ShadowLED"
hasmethod(MicroscopeControl.setpower, Tuple{ShadowDriver.ShadowLED,Float64})      # -> true   # resolves to the throwing stub
```

`hasmethod` cannot detect the bug; `which(f, Tuple{T,...}).sig.parameters[2] === T`
can, and so can checking `MyModule.setpower === MicroscopeControl.setpower`.
Two correct idioms; use one consistently:

| Idiom | Looks like | MC's own drivers use it for |
|---|---|---|
| import the generic, define unqualified | `import MicroscopeControl: initialize, shutdown, export_state, gui` then `function initialize(::T)` | the lifecycle generics |
| qualify the definition | `function CameraInterface.capture(::T)`, `StageInterface.move(::T, x, y)` | the interface operations |

**[limitation, 0.2.7-DEV]**, traced: the PI stage driver names its private `ccall`
wrappers `move`, `getposition`, `getrange`, `stopmotion`, `servo` and its
qualified `StageInterface.move(::PIStage, ...)` methods call them unqualified;
importing those names would make each wrapper recurse forever, so upstream's
identity guard exempts exactly those five names in exactly that module. Name
your private helpers differently (`sdk_move`, `port_write!`).

### The implicit structural contract: fields the shared GUIs read

**[guarantee, 0.2.7-DEV]** The interface `gui` methods are real shared panels that read
fields by name; a device lacking one gets a missing-field error when its panel opens
(a `FieldError` on Julia 1.12 and later, an `ErrorException` on 1.11) even though every
method dispatches. The full catalog, per field and per
device, is `mc-api-map`'s `references/gui-fields.md`. What a new driver must
carry:

- **Stage**: `dimensions` (1, 2 or 3; drives the dispatch), `connectionstatus`,
  `stagelabel` (window title, **unguarded**), `targ_*`/`real_*`/`range_*` for
  each axis it has; `servostatus`/`driftcorrectionstatus` optional (guarded by
  `hasfield`). **[limitation, suite: testing]** the Sim stages carry `label`, so
  `gui(SimStage3d())` throws; `N472` lacks the position fields and
  ships its own `gui(::N472)` override, which is the alternative route (suite: testing).
- **Camera**: `unique_id`, `exposure_time`, `roi::CameraROI`,
  `capture_mode` and `trigger_mode` as `Enum`s (the menus call `instances`),
  `sequence_length`, `is_running` (compared `== 1`). The panel uses the return
  value of `capture` as the frame. All four upstream cameras carry every field
  name (suite: testing), but not every type the panel needs: the types are in
  `mc-api-map`'s `references/gui-fields.md`, section `gui(::Camera)`.
- **LightSource / Attenuator**: `unique_id` and `properties`
  (`LightSourceProperties` / `AttenuatorProperties`). **Fixed in 0.2.1:** the
  light panel used to call `setpower(light, 0.5)` the moment it opened (the
  slider `lift` fired at creation), so opening a panel was a hardware write;
  a driver whose `setpower` correctly throws on a closed link would throw
  from inside `gui` (executed against a fake-transport light before the fix).
  The slider and toggle are now wired with `on`, which fires only on a later
  change, and initialized from the device's current `properties.power`/
  `properties.is_on`.
- **DiodeLaser** (0.2.5; a laser on a controller that regulates drive current or
  monitor photocurrent; a light that is only voltage-modulated stays a plain
  `LightSource`): **[guarantee, 0.2.7-DEV]** the shared `current_panel`/`power_panel` and
  `setlevel!` read `unique_id`, `properties` (`is_on`; `min_power`/`max_power` as
  the enforced mW bounds at the laser output in `ConstantPhotocurrent` mode),
  `min_current`, `max_current`, `threshold_current` (mA, `NaN` unknown),
  `drive_current` (mA requested, `NaN` before the first and always in
  `ConstantPhotocurrent`) and `pd::Union{Nothing,PhotodiodeLoop}` (a
  `PhotodiodeLoop` exactly in `ConstantPhotocurrent`). Beyond fields, the driver
  is parametric, `MyLaser{M<:RegulationMode} <: DiodeLaser`, and defines
  `supported_modes(::Type{<:MyLaser})` (a tuple of mode types; the contract test
  expands the device through it) and `regulation_mode(::Type{MyLaser{M}}) where
  {M} = M()`; its inner constructor rejects a mode not in `supported_modes` and
  calls `LightSourceInterface.check_diode_config`. Do not define `setpower`: the
  `DiodeLaser` method (a deprecated forwarder in open loop, a refusal in closed loop) must answer. `TCubeLaser` and `SimDiodeLaser` are the two
  templates.

**[guarantee, 0.2.7-DEV]** Mode-shared methods (`initialize`, `shutdown`, `export_state`,
`light_on`, `light_off`, `measured_current`, `measured_photocurrent`,
`loop_status`) are written against the bare type (`TCubeLaser`); mode-specific
ones against the instantiation (`setcurrent!(::TCubeLaser{ConstantCurrent},
::Float64)`, `setoutputpower!`/`indicated_output_power` on
`TCubeLaser{ConstantPhotocurrent}`). `test/contract.jl` checks exactly those
signatures, so **[policy]** never write a `where M` method on a generic the
contract test checks: its signature matches neither the bare type nor an
instantiation, and the gate fails. Dispatch on the mode inside a mode-shared method
with a helper (`enter_mode!(regulation_mode(l), l)`), as `TCubeLaser` does.

**[policy]** carry the fields rather than writing your own panel: the fields are
what make the Sim-for-hardware swap in `mc-testing` work.

### A light that takes a modulator

A light whose level can go out as a voltage on an analog input (a TLD001's rear MOD IN, driven by a DAQ output; a
Triggerscope DAC modulator follows in a later release) carries `modulator::Union{Nothing,AbstractModulationControl}`, keyword `modulator = nothing`.
**[guarantee, 0.2.7-DEV]** (since 0.2.7) `TCubeLaser`, `SimDiodeLaser` and `SimLight` do; with `nothing` every method runs the code it always
did. **[limitation, 0.2.7-DEV]** `CrystaLaser`, `VortranLaser` and `DaqTrLight` take none: their native level path is already a DAQ
voltage. The modulator holds the scale: `NIDAQModulator(; channel, v_range, per_volt, daq)` converts `setpower(modulator, p)`, with `p` in the light's own unit
(`per_volt` is that unit per volt), to a voltage; `p = 0` is 0 V; an `ArgumentError` means out of reach and nothing was
written. A modulator is not an `AbstractInstrument` (no panel). It defines `setpower(mc, ::Float64)`,
`initialize(mc)`, `shutdown(mc)` and `output_id(mc)`; the contract test checks all four on its own type, and
`output_id` is in the shadowed-generics list, so `import` it to extend it.

**[policy]** A driver that takes one keeps this convention (the `LightSource` docstring has it in full):

1. a `const modulator` field, default `nothing`; `initialize` ends with `LightSourceInterface.open_modulator!(light)`,
   the output off (it claims `output_id`, so a second light object cannot drive the same output, then opens at 0 V);
   `shutdown` calls `close_modulator!(light)` after switching off (a failed `shutdown(mc)` keeps the claim for a retry);
2. `light_on` writes level 0 before the enable (a throw enables nothing), runs its own steps, then
   `setpower(modulator, request)`; any throw after the enable, an `ArgumentError` included, switches the light off;
3. `light_off` writes 0 first, logging a failure, and always switches off, even when the write is interrupted
   (`LightSourceInterface.propagate_interrupt` passes the interrupt on after the switch-off);
4. a level setter validates as it did, then writes `setpower(modulator, p)` only while the light is on, so the output
   holds 0 V while off; an `ArgumentError` changes nothing, any other throw tries level 0, switches off and rethrows
   (`LightSourceInterface.apply_level!` does that). A switch-off that itself fails leaves the output unknown: say so,
   and leave `properties.is_on` set;
5. never use the native level path while there is a modulator;
6. **[guarantee, 0.2.7-DEV]** for `TCubeLaser`: a per-light lock serializes the writes and state changes, a short `usb_lock` only the
   Kinesis enable and disable calls; `light_on` arms under the first, sleeps and polls unlocked, and applies the current
   request under it, so a setter, `light_off`, `initialize`, `shutdown` or a second `light_on` landing anywhere in between
   ends consistent (a setter while arming only records). `light_off` and `shutdown` disable at once, never waiting for
   a stalled modulator write, and write level 0 after, so the TCube's order is the reverse of item 3's; the same
   holds for its failed level write, which disables before it writes 0. A disable that fails throws, stays pending
   (`disable_pending`, `properties.is_on` still `true`, the output possibly on) and is retried by `shutdown`
   (traced from `tcube_laser/modulation.jl`). A new driver that sleeps inside `light_on` should follow the same split.

**[guarantee, 0.2.7-DEV]** (since 0.2.7) `MicroscopeControl.modulation_violations(light; set!, expect)` checks 1 to 5 on an initialized light
whose `modulator` is a `MicroscopeControl.RecordingModulator` (it writes nothing, records everything, and can be made to
fail or to refuse a level), and returns the list of violations. A downstream package, with its native side faked, adds

```julia
@test isempty(MicroscopeControl.modulation_violations(light; set! = l -> setpower(l, 2.0), expect = 2.0))
```

`set!` sets a level in the light's unit and `expect` is what the modulator should then be asked for; pass
`RecordingModulator(sink = p -> ...)` to drive the faked device from each accepted level. The TCube's own part of the
convention (control source 3, the 1.3 s settle wait, the confirm at each `light_on`) is in its docstring and
`CALIBRATION.md`.

**[guarantee, 0.2.7-DEV]** (since 0.2.7) The DAQ voltage lights take `setpower(light, ::Float64)`
in volts, retain `level_requested`, export that request in V, and write before they record state; the full rules
are in `mc-system-design`'s `references/driver-caveats.md`, "DAQ voltage-light state", and only there.
**[policy]** use `lights_off(lights)` (since 0.2.7) for teardown; it continues after every
exception and raises `MicroscopeControl.LightsOffError` with all name/error pairs.

### Behavioral obligations beyond method names

**[policy]** for a new driver; the third column names the upstream driver that
shows the failure mode as a **[limitation, 0.2.7-DEV]** (traced unless marked).

| Obligation | Do this | Because |
|---|---|---|
| Constructor side effects | construct pure; open in `initialize` | `DCAM4Camera()` and `ThorCamCSCCamera()` open hardware in the constructor; what DCAM4's constructor does on failure, and how its API is reference-counted across cameras (since 0.2.7), is in `mc-system-design`'s `references/driver-caveats.md`, the `DCAM4Camera` row |
| Connection ownership | take shared dependencies as keyword arguments; record who closes (`owns_port`) | **[guarantee, 0.2.7-DEV]** (since 0.2.7) DAQ lights accept `daq::DAQ` and named outputs; **[limitation, 0.2.7-DEV]** omitted names retain discovery by enumeration |
| Partial-failure cleanup | if `initialize` opens A then fails on B, close A before rethrowing | nothing upstream does this for you |
| Failure visibility | throw, or set `last_error` and return `nothing`, and document which | **[guarantee, 0.2.7-DEV]** (since 0.2.7) DAQ voltage lights throw on missing outputs or failed commands, and record state only after a successful write and cleanup; `shutdown(::ThorCamCSCCamera)` instead returns its two SDK status codes, so a failed close does not throw |
| Buffer lifetime | copy out of SDK buffers before releasing them | DCAM4's and DCx's `getdata` copy every frame out before they release the buffers; `getdata` after `capture` on a `DCAM4Camera` reads from a buffer `capture` already released (`mc-acquire`, capture contract) |
| Acquisition completion | return the task `sequence` spawns, or make `getdata` block until the sequence ends, and document which; report a failed start or stop as a failure | no two drivers agree, and `is_running` is no completion signal: the per-driver table in `mc-acquire`, "Finite ordered sequence", is the one statement; add your driver's `read_sequence`, `stop_camera!`, `camera_ok` and `live_started` methods there, making its camera calls inside `with_camera` (in `stop_camera!`, `with_stop`) |
| Units | a `units`/`power_unit` field and the docstring; convert at the SDK boundary | PI millimeters, MCL micrometers, Sims unitless 0..100 |
| Calibration | table in the device (`AttenuatorProperties.cal_*`); values measured on the instrument | `LCC1620.settransmission` `@error`s and returns when uncalibrated |
| Cached versus measured | name it (`power_requested`); update `real_*` only from a readback | Sim stages copy `targ_*` into `real_*`; `getposition(::SimStage3d)` returns a scalar, not the documented tuple (suite: testing) |
| Image axis convention | `[y, x]`: `(H, W)` per frame, `(H, W, N)` per stack, `[1, 1]` top left (lab decision 0040, `docs/src/conventions.md`); at a row-major SDK boundary call `CameraInterface.rowmajor_to_yx(buf, W, H; stride)` once and permute nothing afterwards | DCAM4, DCx and CSC call it (tested through fakes in `test/image_layout*.jl`); `SimCamera` returns `(roi.height, roi.width[, N])` (suite: testing); `save_h5` stamps `dimension_order = "y,x[,frame]"` assuming it |
| `export_state` | 1-arg, `(Dict{String,Any}, data_or_nothing, Dict{String,Any})`; HDF5-safe values (`collect` tuples, `string` enums, `copy` vectors); children are named tuples | `Triggerscope4` has none (`MethodError`). `TCubeLaser` had only a 2-arg method until **v0.2.3**, so the contract call threw; the 1-arg method was added there, and the 2-arg one is kept as a deprecated forwarder to this day (`test/contract.jl` asserts `hasmethod(export_state, Tuple{TCubeLaser,Any})`; removal waits for the next breaking release) |
| Unsupported operations | do not define the method; let the throwing stub answer | `stopmotion(::MCLStage)` is a concrete method whose body is `@error "STOP MOTION NOT IMPLEMENTED"` (suite: testing), so `hasmethod` and the API map count it as implemented |

## 4. Define a new interface (rare, consequential)

You are writing a contract every future driver must satisfy and every system
will assume. Add one only when **all** hold: no existing interface can name the
operations without lying (a shutter as a `LightSource` is a defensible stretch,
a spectrometer as a `Camera` is not); at least two implementations are in view,
one real and the simulated one you ship with it; and someone will write system
code against the *interface* (Sim swap, shared panel, interface-typed field).
Otherwise write a driver and, if the fit is poor, a small adapter in your system.

**[guarantee, 0.2.7-DEV]** An interface is `abstract type X <: AbstractInstrument end`, an
optional property struct, one generic per operation whose only method is a
stub that **throws** `error("<op> not implemented for $(typeof(x))")`, and an
optional shared `gui(::X)`. That is true of the five `AbstractInstrument`
interfaces; **[limitation, 0.2.7-DEV]** `SLMInterface`'s `displayimage(::SLM)` has an empty
body and returns `nothing`, the one interface stub that does not throw (traced). The lifecycle generics come from
`AbstractInstrument` and need no redeclaration. **[limitation, 0.2.7-DEV]** `SLM` and `TRIG`
are **not** the template: they sit outside `AbstractInstrument`, so `MLSLM` has
no `initialize`/`shutdown`/`gui` at all (`MethodError`, not the
"not implemented" error). **[guarantee, 0.2.7-DEV]** Its `export_state` returns cached configuration attributes only. **[limitation, 0.2.7-DEV]** `Triggerscope4` has no `export_state`; neither can sit
in an `AbstractInstrument`-typed field or rollback list, and Meadowlark never
`include`s its `interface_functions.jl` so `displayimage(::MLSLM)` resolves to
an empty-bodied `displayimage(::SLM)` (the generated API map files it under the interface fallback). Full table, the executed
`Shutter` scaffold with its Sim implementation, and the rules for writing each
stub's docstring (signature and units, return, state update, failure behavior,
completion, required versus optional) are in `references/interface-scaffold.md`.

**[policy]** the simulated implementation is mandatory and ships with the
interface: the stubs all throw (write them so), so nothing exercises the contract without it;
upstream's contract test iterates the interface's non-abstract leaves (from 0.2.5
`device_types` walks through abstract intermediates such as `DiodeLaser`;
**[limitation, 0.2.7-DEV]** a plain `subtypes(iface)` is one level deep and misses them); downstream tests put it in the
interface-typed field; a shared panel is developed against it. Make it honest
about what it does not model. **[limitation, 0.2.7-DEV]** upstream CLAUDE.md calls interface
GUIs optional while `test/contract.jl` requires every non-exempt device to
dispatch `gui` somewhere other than the `AbstractInstrument` stub; decide for
your interface and write it down.

## 5. Registration and exports (upstream)

**[guarantee, 0.2.7-DEV]** Both container modules are flat include lists, and the root
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
neither file walks `subtypes(AbstractInstrument)` [guarantee, 0.2.7-DEV]**, checked in
both files:

```julia
# test/contract.jl, "Interface Contract" testset          # src/skills.jl, API-map generator (~line 272)
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
`AbstractInstrument` stub), plus a "LightSource contract" testset: every light
has `light_on`/`light_off` on its own type and **no** 2-arg `light_on` (the
`@test_broken` of v0.2.x is gone with the stub); a `DiodeLaser` must have a
non-empty `supported_modes`, per mode a `regulation_mode` of that mode, the
mode-specific setter on the instantiation and not the other one, `setlevel!` and
`setpower` landing on the `DiodeLaser` method, and `measured_current`,
`measured_photocurrent`, `loop_status` on its own type; any other light must have
its own `setpower`. Item 4 is **not** run per subtype: the only stub-throws
checks are a handful of assertions on three test fixture types (`_ContractDummyStage`,
`_ContractDummyInstrument`, `_ContractDummyModulator`), so write your own
`@test_throws` for the operations you leave unimplemented. Items 5 and 6 are
never automatic anywhere (full testset in `references/driver-scaffold.md`, 23
assertions, executed):

1. exact signatures: `which(f, Tuple{T,...}).sig.parameters[2] === T` for the
   lifecycle and every required operation;
2. shared-function identity: every generic your module defines
   `=== getfield(MicroscopeControl, g)`;
3. inherited `gui` lands on the interface panel, not the `AbstractInstrument` stub;
4. unsupported operations fail loudly (`@test_throws ErrorException`);
5. lifecycle and behavior through a fake transport (pure constructor, opens on
   `initialize`, closed link is an error, failed open leaves nothing to clean);
6. `export_state` serializes: write it with `save_attributes_and_data` and read
   the attributes back.

A light with a `modulator` field also runs `modulation_violations` on its fake (see "A light that takes a modulator"
above): **[guarantee, 0.2.7-DEV]** it is the only check of the five-part modulator convention, and `test/contract.jl` checks the
field (`Nothing` in its type, keyword default `nothing`) on `TCubeLaser`, `SimDiodeLaser` and `SimLight` only.

| Simulation or fake transport establishes | Only hardware acceptance establishes |
|---|---|
| dispatch reaches your methods; no shadow bindings | the SDK does what the command says |
| lifecycle ordering and cleanup logic | timing, settling, buffer sizes, timeouts |
| range checks and error paths you coded | vendor error codes you have not seen |
| the export tree serializes | units and sign conventions on the real axis |
| GUI field compatibility (`hasfield`, or open the panel under `xvfb-run -a`) | that the panel's actions do the right physical thing |

**[policy]** record hardware acceptance (device, firmware, pinned tag or commit, what was
checked) in the instrument repo; upstream's CLAUDE.md says it is not tracked in MC.

## 7. Workflow

1. **Prototype downstream** as a module in your repo; type the system's field
   by the interface so the Sim device and yours are interchangeable in tests
   (`mc-testing`).
2. **Decide the destination** with the boundary test in `mc-system-design`: if
   it would make sense on another microscope, contribute it.
3. **Contribute from a source checkout**, never by editing the depot copy:
   `Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")`
   (or `path=` on a clone), a branch, the three-dot imports, registration
   (section 5, both tuples for an interface), a behavioral testset, full suite
   under `xvfb-run -a`.
4. **Docs**: docstrings on the type and every method (the stubs' docstrings are
   the template), a CHANGELOG entry under `[Unreleased]`, and a hardware
   verification line.
5. **Version** (traced from upstream CLAUDE.md and lab decision 0033): before 1.0, in `0.Y.Z` raising
   `Z` is any non-breaking change, new features included, and raising `Y` is an interface break (a signature, an export
   or what a call returns or throws changing for working code). `main` carries `X.Y.Z-DEV`; a pull request leaves it
   alone unless it breaks an interface, and a release is a separate pull request that drops `-DEV`. A new driver or a new
   interface adds names and is not a break by itself. Pin a tag, or the `main` commit the instrument
   was tested against when the installed skills say `-DEV` (`mc-system-design`, "Before anything"); never the
   branch itself.
6. **Refresh the installed skills** after moving the pin: `install_skills()`
   again regenerates `mc-api-map`'s `references/api-map.md`, the only place your
   new type's method list appears automatically.
