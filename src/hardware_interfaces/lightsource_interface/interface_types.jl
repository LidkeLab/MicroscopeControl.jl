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

`[guarantee]` `setpower` is not defined for any `DiodeLaser`: its unit changed
with the regulation mode, so it is replaced by [`setcurrent!`](@ref),
[`setoutputpower!`](@ref) and the unit-free [`setlevel!`](@ref).

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

Construct it with the keyword form, which fills the last three fields.
"""
mutable struct PhotodiodeLoop
    wa_calibration::Float64
    tia_range::Float64
    tec_stabilised::Union{Bool,Missing}
    max_current_clamp::Float64
    output_power_requested::Float64
    photocurrent_requested::Float64
end

"""
    PhotodiodeLoop(; wa_calibration, tia_range, tec_stabilised)

All three are required, and none has a default: a power-mode laser cannot be
built without a measured calibration, a stated amplifier range and an answer
(possibly `missing`) to whether the diode's temperature is stabilised.
"""
function PhotodiodeLoop(; wa_calibration::Real, tia_range::Real, tec_stabilised::Union{Bool,Missing})
    (isfinite(wa_calibration) && wa_calibration > 0) || throw(ArgumentError(
        "PhotodiodeLoop: wa_calibration is W/A measured at the laser output and must be finite and positive, got $(wa_calibration)"))
    (isfinite(tia_range) && tia_range > 0) || throw(ArgumentError(
        "PhotodiodeLoop: tia_range is the photodiode amplifier's full scale in A and must be finite and positive, got $(tia_range)"))
    return PhotodiodeLoop(Float64(wa_calibration), Float64(tia_range), tec_stabilised, NaN, NaN, NaN)
end

