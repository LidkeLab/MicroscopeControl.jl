# Driver scaffold and contract tests

Companion to `mc-extend` (MicroscopeControl.jl v0.2.0). Executed under `xvfb-run -a`; labels `[guarantee]`/`[limitation]`/`[policy]` as in `mc-system-design`.

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
`setpower(::LightSource, ::Float64)` and `light_off(::LightSource)`.
**[limitation]** for `light_on` the interface declares **only** the 2-arg
`light_on(::LightSource, ipower::Float64)`, which no driver implements and
upstream tracks as `@test_broken`; every driver and both shared panels use the
1-arg `light_on(light)`, for which there is no stub at all, so a bare
`LightSource` subtype gets a `MethodError` for it, not the "not implemented"
error. Implement the 1-arg form; the contract testset's `has_specific(MC.light_on, T)`
checks it.

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
