"""
    TriggerscopeModulator(; scope, dac, range, per_volt)

An [`AbstractModulationControl`](@ref) that drives a light's analogue input from one Triggerscope DAC. `range`
(`ZEROTOFIVE`, `ZEROTOTEN`, ...) is required: `initialize` sets it on the device (`setrange`), and `setpower`
refuses, with an `ArgumentError` before any write, a level whose voltage lies outside its span
([`dac_range_volts`](@ref)); it also refuses (`ErrorException`) once the scope's range for this DAC is no longer
`range`. `per_volt` is required and positive, in the light's unit per volt (mW/V in closed loop, mA/V in open
loop). Construction is pure.

Each write is a serial round trip plus twice `scope.compause`; `initialize` warns when `compause` is above
10 ms, because every level change then costs about `2 * compause`. The scope's port is the system's: opening
and closing it is not this type's business, and it must be open when this is initialized.

`[limitation]` The serial path has no test seam: the tests cover construction, the voltage arithmetic and the
range checks, and the writes are checked on the hardware.
"""
mutable struct TriggerscopeModulator <: AbstractModulationControl
    scope::Triggerscope4
    dac::Int
    range::Range
    per_volt::Float64
    is_open::Bool
end

function TriggerscopeModulator(; scope::Triggerscope4, dac::Integer, range::Range, per_volt::Real)
    1 <= dac <= scope.dacoutputs || throw(ArgumentError(
        "TriggerscopeModulator: DAC $dac does not exist (1..$(scope.dacoutputs))"))
    (isfinite(per_volt) && per_volt > 0) || throw(ArgumentError(
        "TriggerscopeModulator: per_volt is the light's unit per volt and must be finite and positive, got $(per_volt)"))
    return TriggerscopeModulator(scope, Int(dac), range, Float64(per_volt), false)
end

# Open means the DAC is this modulator's to zero: a failed re-initialize keeps its claim.
holds_resources(m::TriggerscopeModulator) = m.is_open

output_id(m::TriggerscopeModulator) = dac_output_id(m.scope, m.dac)

"The voltage `setpower(m, p)` writes; `ArgumentError` when `p` is not a finite level of at least 0 or has no voltage this DAC range can make."
function volts(m::TriggerscopeModulator, p::Float64)
    (isfinite(p) && p >= 0) || throw(ArgumentError(
        "TriggerscopeModulator DAC $(m.dac): a level is finite and at least 0 (0 is 0 V), got $p"))
    v = p / m.per_volt
    lo, hi = dac_range_volts(m.range)
    (isfinite(v) && lo <= v <= hi) || throw(ArgumentError(
        "TriggerscopeModulator DAC $(m.dac): level $p needs $v V ($(m.per_volt) per V), outside the range $(m.range) [$lo, $hi] V"))
    return v
end

"Warn when every DAC write costs more than ~20 ms of `compause`."
function check_compause(m::TriggerscopeModulator)
    m.scope.compause > 0.01 && @warn "Triggerscope $(m.scope.portname): compause = $(m.scope.compause) s makes every DAC write cost about $(2 * m.scope.compause) s; set scope.compause = 0 for fast use"
    return nothing
end

# The checks, the conversion and the command run under the scope's lock (reentrant), so another task cannot change the
# DAC's range between the check and the encoding.
function setpower(m::TriggerscopeModulator, p::Float64)
    lock(m.scope.lock) do
        v = volts(m, p)
        m.is_open || error("TriggerscopeModulator DAC $(m.dac): setpower before initialize (or after shutdown)")
        m.scope.dacranges[m.dac] == m.range || error(
            "TriggerscopeModulator DAC $(m.dac): the scope's range for this DAC is $(m.scope.dacranges[m.dac]), not $(m.range); the voltage would not be the one computed")
        setdac(m.scope, m.dac, v)
    end
    return nothing
end

function initialize(m::TriggerscopeModulator)
    check_compause(m)
    setrange(m.scope, m.dac, m.range)
    setdac(m.scope, m.dac, 0.0)
    m.is_open = true
    return nothing
end

function shutdown(m::TriggerscopeModulator)
    m.is_open || return nothing
    lock(m.scope.lock) do
        # 0 V must be encoded for this modulator's range: put it back if it moved or became unknown.
        (m.dac in m.scope.range_unknown || m.scope.dacranges[m.dac] != m.range) && setrange(m.scope, m.dac, m.range)
        setdac(m.scope, m.dac, 0.0)
    end
    m.is_open = false
    return nothing
end

function export_state(m::TriggerscopeModulator)
    attributes = Dict{String,Any}("modulator_type" => "TriggerscopeModulator", "output_id" => output_id(m),
        "dac" => m.dac, "range" => string(m.range), "per_volt" => m.per_volt)
    return attributes, nothing, Dict{String,Any}()
end
