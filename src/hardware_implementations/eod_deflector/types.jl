"""
    EOD(backend; kwargs...)

A two-axis electro-optic deflector: a pair of EOD crystals, each fed by a high-voltage
amplifier that is in turn driven by one analog output of the backend.

An EOD is a `BeamSteerer`, so it gets `setvoltage`, `setangle`, `gridscan` and the rest
from the interface. What it adds is the amplifier: the volts the DAQ puts out and the
volts across the crystal differ by the amplifier's gain, and on an inverting amplifier
by a sign as well. Both are available:

- [`setvoltage`](@ref)`(eod, vx, vy)` — **DAQ output volts**, what the card actually emits
- [`setcrystalvoltage`](@ref)`(eod, vx, vy)` — **crystal volts**, after the amplifier

For an HVA200 at a gain of 20 with an inverting output, `setcrystalvoltage(eod, 100.0,
0.0)` writes −5 V on the DAQ. The limits are always checked in DAQ volts, since that is
what reaches hardware, and a rejected crystal-volt command reports both numbers.

The crystal's rating is a required keyword, `max_crystal_volts`, and the DAQ limits are
held to it: the backend's ±10 V alone would put ±200 V across the crystal at gain 20.

# Arguments
- `backend::SteeringBackend`: What drives the two amplifier inputs — usually a
  `DAQmxBackend`, though a `TriggerscopeBackend` works the same way.

# Keywords
- `calibration::AngleCalibration`: Voltage ↔ angle map in mrad/V. Defaults to the identity.
- `calibration_basis::Symbol`: Which voltage the calibration was measured against —
  `:crystal` (the default) when the mrad/V came from the amplifier monitor or from the
  real high voltage, `:daq` when it came from the DAQ output. Getting this wrong is a
  silent factor-of-gain error in every angle, which is why it is explicit. The analysis
  in `dev/MINFLUX Project/angle_defle.jl` works from the monitor trace, so its numbers
  are `:crystal`.
- `amplifier_gain::Real`: Volts across the crystal per volt from the DAQ. Default `20.0`,
  the HVA200.
- `invert::Bool`: `true` when the amplifier inverts, so positive DAQ volts give negative
  crystal volts. Default `true`, matching the HVA200 wiring in the MINFLUX scripts, where
  the monitor has to be negated to recover the real output.
- `max_crystal_volts::Real`: **Required.** The highest voltage, of either sign, the
  crystals may see. The DAQ limits are held to `max_crystal_volts / amplifier_gain`:
  omitted limits are narrowed to it, and explicit limits beyond it throw.
- `xlimits`, `ylimits`: Allowed **DAQ** voltage range per axis. Default to the backend's
  range, narrowed to the crystal ceiling. See `MicroscopeControl.crystal_limits` for the
  same bounds expressed across the crystal.
- `unique_id::String`: Name used in logs and `export_state`. Default `"EOD"`.

# Example
```julia
# HVA200 pair on Dev2, inverting, gain 20, kept under +/-150 V on the crystal
eod = EOD(DAQmxBackend("Dev2/ao0", "Dev2/ao1"),
          calibration = AngleCalibration(mrad_per_volt_x = 0.003, mrad_per_volt_y = 0.003),
          calibration_basis = :crystal,
          amplifier_gain = 20.0, invert = true,
          max_crystal_volts = 150.0)        # DAQ limits become +/-7.5 V
initialize(eod)
setcrystalvoltage(eod, 100.0, 0.0)   # 100 V on the X crystal, -5 V out of the DAQ
setangle(eod, 0.3, 0.0)              # 0.3 mrad on X
shutdown(eod)
```
"""
mutable struct EOD <: BeamSteerer
    unique_id::String
    backend::SteeringBackend
    calibration::AngleCalibration
    calibration_basis::Symbol
    amplifier_gain::Float64
    invert::Bool
    max_crystal_volts::Float64
    xlimits::Tuple{Float64,Float64}
    ylimits::Tuple{Float64,Float64}
    voltages::Vector{Float64}
    isopen::Bool
end

function EOD(backend::SteeringBackend;
    calibration::AngleCalibration=AngleCalibration([1.0 0.0; 0.0 1.0]),
    calibration_basis::Symbol=:crystal,
    amplifier_gain::Real=20.0,
    invert::Bool=true,
    max_crystal_volts::Union{Nothing,Real}=nothing,
    xlimits::Union{Nothing,Tuple{<:Real,<:Real}}=nothing,
    ylimits::Union{Nothing,Tuple{<:Real,<:Real}}=nothing,
    unique_id::String="EOD")

    calibration_basis in (:crystal, :daq) || throw(ArgumentError(
        "calibration_basis must be :crystal or :daq, got :$calibration_basis"))
    amplifier_gain == 0 && throw(ArgumentError("amplifier_gain cannot be zero"))
    max_crystal_volts === nothing && throw(ArgumentError(
        "$unique_id: max_crystal_volts is required: the highest voltage, of either sign, the " *
        "crystals may see. Without it the limits would be the backend's range times the gain."))
    max_crystal_volts > 0 || throw(ArgumentError(
        "$unique_id: max_crystal_volts must be positive, got $max_crystal_volts"))

    xlim, ylim = resolve_limits(backend, xlimits, ylimits, unique_id;
        max_abs=max_crystal_volts / abs(amplifier_gain))
    return EOD(unique_id, backend, calibration, calibration_basis, Float64(amplifier_gain),
        invert, Float64(max_crystal_volts), xlim, ylim, [0.0, 0.0], false)
end
