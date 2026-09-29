"""
    regulation_mode(laser::DiodeLaser)

The laser's [`RegulationMode`](@ref), as an instance: `ConstantCurrent()` or
`ConstantPhotocurrent()`. To ask "do I command power here", write
`regulation_mode(laser) isa ConstantPhotocurrent`.

There is no `LightSource` fallback: a light with no loop has no honest answer,
and "is this a regulated diode" is answered by `isa DiodeLaser`.
"""
regulation_mode(light::DiodeLaser) = regulation_mode(typeof(light))

function setlevel!(laser::DiodeLaser, frac::Float64)
    (isfinite(frac) && 0.0 <= frac <= 1.0) || throw(ArgumentError(
        "setlevel!: frac is a fraction of $(laser.unique_id)'s declared range and must be within [0, 1], got $(frac)"))
    return _setlevel(regulation_mode(laser), laser, frac)
end

_setlevel(::ConstantPhotocurrent, l::DiodeLaser, f::Float64) =
    setoutputpower!(l, l.properties.min_power + f * (l.properties.max_power - l.properties.min_power))
_setlevel(::ConstantCurrent, l::DiodeLaser, f::Float64) =
    setcurrent!(l, l.min_current + f * (effective_max_current(l) - l.min_current))

"""
    effective_max_current(laser::DiodeLaser)

The highest drive current, in mA, this laser will accept or report as the top
of its range: the ceiling [`setlevel!`](@ref) maps `frac = 1.0` to in
[`ConstantCurrent`](@ref) mode. The fallback is `laser.max_current`; a driver
that knows further ceilings (a controller limit, a DAC full scale) extends this
to the smallest of them.
"""
effective_max_current(laser::DiodeLaser) = laser.max_current

"""
    STATUS_BITS

The controller status-word layout the [`DiodeLaser`](@ref) drivers in this
package report, which is the Thorlabs TLD001's (`LD_GetStatusBits`, from the
Kinesis header): one definition, shared by the TCube driver and its simulated
twin so that [`loop_status`](@ref) reads the same from both.
"""
const STATUS_BITS = (
    output_enabled = 0x00000001,
    key = 0x00000002,
    closed_loop = 0x00000004,
    interlock = 0x00000008,
    tia_10uA = 0x00000010,
    tia_100uA = 0x00000020,
    tia_1mA = 0x00000040,
    tia_10mA = 0x00000080,
    saturated = 0x00000400,
    open_circuit = 0x00000800,
    psu_ok = 0x00001000,
    tia_over = 0x00002000,
    tia_under = 0x00004000,
)

"""
    TIA_RANGE_BITS

Photodiode amplifier range, in A of full scale, for each range bit of
[`STATUS_BITS`](@ref).
"""
const TIA_RANGE_BITS = (
    STATUS_BITS.tia_10uA => 10e-6,
    STATUS_BITS.tia_100uA => 100e-6,
    STATUS_BITS.tia_1mA => 1e-3,
    STATUS_BITS.tia_10mA => 10e-3,
)

"""
    tia_range_from_word(word)

The amplifier range in A that `word` reports, or `NaN` unless exactly one range
bit is set.
"""
function tia_range_from_word(word)
    w = UInt32(word)
    set = [range for (bit, range) in TIA_RANGE_BITS if w & bit != 0]
    return length(set) == 1 ? set[1] : NaN
end

"""
    status_snapshot(word, current_mA, photocurrent_A; threshold_current, commanded)

Build [`loop_status`](@ref)'s `NamedTuple` from a raw status word and the two
readings. `commanded` says whether a level has been commanded since the laser
was constructed, which the `below_threshold` check needs.
"""
function status_snapshot(word, current_mA::Float64, photocurrent_A::Float64;
                         threshold_current::Float64, commanded::Bool)
    w = UInt32(word)
    has(bit) = w & bit != 0
    output_enabled = has(STATUS_BITS.output_enabled)
    below_threshold = if isnan(threshold_current)
        missing
    else
        output_enabled && commanded && current_mA < threshold_current
    end
    return (
        word = w,
        output_enabled = output_enabled,
        key = has(STATUS_BITS.key),
        interlock = has(STATUS_BITS.interlock),
        closed_loop = has(STATUS_BITS.closed_loop),
        psu_ok = has(STATUS_BITS.psu_ok),
        # Only meaningful while the output is on: with the output OFF the rig's
        # TLD001 was seen to set 0x400 and report a drive current equal to its
        # limit after a potentiometer change (2026-09-28). The raw bit stays in `word`.
        saturated = output_enabled && has(STATUS_BITS.saturated),
        open_circuit = has(STATUS_BITS.open_circuit),
        # An over-range reading (decoded as Inf) counts as over range even if
        # the status bit is clear, as it was on the rig.
        tia_over = has(STATUS_BITS.tia_over) || photocurrent_A == Inf,
        tia_under = has(STATUS_BITS.tia_under),
        tia_range_A = tia_range_from_word(w),
        current_mA = current_mA,
        photocurrent_A = photocurrent_A,
        below_threshold = below_threshold,
    )
end

"""
    diode_loop_from_keywords(mode::RegulationMode, name; wa_calibration, tia_range,
        tec_stabilised, properties, max_current, ramp_step_mW, ramp_step_s,
        lock_check_s, lock_ratio)

The keyword rules a [`DiodeLaser`](@ref) constructor applies, in one place so
`TCubeLaser(serialNo; ...)` and `SimDiodeLaser(; ...)` cannot drift apart. Every
keyword is `nothing` when the caller did not pass it. In `ConstantPhotocurrent`
mode `wa_calibration`, `tia_range`, `tec_stabilised`, `properties` and
`max_current` are required and the [`PhotodiodeLoop`](@ref) is returned, built
from them and from whichever of the loop keywords (`ramp_step_mW`, `ramp_step_s`,
`lock_check_s`, `lock_ratio`) were passed. In any other mode passing a loop
keyword throws and `nothing` is returned. Throws `ArgumentError`s prefixed with
`name`.
"""
function diode_loop_from_keywords(mode::RegulationMode, name; wa_calibration, tia_range,
        tec_stabilised, properties, max_current, ramp_step_mW, ramp_step_s, lock_check_s, lock_ratio)
    if mode isa ConstantPhotocurrent
        absent = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                     :tec_stabilised => tec_stabilised, :properties => properties,
                                     :max_current => max_current) if v === nothing]
        isempty(absent) || throw(ArgumentError(
            "$name: a ConstantPhotocurrent laser needs these keywords, none of which has a default: $(join(absent, ", ")). " *
            "wa_calibration is W/A measured with a power meter at the laser output; tia_range is the rear-panel DIP switch in A; " *
            "tec_stabilised is true, false or missing; properties carries the enforced min_power/max_power in mW; " *
            "max_current is the clamp initialize programs into the controller, the only real protection in closed loop."))
        loop_kw = (; (kw => v for (kw, v) in (:ramp_step_mW => ramp_step_mW, :ramp_step_s => ramp_step_s,
                                              :lock_check_s => lock_check_s, :lock_ratio => lock_ratio) if v !== nothing)...)
        return PhotodiodeLoop(; wa_calibration=wa_calibration, tia_range=tia_range, tec_stabilised=tec_stabilised, loop_kw...)
    end
    given = [kw for (kw, v) in (:wa_calibration => wa_calibration, :tia_range => tia_range,
                                :tec_stabilised => tec_stabilised, :ramp_step_mW => ramp_step_mW,
                                :ramp_step_s => ramp_step_s, :lock_check_s => lock_check_s,
                                :lock_ratio => lock_ratio) if v !== nothing]
    isempty(given) || throw(ArgumentError(
        "$name: $(join(given, ", ")) describe a photodiode loop, which only a ConstantPhotocurrent laser has; " *
        "this one is $(nameof(typeof(mode)))"))
    return nothing
end

"""
    check_diode_config(M, pd, properties, max_current, name)

The construction-time invariants every [`DiodeLaser`](@ref) shares, for a
driver's inner constructor to call. Throws an `ArgumentError` naming the field
at fault:

- `pd` is a [`PhotodiodeLoop`](@ref) exactly when `M === ConstantPhotocurrent`;
- in that mode `properties.min_power`/`max_power` are the ENFORCED bounds of
  [`setoutputpower!`](@ref), so they must be finite with
  `0 <= min_power < max_power`, and `max_power` must fit the amplifier's full
  scale (`max_power / 1000 / wa_calibration <= tia_range`): a range the loop
  cannot reach is refused here rather than at the first command;
- in that mode `max_current` is finite and positive, because it becomes the
  clamp the loop is held under.
"""
function check_diode_config(::Type{M}, pd, properties, max_current::Float64, name) where {M<:RegulationMode}
    if M === ConstantPhotocurrent
        (isfinite(max_current) && max_current > 0) || throw(ArgumentError(
            "$name: max_current is the rig's drive-current ceiling in mA, which power mode programs as the loop's clamp; it must be finite and positive, got $(max_current)"))
        pd isa PhotodiodeLoop || throw(ArgumentError(
            "$name: a ConstantPhotocurrent laser needs a PhotodiodeLoop (wa_calibration, tia_range, tec_stabilised); got $(repr(pd))"))
        lo, hi = properties.min_power, properties.max_power
        (isfinite(lo) && isfinite(hi) && 0 <= lo < hi) || throw(ArgumentError(
            "$name: in ConstantPhotocurrent mode properties.min_power and max_power are the enforced output-power bounds in mW and must satisfy 0 <= min_power < max_power, got [$(lo), $(hi)]"))
        full_scale_mW = pd.tia_range * pd.wa_calibration * 1000
        hi <= full_scale_mW || throw(ArgumentError(
            "$name: properties.max_power = $(hi) mW needs more photocurrent than the amplifier's full scale: " *
            "tia_range = $(pd.tia_range) A x wa_calibration = $(pd.wa_calibration) W/A is $(full_scale_mW) mW. " *
            "Lower max_power, or select a less sensitive range on the controller (the TLD001's rear-panel DIP switch) and state it in tia_range."))
    else
        pd === nothing || throw(ArgumentError(
            "$name: only a ConstantPhotocurrent laser carries a PhotodiodeLoop; a $(nameof(M)) laser must have pd = nothing"))
    end
    return nothing
end
