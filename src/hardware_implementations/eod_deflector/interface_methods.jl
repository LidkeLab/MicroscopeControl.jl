# Everything an EOD does beyond a plain BeamSteerer comes from the high-voltage
# amplifier sitting between the DAQ and the crystal. These methods expose that second
# set of volts and keep the angle conversion honest about which of the two the
# calibration was measured against.

"""
    amplifier_factor(eod::EOD)

Crystal volts per DAQ volt, sign included: `amplifier_gain` for a non-inverting
amplifier and `-amplifier_gain` for an inverting one.
"""
amplifier_factor(eod::EOD) = eod.invert ? -eod.amplifier_gain : eod.amplifier_gain

"""
    tocrystal(eod::EOD, v_daq::Real)

The voltage across the crystal when the DAQ puts out `v_daq` volts.
"""
#     + 0.0 normalises the negative zero an inverting amplifier otherwise produces from a
#     commanded 0 V, which would show up as "-0.0 V" and be saved that way by export_state.
tocrystal(eod::EOD, v_daq::Real) = Float64(v_daq) * amplifier_factor(eod) + 0.0

"""
    todaq(eod::EOD, v_crystal::Real)

The DAQ output voltage needed to put `v_crystal` volts across the crystal.
"""
todaq(eod::EOD, v_crystal::Real) = Float64(v_crystal) / amplifier_factor(eod) + 0.0

"""
    crystal_limits(eod::EOD)

The device's voltage limits expressed across the crystal, as `((xmin, xmax), (ymin,
ymax))` in crystal volts. An inverting amplifier swaps each pair's ends, which is why
this is worth asking for rather than multiplying the DAQ limits by the gain yourself.
"""
function crystal_limits(eod::EOD)
    f = amplifier_factor(eod)
    pair(lims) = f >= 0 ? (lims[1] * f, lims[2] * f) : (lims[2] * f, lims[1] * f)
    return (pair(eod.xlimits), pair(eod.ylimits))
end

"""
    setcrystalvoltage(eod::EOD, vx::Real, vy::Real)

Drive the two crystals to `vx` and `vy` **volts across the crystal**, dividing by the
amplifier gain (and sign) to get the DAQ output that produces them.

Throws an `ArgumentError` without touching the hardware when the required DAQ voltage is
outside the device's limits; the message reports the crystal voltage asked for and the
DAQ voltage it worked out to.

# Arguments
- `eod::EOD`: The deflector.
- `vx::Real`: X-axis crystal voltage, volts.
- `vy::Real`: Y-axis crystal voltage, volts.
"""
function setcrystalvoltage(eod::EOD, vx::Real, vy::Real)
    dx, dy = todaq(eod, vx), todaq(eod, vy)
    try
        setvoltage(eod, dx, dy)
    catch e
        e isa ArgumentError || rethrow()
        throw(ArgumentError(
            "$(eod.unique_id): crystal voltage ($(vx), $(vy)) V needs " *
            "($(round(dx, digits=4)), $(round(dy, digits=4))) V out of the DAQ, " *
            "which is out of range. $(e.msg)"))
    end
    return nothing
end

"""
    getcrystalvoltage(eod::EOD)

The last commanded `(vx, vy)` in volts across the crystal.
"""
function getcrystalvoltage(eod::EOD)
    dx, dy = getvoltage(eod)
    return (tocrystal(eod, dx), tocrystal(eod, dy))
end

# ── Angle ────────────────────────────────────────────────────────────────────
# The generic setangle/getangle assume the calibration is in mrad per DAQ volt. When it
# was measured against the amplifier monitor instead — which is how the sweeps in
# dev/MINFLUX Project/ were analysed — the same matrix is in mrad per crystal volt, and
# using it unchanged would be wrong by the gain. `calibration_basis` picks which.

"""
    calibration_voltage(eod::EOD, vx::Real, vy::Real)

Convert a DAQ voltage pair into whichever voltage the calibration matrix is expressed
against, so the shared angle arithmetic can be applied to it.
"""
calibration_voltage(eod::EOD, vx::Real, vy::Real) =
    eod.calibration_basis === :crystal ? (tocrystal(eod, vx), tocrystal(eod, vy)) :
    (Float64(vx), Float64(vy))

"""
    daq_voltage(eod::EOD, vx::Real, vy::Real)

Inverse of [`calibration_voltage`](@ref): turn a voltage in the calibration's basis back
into the DAQ voltage that produces it.
"""
daq_voltage(eod::EOD, vx::Real, vy::Real) =
    eod.calibration_basis === :crystal ? (todaq(eod, vx), todaq(eod, vy)) :
    (Float64(vx), Float64(vy))

# Overriding this one conversion is all an EOD needs: `setangle` and the range check that
# `gridscan` runs before it moves both go through it, so both land on DAQ volts no matter
# which basis the calibration was measured in.
function BeamSteeringInterface.angle_setpoint_voltage(eod::EOD, ax::Real, ay::Real)
    cx, cy = angle_to_voltage(eod.calibration, ax, ay)
    return daq_voltage(eod, cx, cy)
end

function BeamSteeringInterface.getangle(eod::EOD)
    cx, cy = calibration_voltage(eod, eod.voltages[1], eod.voltages[2])
    return voltage_to_angle(eod.calibration, cx, cy)
end

# ── State ────────────────────────────────────────────────────────────────────

function MicroscopeControl.export_state(eod::EOD)
    attributes, data, children = invoke(export_state, Tuple{BeamSteerer}, eod)
    cx, cy = getcrystalvoltage(eod)
    attributes["amplifier_gain"] = eod.amplifier_gain
    attributes["amplifier_inverting"] = eod.invert
    attributes["calibration_basis"] = string(eod.calibration_basis)
    attributes["crystal_voltage_x"] = cx
    attributes["crystal_voltage_y"] = cy
    return attributes, data, children
end

function Base.show(io::IO, eod::EOD)
    dx, dy = getvoltage(eod)
    cx, cy = getcrystalvoltage(eod)
    state = eod.isopen ? "open" : "closed"
    print(io, "EOD(\"", eod.unique_id, "\", ", state,
        ", DAQ ", round(dx, digits=4), " V / ", round(dy, digits=4), " V",
        ", crystal ", round(cx, digits=2), " V / ", round(cy, digits=2), " V",
        ", backend ", typeof(eod.backend), ")")
end
