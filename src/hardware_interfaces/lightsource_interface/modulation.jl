"""
    AbstractModulationControl

Something that puts a LEVEL on a light's analogue input, in the light's own unit (mW in
`ConstantPhotocurrent`, mA in `ConstantCurrent`, whatever a plain `setpower` takes), by driving a
voltage: a DAQ analogue output ([`NIDAQModulator`](@ref)) or a recorder ([`RecordingModulator`](@ref)). (A Triggerscope
DAC modulator follows in a later release.) It holds the scale
(`per_volt`, the light's unit per volt), so `setpower(modulator, p)` is the whole conversation.

It is not an `AbstractInstrument` and has no panel. A modulator is built for one pairing of an output
and a light; the claim in [`open_modulator!`](@ref) refuses a second light on the same output.

# The four methods a modulator defines

`[guarantee]` of a type that `<: AbstractModulationControl` (checked by `test/contract.jl`):

- `setpower(mc, p::Float64)`: put level `p` on the output; `p = 0` is 0 V. Throws `ArgumentError`
  BEFORE any write when `p` is out of the output's reach; any other throw leaves the output unknown.
- `initialize(mc)`: open the output, leaving 0 V; or throw having released what it took.
- `shutdown(mc)`: write 0 V, then release.
- `output_id(mc)::String`: names the physical output, for the claim.

[`export_state`](@ref)`(mc)` has a fallback (the type and `output_id`) and is a child of the light's.

# How a light takes one

See [`LightSource`](@ref) and [`modulation_violations`](@ref).
"""
abstract type AbstractModulationControl end

"""
    setpower(mc::AbstractModulationControl, p::Float64)

Put level `p`, in the light's unit, on the modulator's output. `p = 0` is 0 V. Throws `ArgumentError`
before any write when `p` is out of the output's reach (not finite, below 0, or needing a voltage the
output cannot make); any other throw leaves the output's level unknown, and the light darkens.
"""
function setpower(mc::AbstractModulationControl, p::Float64)
    error("setpower not implemented for $(typeof(mc))")
end

"""
    initialize(mc::AbstractModulationControl)

Open the modulator's output leaving 0 V, or throw having released whatever it took. Called by
[`open_modulator!`](@ref), not by user code.
"""
function initialize(mc::AbstractModulationControl)
    error("initialize not implemented for $(typeof(mc))")
end

"""
    shutdown(mc::AbstractModulationControl)

Write 0 V, then release the output. Called by [`close_modulator!`](@ref), not by user code.
"""
function shutdown(mc::AbstractModulationControl)
    error("shutdown not implemented for $(typeof(mc))")
end

"""
    output_id(mc::AbstractModulationControl) -> String

Names the physical output (`"NIDAQ Dev1/ao1"`), the key of the claim that
lets only one light object drive it. Public, not exported.
"""
function output_id(mc::AbstractModulationControl)
    error("output_id not implemented for $(typeof(mc))")
end

"""
    export_state(mc::AbstractModulationControl)

The fallback: the modulator's type and its [`output_id`](@ref). A driver adds what it knows (the scale,
the range). A child of the light's `export_state`.
"""
function export_state(mc::AbstractModulationControl)
    attributes = Dict{String,Any}("modulator_type" => string(nameof(typeof(mc))), "output_id" => output_id(mc))
    return attributes, nothing, Dict{String,Any}()
end

# Which light object holds each modulator output, process-wide.
const MODULATOR_OUTPUTS = Dict{String,Any}()
const MODULATOR_OUTPUTS_LOCK = ReentrantLock()

"""
Claim `id` for `light`, or refuse (`ErrorException`) when another light object holds it. Returns `true` when this call
took the claim and `false` when `light` already held it.
"""
function claim_output!(light, id::AbstractString)
    lock(MODULATOR_OUTPUTS_LOCK) do
        holder = get(MODULATOR_OUTPUTS, id, nothing)
        (holder === nothing || holder === light) || error(
            "modulator output \"$id\" is already driving the light $(repr(holder.unique_id)); a second light object may not use it. " *
            "Give each light its own output, or shut the other light down first.")
        MODULATOR_OUTPUTS[id] = light
        return holder === nothing
    end
end

"Release `id` if `light` holds it."
function release_output!(light, id::AbstractString)
    lock(MODULATOR_OUTPUTS_LOCK) do
        get(MODULATOR_OUTPUTS, id, nothing) === light && delete!(MODULATOR_OUTPUTS, id)
    end
    return nothing
end

holds_output(light, id::AbstractString) = lock(MODULATOR_OUTPUTS_LOCK) do
    get(MODULATOR_OUTPUTS, id, nothing) === light
end

"""
    holds_resources(mc::AbstractModulationControl) -> Bool

Whether `mc` still holds something that a `shutdown` must release (an open task whose cleanup failed). `false` by
default. [`open_modulator!`](@ref) keeps the claim while this is `true`, so a later `shutdown` can still release it.
"""
holds_resources(mc::AbstractModulationControl) = false

"""
    open_modulator!(light)

Claim `output_id(light.modulator)` for `light` (refused if another light object holds it), then
[`initialize`](@ref) the modulator, which leaves 0 V. If the initialize throws, the error is rethrown and the claim
is released, unless the modulator still [`holds_resources`](@ref) (a task it could not delete): the claim, whether
taken by this call or an earlier `initialize`, then stays until `close_modulator!` releases it. A no-op when
`light.modulator === nothing`. A light calls it at the end of its own `initialize`, with its output off. Public, not
exported.
"""
function open_modulator!(light)
    mc = light.modulator
    mc === nothing && return nothing
    id = output_id(mc)
    claim_output!(light, id)
    try
        initialize(mc)
    catch
        holds_resources(mc) || release_output!(light, id)
        rethrow()
    end
    return nothing
end

"""
    close_modulator!(light)

[`shutdown`](@ref) `light.modulator` (0 V, then release), then release the claim. A failed `shutdown`
keeps the claim and rethrows, so the next call retries it and no other light can take the output
meanwhile. A no-op when there is no modulator or `light` holds no claim. A light calls it from its own
`shutdown`, after switching off. Public, not exported.
"""
function close_modulator!(light)
    mc = light.modulator
    mc === nothing && return nothing
    id = output_id(mc)
    holds_output(light, id) || return nothing
    shutdown(mc)
    release_output!(light, id)
    return nothing
end

"""
    zero_modulator!(light) -> Nothing or the exception

Write level 0 to `light.modulator`, never throwing: a failure is logged (`@error`) and returned. The
switch-off paths call it first and must go on to switch the light off whatever happens here. An
`InterruptException` is returned like any other failure, so the caller can switch the light off first; it then
passes it on with [`propagate_interrupt`](@ref). Public, not exported.
"""
function zero_modulator!(light)
    mc = light.modulator
    mc === nothing && return nothing
    try
        setpower(mc, 0.0)
        return nothing
    catch e
        @error "$(light.unique_id): writing 0 V to the modulator failed; the voltage on its output is unknown" exception = e
        return e
    end
end

"""
    propagate_interrupt(err)

Throw `err` if it is an `InterruptException`, else return `nothing`. A switch-off path calls it AFTER it has switched
the light off, with what [`zero_modulator!`](@ref) returned, so an interrupted 0 V write never skips the disable.
"""
propagate_interrupt(err) = err isa InterruptException ? throw(err) : nothing

"""
    apply_level!(light, p, darken!; darken_argument_errors = false)

Put level `p` on `light.modulator`. For a level setter whose light is on, an `ArgumentError` (the modulator refused
before writing) is rethrown and changes nothing; with `darken_argument_errors = true` (an activation, where the light
is already enabled) it darkens like any other throw. Any other throw, an `InterruptException` included, leaves the
output unknown: level 0 is written (tried; a failure is logged), `darken!()` switches the light off, and the error is
rethrown. Public, not exported.
"""
function apply_level!(light, p::Float64, darken!; darken_argument_errors::Bool=false)
    try
        setpower(light.modulator, p)
    catch e
        (e isa ArgumentError && !darken_argument_errors) && rethrow()
        zero_modulator!(light)
        darken!()
        rethrow()
    end
    return nothing
end

"""
    RecordingModulator(; id = "RecordingModulator", reach = Inf, sink = nothing)

A test aid: an [`AbstractModulationControl`](@ref) that writes nothing and records everything. `writes`
holds every level it accepted, `attempts` every level it was asked for (accepted or not), `opened` and
`closed` count `initialize` and `shutdown`. Set `failure` to an exception to make every `setpower`,
`initialize` and `shutdown` throw it; `reach` is the largest level it accepts (`ArgumentError` above it, before
any write). `sink`, if given, is called with each accepted level, so a test can drive a faked device from it.
Public, not exported; use it with [`modulation_violations`](@ref).
"""
mutable struct RecordingModulator <: AbstractModulationControl
    id::String
    reach::Float64
    sink::Any
    failure::Any
    writes::Vector{Float64}
    attempts::Vector{Float64}
    opened::Int
    closed::Int
end

RecordingModulator(; id::AbstractString="RecordingModulator", reach::Real=Inf, sink=nothing) =
    RecordingModulator(String(id), Float64(reach), sink, nothing, Float64[], Float64[], 0, 0)

output_id(m::RecordingModulator) = m.id

function setpower(m::RecordingModulator, p::Float64)
    push!(m.attempts, p)
    m.failure === nothing || throw(m.failure)
    (isfinite(p) && 0.0 <= p <= m.reach) || throw(ArgumentError(
        "RecordingModulator $(m.id): level $p is outside its reach [0, $(m.reach)]"))
    push!(m.writes, p)
    m.sink === nothing || m.sink(p)
    return nothing
end

function initialize(m::RecordingModulator)
    m.failure === nothing || throw(m.failure)
    m.opened += 1
    return setpower(m, 0.0)
end

function shutdown(m::RecordingModulator)
    m.failure === nothing || throw(m.failure)
    m.closed += 1
    return setpower(m, 0.0)
end

"""
    modulation_violations(light; set!, expect) -> Vector{String}

Check that an INITIALIZED `light`, whose `modulator` is a [`RecordingModulator`](@ref), follows the convention
a light with a modulator keeps; an empty result means it does. A downstream package runs

```julia
@test isempty(MicroscopeControl.modulation_violations(light; set! = l -> setpower(l, 2.0), expect = 2.0))
```

with its native side faked, where `set!` sets a level (in the light's own unit) and `expect` is what the
modulator should then be asked for. It leaves the light off and the recorder cleared. It checks that:

1. the light has a `modulator` field that admits `nothing`, holding a [`RecordingModulator`](@ref);
2. a level set while the light is off writes nothing but 0;
3. `light_on` writes level 0 first, then the level `expect` (a recorded request);
4. a level set while on reaches the modulator as `expect`;
5. an `ArgumentError` from the modulator reaches the caller and changes nothing (the light stays on, no 0
   written);
6. any other throw from the modulator reaches the caller, level 0 is tried, and the light is off;
7. `light_on` with a failing modulator throws and leaves the light off, and `light_off` with one does not throw;
8. `light_on` with a recorded level the modulator refuses (`ArgumentError` after the enable) leaves the light off.

Public, not exported.
"""
function modulation_violations(light; set!, expect::Real, atol::Real=1e-9)
    v = String[]
    T = typeof(light)
    if !(:modulator in fieldnames(T))
        return ["$(nameof(T)) has no `modulator` field"]
    end
    Nothing <: fieldtype(T, :modulator) || push!(v, "$(nameof(T))'s `modulator` field does not admit `nothing`")
    mc = light.modulator
    if !(mc isa RecordingModulator)
        push!(v, "modulation_violations needs `modulator = RecordingModulator()` on the light, got $(typeof(mc))")
        return v
    end
    ison() = hasproperty(light, :properties) ? light.properties.is_on : missing
    function step(what, f)
        try
            f()
        catch e
            push!(v, "$what: unexpected $(typeof(e)): $(first(split(sprint(showerror, e), '\n')))")
        end
        return nothing
    end
    function throws(f)
        try
            f()
            return nothing
        catch e
            return e
        end
    end
    clear!() = (empty!(mc.writes); empty!(mc.attempts); mc.failure = nothing; mc.reach = Inf)
    near(a, b) = isapprox(a, b; atol=atol, rtol=1e-9)

    step("light_off", () -> light_off(light))
    clear!()
    step("a level set while off", () -> set!(light))
    all(iszero, mc.writes) || push!(v, "a level set while the light was off reached the output: $(mc.writes)")

    clear!()
    step("light_on", () -> light_on(light))
    if isempty(mc.writes)
        push!(v, "light_on wrote nothing to the modulator (the light ignores its `modulator`)")
    else
        iszero(first(mc.writes)) || push!(v, "light_on's first write was $(first(mc.writes)), not level 0 before the enable")
        near(last(mc.writes), expect) || push!(v, "after light_on the modulator holds $(last(mc.writes)), expected $expect")
    end

    clear!()
    step("a level set while on", () -> set!(light))
    if isempty(mc.writes)
        push!(v, "a level set while the light was on did not reach the modulator")
    else
        near(last(mc.writes), expect) || push!(v, "a level set while on wrote $(last(mc.writes)), expected $expect")
    end

    clear!()
    mc.failure = ArgumentError("RecordingModulator: out of reach")
    e = throws(() -> set!(light))
    e isa ArgumentError || push!(v, "an ArgumentError from the modulator did not reach the caller (got $(repr(e)))")
    isempty(mc.writes) || push!(v, "after an ArgumentError from the modulator it wrote $(mc.writes), but it should change nothing")
    ison() === false && push!(v, "an ArgumentError from the modulator switched the light off; it should change nothing")

    clear!()
    mc.failure = ErrorException("RecordingModulator: transport failed")
    e = throws(() -> set!(light))
    e isa ErrorException || push!(v, "a non-ArgumentError throw from the modulator did not reach the caller (got $(repr(e)))")
    (!isempty(mc.attempts) && near(last(mc.attempts), 0.0)) || push!(v, "after a transport failure the light did not try level 0 (attempts $(mc.attempts))")
    ison() === true && push!(v, "after a transport failure the light is still on")

    clear!()
    step("light_off", () -> light_off(light))
    clear!()
    mc.failure = ErrorException("RecordingModulator: transport failed")
    e = throws(() -> light_on(light))
    e === nothing && push!(v, "light_on succeeded with a failing modulator")
    ison() === true && push!(v, "light_on with a failing modulator left the light on; a throw must enable nothing")
    e = throws(() -> light_off(light))
    e === nothing || push!(v, "light_off threw when the modulator's write failed ($(repr(e))); it must log and switch off")
    ison() === true && push!(v, "light_off with a failing modulator left the light on")

    # A level recorded while off that the modulator then refuses: light_on has already enabled, so it must darken.
    clear!()
    step("light_off", () -> light_off(light))
    clear!()
    step("a level set while off", () -> set!(light))
    mc.reach = 0.0
    e = throws(() -> light_on(light))
    e isa ArgumentError || push!(v, "light_on with a level the modulator refuses did not throw its ArgumentError (got $(repr(e)))")
    ison() === true && push!(v, "light_on left the light on after the modulator refused its level; an activation must darken on every throw")

    clear!()
    step("light_off", () -> light_off(light))
    clear!()
    return v
end
