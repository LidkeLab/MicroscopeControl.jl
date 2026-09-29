"""
    SimulatedDiodeLaser

A simulated twin of a regulated laser diode, [`SimDiodeLaser`](@ref), on the same
abstract type as the hardware driver, so a system field typed `::DiodeLaser`
accepts either.
"""
module SimulatedDiodeLaser

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: effective_max_current, STATUS_BITS

import ...MicroscopeControl: export_state, initialize, shutdown

export SimDiodeLaser

"""
    SimDiodeLaser{M<:RegulationMode} <: DiodeLaser

A simulated laser diode on a TLD001-like controller, in either mode. It carries
the field names the shared panels and `setlevel!` read (`unique_id`,
`properties`, `min_current`, `max_current`, `threshold_current`,
`drive_current`, `pd`), reports the same [`loop_status`](@ref) layout as
`TCubeLaser`, throws on every command and read before `initialize` and after
`shutdown` (leaving every `*_requested` field unchanged), and records each call
in `log` as a `(verb, value)` tuple -- reads as well as commands, so a test can
assert that something issued neither.

The diode model is three lines of physics, and is the point of the type:

    P_true       = efficiency * max(0, I - threshold_current)     # mW at the laser output
    photocurrent = responsivity * (1 + responsivity_drift) * P_true / 1000   # A
    loop         : I rises until photocurrent reaches the setpoint, or I reaches the clamp

In `ConstantCurrent` mode `I` is the commanded current, limited by the clamp. In
`ConstantPhotocurrent` mode the loop settles instantly. [`true_output_power`](@ref)
returns `P_true`: the test oracle, on the simulation only, never an interface
generic.

# Model and fault fields
- `efficiency` (mW/mA above threshold), `responsivity` (A/W at the monitor
  photodiode; defaults to `1 / wa_calibration`, so the calibration starts true),
  `responsivity_drift` (fractional; nonzero models a warming photodiode whose
  photocurrent the loop still holds while the light moves).
- `tia_range_A`: the simulated rear-panel DIP switch, in A. Defaults to the
  stated `pd.tia_range` (or 1 mA); set it differently to model a moved switch.
- `key`, `interlock`: the two interlocks `initialize` checks in power mode.
- `pd_blocked`: the photodiode sees nothing, so the loop drives the current
  straight to the clamp.
- `tia_over_fault`, `tia_under_fault`: force the amplifier flags.
- `settle_s`: real `sleep` after each command.
"""
mutable struct SimDiodeLaser{M<:RegulationMode} <: DiodeLaser
    unique_id::String
    properties::LightSourceProperties
    min_current::Float64
    max_current::Float64
    threshold_current::Float64
    drive_current::Float64
    pd::Union{Nothing,PhotodiodeLoop}
    efficiency::Float64
    responsivity::Float64
    responsivity_drift::Float64
    tia_range_A::Float64
    key::Bool
    interlock::Bool
    pd_blocked::Bool
    tia_over_fault::Bool
    tia_under_fault::Bool
    settle_s::Float64
    is_open::Bool
    output_enabled::Bool
    setpoint::Float64
    clamp_mA::Float64
    log::Vector{Tuple{Symbol,Any}}

    function SimDiodeLaser{M}(unique_id, properties, min_current, max_current, threshold_current,
        drive_current, pd, efficiency, responsivity, responsivity_drift, tia_range_A, key, interlock,
        pd_blocked, tia_over_fault, tia_under_fault, settle_s) where {M<:RegulationMode}
        M in supported_modes(SimDiodeLaser) || throw(ArgumentError("SimDiodeLaser: mode $(M) is not supported"))
        LightSourceInterface.check_diode_config(M, pd, properties, Float64(max_current), "SimDiodeLaser $unique_id")
        new{M}(unique_id, properties, min_current, max_current, threshold_current, drive_current, pd,
            efficiency, responsivity, responsivity_drift, tia_range_A, key, interlock,
            pd_blocked, tia_over_fault, tia_under_fault, settle_s,
            false, false, 0.0, max_current, Tuple{Symbol,Any}[])
    end
end

LightSourceInterface.supported_modes(::Type{<:SimDiodeLaser}) = (ConstantCurrent, ConstantPhotocurrent)
LightSourceInterface.regulation_mode(::Type{SimDiodeLaser{M}}) where {M} = M()

"""
    SimDiodeLaser(; mode = ConstantCurrent(), kwargs...)

Constructed exactly as [`TCubeLaser`](@ref) is, so that one construction line
serves a system and its simulated twin. `mode` defaults to `ConstantCurrent()`.
In `ConstantPhotocurrent` mode `wa_calibration`, `tia_range`, `tec_stabilised`,
`properties` and `max_current` are required, and the loop keywords `ramp_step_mW`,
`ramp_step_s`, `lock_check_s` and `lock_ratio` are accepted into the
[`PhotodiodeLoop`](@ref). `[limitation]` the simulation neither ramps nor
checks for a loop lock; it only stores them. `threshold_current` defaults to
65 mA and, in `ConstantCurrent` mode, `max_current` to 160 mA (the 642 nm
diode's numbers); the model fields are documented on the type.

Unlike `TCubeLaser`, whose default `properties` are 0.2.4's `"mW"` labels, the
default `properties` here are labelled `"mA"`: this type is new, has no 0.2.x
behaviour to keep, and its values are mA.
"""
function SimDiodeLaser(;
    mode::RegulationMode=ConstantCurrent(),
    unique_id::String="SimDiodeLaser",
    properties::Union{Nothing,LightSourceProperties}=nothing,
    min_current::Float64=0.0,
    max_current::Union{Nothing,Float64}=nothing,
    threshold_current::Float64=65.0,
    wa_calibration::Union{Nothing,Real}=nothing,
    tia_range::Union{Nothing,Real}=nothing,
    tec_stabilised::Union{Nothing,Bool,Missing}=nothing,
    ramp_step_mW::Union{Nothing,Real}=nothing,
    ramp_step_s::Union{Nothing,Real}=nothing,
    lock_check_s::Union{Nothing,Real}=nothing,
    lock_ratio::Union{Nothing,Real}=nothing,
    efficiency::Float64=1.2,
    responsivity::Union{Nothing,Float64}=nothing,
    responsivity_drift::Float64=0.0,
    tia_range_A::Union{Nothing,Float64}=nothing,
    key::Bool=true,
    interlock::Bool=true,
    pd_blocked::Bool=false,
    settle_s::Float64=0.0,
)
    pd = if mode isa ConstantPhotocurrent
        absent = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                     :tec_stabilised => tec_stabilised, :properties => properties,
                                     :max_current => max_current) if v === nothing]
        isempty(absent) || throw(ArgumentError(
            "SimDiodeLaser: a ConstantPhotocurrent laser needs these keywords, none of which has a default: $(join(absent, ", "))"))
        loopkw = (; (k => v for (k, v) in (:ramp_step_mW => ramp_step_mW, :ramp_step_s => ramp_step_s,
                   :lock_check_s => lock_check_s, :lock_ratio => lock_ratio) if v !== nothing)...)
        PhotodiodeLoop(; wa_calibration=wa_calibration, tia_range=tia_range, tec_stabilised=tec_stabilised, loopkw...)
    else
        any(!isnothing, (wa_calibration, tia_range, tec_stabilised, ramp_step_mW, ramp_step_s, lock_check_s, lock_ratio)) &&
            throw(ArgumentError("SimDiodeLaser: wa_calibration, tia_range, tec_stabilised and the ramp and lock keywords " *
                                "describe a photodiode loop, which only a ConstantPhotocurrent laser has"))
        nothing
    end
    max_current = something(max_current, 160.0)
    props = something(properties, LightSourceProperties("mA", 0.0, false, min_current, max_current))
    resp = something(responsivity, pd === nothing ? 1 / 224.2 : 1 / pd.wa_calibration)
    range = something(tia_range_A, pd === nothing ? 1e-3 : pd.tia_range)
    SimDiodeLaser{typeof(mode)}(unique_id, props, min_current, max_current, threshold_current,
        NaN, pd, efficiency, resp, responsivity_drift, range, key, interlock,
        pd_blocked, false, false, settle_s)
end

# --- the model ------------------------------------------------------------

_responsivity(sim::SimDiodeLaser) = sim.pd_blocked ? 0.0 : sim.responsivity * (1 + sim.responsivity_drift)

"Drive current in mA the simulated controller is passing."
function _current(sim::SimDiodeLaser{ConstantCurrent})
    sim.output_enabled || return 0.0
    return min(sim.setpoint, sim.clamp_mA)
end

function _current(sim::SimDiodeLaser{ConstantPhotocurrent})
    (sim.output_enabled && sim.setpoint > 0) || return 0.0
    r = _responsivity(sim)
    r > 0 || return sim.clamp_mA                        # nothing to regulate on: straight to the clamp
    needed = sim.threshold_current + sim.setpoint / r * 1000 / sim.efficiency
    return min(needed, sim.clamp_mA)
end

_true_power(sim::SimDiodeLaser) = sim.efficiency * max(0.0, _current(sim) - sim.threshold_current)
_photocurrent(sim::SimDiodeLaser) = _responsivity(sim) * _true_power(sim) / 1000

function _saturated(sim::SimDiodeLaser{ConstantCurrent})
    sim.output_enabled && sim.setpoint >= sim.clamp_mA
end
function _saturated(sim::SimDiodeLaser{ConstantPhotocurrent})
    sim.output_enabled && sim.setpoint > 0 && _current(sim) >= sim.clamp_mA &&
        _photocurrent(sim) < sim.setpoint
end

function _status_word(sim::SimDiodeLaser)
    w = UInt32(0)
    set(bit, on) = on ? (w |= bit) : w
    set(STATUS_BITS.output_enabled, sim.output_enabled)
    set(STATUS_BITS.key, sim.key)
    set(STATUS_BITS.interlock, sim.interlock)
    set(STATUS_BITS.closed_loop, regulation_mode(sim) isa ConstantPhotocurrent && sim.is_open)
    set(STATUS_BITS.psu_ok, true)
    for (bit, range) in LightSourceInterface.TIA_RANGE_BITS
        set(bit, isapprox(range, sim.tia_range_A; rtol=1e-9))
    end
    set(STATUS_BITS.saturated, _saturated(sim))
    set(STATUS_BITS.tia_over, sim.tia_over_fault || _photocurrent(sim) > sim.tia_range_A)
    set(STATUS_BITS.tia_under, sim.tia_under_fault)
    return w
end

"""
    true_output_power(sim::SimDiodeLaser)

The simulated optical power at the laser output, in mW: the model's ground
truth, which no driver can report. A test oracle only, not an interface
generic -- compare it with `indicated_output_power` to see what the
calibration does and does not guarantee.
"""
true_output_power(sim::SimDiodeLaser) = _true_power(sim)

# --- lifecycle and commands ------------------------------------------------

function _require_open(sim::SimDiodeLaser, op)
    sim.is_open || error("SimDiodeLaser $(sim.unique_id): $op refused: not initialized (or already shut down)")
    return nothing
end

function _require_clamp(sim::SimDiodeLaser, op)
    regulation_mode(sim) isa ConstantPhotocurrent && isnan(sim.pd.max_current_clamp) && error(
        "SimDiodeLaser $(sim.unique_id): $op refused: the max-current clamp has not been programmed")
    return nothing
end

_settle(sim::SimDiodeLaser) = sim.settle_s > 0 && sleep(sim.settle_s)

function initialize(sim::SimDiodeLaser)
    push!(sim.log, (:initialize, nothing))
    if regulation_mode(sim) isa ConstantPhotocurrent
        missing_bits = [label for (label, ok) in (("key switch", sim.key), ("interlock", sim.interlock)) if !ok]
        isempty(missing_bits) || error("SimDiodeLaser $(sim.unique_id): refusing closed loop: $(join(missing_bits, " and ")) not set")
        isapprox(sim.tia_range_A, sim.pd.tia_range; rtol=1e-9) || error(
            "SimDiodeLaser $(sim.unique_id): refusing closed loop: the controller's photodiode range is $(sim.tia_range_A) A but tia_range states $(sim.pd.tia_range) A")
        sim.clamp_mA = sim.max_current
        sim.pd.max_current_clamp = sim.clamp_mA
    end
    sim.output_enabled = false
    sim.properties.is_on = false
    sim.setpoint = 0.0
    sim.is_open = true
    return nothing
end

function shutdown(sim::SimDiodeLaser)
    push!(sim.log, (:shutdown, nothing))
    sim.output_enabled = false
    sim.properties.is_on = false
    sim.is_open = false
    return nothing
end

function LightSourceInterface.light_on(sim::SimDiodeLaser)
    push!(sim.log, (:light_on, nothing))
    _require_open(sim, "light_on")
    _require_clamp(sim, "light_on")
    sim.output_enabled = true
    sim.properties.is_on = true
    _settle(sim)
    return nothing
end

function LightSourceInterface.light_off(sim::SimDiodeLaser)
    push!(sim.log, (:light_off, nothing))
    _require_open(sim, "light_off")
    sim.output_enabled = false
    sim.properties.is_on = false
    return nothing
end

function LightSourceInterface.setcurrent!(sim::SimDiodeLaser{ConstantCurrent}, current::Float64)
    push!(sim.log, (:setcurrent!, current))
    _require_open(sim, "setcurrent!")
    hi = effective_max_current(sim)
    (isfinite(current) && sim.min_current <= current <= hi) || throw(ArgumentError(
        "SimDiodeLaser $(sim.unique_id): requested current $(current) mA is outside the allowed range [$(sim.min_current), $(hi)] mA"))
    sim.setpoint = current
    sim.drive_current = current
    _settle(sim)
    return nothing
end

function LightSourceInterface.setoutputpower!(sim::SimDiodeLaser{ConstantPhotocurrent}, power_mW::Float64)
    push!(sim.log, (:setoutputpower!, power_mW))
    _require_open(sim, "setoutputpower!")
    _require_clamp(sim, "setoutputpower!")
    lo, hi = sim.properties.min_power, sim.properties.max_power
    (isfinite(power_mW) && lo <= power_mW <= hi) || throw(ArgumentError(
        "SimDiodeLaser $(sim.unique_id): requested output power $(power_mW) mW is outside the allowed range [$(lo), $(hi)] mW"))
    word = _status_word(sim)
    word & STATUS_BITS.tia_over != 0 && error(
        "SimDiodeLaser $(sim.unique_id): setoutputpower! refused: the photodiode amplifier reports OVER range")
    (word & STATUS_BITS.tia_under != 0 && sim.output_enabled) && error(
        "SimDiodeLaser $(sim.unique_id): setoutputpower! refused: the photodiode amplifier reports UNDER range with the output on")
    pd = sim.pd
    i_pd = power_mW / 1000 / pd.wa_calibration
    i_pd <= pd.tia_range || throw(ArgumentError(
        "SimDiodeLaser $(sim.unique_id): $(i_pd) A of photocurrent is above the amplifier's full scale of $(pd.tia_range) A"))
    # The same 15-bit, round-down encoding as the TLD001, so the decoded
    # setpoint differs from the request exactly as it does on hardware.
    code = floor(i_pd / pd.tia_range * 32767)
    while code > 0 && code / 32767 * pd.tia_range > i_pd
        code -= 1
    end
    sim.setpoint = code / 32767 * pd.tia_range
    pd.output_power_requested = power_mW
    pd.photocurrent_requested = sim.setpoint
    _settle(sim)
    return nothing
end

# --- readbacks ---------------------------------------------------------------

function LightSourceInterface.measured_current(sim::SimDiodeLaser)
    push!(sim.log, (:read, :measured_current))
    _require_open(sim, "measured_current")
    return _current(sim)
end

function LightSourceInterface.measured_photocurrent(sim::SimDiodeLaser)
    push!(sim.log, (:read, :measured_photocurrent))
    _require_open(sim, "measured_photocurrent")
    return min(_photocurrent(sim), sim.tia_range_A)
end

function LightSourceInterface.indicated_output_power(sim::SimDiodeLaser{ConstantPhotocurrent})
    return measured_photocurrent(sim) * sim.pd.wa_calibration * 1000
end

function LightSourceInterface.loop_status(sim::SimDiodeLaser)
    push!(sim.log, (:read, :loop_status))
    _require_open(sim, "loop_status")
    commanded = regulation_mode(sim) isa ConstantPhotocurrent ? !isnan(sim.pd.output_power_requested) :
                !isnan(sim.drive_current)
    return LightSourceInterface.status_snapshot(_status_word(sim), _current(sim),
        min(_photocurrent(sim), sim.tia_range_A);
        threshold_current=sim.threshold_current, commanded=commanded)
end

"""
    export_state(sim::SimDiodeLaser)

The same attribute names as `export_state(::TCubeLaser)`, from field reads only.
"""
function export_state(sim::SimDiodeLaser)
    mode = regulation_mode(sim)
    attributes = Dict{String,Any}(
        "unique_id" => sim.unique_id,
        "regulation_mode" => string(nameof(typeof(mode))),
        "setpoint_unit" => mode isa ConstantPhotocurrent ? "mW" : "mA",
        "min_current_mA" => sim.min_current, "max_current_mA" => sim.max_current,
        "threshold_current_mA" => sim.threshold_current,
        "drive_current" => sim.drive_current,
        "is_on" => sim.properties.is_on,
    )
    if mode isa ConstantPhotocurrent
        pd = sim.pd
        merge!(attributes, Dict{String,Any}(
            "power_reference" => "laser output",
            "min_output_power_mW" => sim.properties.min_power,
            "max_output_power_mW" => sim.properties.max_power,
            "wa_calibration_W_per_A" => pd.wa_calibration,
            "tia_range_A" => pd.tia_range,
            "tec_stabilised" => pd.tec_stabilised === missing ? "unknown" : string(pd.tec_stabilised),
            "max_current_clamp_mA" => pd.max_current_clamp,
            "output_power_requested_mW" => pd.output_power_requested,
            "photocurrent_requested_A" => pd.photocurrent_requested,
        ))
    end
    return attributes, nothing, Dict{String,Any}()
end

end
