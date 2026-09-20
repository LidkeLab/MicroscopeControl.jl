---
name: mc-add-interface
description: Define a new MicroscopeControl.jl device class -- when a new interface is justified over a new implementation, the interface scaffold (abstract type under AbstractInstrument, property struct, documented throwing stubs), why SLM and TRIG are not the template, the interface_types/interface_functions/gui layout and Reexport wiring, the two hand-maintained interface lists that must be edited, and the simulated implementation that must ship with it; activates for "new interface", "new device class", "abstract type for", "MC has no interface for", or "define the contract".
---

# mc-add-interface

Decide first: `mc-system-design`'s decision rule separates driver, interface
and system code. This skill is the rare and consequential case: you are
defining a contract that every future driver of this device class must
satisfy, and that every system will assume. Labels as in `mc-system-design`:
**[guarantee]** verified at MC v0.2.0, **[limitation]** current shortfall,
**[policy]** recommended. Executed items ran under `xvfb-run -a`.

## The bar

Add an interface only when **all** of these hold:

1. No existing interface (`Camera`, `Stage`, `LightSource`, `DAQ`,
   `Attenuator`) can name the device's operations without lying. A shutter as
   a `LightSource` (`light_on`/`light_off`) is a defensible stretch; a
   spectrometer as a `Camera` is not.
2. At least two implementations are in view: one real device and the
   simulated one you will ship with the interface. An interface with one
   implementation is a driver with extra ceremony.
3. Someone downstream will write system code against the *interface*, not the
   device: they need the Sim swap, the shared panel, or a field of interface
   type in their system struct.

If any fails, write a driver (`mc-add-driver`) and, if the fit is poor, a
small adapter in your system.

## What an interface is in MC

**[guarantee]** An interface module declares an abstract type under
`AbstractInstrument`, optionally a property struct, and one generic function
per operation whose only method is a stub that **throws**
`ErrorException("<op> not implemented for <T>")`. It may add a shared
`gui(::Iface)` panel. Drivers add methods for their concrete type; nothing
else connects them. The lifecycle generics (`initialize`, `shutdown`,
`export_state`, `gui`) come from `AbstractInstrument` and need no
redeclaration, though `CameraInterface` re-stubs `export_state(::Camera)`.

## `SLM` and `TRIG` are NOT the template

**[limitation]**, executed: `abstract type SLM end` and `abstract type TRIG end`
sit *outside* `AbstractInstrument`. What that costs them today:

| Consequence | `MLSLM` (SLM) | `Triggerscope4` (TRIG) |
|---|---|---|
| `T <: AbstractInstrument` | `false` | `false` |
| `initialize`/`shutdown` | **no methods**: `MethodError`, not the "not implemented" error | defined by the driver itself |
| `export_state` | `MethodError` | `MethodError` (`hasmethod` is `false`); cannot appear in a saved record |
| `gui` | none | `gui(::TRIG)` exists because `TrigInterface` imports `gui` and defines it |
| in a system field typed `AbstractInstrument`, or a `Vector{AbstractInstrument}` rollback list | cannot be stored | cannot be stored |
| upstream contract test | listed in `no_core_methods`; exempt from everything | exempt from `export_state` |
| SLM interface operations | `displayimage(::MLSLM)` resolves to the interface's own `displayimage(::SLM)`, whose body is **empty** (returns `nothing`, silently): Meadowlark's `interface_functions.jl` is never `include`d by its module (executed / traced). A non-throwing default is exactly what this skill tells you never to ship. | n/a |

A system cannot treat these two like the other devices: no uniform lifecycle
loop, no export, and an error type (`MethodError`) that a
`catch e; e isa ErrorException` guard will not catch. Making them
`<: AbstractInstrument` is an upstream follow-up. Your new interface goes under
`AbstractInstrument`, full stop.

## The scaffold (executed)

A mechanical shutter. Written as downstream modules here so it runs anywhere;
the comments give the upstream file layout.

```julia
# src/hardware_interfaces/shutter_interface/ShutterInterface.jl
module ShutterInterface
    using MicroscopeControl                       # upstream: using ...MicroscopeControl
    import MicroscopeControl: gui, export_state   # generics this interface adds methods to
    export Shutter, ShutterProperties, open_shutter!, close_shutter!, is_open
    # export gui                                  # only if you ship a gui.jl (see below)

    # ---- interface_types.jl ----
    """
        Shutter <: AbstractInstrument
    A binary optical shutter. Implementations must carry `unique_id::String` and
    `properties::ShutterProperties` (read by the shared panel and by system code).
    """
    abstract type Shutter <: AbstractInstrument end

    """
        ShutterProperties(is_open, switch_time_s)
    - `is_open::Bool`: last commanded state (requested, not measured, unless the driver reads back).
    - `switch_time_s::Float64`: worst-case open/close time in seconds; callers wait this long.
    """
    mutable struct ShutterProperties
        is_open::Bool
        switch_time_s::Float64
    end

    # ---- interface_functions.jl: one throwing stub per operation, documented as the contract ----
    """
        open_shutter!(s::Shutter)
    Open the shutter and block until it is open (at most `properties.switch_time_s`).
    Sets `properties.is_open = true`. Throws if the device is not initialized.
    Returns `nothing`.
    """
    open_shutter!(s::Shutter)  = error("open_shutter! not implemented for $(typeof(s))")

    """
        close_shutter!(s::Shutter)
    Close the shutter and block until closed. Sets `properties.is_open = false`.
    Throws if not initialized. Returns `nothing`.
    """
    close_shutter!(s::Shutter) = error("close_shutter! not implemented for $(typeof(s))")

    """
        is_open(s::Shutter) -> Bool
    Measured state where the hardware can report it; otherwise the last commanded
    state, and the driver docstring must say which.
    """
    is_open(s::Shutter)        = error("is_open not implemented for $(typeof(s))")

    export_state(s::Shutter)   = error("export_state not implemented for $(typeof(s))")

    # ---- gui.jl (optional): a shared panel that reads unique_id and properties ----
    # function gui(s::Shutter) ... end
end

# src/hardware_implementations/simulated_shutter/SimulatedShutter.jl -- ships WITH the interface
module SimulatedShutter
    using MicroscopeControl
    using ..ShutterInterface                       # upstream: using ...MicroscopeControl.HardwareInterfaces.ShutterInterface
    import MicroscopeControl: initialize, shutdown, export_state
    export SimShutter
    mutable struct SimShutter <: Shutter
        unique_id::String
        properties::ShutterProperties
        connected::Bool
    end
    SimShutter(; unique_id="SimShutter") = SimShutter(unique_id, ShutterProperties(false, 0.005), false)
    initialize(s::SimShutter) = (s.connected = true;  s.properties.is_open = false; nothing)
    shutdown(s::SimShutter)   = (s.properties.is_open = false; s.connected = false; nothing)
    ShutterInterface.open_shutter!(s::SimShutter)  = (s.connected || error("not initialized"); sleep(s.properties.switch_time_s); s.properties.is_open = true;  nothing)
    ShutterInterface.close_shutter!(s::SimShutter) = (s.connected || error("not initialized"); sleep(s.properties.switch_time_s); s.properties.is_open = false; nothing)
    ShutterInterface.is_open(s::SimShutter) = s.properties.is_open
    export_state(s::SimShutter) = (Dict{String,Any}("unique_id" => s.unique_id, "is_open" => s.properties.is_open,
                                                    "switch_time_s" => s.properties.switch_time_s, "connected" => s.connected),
                                   nothing, Dict{String,Any}())
end
```

What the run showed:

| Call | Result |
|---|---|
| `open_shutter!(NoMethodsShutter())` for a bare `struct NoMethodsShutter <: Shutter end` | `open_shutter! not implemented for NoMethodsShutter` |
| `initialize(NoMethodsShutter())`, `gui(NoMethodsShutter())` | `initialize not implemented ...`, `gui not implemented ...`: the `AbstractInstrument` stubs are inherited because the type sits under it |
| `initialize(SimShutter()); open_shutter!(sh); is_open(sh)` | `true`; `export_state(sh)[1]["is_open"] == true` |
| `has_specific` for `initialize, shutdown, export_state, open_shutter!, close_shutter!, is_open` on `SimShutter` | all `true` |
| `SimulatedShutter.open_shutter! === ShutterInterface.open_shutter!`, `SimulatedShutter.export_state === MicroscopeControl.export_state` | `true`, `true`: no shadow bindings |
| `subtypes(Shutter)` | `[NoMethodsShutter, SimShutter]`: this is how the contract test and the API map will find your devices |

## Writing the contract, not just the stubs

**[policy]** Each stub's docstring is the contract. State, for every operation:

- **signature and units** (`Float64` seconds, millimetres; be explicit, the
  package has stages in millimetres and micrometres and a `light_on` stub whose
  arity no driver implements);
- **return value** (`nothing`, a `Bool`, an array shape): `getposition`'s
  docstring promises a tuple and the Sim returns a scalar, so this is where
  drift starts;
- **state update** (which `properties` field changes, whether it is requested
  or measured);
- **failure behaviour** (throw, or set a field and return `nothing`; pick one
  for the whole interface);
- **completion** (blocking, or a signal to poll), and
- **required versus optional** operations. An optional operation still gets a
  throwing stub; drivers that lack it simply do not define it. Never ship a
  "does nothing" default: it turns an unsupported operation into a silent one.

If you ship a `gui.jl`, list the fields it reads in the abstract type's
docstring (as `Shutter` does above); those become part of the contract
(`mc-add-driver`, "implicit structural contract"). **[limitation]** upstream
CLAUDE.md calls interface GUIs optional while `test/contract.jl` requires
every non-exempt device to dispatch `gui` to something other than the
`AbstractInstrument` stub. Resolve it for your interface explicitly: either
ship a shared panel, or document that drivers must supply their own.

## Layout and wiring (upstream)

**[guarantee]**, from `src/hardware_interfaces/`:

```
src/hardware_interfaces/shutter_interface/
    ShutterInterface.jl       # module: using ...MicroscopeControl; import ...MicroscopeControl: gui, export_state; exports; includes
    interface_types.jl        # abstract type Shutter <: AbstractInstrument end; ShutterProperties
    interface_functions.jl    # throwing stubs with docstrings
    gui.jl                    # optional shared panel
src/hardware_implementations/simulated_shutter/
    SimulatedShutter.jl       # using ...MicroscopeControl.HardwareInterfaces.ShutterInterface; import ...MicroscopeControl: export_state, initialize, shutdown
    types.jl
    interface_methods.jl
```

Register both, in the two container modules (the root already
`@reexport`s each container, so nothing else changes):

```julia
# src/hardware_interfaces/HardwareInterfaces.jl
include("shutter_interface/ShutterInterface.jl")
@reexport using .ShutterInterface

# src/hardware_implementations/HardwareImplementations.jl
include("simulated_shutter/SimulatedShutter.jl")
@reexport using .SimulatedShutter
```

Export collisions: every name your interface exports lands in the flat
`MicroscopeControl` namespace next to `move`, `capture`, `setpower`,
`open`-like Base names and every driver's exports. Upstream's "No ambiguous
top-level exports" test fails the build if two modules export different
objects under one name. Prefer specific names (`open_shutter!`, not `open`);
`TrigInterface` extends `Base.reset` rather than exporting its own `reset` for
exactly this reason (traced).

## Hand registration: two lists that do not discover new interfaces

**[guarantee]**, verified in both files at v0.2.0. Neither the contract test
nor the API-map generator walks `subtypes(AbstractInstrument)`; each carries a
literal tuple of interface types. A new interface that is not added to both
exists, loads, and is invisible to both gates.

`test/contract.jl`, inside the "Interface Contract" testset:

```julia
# before
interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG)
# after
interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG, MC.Shutter)
```

The same file has a `generics` tuple in "No shadowed generics in submodules";
add your operations so the identity guard covers them:

```julia
generics = (:gui, :initialize, :shutdown, :export_state, :move, ..., :settransmission, :gettransmission,
            :open_shutter!, :close_shutter!, :is_open)
```

and add a per-interface testset alongside "Stage contract"/"Camera contract":

```julia
@testset "Shutter contract" begin
    for T in subtypes(MC.Shutter)
        @test has_specific_method(MC.open_shutter!, T)
        @test has_specific_method(MC.close_shutter!, T)
        @test has_specific_method(MC.is_open, T)
    end
end
```

`src/skills.jl`, in the API-map generator (the function that writes
`references/api-map.md`):

```julia
# before
interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG)
# after
interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG, MC.Shutter)
```

The generator's per-device method walk uses the module's exported function
names, so your exported operations appear under each device automatically
once the interface is in the tuple.

## The simulated implementation is mandatory

**[policy]**, and the reason is structural: the interface's stubs all throw, so
without a concrete subtype nothing exercises the contract. The Sim device is

- what upstream's contract test runs against (it iterates `subtypes`);
- what proves the docstrings are implementable as written (arity, return
  types, `export_state` values that serialise);
- what downstream repos put in the interface-typed field of their system
  struct in tests (`mc-sim-testing`), which is the whole point of having an
  interface rather than a driver;
- what the shared `gui`, if any, is developed against under `xvfb-run -a`.

Make it honest about what it does not model: the Sim shutter above sleeps for
`switch_time_s`, and its `is_open` is the commanded state. Say so in its
docstring so nobody reads a Sim pass as a hardware result.

## Checklist before opening the PR

1. `abstract type X <: AbstractInstrument end`, property struct, documented
   throwing stubs, optional `gui.jl`.
2. Sim implementation with `initialize`, `shutdown`, 1-arg `export_state`, every
   required operation, and a behavioural testset.
3. `include` + `@reexport` in **both** container modules.
4. Interface tuple in **both** `test/contract.jl` and `src/skills.jl`; operations
   in the `generics` tuple; a per-interface contract testset.
5. Full suite green under `xvfb-run -a`; "No ambiguous top-level exports" passes.
6. CHANGELOG under `[Unreleased]`; this is an interface change, so a minor bump
   under upstream's policy.
7. After the tag: downstream repos re-run `install_skills()` so the generated API
   map lists the new interface (`mc-add-driver`, Workflow).
