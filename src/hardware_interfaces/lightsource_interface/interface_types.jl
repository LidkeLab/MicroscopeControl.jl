"""
`LightSource` is an abstract type that defines the interface for a light source.
"""
abstract type LightSource <: AbstractInstrument end

"""
    LightSourceProperties

Generic properties for a light source.

# Fields
- `power_unit::String`: The unit of the power of the light source.
- `power::Float64`: The current power of the light source.
- `is_on::Bool`: Whether the light source is on or off.
- `min_power::Float64`: The minimum power of the light source.
- `max_power::Float64`: The maximum power of the light source.
"""
mutable struct LightSourceProperties
    power_unit::String
    power::Float64
    is_on::Bool
    min_power::Float64
    max_power::Float64
end

"""
    DiodeLaser <: LightSource

A laser diode driven by a controller that REGULATES something: drive current,
or monitor photocurrent under photodiode feedback. Every `DiodeLaser` declares
which, as a type parameter fixed at construction; see [`RegulationMode`](@ref).

A light that is only modulated by an analogue voltage (`CrystaLaser`,
`VortranLaser`, `DaqTrLight`) is NOT a `DiodeLaser`. It has no controller, no
loop and no readback, and none of the generics in this file are defined for it.

A `DiodeLaser` carries, by name, the fields the shared panels and
[`setlevel!`](@ref) read: `unique_id`, `properties`, `min_current`,
`max_current`, `threshold_current`, `drive_current` and `pd`.

`[guarantee]` `setpower(laser, mA)` on a `ConstantCurrent` `DiodeLaser` forwards
to [`setcurrent!`](@ref) with a deprecation warning, and means what it always
did; the mode is a type parameter fixed at construction, so a forwarded call can
never change unit. On a `ConstantPhotocurrent` `DiodeLaser` it throws, and
[`setoutputpower!`](@ref) and the unit-free [`setlevel!`](@ref) replace it.

`[limitation]` `InteractiveUtils.subtypes` is one level deep, so
`subtypes(LightSource)` lists `DiodeLaser` and not the drivers beneath it. Walk
the hierarchy to its non-abstract leaves to enumerate devices.
"""
abstract type DiodeLaser <: LightSource end

"""
    RegulationMode

The quantity a [`DiodeLaser`](@ref)'s controller holds constant: a type, not a
flag, so that it is fixed per instance and can be dispatched on. The two modes
are [`ConstantCurrent`](@ref) and [`ConstantPhotocurrent`](@ref).
"""
abstract type RegulationMode end

"""
    ConstantCurrent <: RegulationMode

The loop holds the diode DRIVE CURRENT constant (open loop, in Thorlabs'
terms). Optical power follows diode efficiency, which drifts with temperature
and age. Commanded with [`setcurrent!`](@ref), in mA.
"""
struct ConstantCurrent <: RegulationMode end

"""
    ConstantPhotocurrent <: RegulationMode

The loop holds the MONITOR PHOTOCURRENT constant (closed loop, "constant power"
in Thorlabs' terms). Optical power follows photodiode responsivity, which is
temperature dependent: without a TEC-stabilised mount the delivered power
drifts against a still setpoint. Commanded with [`setoutputpower!`](@ref), in mW
at the laser output, through the calibration held in [`PhotodiodeLoop`](@ref).

There is deliberately no `ConstantPower`: the loop does not hold optical power
anywhere, and the name would say it did.
"""
struct ConstantPhotocurrent <: RegulationMode end

"""
    LOCK_CHECK_MIN_S

The shortest `lock_check_s` a [`PhotodiodeLoop`](@ref) accepts, in s: 0.1. The floor gives the
loop time to settle before `check_lock` reads; `check_lock` makes its own reads and does not
depend on polling. Below it the photodiode is read before the loop has answered a new setpoint. At 0, before 0.2.6, the lock check read the polled cache before the loop moved
and could never trip; with the two-sided check it would trip on every upward step.
"""
const LOCK_CHECK_MIN_S = 0.1

"""
    PhotodiodeLoop

State of a monitor-photodiode regulation loop. Present on a
[`ConstantPhotocurrent`](@ref) laser and on no other (`laser.pd === nothing`).

The loop regulates PHOTOCURRENT. `wa_calibration` converts photocurrent into a
power NUMBER at the LASER OUTPUT -- the plane where it was measured with a power
meter -- and it does not make the loop hold optical power anywhere. Without a
TEC-stabilised mount the photodiode's responsivity drifts with temperature, so
delivered power drifts while photocurrent is held steady. That is why
`tec_stabilised` has no default and may be `missing`.

# Fields
- `wa_calibration::Float64`: W/A at the laser output, rig-measured with a power
  meter. Conversion and display only.
- `tia_range::Float64`: A, full scale of the photodiode amplifier. The rig's
  STATEMENT of the controller's range setting (a rear-panel DIP switch on the
  TLD001); `initialize` throws if the controller disagrees.
- `tec_stabilised::Union{Bool,Missing}`: rig fact. `missing` is legitimate and
  is the only honest answer before it has been checked.
- `max_current_clamp::Float64`: mA. The drive-current clamp `initialize`
  programmed, as READ BACK from the controller, never as requested. `NaN` until
  `initialize` has programmed and verified it; a laser whose clamp is `NaN`
  refuses [`setoutputpower!`](@ref).
- `output_power_requested::Float64`: mW at the laser output, the last request
  [`setoutputpower!`](@ref) completed. `NaN` before the first.
- `photocurrent_requested::Float64`: A. The DECODED setpoint the loop was
  actually given, which the downward-rounding encoding makes differ from
  `output_power_requested / wa_calibration`. `NaN` before the first command.
- `ramp_step_mW::Float64`: `Inf` (the default) sends every setpoint as one
  write, ~10 ms. A finite value in mW makes the driver walk any larger upward
  step in increments of that size, `ramp_step_s` apart; downward steps are
  always one write. History (642 nm rig's TLD001, 2026-09-28/29): on one night
  a setpoint jumped from 0 to 10 mW locked the loop at ~90 mA / ~21 mW whatever
  the request, 3 times out of 3, while the same target reached in steps settled
  at 78 mA / 9.3 mW, as the Kinesis application does. Later the same night,
  after a Kinesis CONST P session, the jump worked 4 times out of 4 (9.30-9.31
  mW). Ramped runs never failed (10 of 10, 10-70 mW). The cause is not known.
  The jump is the default because it is the fastest and was reliable when last
  tested; if the lock recurs (the symptom: ~90 mA and ~21 mW whatever is
  requested) construct the laser with `ramp_step_mW = 3.0, ramp_step_s = 0.01`,
  which were verified on the rig: 1 mW steps worked at 2 s, 50, 20, 10 and 5 ms
  spacing; below ~10 ms the USB round trip per write (~15 ms) sets the pace; 3
  mW steps at 10 ms reached 40 mW in 0.22 s (38.74 mW) and 70 mW in 0.38 s
  (68.59 mW).
- `ramp_step_s::Float64`: seconds between ramp steps. Default `0.01`.
- `lock_check_s::Float64`: seconds the driver waits after sending a setpoint
  before it compares the measured photocurrent with the request. Default `0.2`;
  at least [`LOCK_CHECK_MIN_S`](@ref).
- `lock_ratio::Float64`: the measured photocurrent may exceed the request by
  this factor before the driver reports a suspected loop lock. Default `1.5`.
  `[limitation]` this threshold and wait are unvalidated on hardware: the one
  lock observed measured about 98 uA for 44.6 uA requested (2.2x). A false trip
  refuses, which is the safe direction.
- `ref_current_mA::Float64`, `ref_photocurrent_A::Float64`: the calibration
  reference. The open-loop drive current, and the photocurrent in A the controller
  read at it, decoded with the same `tia_range` as the config states, recorded in
  the same session and on the same range and gain as `wa_calibration`
  (CALIBRATION.md). With one, the first power-mode `light_on` after each
  `initialize` re-measures it and refuses on a mismatch. `NaN` (both) means none:
  that `light_on` warns once and `check_lock` is the only guard. The reference is
  in amps, decoded with `tia_range`, so a range the reading does not follow, or a
  `tia_range` relabelled with W/A kept (the 642 nm rig's observation of
  2026-09-29), fails the re-check. Re-measure W/A and the reference whenever the
  DIP switch moves.
- `ref_ratio::Float64`: the re-measured photocurrent must be within this factor
  of `ref_photocurrent_A`, either way. Default `1.5`: a 10x change in counts is
  caught with a wide margin, a scale drop under 1.5x passes, and the reading is
  proportional to (I - I_th), so a small margin above threshold is sensitive to
  ordinary drift. Choose the reference at least 20 mA above threshold.
- `scale_checked::Bool`: state, `true` once this initialize's re-check passed or
  was skipped for want of a reference.
- `scale_refused::Bool`: state, `true` once this initialize's re-check found a mismatch.
  Every later power-mode `light_on` refuses without lighting the diode until the next `initialize`.

Construct it with the keyword form, which fills the last twelve fields.
"""
mutable struct PhotodiodeLoop
    wa_calibration::Float64
    tia_range::Float64
    tec_stabilised::Union{Bool,Missing}
    max_current_clamp::Float64
    output_power_requested::Float64
    photocurrent_requested::Float64
    ramp_step_mW::Float64
    ramp_step_s::Float64
    lock_check_s::Float64
    lock_ratio::Float64
    ref_current_mA::Float64
    ref_photocurrent_A::Float64
    ref_ratio::Float64
    scale_checked::Bool
    scale_refused::Bool
end

"""
    PhotodiodeLoop(; wa_calibration, tia_range, tec_stabilised,
                   ramp_step_mW=Inf, ramp_step_s=0.01, lock_check_s=0.2, lock_ratio=1.5,
                   ref_current_mA=nothing, ref_photocurrent_A=nothing, ref_ratio=1.5)

The first three are required, and none has a default: a power-mode laser cannot
be built without a measured calibration, a stated amplifier range and an answer
(possibly `missing`) to whether the diode's temperature is stabilised. The rest
are documented on [`PhotodiodeLoop`](@ref).
"""
function PhotodiodeLoop(; wa_calibration::Real, tia_range::Real, tec_stabilised::Union{Bool,Missing},
                        ramp_step_mW::Real=Inf, ramp_step_s::Real=0.01,
                        lock_check_s::Real=0.2, lock_ratio::Real=1.5,
                        ref_current_mA::Union{Nothing,Real}=nothing,
                        ref_photocurrent_A::Union{Nothing,Real}=nothing, ref_ratio::Real=1.5)
    (isfinite(wa_calibration) && wa_calibration > 0) || throw(ArgumentError(
        "PhotodiodeLoop: wa_calibration is W/A measured at the laser output and must be finite and positive, got $(wa_calibration)"))
    (isfinite(tia_range) && tia_range > 0) || throw(ArgumentError(
        "PhotodiodeLoop: tia_range is the photodiode amplifier's full scale in A and must be finite and positive, got $(tia_range)"))
    ramp_step_mW > 0 || throw(ArgumentError("PhotodiodeLoop: ramp_step_mW must be positive (Inf for no ramp), got $(ramp_step_mW)"))
    (isfinite(ramp_step_s) && ramp_step_s >= 0) || throw(ArgumentError("PhotodiodeLoop: ramp_step_s must be finite and non-negative, got $(ramp_step_s)"))
    (isfinite(lock_check_s) && lock_check_s >= LOCK_CHECK_MIN_S) || throw(ArgumentError("PhotodiodeLoop: lock_check_s must be finite and at least $(LOCK_CHECK_MIN_S) s, got $(lock_check_s)"))
    (isfinite(lock_ratio) && lock_ratio > 1) || throw(ArgumentError("PhotodiodeLoop: lock_ratio must be finite and above 1, got $(lock_ratio)"))
    (ref_current_mA === nothing) == (ref_photocurrent_A === nothing) || throw(ArgumentError(
        "PhotodiodeLoop: ref_current_mA and ref_photocurrent_A are one calibration reference; give both or neither, got ref_current_mA = $(repr(ref_current_mA)), ref_photocurrent_A = $(repr(ref_photocurrent_A))"))
    if ref_current_mA !== nothing
        (isfinite(ref_current_mA) && ref_current_mA > 0) || throw(ArgumentError(
            "PhotodiodeLoop: ref_current_mA is the open-loop drive current of the calibration reference in mA and must be finite and positive, got $(ref_current_mA)"))
        (isfinite(ref_photocurrent_A) && 0 < ref_photocurrent_A <= tia_range) || throw(ArgumentError(
            "PhotodiodeLoop: ref_photocurrent_A is the photocurrent in A measured at ref_current_mA, decoded with tia_range, and must be finite with 0 < ref_photocurrent_A <= tia_range ($(tia_range) A), got $(ref_photocurrent_A)"))
    end
    (isfinite(ref_ratio) && ref_ratio > 1) || throw(ArgumentError("PhotodiodeLoop: ref_ratio must be finite and above 1, got $(ref_ratio)"))
    return PhotodiodeLoop(Float64(wa_calibration), Float64(tia_range), tec_stabilised, NaN, NaN, NaN,
                          Float64(ramp_step_mW), Float64(ramp_step_s), Float64(lock_check_s), Float64(lock_ratio),
                          ref_current_mA === nothing ? NaN : Float64(ref_current_mA),
                          ref_photocurrent_A === nothing ? NaN : Float64(ref_photocurrent_A),
                          Float64(ref_ratio), false, false)
end

