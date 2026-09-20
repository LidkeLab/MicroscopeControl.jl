---
name: mc-add-driver
description: Implement an existing MicroscopeControl.jl interface (Camera, Stage, LightSource, DAQ, Attenuator) for a new device -- the complete driver scaffold as a downstream-owned type or an upstream contribution, the import-to-extend binding rule and the shadow bug it prevents, the fields the shared GUIs read, behavioural obligations beyond method names, Reexport registration, the tests a driver must pass, and the prototype-then-contribute workflow; activates for "new driver", "implement Camera/Stage/LightSource", "add hardware", "support this device", "SDK wrapper", or "vendor DLL".
---

# mc-add-driver

Decide first: `mc-system-design`'s decision rule says whether you need a driver
(this skill), a new interface (`mc-add-interface`) or system code. This skill
assumes an interface already names your device's operations.

Labels as in `mc-system-design`: **[guarantee]** verified at MC v0.2.0,
**[limitation]** current shortfall to work around, **[policy]** recommended.
Everything marked *executed* ran under `xvfb-run -a` against v0.2.0; *traced*
was read from the upstream driver source and not run.

## What implementing an interface means in MC

**[guarantee]** There is no registration API. A driver is a concrete subtype of
an interface type plus methods added to MC's existing generic functions for that
subtype. Adding methods to `MicroscopeControl.initialize`,
`CameraInterface.capture`, and so on **for your own type** is the intended
extension mechanism and is not type piracy. Piracy is redefining a method for a
type MC owns (`capture(::SimCamera)`); `mc-driver-issue` covers that case.

Two arrangements, same code:

| | Downstream-owned type (prototype, or a device only your rig has) | Upstream contribution (a device others will use) |
|---|---|---|
| Location | a module in your repo | `src/hardware_implementations/<device>/` with `<Device>.jl`, `types.jl`, `interface_methods.jl`, SDK helpers |
| Imports | `using MicroscopeControl` then `import MicroscopeControl: initialize, shutdown, export_state, gui` and `import MicroscopeControl.LightSourceInterface` (or `CameraInterface`, `StageInterface`, ...) | `using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface` and `import ...MicroscopeControl: export_state, initialize, shutdown` (three dots: the driver module sits two levels below `MicroscopeControl`) |
| Registration | none; `using .MyDrivers` in your system code | `include` + `@reexport using .MyModule` in `HardwareImplementations.jl` (below) |
| Tests | your repo's test suite, with the checks listed below | upstream `test/contract.jl` runs them for every subtype automatically, plus a behavioural testset you add |

## The complete scaffold (executed)

A serial-controlled LED as a `LightSource`, written downstream over a fake
transport so it runs anywhere. The section comments say which upstream file each
part would live in. `FakePort` stands in for `LibSerialPort.SerialPort` or a
vendor `ccall` layer.

```julia
module RigDrivers
    using MicroscopeControl                                             # names only
    import MicroscopeControl: initialize, shutdown, export_state, gui    # generics we ADD methods to
    import MicroscopeControl.LightSourceInterface                        # qualify the interface operations
    export SerialLED, FakePort

    # --- transport / SDK helpers (upstream: serial.jl or <vendor>api.jl) -----------------
    mutable struct FakePort
        isopen::Bool
        log::Vector{String}
        fail_open::Bool
    end
    FakePort(; fail_open=false) = FakePort(false, String[], fail_open)
    function port_open!(p::FakePort)
        p.fail_open && error("FakePort: device not present")
        p.isopen = true
    end
    port_close!(p::FakePort) = (p.isopen = false)
    function port_write!(p::FakePort, cmd::String)
        p.isopen || error("FakePort: write on closed port")            # no silent no-op on a closed link
        push!(p.log, cmd)
    end

    # --- types.jl -------------------------------------------------------------------------
    mutable struct SerialLED <: LightSource
        unique_id::String
        properties::LightSourceProperties     # the field the shared gui and system code read
        port::FakePort
        owns_port::Bool                       # who closes it on shutdown: ownership is a field, not a guess
    end
    function SerialLED(; unique_id="SerialLED", port=FakePort(), owns_port=true, max_power_mW=100.0)
        # PURE: assembles the struct, touches no hardware. initialize() opens the link.
        SerialLED(unique_id, LightSourceProperties("mW", 0.0, false, 0.0, max_power_mW), port, owns_port)
    end

    # --- interface_methods.jl --------------------------------------------------------------
    function initialize(led::SerialLED)                 # unqualified is fine: `initialize` was IMPORTED
        led.port.isopen || port_open!(led.port)         # shared transport may already be open
        port_write!(led.port, "PWR 0"); port_write!(led.port, "OFF")
        led.properties.power = 0.0; led.properties.is_on = false
        return nothing
    end
    function shutdown(led::SerialLED)
        if led.port.isopen
            port_write!(led.port, "OFF"); led.properties.is_on = false
            led.owns_port && port_close!(led.port)      # a borrower leaves the port open
        end
        return nothing
    end
    function LightSourceInterface.setpower(led::SerialLED, power::Float64)   # qualified: adds to the interface generic
        lo, hi = led.properties.min_power, led.properties.max_power
        lo <= power <= hi || throw(ArgumentError("power $power mW outside [$lo, $hi]"))
        port_write!(led.port, "PWR $(round(Int, power))")
        led.properties.power = power                    # CACHED requested value, not a readback
        return nothing
    end
    LightSourceInterface.light_on(led::SerialLED)  = (port_write!(led.port, "ON");  led.properties.is_on = true;  nothing)
    LightSourceInterface.light_off(led::SerialLED) = (port_write!(led.port, "OFF"); led.properties.is_on = false; nothing)
    function export_state(led::SerialLED)
        p = led.properties
        attributes = Dict{String,Any}(
            "unique_id" => led.unique_id, "power_unit" => p.power_unit,
            "power_requested" => p.power,               # name says which kind of state this is
            "is_on" => p.is_on, "min_power" => p.min_power, "max_power" => p.max_power,
            "owns_port" => led.owns_port)
        return attributes, nothing, Dict{String,Any}()  # children: NAMED TUPLES of other exports, never device objects
    end
end
```

What the run showed:

| Call | Result |
|---|---|
| `led = SerialLED()` | `led.port.isopen == false`: constructor is pure |
| `initialize(led); setpower(led, 12.5); light_on(led)` | port log `["PWR 0", "OFF", "PWR 12", "ON"]`, `properties.power == 12.5` |
| `setpower(led, 500.0)` | `ArgumentError: power 500.0 mW outside [0.0, 100.0]` |
| `shutdown(led)` then `setpower(led, 1.0)` | port closed; `setpower` throws `FakePort: write on closed port` instead of pretending |
| `initialize(SerialLED(port=FakePort(fail_open=true)))` | throws `FakePort: device not present`; nothing to clean up because nothing opened |
| `export_state` -> `save_attributes_and_data` -> read back | `is_on` reads back `0.0` (Bool becomes Float64), `power_requested == 12.5` |
| `gui(led)` after `shutdown(led)` | **threw from inside `gui`**: the shared light panel calls `setpower(light, 0.5)` when it opens (see GUI section) |

The interface stub signature is the contract you are satisfying **[guarantee]**:
`setpower(::LightSource, ::Float64)`, `light_on(::LightSource)`,
`light_off(::LightSource)`. **[limitation]** the interface also declares
`light_on(::LightSource, ipower::Float64)`, which no driver implements and
upstream tracks as `@test_broken`; implement the 1-arg form.

## Binding identity: import to extend, never rely on `using`

**[guarantee]** In Julia, `using MicroscopeControl` brings the *name* `gui`
into scope. `function gui(::MyType)` after that does not add a method to
`MicroscopeControl.gui`; it creates a brand-new `MyModule.gui`. Nothing errors.
`MC.gui(dev)` then silently dispatches to the inherited interface panel (or the
throwing stub), and your method is dead code. Two real instances of this
existed in MC's own drivers before v0.2.0, which is why upstream's
`test/contract.jl` now walks every submodule and asserts each generic it
defines `=== getfield(MicroscopeControl, g)`.

Executed demonstration:

```julia
module ShadowDriver
    using MicroscopeControl                 # NAME only
    struct ShadowLED <: LightSource end
    gui(::ShadowLED) = :my_custom_panel     # creates ShadowDriver.gui, a NEW function
    setpower(::ShadowLED, p::Float64) = :never_called
    export ShadowLED
end
using .ShadowDriver
ShadowDriver.gui === MicroscopeControl.gui                       # false
which(MicroscopeControl.gui, Tuple{ShadowLED}).sig.parameters[2] # LightSource  (the shared panel, not yours)
MicroscopeControl.setpower(ShadowLED(), 1.0)                     # throws "setpower not implemented for ShadowLED"
hasmethod(MicroscopeControl.setpower, Tuple{ShadowLED,Float64})  # true!  it resolves -- to the throwing stub
```

The last line is the trap: `hasmethod` cannot detect the bug. Check
`which(f, Tuple{T,...}).sig.parameters[2] === T`, and check the function object
identity from inside your module (`RigDrivers.setpower === MicroscopeControl.setpower`
was `true` for the scaffold above).

Two correct idioms; use one consistently:

| Idiom | Looks like | Notes |
|---|---|---|
| import the generic, then define unqualified | `import MicroscopeControl: initialize, shutdown, export_state, gui` then `function initialize(::T)` | MC's own drivers do this for the lifecycle generics |
| qualify the definition | `function CameraInterface.capture(::T)`, `StageInterface.move(::T, x, y)` | MC's own drivers do this for interface operations; needs `using ...HardwareInterfaces.CameraInterface` (or `import MicroscopeControl.CameraInterface`) for the module name |

**[limitation]**, traced: the PI stage driver deliberately names its private
`ccall` wrappers `move`, `getposition`, `getrange`, `stopmotion`, `servo`, and
its qualified `StageInterface.move(::PIStage, ...)` methods call the private
ones unqualified. Importing those names into PI would turn each wrapper into
infinite recursion, so upstream's identity guard exempts exactly those five
names in exactly that module. Do not copy the arrangement; name private helpers
differently (`pi_move`, `sdk_getposition`).

## The implicit structural contract: fields the shared GUIs read

**[guarantee]** The interface `gui` methods are real, shared implementations,
not stubs. They read fields by name. A device that lacks one gets a `FieldError`
when its panel opens, even though every method dispatches correctly. Enumerated
from `stage_interface/gui.jl` and `camera_interface/gui.jl` at v0.2.0 and
checked with `hasfield` against every subtype (executed).

### `gui(::Stage)`

Dispatches on `stage.dimensions` (1, 2 or 3; anything else throws) to
`gui1d`/`gui2d`/`gui3d`.

| Field | Read by | Required |
|---|---|---|
| `dimensions::Int` | the dispatch | always |
| `connectionstatus::Bool` | every panel (connect/disconnect toggle, status text) | always |
| `stagelabel::String` | `GLMakie.activate!(title=stage.stagelabel)` at the end of each panel | always, **unguarded** |
| `targ_x`, `real_x`, `range_x` | 1d, 2d, 3d panels | always |
| `targ_y`, `real_y`, `range_y` | 2d, 3d panels | `dimensions >= 2` |
| `targ_z`, `real_z`, `range_z` | 3d panel | `dimensions == 3` |
| `servostatus` | servo toggle | optional: guarded by `hasfield(typeof(stage), :servostatus)` |
| `driftcorrectionstatus` | drift toggle | optional: guarded by `hasfield` |

Methods the panels call (arity follows `dimensions`): `initialize`, `shutdown`,
`move(stage, targ_x[, targ_y[, targ_z]])`, `getposition`, `home`, `stopmotion`,
`servo(stage, b[, b[, b]])`, `driftcorrection(stage, b[, b[, b]])`. Field types
follow `StageFormat` in `stage_interface/interface_types.jl`: positions
`Float64`, ranges `Tuple{Float64,Float64}`.

Per-device status at v0.2.0 (executed):

| Device | Missing GUI fields | Panel opens? |
|---|---|---|
| `SimStage1d/2d/3d` | `stagelabel` (they have `label`) | **no: `FieldError` [limitation]** |
| `PIStage` (2d) | `driftcorrectionstatus` (guarded), z fields (unused for 2d) | yes, without hardware |
| `MCLStage` | `servostatus`, `driftcorrectionstatus` (both guarded) | yes |
| `MCS2Stage` | `driftcorrectionstatus` (guarded) | yes |
| `N472` | nearly all (`targ_*`, `real_*`, `range_*`, `drift...`) | has its own `gui(::N472)` override; the shared panel would fail |

So a new stage either carries the fields above with those names, or ships its
own `gui(::MyStage)` (the N472 route). **[policy]** carry the fields: it is
what makes the Sim-for-hardware swap in `mc-sim-testing` work.

### `gui(::Camera)`

| Field | Read by | Notes |
|---|---|---|
| `unique_id::String` | label and window title | |
| `exposure_time::Float64` | textbox, `parse(Float64, text)` assigned back | |
| `roi::CameraROI` | textbox reads and assigns `roi.x_start, roi.y_start, roi.width, roi.height`; display sizes from `roi.height`, `roi.width` | must be MC's `CameraROI` (or have those four `Int` fields) |
| `capture_mode` | dropdown built from `instances(typeof(camera.capture_mode))` | must be an `Enum` |
| `trigger_mode` | same | must be an `Enum` |
| `sequence_length` | textbox, `parse(Int, text)` | |
| `is_running` | live loop `while camera.is_running == 1` | `Bool` or `Int` both satisfy `== 1` |

Methods the panel calls: `capture` (its return value is used as the frame:
`framedata = capture(camera)`), `getlastframe` (in the live loop), `abort`,
plus `live`/`sequence` through `start_live`/`start_sequence`. All four
existing cameras carry every field (executed). **[limitation]** the
mode-dropdown callback assigns to a `camera` name outside its scope (traced,
`create_menu`), so the dropdowns are not a reliable way to change mode; and
because `capture(::SimCamera)` returns an enum, "Start Capture" in the panel
only works for cameras whose `capture` returns the frame.

### `gui(::LightSource)` and `gui(::Attenuator)`

Read `unique_id` and `properties` (`LightSourceProperties`:
`min_power`, `max_power`, `power`; `AttenuatorProperties` similarly). All
current lights and the LCC1620 carry both (executed).
**[limitation]** the light panel's slider `lift` fires on creation, so opening
the panel calls `setpower(light, 0.5)` immediately, then on every slider or
toggle change. Opening a GUI is a hardware write; a driver whose `setpower`
throws on a closed link (as the scaffold does, correctly) will throw from
inside `gui` if the device is not initialized.

## Behavioural obligations beyond method names

**[policy]** for a new driver; each row names the upstream driver that shows
the failure mode as a **[limitation]** (traced unless marked).

| Obligation | Do this | Because |
|---|---|---|
| **Constructor side effects** | construct pure; open in `initialize` | `DCAM4Camera()` and `ThorCamCSCCamera()` open hardware in the constructor, and DCAM4 returns an error code or `nothing` on failure, leaving the SDK initialized (`mc-system-design` caveats) |
| **Connection ownership** | take shared dependencies as keyword arguments; record who closes (`owns_port`) | `CrystaLaser()` builds its own `NIdaq()`, picks the first device and channel; cannot be shared or configured |
| **Partial-failure cleanup** | if `initialize` opens A then fails on B, close A before rethrowing | nothing upstream does this for you (Principle 3 in `mc-system-design`) |
| **Failure visibility** | throw, or set a `last_error` field and return `nothing`, and document which | the DAQ-backed lights `@warn` and return on an empty channel list, so a laser can be "initialized" and inert |
| **Buffer lifetime** | copy out of SDK buffers before releasing them; never hand the caller a view into a buffer you will free | `DCAM4Camera.getdata` allocates, snaps, reads and **releases** buffers; calling `getlastframe` afterwards reads released memory (`mc-acquire`) |
| **Acquisition completion** | expose a completion signal (`is_running`, a `Task`, or a blocking call) and document it | `sequence(::SimCamera)` spawns an `@async` task that flips `is_running`; DCAM4 blocks in `dcamwait_event` |
| **Units** | state them in a field (`units::String`, `power_unit`) and in the docstring; convert at the SDK boundary, not in callers | PI reports millimetres, MCL micrometres, the Sims are unitless 0..100 |
| **Calibration** | store the table in the device (`AttenuatorProperties.cal_voltages`, `cal_transmissions`); take the values from the rig | `LCC1620.settransmission` `@error`s and returns when no calibration is set |
| **Cached versus measured** | name fields and attributes so the reader can tell (`power_requested`); update `real_*` only from a readback | Sim stages copy `targ_*` into `real_*`; `getposition(::SimStage3d)` returns a scalar, not the documented tuple (executed) |
| **Image axis convention (cameras)** | return `(H, W)` for a frame and `(H, W, N)` for a stack; at a row-major SDK boundary use `permutedims(reshape(buf, (W, H)), (2, 1))` | DCAM4 does exactly this in `dcambuf.jl` (traced) and `SimCamera` returns `(roi.height, roi.width[, N])` (executed); `save_h5` stamps `dimension_order = "HW"/"HWN"` assuming it |
| **`export_state`** | 1-arg method returning `(Dict{String,Any}, data_or_nothing, Dict{String,Any})`; HDF5-safe values (`collect` tuples, `string` enums, `copy` mutable vectors); children are named tuples | `TCubeLaser` defines only a 2-arg `export_state`, so the contract call throws; `Triggerscope4` has none (`MethodError`) |
| **Unsupported operations** | do not define the method; let the throwing interface stub answer, and document the gap | `stopmotion(::MCLStage)` is a concrete method whose body is `@error "STOP MOTION NOT IMPLEMENTED"`, so it looks implemented to `hasmethod` and the API map |

## Registration and exports (upstream contribution)

**[guarantee]** `src/hardware_implementations/HardwareImplementations.jl` is a
flat list of

```julia
include("my_device/MyDevice.jl")
@reexport using .MyDevice
```

Order matters only for **module load**: a module that references another
driver's type (`LCC1620` holds a `Triggerscope4`) must be included after it.
`src/MicroscopeControl.jl` already does `@reexport using .HardwareImplementations`,
so a name exported from your module is callable unqualified after
`using MicroscopeControl` with no further edit. CLAUDE.md's "re-export in main"
step means this chain, not another hand-maintained export list.

Export discipline **[guarantee]**, enforced by upstream's "No ambiguous
top-level exports" test (`names(MC)` must all be `isdefined`):

- Export your type and the operations users call. Re-exporting `gui`,
  `move`, `setpower` from your module is fine **only** because they are the same
  function objects as MC's (that is what `import`/qualification gives you).
- Never export a *different* function under a generic's name. Two modules each
  exporting their own `move` makes the top-level `move` ambiguous and every
  driver's stage stops working.
- Keep SDK helper names private (`dcamapi_init`, `port_write!`); do not export
  them, and do not give them generic names (the PI exception above).
- Driver-specific aliases such as `laser_488_gui` exist upstream as
  `import ...: gui as laser_488_gui`; they are the same object as `gui`. Do not
  add new ones.

## Tests a new driver must satisfy

Upstream `test/contract.jl` applies these to every subtype of every interface
automatically; downstream, write them yourself. `has_specific` is the same
check upstream uses.

```julia
using Test, MicroscopeControl
const MC = MicroscopeControl
has_specific(f, T, args...) = hasmethod(f, Tuple{T,args...}) && which(f, Tuple{T,args...}).sig.parameters[2] === T

@testset "SerialLED contract" begin
    T = SerialLED
    # 1. exact signatures: the method is defined ON T, not inherited from a stub
    @test has_specific(MC.initialize, T)
    @test has_specific(MC.shutdown, T)
    @test has_specific(MC.export_state, T)
    @test has_specific(MC.setpower, T, Float64)
    @test has_specific(MC.light_on, T)
    @test has_specific(MC.light_off, T)
    # 2. shared-function identity: no shadow bindings in the driver module
    for g in (:initialize, :shutdown, :export_state, :gui, :setpower, :light_on, :light_off)
        isdefined(RigDrivers, g) && @test getfield(RigDrivers, g) === getfield(MC, g)
    end
    # 3. inherited gui is the interface panel, not the AbstractInstrument stub
    @test which(MC.gui, Tuple{T}).sig.parameters[2] === LightSource
    # 4. unsupported operations fail loudly (2-arg light_on is not implemented, on purpose)
    @test_throws ErrorException MC.light_on(SerialLED(), 1.0)
    # 5. lifecycle and behaviour through the fake transport
    led = SerialLED()
    @test !led.port.isopen
    initialize(led); setpower(led, 12.5); light_on(led)
    @test led.port.log == ["PWR 0", "OFF", "PWR 12", "ON"]
    @test_throws ArgumentError setpower(led, 500.0)
    shutdown(led)
    @test !led.port.isopen
    @test_throws ErrorException setpower(led, 1.0)          # closed link is an error, not a no-op
    @test_throws ErrorException initialize(SerialLED(port=FakePort(fail_open=true)))
    # 6. state export is serialisable, not just present
    a, d, c = export_state(led)
    @test a isa Dict{String,Any} && c isa Dict{String,Any}
    mktempdir() do dir
        f = joinpath(dir, "led.h5")
        save_attributes_and_data(f, "Main", a, d, c)          # synchronous form
        MC.HDF5.h5open(f, "r") do h
            @test MC.HDF5.attrs(h["Main"])["power_requested"] == 12.5   # last requested value; shutdown does not reset it
        end
    end
end
```

All of these passed for the scaffold (executed). What they establish, and what
they do not:

| Simulation or fake transport establishes | Only hardware acceptance establishes |
|---|---|
| dispatch reaches your methods; no shadow bindings | the SDK actually does what the command string says |
| lifecycle ordering and cleanup logic | timing, settling, buffer sizes, timeouts |
| range checks and error paths you coded | vendor error codes you have not seen |
| the export tree serialises | units and sign conventions on the real axis |
| GUI field compatibility (`hasfield`, or open the panel under `xvfb-run -a`) | that the panel's actions do the right physical thing |

**[policy]** record hardware acceptance (device, firmware, pinned MC tag, what
was checked) in the rig repo, as upstream's CLAUDE.md says it is not tracked in
MC.

## Workflow

1. **Prototype downstream** as a module in your repo (left column of the
   arrangements table). Type your system's field by the interface
   (`laser::LightSource`) so the Sim device and your driver are interchangeable
   in tests (`mc-sim-testing`).
2. **Decide the destination** with the boundary test in `mc-system-design`.
   If it would make sense on another microscope, contribute it.
3. **Contribute upstream from a source checkout**, never by editing the copy in
   the Julia depot: `Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")`
   (or `Pkg.develop(path=...)` on a clone), work on a branch, move the module to
   `src/hardware_implementations/<device>/`, switch the imports to the
   three-dot relative form, register it in `HardwareImplementations.jl`, add a
   behavioural testset, and run the suite under `xvfb-run -a` (the contract
   tests will now cover your type).
4. **Docs**: docstrings on the type and every method (the contract stubs'
   docstrings are the template: arguments, units, returns), a CHANGELOG entry
   under `[Unreleased]`, and a "hardware verification" line saying what was or
   was not checked on hardware.
5. **Version compatibility** (traced from upstream CLAUDE.md): a minor bump
   means an interface change (a signature, export or dispatch contract), a
   patch bump is everything else; every merge to `main` is tagged. A new driver
   adds exports, so expect a minor bump; ask the maintainer if unsure. Your rig
   repo pins a tag; do not depend on `main`.
6. **Refresh the installed skills** after moving the pin: run `install_skills()`
   again in the rig repo. It regenerates `mc-api-map`'s `references/api-map.md`,
   which is the only place your new type's method list appears automatically.
