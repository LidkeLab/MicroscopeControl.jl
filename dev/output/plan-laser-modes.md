# Constant-current and constant-power laser diodes in MicroscopeControl.jl

Design plan, **revision 3**. Repo: `/home/kalidke/julia_shared_dev/LidkeLab/microscopes/MicroscopeControl.jl`,
branch `fix/tcube-laser` (v0.2.3, in review). Nothing in the repo's source was modified to
write this.

- Revision 2 folded in six consumer requirements from the 642 nm rig; §14 maps each.
- Revision 3 applies "as simple as possible, but no simpler". Eight elements were cut or
  deferred; §15 lists each with the **trigger that brings it back**, because a deferral
  without a trigger is just a gap. Two things were explicitly protected from the cut: the
  naming honesty (§6) and the closed-loop safety preconditions (§8.3).

Every architectural statement is labelled **[guarantee]** (true of the code today),
**[limitation]** (true and bad) or **[policy]** (what this plan chooses). Where the reasoning
comes from physics or from the relayed vendor documentation rather than from this source
tree, it says so.

---

## 0. Premise check

Every fact in the brief is confirmed in the tree except one, which changes what the work
costs.

- `LightSourceProperties` is `power_unit, power, is_on, min_power, max_power`
  (`src/hardware_interfaces/lightsource_interface/interface_types.jl:19-25`), shared by all
  five light types. **[guarantee]**
- `CrystaLaser`, `VortranLaser`, `DaqTrLight` only ever write AO/DO channels; there is no
  read path of any kind (`crysta_laser_561/interface_methods.jl:18-33` and the two
  siblings). **[guarantee]**
- `TCubeLaser` at v0.2.3 carries `drive_current` and a deprecated `power` documented as an
  uncalibrated guess (`tcube_laser/types.jl:34-41,54-62`). **[guarantee]**
- `setpower(::TCubeLaser, ::Float64)` takes **milliamps** while `properties.power_unit` says
  `"mW"` (`tcube_laser/interface_methods.jl:276-325`). **[limitation]**
- All closed-loop bindings already exist with correct arity: `LD_SetClosedLoopMode`,
  `LD_SetOpenLoopMode`, `LD_GetPhotoCurrentReading`, `LD_Get/SetWACalibFactor`,
  `LD_Get/SetMaxCurrentDigPot`, `LD_EnableMaxCurrentAdjust`, `LD_GetStatusBits`,
  `LD_GetLaserDiodeCurrentReading`, `LD_Start/StopPolling`
  (`tcube_laser/functions_Tlaser.jl:121-275`). **No new `ccall` work is required**, only one
  return-type fix (§12). **[guarantee]**
- `initialize(::TCubeLaser)` calls `LD_SetOpenLoopMode` unconditionally
  (`tcube_laser/interface_methods.jl:230`). That single line is the anchor point for mode
  selection. **[guarantee]**
- `TCubeLaser` ships no `gui.jl`; it imports the shared panel
  (`tcube_laser/TCubeLaserControl.jl:19`). **[guarantee]** — this is §1.

**Correction to the brief's fact 10.** Fact 10 describes the cost of defining a *new
interface*: hand-registration in the literal `interfaces` tuple in both `test/contract.jl:101`
and `src/skills.jl:251`, plus a mandatory `gui.jl`. **None of that applies here.** This design
extends the existing `LightSource` interface from inside `LightSourceInterface`; neither
`interfaces` tuple is edited, and `gui(::LightSource)` already satisfies `has_working_gui` for
every light. What does apply is one line: the new generics must be appended to the `generics`
tuple at `test/contract.jl:132-134`, or a driver can shadow them invisibly.

There is a different and more dangerous registration hazard that the brief could not have
anticipated, created by the hierarchy this plan introduces. It is §2.3, and it must land in
the same commit as the hierarchy.

---

## 1. Release-gating question: the shared panel on the two rigs

First because it is the only time-sensitive item; everything after it is design.

### 1.1 What the code does

`TCubeLaser` has no panel of its own, so `gui(laser)` resolves to the shared
`gui(::LightSource)` at `lightsource_interface/gui.jl:9`:

```julia
slider = Slider(control_fig[1,1], ...,
    range = light.properties.min_power:0.1:light.properties.max_power,
    startvalue = light.properties.power, ...)

on(slider.value) do x
    textbox.displayed_string = string(x)   # display updated FIRST
    setpower(light, x)                     # ... then the hardware command
end
```

With the constructor's default `properties` — `LightSourceProperties("mW", 0.0, false, 0.0,
100.0)` (`tcube_laser/types.jl:120`) — that is **a 0-to-100 slider labelled in "mW" that
commands milliamps**. **[limitation]**

### 1.2 What a user sees today, per rig

**642 nm (ceiling 160 mA, controller 160.9).** Every slider position 0..100 passes
`check_current`, so nothing throws. The user drags to "50" on a panel whose unit field says
`mW` and the diode receives **50 mA**; the console prints `Laser current set to 50.0 mA`,
the only place the truth appears. The rig's operating band is 60–132 mA, so the top 60 mA is
**unreachable from the panel**, and the bottom of the slider sits below the diode's ~65 mA
threshold, so roughly the first two thirds of the travel is dark.

**405 nm (caller ceiling 32.25 mA, controller reports 64.39).** Slider positions up to 32.2
work. From 32.3 upward `check_current` throws `ArgumentError` — **inside the Makie observable
callback**, and *after* `displayed_string` has already been set. During a drag from 0 to 40
the early updates succeed and every later one throws, so the panel comes to rest showing
**40** while the diode holds **32.2**. `drive_current` correctly records 32.2: the panel is
the only component lying. **[limitation]**

### 1.3 Did v0.2.3 cause this?

Partly, and the distinction decides the ruling. Before v0.2.3, `setpower` logged `@error` and
continued (`interface_methods.jl:180-192`); a 40 on the 405 rig's slider **actually commanded
40 mA, 24% above the rig's declared ceiling**. v0.2.3 converted that silent overdrive into a
refusal. So hardware safety strictly improved and user feedback strictly worsened. The mW/mA
substitution is older than v0.2.3 and untouched by it.

**Unverified:** what GLMakie does with an exception thrown from an `on(::Observable)`
listener. It is raised on the task processing window events, so outcomes range from a stack
trace on stderr a user never sees to the event task dying and the panel going unresponsive. I
did not run it. `test/gui.jl` already drives panels under `xvfb-run` with a `RecordingLight`
fixture, so a fixture whose `setpower` throws would settle it in about twenty lines — worth
writing whatever is decided below, because it pins the answer for every future panel.

### 1.4 Ruling

**Ship v0.2.3. Do not reopen it for this.**

1. The dimension that can damage a diode improved. Holding the release restores a state in
   which the 405 rig's panel can command 24% over its ceiling.
2. The correct fix is the mode-dispatched panel of §5, where the slider is built over the
   bounds the device accepts and labelled in the unit it takes. Any interim fix is thrown
   away.
3. `gui(::LightSource)` is shared by every light in the package. Editing it inside an already
   reviewed PR imports risk into five drivers to fix something with a zero-risk mitigation
   outside the PR.

**The mitigation, available today, with no upstream change.** The panel's range, unit and
start value all come from `properties`, and the constructor already accepts a custom
`properties` — the pattern is exercised at `test/runtests.jl:172`. Each rig fixes its own
panel in its own constructor call:

```julia
# 405 nm rig, in the rig repo. No MicroscopeControl change.
TCubeLaser("SN405";
    max_current = 32.25,
    properties  = LightSourceProperties("mA", 0.0, false, 0.0, 32.25))

# 642 nm rig. Raising the floor as well as fixing the unit previews §10.2.
TCubeLaser("SN642";
    min_current = 70.0, max_current = 160.0,
    properties  = LightSourceProperties("mA", 70.0, false, 70.0, 160.0))
```

**[policy]** put that in the v0.2.3 release note as the required rig-side action: the panel's
unit and range are rig configuration until 0.3.0 makes them the driver's business.

Two residual defects in that panel, both scheduled for 0.3.0 with the rewrite: the display is
updated **before** the command (swapping the two lines makes the readout stop lying on a
refusal, and is the only edit I would accept into v0.2.3 if the maintainer wants belt and
braces — I am not recommending it); and a textbox entry issues **two** commands, because
`set_close_to!` retriggers the slider's own handler (`gui.jl:26-30`).

---

## 2. Question A — two types, a trait, a parametric type, or a mode field

### 2.1 What the mode types are types *of*

Power is not a *mode*. It is the **quantity the regulation loop closes on**:

| What the loop holds constant | Who holds it | Name |
|---|---|---|
| diode drive current | TLD001 open loop | `ConstantCurrent` |
| monitor **photocurrent** | TLD001 closed loop, photodiode feedback | `ConstantPhotocurrent` |

A light that is merely *modulated* by an analogue voltage — `CrystaLaser`, `VortranLaser`,
`DaqTrLight` — is not on that table. It has no controller, no loop and nothing to read, and
it should not be dragged through a mode taxonomy in order to answer "none". So the split is
not three-way across all lights; it is two-way in the type hierarchy, with the modes living
strictly on the laser-diode side:

```julia
abstract type LightSource <: AbstractInstrument end          # unchanged

"""
    DiodeLaser <: LightSource

A laser diode driven by a controller that REGULATES something: drive current, or monitor
photocurrent under photodiode feedback. Every `DiodeLaser` declares which, as a type
parameter fixed at construction.

A light that is only modulated by an analogue voltage (`CrystaLaser`, `VortranLaser`,
`DaqTrLight`) is NOT a `DiodeLaser`. It has no controller, no loop and no readback, and none
of the generics below are defined for it.
"""
abstract type DiodeLaser <: LightSource end
```

**[policy]** `CrystaLaser`, `VortranLaser`, `DaqTrLight` and `SimLight` are not edited by this
plan. Not one line, not one field.

### 2.2 The mode types and traits

Two leaf types, directly under one abstract type. No intermediate `CurrentRegulated` /
`PowerRegulated` layer: an abstract type with exactly one leaf under it is a category with
one member, which the leaf name already serves (§15, deferral 1).

```julia
abstract type RegulationMode end

"""The loop holds the diode DRIVE CURRENT constant. Optical power follows diode efficiency,
which drifts with temperature and age."""
struct ConstantCurrent <: RegulationMode end

"""The loop holds the MONITOR PHOTOCURRENT constant. Optical power follows photodiode
responsivity, which is temperature dependent: without a TEC-stabilised mount the delivered
power drifts against a still setpoint. See [`PhotodiodeLoop`](@ref)."""
struct ConstantPhotocurrent <: RegulationMode end
```

Two traits in `interface_functions.jl`:

```julia
"""Concrete modes this device may be constructed in. The contract test expands a parametric
device into its instantiations through this -- a type parameter cannot be enumerated any
other way -- and the inner constructor rejects a mode absent from it."""
supported_modes(::Type{<:DiodeLaser}) = ()

regulation_mode(light::DiodeLaser) = regulation_mode(typeof(light))
```

`regulation_mode` has **no** `LightSource` fallback: there is no honest default for a light
with no loop, and "is this a regulated diode" is answered by `isa DiodeLaser`. A caller
asking "do I command power here" writes `regulation_mode(l) isa ConstantPhotocurrent` today.

There is no `has_readback` trait. The requested-vs-measured rule asks for one so a caller can
tell without calling; here the **abstract type already says it** — a `DiodeLaser` has a
controller that reads back, and nothing else in this interface does. A trait restating the
type system is a second source of truth that can disagree with it (§15, deferral 2).

### 2.3 Why parametric, and the gate hazard it creates

**Ruling: a type parameter on the driver.** The maintainer's instinct — two types, dispatching
for GUI creation — is right; the literal form (two unrelated concrete driver structs) is not,
because it duplicates fourteen fields and ~500 lines of `interface_methods.jl` for a
difference of two fields and three methods. A parametric type *yields* two concrete types from
one definition, and because the mode is a type parameter it is immutable per instance, which
is the earlier ruling that the unit of the setter must be checkable. A `mode::Symbol` field
gives neither dispatch nor immutability; a wrapper type would have to forward every field the
shared panels read by name.

The memory file notes that closed loop makes `has_readback` **per-instance** rather than
per-type. The parametric design removes that problem at the root: the mode is in the type, and
the power-mode type cannot be constructed without the photodiode calibration (§4, §8.2).

**Verified mechanics.** I ran these; they decide how methods must be written.

- `has_specific_method` (`test/contract.jl:36-42`) does
  `which(f, sig).sig.parameters[2] === T`. A **`where`-method** —
  `setcurrent!(l::TCubeLaser{M}, x::Float64) where M` — has a `UnionAll` signature, and
  `.parameters` on a `UnionAll` **throws `FieldError`**. The gate would *error*, not fail.
- A method against the **bare UnionAll** — `setcurrent!(l::TCubeLaser, x::Float64)` — has a
  `DataType` signature whose `parameters[2] === TCubeLaser`, so the gate passes untouched.
- A **concrete-parameter** method — `setoutputpower!(l::TCubeLaser{ConstantPhotocurrent}, x)`
  — also has a `DataType` signature and passes for that instantiation.
- `l isa TCubeLaser` stays true; a downstream field typed `::TCubeLaser` still accepts the
  value (the field becomes abstract, hence type-unstable — a performance note, not a break);
  `nameof` on the UnionAll still gives `:TCubeLaser`, so every exclusion set keeps working.

**[policy], binding on the implementer:** mode-shared methods (`light_on`, `light_off`,
`shutdown`, `export_state`, the shared part of `initialize`) are written against the bare
`TCubeLaser`; mode-specific methods against the concrete instantiation. **Never a `where M`
method on a generic the contract test checks.** Harden the gate in the same PR:

```julia
p = m.sig isa UnionAll ? Base.unwrap_unionall(m.sig).parameters[2] : m.sig.parameters[2]
return p === T
```

Do not assert `regulation_mode` with `has_specific_method` for the same reason; assert its
value.

**The severe hazard: `subtypes` is one level deep.** Both contract loops call `subtypes(iface)`
(`test/contract.jl:105`, `:210`) and so does the API-map generator (`src/skills.jl:253`). I ran
it against the new hierarchy:

```
subtypes(LightSource) = [CrystaLaser, DiodeLaser, SimLight]     # TCubeLaser is GONE
```

The moment `TCubeLaser` moves under `DiodeLaser`, **it silently stops being tested** — every
`setpower`/`light_on`/`gui`/`export_state` assertion on the package's most consequential
driver evaporates, and the abstract `DiodeLaser` is tested in its place as though it were a
device. Nothing fails; coverage just disappears. **This is not an extra: it is the price of the
hierarchy, and it lands in the same commit.**

```julia
# Devices are the non-abstract leaves. `subtypes` is one level deep, so an abstract
# intermediate (DiodeLaser) hides every driver beneath it from this gate.
function device_types(T)
    out = Any[]
    for S in subtypes(T)
        isabstracttype(S) ? append!(out, device_types(S)) : push!(out, S)
    end
    return out
end
```

Verified: `device_types(LightSource)` returns the leaves including the parametric `TCubeLaser`
(`isabstracttype` correctly returns `false` for the UnionAll — `isconcretetype` would have
dropped it), and `gui` resolves to `DiodeLaser` for the lasers and `LightSource` for the rest,
both passing `has_working_gui`. Add a regression assertion that
`:TCubeLaser in nameof.(device_types(MC.LightSource))`, so the next abstract intermediate
cannot repeat this quietly.

---

## 3. Question B — what replaces `setpower`

**[limitation]** Today `setpower` means milliamps on `TCubeLaser`, volts on the three
DAQ-modulated lights, and a unitless number on `SimLight`. One name, three units, and no way
for a caller to tell which it holds.

**Ruling: two unit-true setters naming their reference plane, one unit-free setter, and three
readbacks. `setpower` is not defined for `TCubeLaser` at all after the change.**

```julia
"""    setcurrent!(laser::DiodeLaser, current_mA::Float64)

Command the diode DRIVE CURRENT, in mA. Defined only for `ConstantCurrent` lasers: where a
loop owns the current, this generic must not exist, and the inherited stub throws."""
function setcurrent!(laser::DiodeLaser, current_mA::Float64)
    error("setcurrent! not implemented for $(typeof(laser))")
end

"""    setoutputpower!(laser::DiodeLaser, power_mW::Float64)

Command the optical power **at the laser output**, in mW -- the plane a power meter sees at
the head, which is where the `wa_calibration` of [`PhotodiodeLoop`](@ref) is measured.

This is NOT power at the sample. Everything between the head and the sample -- splitters,
attenuators, fibres, objectives -- belongs to the system that owns those parts, and this
driver holds no field describing any of it (§4).

Defined only for `ConstantPhotocurrent` lasers, where the number is the driver's own
arithmetic over the photodiode calibration: a command, not a measurement."""
function setoutputpower!(laser::DiodeLaser, power_mW::Float64)
    error("setoutputpower! not implemented for $(typeof(laser))")
end
```

plus `setlevel!` (§10) and exactly three readbacks:

```julia
measured_current(laser::DiodeLaser)          # mA, diode drive current, from the controller
measured_photocurrent(laser::DiodeLaser)     # A, the regulated quantity in photocurrent mode
indicated_output_power(laser::DiodeLaser)    # mW at the head: photocurrent x calibration
loop_status(laser::DiodeLaser)               # one consistent snapshot; see below
```

`loop_status` returns a NamedTuple: the **raw status word**, the decoded flags (`output_enabled`,
`interlock`, `key`, `saturated` 0x400, `tia_over` 0x2000, `tia_under` 0x4000, `open_circuit`
0x800), both readings, and `below_threshold` (§7). It replaces a separate `status_word` getter:
the 642 rig logs photocurrent, diode current and the raw word together at 1–10 Hz, and three
separate getters give three separately-timed reads where one call gives a consistent set. It
is also the only place the bit constants are decoded, so the panel lamps, the runtime fault
check and the rig's logger share one definition.

`indicated_output_power` earns its place as the inverse of `setoutputpower!`'s conversion:
letting the rig recompute `photocurrent x wa_calibration` downstream is the duplicated-scaling
mistake this driver already refuses elsewhere (`setpoint_current`'s docstring, "one definition,
used by every place in this driver that turns a raw controller word into mA").

There is no `measured_output_power` stub (§15, deferral 3).

Naming convention, stated once: setters run the words together (`setcurrent!`,
`setoutputpower!`), matching `setexposuretime!`/`setdrivevoltage`; accessors use underscores
(`measured_current`, `indicated_output_power`), matching `max_setcurrent`/`get_state`. Both
already exist in this package and the setter/accessor line is where they divide.

**Ruling on the `@test_broken` 2-arg `light_on`** (`test/contract.jl:220`): do not resurrect
it. `light_on(light, ipower)` has no definable unit — the exact ambiguity being removed. The
stub's arity drops to `light_on(light)`, the `@test_broken` goes with it, and "on at a power"
becomes two checkable verbs. **[policy]**

---

## 4. Question C — the field set

**Ruling: do not touch `LightSourceProperties`.** It is shared by every light; a
`threshold_current` there would be a permanent `NaN` on three DAQ-modulated lamps and on every
future LED. **[policy]**

**Ruling: the driver holds no field describing anything downstream of the laser head.** No
transmission, no split ratio, no attenuator reference, ever. A `setoutputpower!` that quietly
applied a path transmission would produce a number that is neither what the meter reads at the
head nor what the sample receives, and no field could tell a reader which. The 642's PBS split
into TIRF and SLM arms — ~300:1 extinction on the spot arm, unknown on the TIRF arm — is
exactly the kind of fact that must live where the arms are known. **[policy]**

Three of the five numbers the maintainer asked for already exist:

| Wanted | Where it already is | Change |
|---|---|---|
| min/max current | `TCubeLaser.min_current`/`.max_current`, mA | none in the struct; `min_current` gains a second stated role as the bottom of the `setlevel!` scale (§10.2) |
| min/max power | `LightSourceProperties.min_power`/`.max_power` | **[policy]** for a `ConstantPhotocurrent` laser these become the *enforced* bounds of `setoutputpower!` and the endpoints of `setlevel!`, in mW at the laser output. For every other light they stay nominal display bounds |
| threshold current | nowhere | new field, §7 |

Two new fields on `TCubeLaser`, appended at the **end**. The struct already documents that
convention and carries an old-arity inner constructor that defaults trailing fields
(`types.jl:64-66,95-102`), so this is the migration path the type was built for:

```julia
mutable struct TCubeLaser{M<:RegulationMode} <: DiodeLaser
    # ... the fourteen v0.2.3 fields, unchanged and in their existing order ...
    threshold_current::Float64          # mA; rig-declared, bench-measured. NaN = unknown.
    pd::Union{Nothing,PhotodiodeLoop}   # non-nothing IFF M === ConstantPhotocurrent.
end
```

`pd` is one nullable field rather than six, and that is the point: the invariant *"these six
numbers exist exactly when the loop is closed on a photodiode"* is a single check in the inner
constructor. Six independently nullable fields make a half-configured loop representable, and
the shared power panel would have to read six names instead of one. **[policy]** it stays a
struct, in the **interface** rather than the driver, so a second photodiode-monitored laser
reuses both it and the panel:

```julia
"""
    PhotodiodeLoop

State of a monitor-photodiode regulation loop. Present only on a `ConstantPhotocurrent` laser.

The loop regulates PHOTOCURRENT. `wa_calibration` converts photocurrent into a power NUMBER at
the LASER OUTPUT -- the plane where it was measured with a power meter -- and it does not make
the loop hold optical power anywhere. Without a TEC-stabilised mount the photodiode's
responsivity drifts with temperature, so delivered power drifts while photocurrent is held
steady. That is why `tec_stabilised` has no default and may be `missing`.
"""
mutable struct PhotodiodeLoop
    wa_calibration::Float64             # W/A at the LASER OUTPUT. Rig-measured with a meter
                                        # at the head. Conversion and display only.
    tia_range::Float64                  # A, full scale. The rig's STATEMENT of the rear-panel
                                        # DIP switch; `initialize` throws if the status bits
                                        # disagree. Required keyword, no default.
    tec_stabilised::Union{Bool,Missing}  # rig fact. Required keyword; `missing` is legitimate
                                        # and is the only honest answer before the probe runs.
    max_current_clamp::Float64          # mA. Programmed, then READ BACK from LD_GetMaxCurrentDigPot.
    output_power_requested::Float64     # mW at the head, requested. NaN before the first command.
    photocurrent_requested::Float64     # A. The DECODED setpoint the loop was actually given.
end
```

Six fields, each naming an invariant:

| Field | Unit | Written by | Kind |
|---|---|---|---|
| `min_current`, `max_current` | mA | rig, at construction; never overwritten | rig constant; `min_current` is also the `setlevel!` floor |
| `controller_max_current` | mA | `initialize`, from `LD_GetLaserDiodeMaxCurrentLimit` | device readback |
| `max_setcurrent`, `max_setpoint` | mA, code | rig / protocol constant | protocol constant |
| `threshold_current` | mA | rig, at construction | measured diode property, *declared* |
| `drive_current` | mA | **`setcurrent!` only** | requested. Stays `NaN` for the life of a `ConstantPhotocurrent` laser: the loop owns current there, and a requested value would be a fiction |
| `properties.min_power`, `.max_power` | mW at head | rig, at construction | rig constant; enforced bound and `setlevel!` endpoints in power mode |
| `pd.wa_calibration` | W/A at head | rig, at construction | calibration |
| `pd.tia_range` | A | rig, at construction; **verified** against the bits by `initialize` | rig statement of a physical switch |
| `pd.tec_stabilised` | - | rig, required keyword | rig fact, possibly `missing` |
| `pd.max_current_clamp` | mA | `initialize`: written, then read back | requested *and* verified |
| `pd.output_power_requested` | mW | `setoutputpower!`, after the transport returns | requested |
| `pd.photocurrent_requested` | A | `setoutputpower!`, after the transport returns | requested, **and exact** |

Two rows deserve a sentence each.

**The TIA range is one field, not two.** The rig states it; `initialize` reads bits
0x10/0x20/0x40/0x80 and throws if they disagree. After a successful `initialize` a separate
"as read" value would be equal to the stated one by construction, so storing both stores the
same number twice. A DIP switch moved between sessions shows up as a refusal to initialize,
which is the behaviour that matters.

**`photocurrent_requested` is the field v0.2.3 does not have.** Its docstring says plainly of
`drive_current`: *"nothing here reports the commanded code... There is no field here that
reports what actually went to the wire."* In power mode we can close that gap for free, because
the setpoint encoding rounds down: this field holds the **decoded** setpoint, which is not
derivable from `output_power_requested`. It is the honest answer to "what is the loop actually
holding".

**`export_state`** stays pure field reads — no transport call, so its cost and failure modes do
not change — and emits every number above: `regulation_mode` (the leaf type name as a `String`),
`setpoint_unit` (`"mA"` or `"mW"`, the unambiguous replacement for the lying `power_unit`),
`power_reference` (`"laser output"`), `threshold_current_mA`, `min_current_mA`, `max_current_mA`,
`min_output_power_mW`, `max_output_power_mW`, `wa_calibration_W_per_A`, `tia_range_A`,
`tec_stabilised` (`"true"`/`"false"`/`"unknown"` — `missing` is not an HDF5-safe value and
`mc-extend`'s export rules require the conversion), `max_current_clamp_mA`,
`output_power_requested_mW`, `photocurrent_requested_A`.

It emits **no measured state at all**, and that is deliberate: `export_state` is a snapshot of
what was commanded, and evidence that the loop was holding it comes from `loop_status`, which
the rig already logs at 1–10 Hz with its own timestamps. Caching a stale status word in the
device so a pure-field-read snapshot could look like a measurement is the sort of half-truth
this package has been removing (§15, deferral 4).

---

## 5. Question D — the GUI

Dispatch on the hierarchy first, the mode second. The DAQ-modulated lights keep today's method
object and today's behaviour:

```julia
gui(light::LightSource) = legacy_panel(light)                 # today's gui.jl body, unmoved
gui(laser::DiodeLaser)  = _panel(regulation_mode(laser), laser)
_panel(::ConstantPhotocurrent, laser) = power_panel(laser)
_panel(::ConstantCurrent,      laser) = current_panel(laser)
```

`has_working_gui` passes for every device: dispatch lands on `LightSource` or `DiodeLaser`,
neither of which is the `AbstractInstrument` stub (verified per leaf). `test/gui.jl`'s
`RecordingLight` is a bare `LightSource`, gets `legacy_panel`, and its zero-commands assertion
passes unedited.

**`current_panel`** — slider in **mA** over `min_current .. effective_max_current(laser)`,
calling `setcurrent!`. This is where §1's bug dies: correct unit, correct range, nothing to
throw. A static marker at `threshold_current` when known, a read-only row for
`measured_current`, and status lamps from `loop_status`, refreshed only by an explicit Read
button or a poll toggle that defaults to off.

**`power_panel`** — slider in **mW at the laser output** over
`properties.min_power .. max_power`, calling `setoutputpower!`, axis labelled `output power
(mW)` and never `power`. Plus the three things a current panel cannot show and a power-mode
user must see:

1. `measured_photocurrent` in µA with its TIA range and the over/under flags — those two bits
   invalidate the loop;
2. `measured_current` — **the diagnostic**: a drive current climbing at a fixed setpoint is a
   blocked photodiode or an ageing diode;
3. the `saturated` lamp (0x400), which in power mode means *the loop is at the clamp and the
   power is not being held*.

and a static basis label built from fields, e.g.
`output power: photodiode x 224.2 W/A, TIA 1 mA, TEC: unknown`.

**Both panels: the bottom of the slider is not "off".** With a rig floor at or above threshold
(§10.2) the lowest slider position still emits. The off control is the toggle, the minimum is
labelled with its value and unit, and neither panel shows a zero it cannot command. **[policy]**

**Extending the v0.2.3 no-commands-on-open rule:** opening a panel must issue neither a command
**nor a repeating read**. A single read to populate the readout is permitted; a poll timer is
not, until the user arms it. The `SimDiodeLaser` command log (§9) makes both halves assertable.
Both panels also fix the display-before-command ordering and the double-command textbox handler
of §1.4.

---

## 6. Question E — stopping "constant power" from reading as a guarantee

Photodiode feedback is the *normal* path for this lab's diode lasers — the 642 nm diode was
bought for it. That makes this requirement more important, not less. Four structural
mechanisms, no docstring relied upon. **None of them was touched by revision 3's simplification.**

1. **The name of the mode.** The type a TLD001 can be constructed with is
   `ConstantPhotocurrent`. `ConstantPower` does not exist as a name anywhere in the package.
   Anyone who dispatches on it, prints it, or reads the HDF5 attribute sees what is regulated.
   Free.
2. **The name of the quantity.** Every power number in the API says **where** (`output`) and
   **how well known** (`indicated`): `setoutputpower!`, `indicated_output_power`,
   `output_power_requested`, `power_reference = "laser output"`. There is exactly one power
   getter and its name says it is a conversion.
3. **The forced declaration.** `tec_stabilised` is a **required keyword with no default**,
   typed `Union{Bool,Missing}`. The rig cannot obtain a power-mode laser without answering, and
   `missing` is legitimate — the only honest answer before the probe runs. It reaches
   `export_state` as `"unknown"` and the panel label as `TEC: unknown`.
4. **The absent field.** The driver holds nothing describing the optical path downstream of the
   head (§4), so no code path exists by which an output power could be mistaken for a sample
   power. The name says the plane; the absence of any transmission field means the driver could
   not convert to another plane even if someone wanted it to.

**This section does not depend on anything currently unknown.** Audited against the three open
questions:

| Open question | Effect on §6 |
|---|---|
| Is the 642 TEC-stabilised? | None. Mechanism 3 records `missing` and says `unknown`. Nothing branches on the value |
| Is its photodiode wired? | None. `wa_calibration` cannot be produced unless the photodiode works, so an unprobed rig cannot reach power mode by accident |
| What problem must constant power solve? | None. Both modes are implemented and `mode = ConstantCurrent()` is a one-line opt-out (§8.2) |

The physics behind the constraint, stated once: closed loop removes drift in diode efficiency
(current to light) and leaves drift in photodiode responsivity (light to photocurrent). It is
very likely better than open-loop current control and it is **not** the guarantee the words
"constant power" imply.

---

## 7. Question F — threshold current

It is a **measured property of the diode**, obtained on a bench from a drive-current versus
optical-power sweep. The controller cannot report it and MC never measures it. **[policy]** the
rig declares it; MC stores it, reports it, and says where it came from.

- **Stored** in `TCubeLaser.threshold_current`, mA, `NaN` when unknown. The 642's is ~65 mA.
- **Used by exactly three things.** The current panel's marker; the **loop-alive check** in
  `loop_status` — if a non-zero power has been commanded and `measured_current` sits below
  `threshold_current`, the diode is not lasing and every power number is junk, which is a
  distinct fault from clamp saturation; and the rig's own choice of `min_current` (§10.2),
  which it sets *above* this value.
- **Not used as a bound by `setcurrent!`.** `check_current` enforces `min_current`, which the
  rig may set at or above threshold, but the driver never derives a bound from
  `threshold_current` itself. Below threshold is dark, not dangerous, and a low-power diode
  with no declared threshold must not inherit a floor from a reporting field. **[policy]**
- **If unset (`NaN`):** the marker is omitted and the loop-alive check is **skipped and
  reported**, not skipped silently — `loop_status` returns `below_threshold = missing`, never
  `false`. A skipped check must not read as a passed one.

---

## 8. Question G — migration and sequencing

### 8.1 One release, not two

The queued removals, the vocabulary, and both mode implementations land together as **0.3.0**.
The repo's versioning policy already makes any new export a minor bump and `properties.power`'s
removal is earmarked for 0.3.0; the two rigs pin exact tags and absorb breaking releases
deliberately, so one migration costs them less than two; and with power mode as the default a
release whose default construction is unimplemented is not a shippable intermediate.

**v0.2.3 is untouched.** It is in review; nothing below edits a line it changes except by
addition after it merges.

1. `DiodeLaser` + `device_types` in `test/contract.jl` and `src/skills.jl` + the regression
   assertion. **First, alone, and confirm the gate still names `TCubeLaser`** — the only step
   that can lose coverage silently (§2.3).
2. `TCubeLaser` becomes `TCubeLaser{M}` under `DiodeLaser`; mode types, the two traits,
   `PhotodiodeLoop`, the stubs; `generics` tuple extended; `has_specific_method` hardened.
3. `setcurrent!` on `{ConstantCurrent}` — a mechanical move of today's `setpower` body plus a
   setpoint read-back verify. `measured_current` and `loop_status`, after the signedness fix
   (§12) and the polling ruling (§8.4).
4. `setlevel!` on `DiodeLaser` (§10).
5. `SimDiodeLaser{ConstantCurrent}`; `current_panel`.
6. Closed loop: the §8.3 sequence, clamp programming with read-back, `setoutputpower!`,
   `indicated_output_power`, `measured_photocurrent`.
7. `SimDiodeLaser{ConstantPhotocurrent}` with the blocked-photodiode and drift faults.
8. `power_panel`.
9. The queued removals: `properties.power`/`power_unit` on TCube, the 2-arg `export_state`,
   `is_on` -> `is_on_requested` across all five lights, the 2-arg `light_on` stub and its
   `@test_broken`.
10. Skills: `mc-extend`'s structural-contract table gains the `DiodeLaser` field requirements;
    `mc-system-design`'s decision rule gains the `LightSource`-versus-`DiodeLaser` line, its
    state table gains the mode split on `drive_current`, and its responsibility split gains the
    output-power-versus-sample-power boundary. Labels kept.

**One contingency, ruled rather than left open:** if step 6 is not bench-verified when the rest
is ready, ship 0.3.0 with `mode` as a **required keyword and no default**, and flip the default
to `ConstantPhotocurrent()` in the next tag. One line, and the only part of this release that
waits on hardware.

### 8.2 The default is power mode, and why that is safe

```julia
laser = TCubeLaser("SN642";
    mode              = ConstantPhotocurrent(),   # the default; shown for clarity
    wa_calibration    = 224.2,                    # W/A, measured at the head. See §13.
    tia_range         = 1e-3,                     # A: the rear-panel DIP switch, as set
    tec_stabilised    = missing,                  # honest until the probe runs
    threshold_current = 65.0,
    min_current       = 70.0,                     # §10.2: above threshold, not at it
    max_current       = 160.0,
    properties        = LightSourceProperties("mW", 0.0, false, 2.0, 45.0))

laser = TCubeLaser("SN405"; mode = ConstantCurrent(), max_current = 32.25)
```

`wa_calibration`, `tia_range` and `tec_stabilised` are **required keywords with no defaults**
in power mode, and `properties.min_power`/`max_power` become required too. A rig cannot reach
the default path without producing a W/A calibration measured at the head — which it can only
have if the photodiode works — without reading its own DIP switch, and without answering the
TEC question. That is §6's mechanism 3 doing double duty: it also catches "we defaulted to power
mode but this diode has no photodiode", at construction, on the bench, rather than at first
emission.

**The default flip must not silently reinterpret an existing call, so `setpower` is not defined
for `TCubeLaser` at all after the change.** No deprecated forwarder. `setpower(laser, 80.0)`
hits the interface stub and throws. That is the entire reason the flip is safe: a forwarder plus
a flipped default would turn 80 mA into 80 mW on a live rig with only a deprecation warning in
between — the precise class of failure this package has spent v0.2.1 through v0.2.3 removing.
`setpower` survives unchanged on the three DAQ-modulated lights, where it has always meant volts.

Both rigs edit two things at this tag: one construction line, and their `setpower` calls become
`setoutputpower!` (642) or `setcurrent!` (405). **Nothing they can write silently changes
meaning.** Code written against `setlevel!` needs no edit and survives a mode switch (§10.3).

### 8.3 The closed-loop entry sequence — protected from simplification

`initialize(laser::TCubeLaser{ConstantPhotocurrent})`, after the existing open:

1. Read status bits. Require key switch (0x2) **and** interlock (0x8); throw naming which is
   missing.
2. Decode the TIA range from 0x10/0x20/0x40/0x80. Exactly one bit set, or throw. **Throw if it
   disagrees with `pd.tia_range`**, naming both values and the rear-panel switch: a range moved
   between sessions is a silent factor-of-ten error in every commanded power.
3. Program the clamp — **the only real protection in power mode**, because the loop raises
   current by itself to hold the setpoint: `LD_EnableMaxCurrentAdjust(serial, true, false)`,
   `LD_SetMaxCurrentDigPot(serial, pot)`, `LD_GetMaxCurrentDigPot` **read-back**, then
   `LD_EnableMaxCurrentAdjust(serial, false, false)`. Throw unless the read-back decodes to
   `<= laser.max_current`. Record `pd.max_current_clamp` from the **read-back**, never the
   request. (On the boolean argument width, see §12.2 — the binding takes the header's 4-byte
   `BOOL`, and passing Julia `true`/`false` converts correctly.)
4. `LD_SetClosedLoopMode`, then re-read bits and require 0x4; throw otherwise.
5. `LD_SetWACalibFactor(serial, pd.wa_calibration)` then `LD_GetWACalibFactor` within `Cfloat`
   tolerance, so the front panel and MC agree on the displayed number.
6. `LD_StartPolling(serial, 50)` — §8.4.
7. **Do not** enable output. `initialize` must not emit.

Clamp arithmetic, from the relayed header (pot 20..255 = 17.3..220 mA): the step is
`202.7/235 ~ 0.863` mA, and the pot is rounded **down** so the clamp never lands above the rig's
ceiling — the same never-exceed-the-request rule `setpoint_code` already enforces. Two
consequences belong in the driver docstring: the effective clamp can sit up to 0.86 mA below
`max_current`; and **a diode whose ceiling is below 17.3 mA cannot be clamped at all**, which
must throw at construction rather than run unprotected. The 405's 32.25 mA is comfortably
programmable.

**The dead-photodiode refusal.** A blocked or dead photodiode makes the loop drive to the clamp
immediately and silently (relayed vendor fact). Three things catch it, and none was simplified
away: the clamp itself bounds the damage; `loop_status`'s `saturated` flag (0x400) names it; and
the `below_threshold` check (§7) distinguishes "at the clamp and lasing hard" from "at the clamp
and dark". **[policy]** a rig running unattended polls `loop_status` and treats sustained
`saturated` as a fault — the driver reports, the system decides.

`setoutputpower!(laser::TCubeLaser{ConstantPhotocurrent}, power_mW)`:

1. `check_power` against `properties.min_power..max_power`; throw.
2. `i_pd = power_mW/1000 / pd.wa_calibration`; `code = floor(i_pd / pd.tia_range * 32767)`,
   rounding **down**. If `code > 32767`, throw naming the rear-panel DIP switch: the request
   exceeds full-scale photocurrent for the installed range and no software setting can fix it.
3. `LD_SetLaserSetPoint`, then `LD_GetLaserSetPoint` and verify the code.
4. Record `pd.output_power_requested` and the decoded `pd.photocurrent_requested` — **after**
   the transport returned, per the requested-vs-measured rule's part B.
5. Never touch `drive_current`.

### 8.4 Readback cadence and staleness

The 642 rig logs at **1–10 Hz**, so the getters must be cheap, non-blocking and never
commanding. The Kinesis API makes that a design decision rather than a detail: `LD_GetXReading`
returns a **cached** value, refreshed either by an explicit `LD_RequestReadings` or by the
library's background polling thread. Today `initialize` issues a single `LD_RequestReadings`
(`interface_methods.jl:231`) and nothing after it, so a getter written naively would return the
same stale value forever — a **[limitation]** in waiting, latent only because nothing reads
those values today.

**Ruling:** `initialize` calls `LD_StartPolling(serialNo, 50)` and `shutdown` calls
`LD_StopPolling`. 50 ms is 20 Hz, comfortably above the declared 10 Hz, and it is a **documented
constant, not a constructor keyword**: no stated use needs another value, and the day one does is
the day it becomes a keyword. The getters are then pure cache reads — one `ccall` each, no
allocation, no round trip. **[policy]** each getter's docstring states the staleness bound: the
value is as of the last poll, at most 50 ms old.

`LD_StartPolling` returns a **success flag, not a status code**, and is typed `KBOOL_RET`
(`Bool`) for the reason in §12.2. The rule it belongs to, which holds across this whole driver:
a `Cshort` return is a status code where **0 means success**, a boolean return is a success flag
where **0 means failure**. `check_err` implements the first, so pointing it at this call would
invert the test — reading every successful start as a failure. Check the returned `Bool`
directly and throw on `false`.

---

## 9. Question H — what the Sim must simulate

`SimLight` stays exactly as it is. The new twin follows the `SimShutter` pattern, **on the same
abstract type as the hardware driver** so a system field typed `::DiodeLaser` accepts either:

```julia
mutable struct SimDiodeLaser{M<:RegulationMode} <: DiodeLaser
supported_modes(::Type{<:SimDiodeLaser}) = (ConstantCurrent, ConstantPhotocurrent)
```

It carries the same field names the panels read (`min_current`, `max_current`,
`threshold_current`, `properties`, `pd`), a command log of `(verb, value)` tuples, real `sleep`
of a declared settle time, fault flags, and it throws before `initialize` and after `shutdown`
with every `*_requested` field unchanged. Its diode model is three lines of physics and is the
entire point:

```
P_true       = efficiency * max(0.0, I - threshold)     # mW at the head
photocurrent = responsivity * P_true                    # A; responsivity drifts with `temperature`
loop         : raise I until photocurrent >= setpoint, or I reaches the clamp (latch 0x400)
```

`true_output_power(sim)` exists on the **Sim only**, is not an interface generic, and no driver
ever returns it. It is the oracle the tests assert against.

Nine headless tests, every one an assertion about this design rather than about Makie:

1. `setoutputpower!` converges; `indicated_output_power ~ requested`; `measured_current`
   settles above threshold.
2. `pd_blocked = true` -> **the loop drives straight to the clamp**, `measured_current ==
   clamp`, `loop_status().saturated` is true, `indicated_output_power ~ 0`.
3. Responsivity drift -> `indicated_output_power` stays flat while `true_output_power` moves
   15%. The driver reports the flat number and never claims otherwise; §6 executed.
4. `setcurrent!` on a `{ConstantPhotocurrent}` laser throws; `setoutputpower!` on a
   `{ConstantCurrent}` laser throws.
5. Commands before `initialize` or after `shutdown` throw, with `*_requested` unchanged.
6. `tia_over`/`tia_under` make `setoutputpower!` refuse rather than command.
7. Opening either panel issues zero commands and zero polls (empty log).
8. **`setlevel!` endpoints**: `setlevel!(sim, 0.0)` lands exactly on `min_current` (CC) or
   `min_power` (CP), `setlevel!(sim, 1.0)` on the ceiling, the midpoint is linear in the
   regulated quantity, and with `min_current` above `threshold_current`, fraction 0 emits.
9. **Mode-switch invariance**: the same `setlevel!` sequence runs unchanged against both
   instantiations — the property requirement 5's "one-line switch back" actually depends on.

---

## 10. `setlevel!`, and what the taxonomy costs a caller who does not care

### 10.1 The vocabulary, and the one-liner

Two leaf types and one abstract parent. No light outside `DiodeLaser` meets any of them.

A caller who does not care about the mode still cares about the unit, whether they know it or
not — that is not a cost this design adds, it is the cost `setpower` has been hiding. So the
design refuses to offer a mode-agnostic setter taking a bare number in an unstated unit, and
offers one taking something with no unit at all:

```julia
"""    setlevel!(light::LightSource, frac::Float64)

Set the light to `frac` of its own declared operating range, `frac` in 0..1. Unit-free BY
CONSTRUCTION: the endpoints come from the device, so no caller ever names a unit it cannot
check.

The mapping is LINEAR IN THE REGULATED QUANTITY -- drive current in `ConstantCurrent`, output
power (hence photocurrent, which is proportional to it) in `ConstantPhotocurrent`.
`frac = 0.0` is the bottom of the declared range, which is NOT off: use `light_off`."""
function setlevel!(light::LightSource, frac::Float64)
    error("setlevel! not implemented for $(typeof(light))")
end

setlevel!(l::DiodeLaser, f) = _setlevel(regulation_mode(l), l, f)
_setlevel(::ConstantPhotocurrent, l, f) =
    setoutputpower!(l, l.properties.min_power + f * (l.properties.max_power - l.properties.min_power))
_setlevel(::ConstantCurrent, l, f) =
    setcurrent!(l, l.min_current + f * (effective_max_current(l) - l.min_current))
```

**The one-liner a system author writes when they hold a laser and do not care which kind:**

```julia
setlevel!(laser, 0.4)          # 40% of whatever this device's declared range is
```

The stub is declared on `LightSource` so the throwing message names the gap precisely, but
**methods are shipped only for `DiodeLaser`** in this release. The three DAQ-modulated lights
are three more three-line methods over their own `min_voltage..max_voltage`, nobody has asked
for them, and the shared-slider payoff only arrives when the legacy panel is rewritten, which
this release does not do (§15, deferral 6).

### 10.2 The endpoints, and the floor

The endpoints are the declared per-mode range, in fields the rig sets and `export_state`
records: `[min_current, effective_max_current]` in mA for `ConstantCurrent`, and
`[properties.min_power, properties.max_power]` in mW at the head for `ConstantPhotocurrent`. In
photocurrent mode the mW-to-photocurrent conversion is itself linear, so a linear fraction of mW
is a linear fraction of the regulated photocurrent — the rig's percent finally moves linearly in
*light*, to exactly the accuracy the W/A calibration holds.

**On the floor, and the tension with v0.2.3.** `min_current` defaults to `0.0` upstream and
**that default does not change**. `types.jl:13-15` chose it deliberately: a non-zero default
would reject safe small currents on a low-power diode while protecting against nothing, since
only the ceiling protects. A floor at or above threshold is a **per-rig value the rig sets**.
The 642 sets `min_current = 70.0` against its ~65 mA threshold; the 405, whose entire operating
range is 32.25 mA, keeps 0.0. **[policy]**

Three consequences, all of which the rig should expect:

1. `min_current` is one field with one meaning — *the lowest current this rig will command* —
   serving both `check_current`'s floor and `setlevel!`'s zero. With `min_current = 70.0`,
   `setcurrent!(laser, 20.0)` **throws**. That is intended: darkness is `light_off`, not a small
   current. No second field separates the two roles, because they are the same invariant.
2. **Set the floor a little above threshold, not at it.** At exactly the threshold the diode is
   at the knee of its curve and emits almost nothing, so `frac = 0.0` would still be dark —
   the outcome the requirement is trying to avoid. The floor should be the lowest *usable*
   output. This is physics, not a source-tree claim, and the margin is a bench measurement.
3. **The analogous floor in power mode is `properties.min_power`**, in mW at the head, and it
   carries a hazard the current floor does not: a `min_power` below the power the diode emits at
   threshold asks the loop for a photocurrent the diode cannot produce, so the loop raises
   current to the clamp and saturates — the same signature as a blocked photodiode. The driver
   cannot check this at construction, because it does not know the optical power at threshold
   and will not be given a field to hold it. It is caught at runtime by the loop-alive check of
   §7, which is why that check exists.

### 10.3 What survives a mode switch

- **`setlevel!`, `light_on`, `light_off`, `initialize`, `shutdown`, `export_state`, `gui` and
  every readback are mode-invariant.** Code written against them needs no edit, and the switch
  really is the one constructor line.
- **`setcurrent!` and `setoutputpower!` are not**, by design: their unit changes with the mode,
  which is why they are two names.

**[policy]** drive the laser through `setlevel!` in anything that must survive a mode switch —
acquisition sequences, the per-frame level log, system `set_state` — and reserve the unit-true
setters for places where the number is a physical quantity someone wrote down. Test 9 of §9 is
the regression that keeps this true.

### 10.4 Existing code written against `LightSource`

| Code | After 0.3.0 |
|---|---|
| holds a `CrystaLaser`, `VortranLaser`, `DaqTrLight` or `SimLight` | **untouched.** No new supertype, no new field, `setpower` unchanged, panel unchanged (verified: `gui(CrystaLaser)` still resolves to `gui(::LightSource)`) |
| a field annotated `::LightSource` holding a TCube or a `SimDiodeLaser` | **still type-correct**; verified `isa` |
| a field annotated `::TCubeLaser` | **still accepts the value**; becomes abstract, so type-unstable. A field that must take the Sim too should be typed `::DiodeLaser` |
| calls `light_on`, `light_off`, `initialize`, `shutdown`, `export_state`, `gui` | **unchanged** |
| calls `setpower(tcube, mA)` | **breaks loudly**, by design (§8.2) |
| reads `properties.is_on` | **breaks loudly** — renamed `is_on_requested` in the same release |
| calls `subtypes(MC.LightSource)` downstream | **silently loses `TCubeLaser`.** Same hazard as §2.3, outside our test suite; belongs in the release notes with `device_types` offered as the fix |

---

## 11. Registration checklist

Not a new interface, so neither `interfaces` tuple is edited. What must be touched:

- `test/contract.jl:132-134` — append `setcurrent!`, `setoutputpower!`, `setlevel!`,
  `measured_current`, `measured_photocurrent`, `indicated_output_power`, `loop_status`,
  `regulation_mode`, `supported_modes` to the `generics` tuple. Anything a driver defines
  belongs there or it can be shadowed invisibly.
- `test/contract.jl:36-42` — harden `has_specific_method` against `UnionAll` signatures.
- `test/contract.jl:105,210` and `src/skills.jl:253` — `device_types` instead of bare
  `subtypes`, plus the `:TCubeLaser in nameof.(...)` regression assertion.
- `test/contract.jl:209-223` — the LightSource testset becomes mode-branched over the concrete
  instantiations from `supported_modes`, asserting `setcurrent!` for `ConstantCurrent`,
  `setoutputpower!` for `ConstantPhotocurrent`, and `setlevel!` for every `DiodeLaser`.
- `LightSourceInterface`'s export list; drivers define methods in the qualified
  `LightSourceInterface.setcurrent!(...)` form they already use, so the shadow guard stays green.

---

## 12. Binding fidelity: three places the bindings must match the header

### 12.1 The signed diode current reading — still open

`tcube_laser/functions_Tlaser.jl:229-231` binds `LD_GetLaserDiodeCurrentReading` as returning
`WORD`, and `constants_Tlaser.jl:3` defines `const WORD = Cushort`. The relayed vendor header
says the **diode current reading is signed**, ±32767 = ±220 mA. A negative reading therefore
decodes to roughly 65000, i.e. ~440 mA — twice full scale, reported as a plausible-looking
number. Nothing reads it today, so it is latent; `measured_current` is its first caller and must
not be built on it. Re-type to `Cshort` and add a range assertion. `LD_GetPhotoCurrentReading`
is correctly unsigned per the header, but a value above 32767 should be treated as a protocol
error rather than scaled.

### 12.2 The boolean width — settled, and it differs by ROLE

**Supersedes what this section said in the first revision 3 draft, which rested on the wrong
artefact.** The **installed** vendor header declares 32 lowercase `bool` and zero `BOOL`. The
copy that said otherwise — `typedef unsigned int BOOL`, no lowercase `bool` — is a **Clang.jl
generation input**, hand-edited to parse without Windows headers: vendor preamble replaced by
local typedefs, `OaIdl.h` and `__declspec` stripped, both `#pragma pack` lines commented out,
every `bool` rewritten to `BOOL`. **It carries no ABI information at all** (§13).

Neither pure type is right, because the two roles have different right answers.
Commit `fc86c1e` on `fix/revert-cppbool` splits them, and that is the current state.
**[guarantee]**, verified at that commit:

| Alias | Julia type | Why | Where |
|---|---|---|---|
| `KBOOL_ARG` | `Cuint` (4 bytes) | Zero-extended 0 or 1 is robust under **either** ABI: a `bool` callee reads the low byte, a `BOOL` callee reads four, and both see 0 or 1. A one-byte argument is the unsafe direction, because the upper bytes are undefined | 4 argument positions across 3 functions (`constants_Tlaser.jl:26`) |
| `KBOOL_RET` | `Bool` (1 byte) | A `bool` return sets only `AL` and leaves the rest of `EAX` undefined, so reading four bytes can turn `false` into a nonzero value — `LD_CheckConnection` reporting a disconnected controller as connected | 9 returns (`constants_Tlaser.jl:49`) |
| `BOOL` | `Cuint` | Survives **only** for `TLI_DeviceInfo`'s struct fields | §12.3 |

This plan depends on one of each, so the state matters rather than being trivia:

- §8.3 step 3 calls `LD_EnableMaxCurrentAdjust(serial, true, false)` in the clamp-programming
  path, the one real protection in power mode. Its two flags are `KBOOL_ARG`, so Julia converts
  the literals to `Cuint(1)`/`Cuint(0)` at the `ccall` boundary. **The conclusion is unchanged
  and the reason is now stronger:** those four bytes are deliberate, chosen to be correct under
  either ABI, rather than incidentally correct under an ABI we had misread.
- §8.4 calls `LD_StartPolling`, whose return is `KBOOL_RET`.

**The general rule this makes explicit, because getting it backwards is silent.** In this driver
a `Cshort` return is a **status code where 0 means success**, and a boolean return is a
**success flag where 0 means FAILURE**. `check_err` implements the first and must never be
pointed at the second: it would read every successful call as a failure and every failure as a
success. With `KBOOL_RET` the return now *reads* as a `Bool` at the call site, so the inversion
is visible in the type rather than waiting to be discovered.

### 12.3 `TLI_DeviceInfo` is packed, and our declaration is not — still unfixed

**[limitation]**, restored: it was correct, and was deleted on the strength of the same
generator-edited copy. The installed header has an **active** `#pragma pack(1)`, and with
1-byte flags the real layout is **100 bytes with `PID` at offset 85** — `typeID` 4 +
`description` 65 + `serialNo` 16, leaving no padding to absorb. Our declaration is a verified
**120 bytes with `PID` at offset 88**.

It stays unfixed here because correcting it needs the field types *and* the packing changed
together, plus a controller to read a device list back from — and nothing in this plan reads a
device list. `initialize` calls `TLI_BuildDeviceList`/`TLI_GetDeviceListSize`
(`interface_methods.jl:225-226`), which return counts rather than filling this struct, so no
path in this design touches the mismatched layout. Anyone who adds device enumeration inherits
the bug and should fix it first.

---

## 13. What I could not verify

- **GLMakie's behaviour when an `on` listener throws** (§1.3). Settle it with a throwing fixture
  in `test/gui.jl` under `xvfb-run`.
- **Whether the two rigs pass custom `properties` today.** §1.2 assumes the constructor defaults.
- **Kinesis polling semantics** (§8.4): that `LD_GetXReading` returns a cached value and that
  `LD_StartPolling` refreshes it at the requested period is read from the binding names and the
  relayed header, not verified on hardware. If polling does not refresh the readings, each getter
  must issue `LD_RequestReadings` and wait — turning cheap cache reads into round trips and
  putting a real bound on the 10 Hz cadence. **This is the one item whose answer changes an
  interface's cost rather than its shape.** The probe should measure it: read the diode current
  twice a second apart at two different currents and see whether the second read moves.
- **Whether `LD_FindTIAGain` must be called explicitly.** The relayed note says it "runs
  automatically, must follow the range setting, and needs the laser on" — which reads as though
  the controller does it itself. §8.3 therefore does not call it and exposes no wrapper (§15,
  deferral 8). If the probe shows the gain must be found explicitly, that is one exported
  function added then, documented as requiring emission.
- **The earlier ruling that mode is per-instance and fixed at construction** is not represented
  anywhere in the tree. I have honoured it; the type parameter makes it structural.
- **All vendor semantics** — the pot scale 20..255 = 17.3..220 mA, the status-bit map, the
  signedness, the DIP-switch-only TIA range, the TEC dependence — come from the relayed Kinesis
  header and manual, not from this tree. One binding return type still contradicts the header
  (§12.1) and one struct layout does (§12.3), which is why every scaling constant deserves a
  bench check before it is trusted.
- **Which copy of the header is evidence.** The **installed** vendor header is the artefact of
  record. A generator-edited copy — one prepared as Clang.jl input, with the preamble replaced,
  `__declspec` stripped, `#pragma pack` commented out and `bool` rewritten to `BOOL` — is
  evidence about *nothing* to do with the ABI, because every one of those edits removes ABI
  information on purpose. Treating one as evidence produced **two wrong rulings in opposite
  directions in a single afternoon** (§12.2, §12.3). Diff against the installed header before
  any binding type is changed on the strength of what a header "says".
- **`LD_EnableMaxCurrentAdjust`'s second and third arguments** (`enableAdjust`, `enableDiode`).
  Their *width* is settled (§12.2); their *meaning* is not. I recommend `(true, false)` then
  `(false, false)` and flag `enableDiode` as unverified. If it enables emission, clamp
  programming must move out of `initialize` entirely.
- **Whether `LD_SetClosedLoopMode` requires the output disabled.** §8.3 enters the mode with
  output disabled, which is the safe order either way.
- **The 224.2 W/A figure** preserved at `TCubeLaserControl.jl:38-44`, where it was *set* rather
  than measured. With power mode as the default it becomes the conversion constant every
  commanded milliwatt passes through. It needs a power-meter measurement **at the laser head**
  before 0.3.0 ships, or the 642 constructs with `mode = ConstantCurrent()` until it has one.
- **Three facts the design deliberately does not require** (§6): whether the 642 is
  TEC-stabilised, whether its photodiode is wired, and what problem constant power is meant to
  solve. The first two are what the rig's probe measures; the third is outstanding. None gates
  this plan.

---

## 14. Consumer requirements from the 642 rig, and where each landed

| # | Requirement | Where it landed | Adopted? |
|---|---|---|---|
| 1 | mW **at the laser output**; no sample-plane conversion in the driver; name it "output power" | `setoutputpower!`, `indicated_output_power`, `pd.output_power_requested`, `power_reference` in `export_state` (§3, §4); the no-downstream-fields policy (§4) and honesty mechanisms 2 and 4 (§6); panel axis `output power (mW)` (§5) | **Yes** — with one clarification below |
| 2 | `setlevel!` endpoints per mode; floor at/above threshold; linear in the regulated quantity | §10.2 in full, plus Sim test 8 | **Yes**, with a physics caveat and a named consequence |
| 3 | Per-laser numbers as fields, in `export_state`, with the mode name; TIA range as a stated expectation checked against the bits | `pd.tia_range` stated by the rig and verified in `initialize` step 2 (§4, §8.3); the full attribute list including `regulation_mode` (§4) | **Yes**, and it improved the design |
| 4 | Getters for photocurrent, diode current and the raw status word, at 1–10 Hz | `measured_photocurrent`, `measured_current`, and the raw word inside `loop_status` (§3); the polling ruling (§8.4) | **Yes**, delivered as one consistent snapshot rather than three getters |
| 5 | Mode fixed per instance; a one-line switch back | Type parameter (§2.3); the exact scope of "one line" (§10.3); Sim test 9 | **Yes**, with the boundary made explicit |
| 6 | The Sim twin on the same abstract type | `SimDiodeLaser{M} <: DiodeLaser` (§9), plus the `::DiodeLaser` field-typing advice (§10.4) | **Yes** |

**Where I did not adopt a requirement exactly as stated.** Three places, recorded because the
rig is the consumer and should be able to argue back:

1. **"Output power" names the plane; it does not upgrade `indicated_` to `measured_`.** The
   number is calibrated with a power meter at the head, which is right — but a one-time bench
   calibration makes every subsequent number a *conversion*, not a *measurement*. The two
   adjectives answer different questions: `output_power` says **where**, `indicated_` says **how
   well known**. Dropping `indicated_` would undo §6's mechanism 2. A genuinely measured output
   power needs a meter left in the beam, which is a different device and a different driver.
2. **A floor "at or above threshold" should be above it, not at it, and it is per-rig.** §10.2
   adopts the intent and adds two things: at exactly the ~65 mA threshold the diode is at the
   knee and `frac = 0.0` is still effectively dark, so the floor wants margin only a bench
   measurement can fix; and `min_current`'s upstream default stays `0.0`, because v0.2.3 chose
   that deliberately and the 405 depends on it.
3. **Three separate getters became one snapshot.** Requirement 4 asked for a raw-status-word
   getter alongside the two readings. `loop_status` returns all three plus the decoded flags in a
   single call, which is what a 1–10 Hz logger actually wants: three getters give three
   separately-timed reads of a system that is moving. If the rig wants the bare word on its own,
   that is a one-line accessor over the same call and I will add it on request.

---

## 15. What revision 3 removed, and the trigger that brings each back

A deferral without a trigger is a gap. Each row names what makes it come back, so nobody has to
re-derive the decision.

| # | Removed | Why it was not load-bearing | Trigger to restore |
|---|---|---|---|
| 1 | `ConstantOpticalPower`, and with it the `CurrentRegulated`/`PowerRegulated` supertypes | No device in MC has a metered optical loop; MPB is downstream and not an MC driver. Each supertype would have had exactly one leaf, and a category with one member is served by the leaf's own name | A driver that reports a metered optical power. It arrives with `ConstantOpticalPower`, `PowerRegulated` is introduced to group the two, and `isa ConstantPhotocurrent` becomes `isa PowerRegulated` at **three call sites in one file** (`_panel`, `_setlevel`, `export_state`'s `setpoint_unit`) |
| 2 | The `has_readback` trait | The abstract type already carries it: a `DiodeLaser` reads back, nothing else in this interface does. A trait restating the type system is a second source of truth that can disagree with it | A `DiodeLaser` with no readback, or a second interface where the hierarchy does not answer the question. Then it is a one-line trait, per the requested-vs-measured rule |
| 3 | The `measured_output_power` stub | Zero implementations, now and after this release. Its only job was reserving a name, and a name that does not exist cannot be misused: a caller gets `UndefVarError` instead of a thrown stub, which is also a refusal | The same device as trigger 1. One device, one generic — that is the natural pairing |
| 4 | `pd.last_status` and `pd.last_status_time` | They existed so a pure-field-read `export_state` could look like it carried measured evidence. The rig already logs `loop_status` at 1–10 Hz with its own timestamps, at far better resolution. The driver records what it commanded; the system records health (`mc-system-design` principle 5) | A consumer that needs loop health inside the HDF5 tree and cannot poll. Note the cost: either `export_state` touches the wire, which this plan refuses, or the cached fields come back |
| 5 | `pd.tia_range_expected` as a field separate from `pd.tia_range` | After a successful `initialize` the two are equal by construction, because a disagreement throws. Storing both stores the same number twice | Nothing foreseeable. If `initialize` ever *warned* instead of throwing, the two would diverge and both would be needed — which is a reason not to weaken the throw |
| 6 | `setlevel!` methods on the three DAQ-modulated lights | Nobody asked; the shared-slider payoff arrives only when the legacy panel is rewritten to use `setlevel!`, which this release does not do. The stub's message names the gap precisely | The legacy panel rewrite, or the first system that iterates a mixed list of lights. Three three-line methods, purely additive |
| 7 | `polling_interval_ms` as a constructor keyword | 50 ms (20 Hz) covers every stated cadence, and a knob nobody turns is a knob that can be turned wrong | A rig whose log cadence exceeds ~10 Hz, or a controller where 50 ms polling is too costly |
| 8 | `find_tia_gain!` | The relayed note says `LD_FindTIAGain` "runs automatically". Exporting a wrapper for a call the controller may already make is speculative, and it is the one export that requires emission to use | The probe showing that TIA gain must be found explicitly (§13). One exported function, documented as requiring the laser on |

**What was protected from the cut**, because simplifying it would mean doing it twice or losing
something that cannot be recovered later:

- **The naming honesty** (§6, all four mechanisms) — it costs nothing and is the main deliverable.
- **The closed-loop safety preconditions** (§8.3) — key, interlock, TIA agreement, the clamp
  programmed *and read back*, and the three-way dead-photodiode detection. Every one of these is
  a refusal that cannot be retrofitted after a diode is damaged.
- **`device_types` and the transitive contract fix** (§2.3) — not an extra but the price of the
  hierarchy: without it, `TCubeLaser` silently leaves both gates the moment it moves under
  `DiodeLaser`, verified.
- **`PhotodiodeLoop` as a struct** (§4) — collapsing six fields onto the laser makes a
  half-configured loop representable and turns one inner-constructor check into six.
- **`pd.photocurrent_requested`** (§4) — it holds the *decoded* setpoint, which is not derivable
  from the requested power, and it closes the gap v0.2.3's own docstring names: "there is no
  field here that reports what actually went to the wire".
