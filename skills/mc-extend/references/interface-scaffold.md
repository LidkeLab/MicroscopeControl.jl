# Interface scaffold: `Shutter`

Companion to `mc-extend` (MicroscopeControl.jl v0.2.0). Executed under `xvfb-run -a`. The bar for a new interface, the wiring and the hand-registration edits are in the skill body.

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
(`mc-extend`, "implicit structural contract", and `mc-api-map`'s `references/gui-fields.md`). **[limitation]** upstream
CLAUDE.md calls interface GUIs optional while `test/contract.jl` requires
every non-exempt device to dispatch `gui` to something other than the
`AbstractInstrument` stub. Resolve it for your interface explicitly: either
ship a shared panel, or document that drivers must supply their own.
