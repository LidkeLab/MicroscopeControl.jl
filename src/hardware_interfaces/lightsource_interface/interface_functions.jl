
"""
    setpower(lightsource::LightSource,power::Float64)

Set the power of the lightsource.

# Arguments
- `lightsource::LightSource`: A LightSource type.
- `power::Float64`: The power to set the lightsource to.
"""
function setpower(lightsource::LightSource, power::Float64)
    # set the power of the lightsource
    error("setpower not implemented for $(typeof(lightsource))")
end

"""
    light_on(lightsource::LightSource)

Turn on the light source.

The stub used to take a second `ipower::Float64` argument that no driver
implemented. It was removed in 0.2.5 rather than implemented: "on at a power"
has no definable unit across lights, so it is two checkable calls -- set the
level, then `light_on`.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function light_on(lightsource::LightSource)
    # turn on the lightsource
    error("light_on not implemented for $(typeof(lightsource))")
end

"""
    light_off(lightsource::LightSource)

Turn off the light source.

# Arguments
- `lightsource::LightSource`: A LightSource type.
"""
function light_off(lightsource::LightSource)
    # turn off the lightsource
    error("light_off not implemented for $(typeof(lightsource))")
end

"""
    setpower(laser::DiodeLaser, x::Float64)

Deprecated for a [`ConstantCurrent`](@ref) laser, where it forwards to
[`setcurrent!`](@ref) (`x` in mA, as it always was on a TCube) and warns. The
mode is a type parameter fixed at construction, so a forwarded call can never
change unit. It throws for a [`ConstantPhotocurrent`](@ref) laser: an mA call
must not become an mW one, so use [`setoutputpower!`](@ref) there, or the
unit-free [`setlevel!`](@ref) on either.
"""
function setpower(laser::DiodeLaser, x::Float64)
    if regulation_mode(laser) isa ConstantCurrent
        Base.depwarn("setpower(laser, mA) on a $(nameof(typeof(laser))) is deprecated; use setcurrent!(laser, mA), or setlevel!(laser, frac)", :setpower)
        return setcurrent!(laser, x)
    end
    error("setpower is not defined for $(typeof(laser)): it took mA on this driver while its name said mW. " *
          "Use setoutputpower!(laser, mW) on a ConstantPhotocurrent laser, or the unit-free setlevel!(laser, frac) " *
          "on either. This laser is $(nameof(typeof(regulation_mode(laser)))).")
end

"""
    supported_modes(::Type{<:DiodeLaser})

The concrete [`RegulationMode`](@ref) types this device may be constructed in,
as a tuple of types. The contract test expands a parametric device into its
instantiations through this -- a type parameter cannot be enumerated any other
way -- and a driver's inner constructor rejects a mode absent from it.
"""
supported_modes(::Type{<:DiodeLaser}) = ()

"""
    setcurrent!(laser::DiodeLaser, current_mA::Float64)

Command the diode DRIVE CURRENT, in mA. Defined only for
[`ConstantCurrent`](@ref) lasers: where a loop owns the current this has no
meaning, and the interface stub throws.
"""
function setcurrent!(laser::DiodeLaser, current_mA::Float64)
    error("setcurrent! not implemented for $(typeof(laser))")
end

"""
    setoutputpower!(laser::DiodeLaser, power_mW::Float64)

Command the optical power **at the laser output**, in mW -- the plane where the
`wa_calibration` of [`PhotodiodeLoop`](@ref) was measured with a power meter.

This is NOT power at the sample. Everything between the laser output and the
sample -- splitters, attenuators, fibres, objectives -- belongs to the system
that owns those parts, and no driver holds a field describing any of it.

Defined only for [`ConstantPhotocurrent`](@ref) lasers, where the number is the
driver's own arithmetic over the photodiode calibration: a command, not a
measurement.
"""
function setoutputpower!(laser::DiodeLaser, power_mW::Float64)
    error("setoutputpower! not implemented for $(typeof(laser))")
end

"""
    setlevel!(light::LightSource, frac::Float64)

Set the light to `frac` of its own declared operating range, `frac` in `0..1`.
Unit-free BY CONSTRUCTION: the endpoints come from the device, so no caller
names a unit it cannot check.

For a [`DiodeLaser`](@ref) the mapping is LINEAR IN THE REGULATED QUANTITY:

- [`ConstantCurrent`](@ref): `min_current + frac * (effective_max_current - min_current)` mA,
  through [`setcurrent!`](@ref);
- [`ConstantPhotocurrent`](@ref): `min_power + frac * (max_power - min_power)` mW
  at the laser output, from `properties`, through [`setoutputpower!`](@ref).
  The mW-to-photocurrent conversion is linear, so this is linear in the
  regulated photocurrent too.

`frac = 0.0` is the bottom of the declared range, which is NOT off: use
`light_off`. Code that must survive a switch between the two modes should drive
the laser through this, not through the unit-true setters.

`[limitation]` Methods ship only for `DiodeLaser`. The voltage-modulated lights
have no `setlevel!` method yet, and this stub throws for them.
"""
function setlevel!(light::LightSource, frac::Float64)
    error("setlevel! not implemented for $(typeof(light))")
end

"""
    measured_current(laser::DiodeLaser)

The diode drive current the controller reports, in mA. A reading, not a
request. In [`ConstantPhotocurrent`](@ref) mode it is **the diagnostic**: a drive
current climbing at a still setpoint is a blocked photodiode or an ageing diode.
"""
function measured_current(laser::DiodeLaser)
    error("measured_current not implemented for $(typeof(laser))")
end

"""
    measured_photocurrent(laser::DiodeLaser)

The monitor photodiode current the controller reports, in A. The regulated
quantity in [`ConstantPhotocurrent`](@ref) mode.
"""
function measured_photocurrent(laser::DiodeLaser)
    error("measured_photocurrent not implemented for $(typeof(laser))")
end

"""
    indicated_output_power(laser::DiodeLaser)

`measured_photocurrent x wa_calibration`, in mW at the laser output. The inverse
of [`setoutputpower!`](@ref)'s conversion, so a caller never recomputes it.

It is INDICATED, not measured: a conversion through a one-time bench
calibration. With a drifting photodiode responsivity it stays flat while the
light moves. Defined only for [`ConstantPhotocurrent`](@ref) lasers.
"""
function indicated_output_power(laser::DiodeLaser)
    error("indicated_output_power not implemented for $(typeof(laser))")
end

"""
    loop_status(laser::DiodeLaser)

One consistent snapshot of the controller, as a `NamedTuple`:

- `word::UInt32`: the raw status word;
- `output_enabled`, `key`, `interlock`, `closed_loop`, `psu_ok`: `Bool`;
- `current_mA`: `[limitation]` with the output OFF this is not a measurement: the
  642 nm rig's TLD001 reported a "drive current" equal to its limit after a
  potentiometer change, with no current flowing (2026-09-28).
- `saturated::Bool`: the drive current is at its limit (bit `0x400`), reported
  only while the output is enabled (the raw bit is still in `word`). In
  [`ConstantPhotocurrent`](@ref) mode this means *the loop is at the clamp and
  the power is not being held*;
- `open_circuit`, `tia_over`, `tia_under`: `Bool`. Either TIA flag invalidates
  the photocurrent reading;
- `tia_range_A::Float64`: the amplifier range the controller reports, `NaN`
  unless exactly one range bit is set;
- `current_mA::Float64`, `photocurrent_A::Float64`: the two readings;
- `below_threshold::Union{Bool,Missing}`: `true` when the output is enabled, a
  level has been commanded and the drive current sits below the declared
  `threshold_current`, i.e. the diode is not lasing and every power number is
  junk -- a fault distinct from `saturated`. `false` when the output is off or
  nothing has been commanded. `missing` when `threshold_current` is unknown
  (`NaN`): a skipped check must not read as a passed one.

It is the only place the status bits are decoded, so panels, fault checks and a
rig's logger share one definition. `[policy]` a rig running unattended polls
this and treats a sustained `saturated` as a fault: the driver reports, the
system decides. The TCube driver also refuses at each power-mode setpoint when `0x400`
is set (`check_lock`, 0.2.6); after that check, nothing watches it.
"""
function loop_status(laser::DiodeLaser)
    error("loop_status not implemented for $(typeof(laser))")
end

