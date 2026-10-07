"""
`BeamSteerer` is an abstract type for two-axis beam-steering devices — galvanometer
mirror pairs, electro-optic deflectors, and anything else that deflects a beam in X and
Y by applying a voltage on each axis.

Every concrete `BeamSteerer` is expected to carry these fields, which the generic
methods in `interface_functions.jl` operate on:

- `unique_id::String`               — name used in logs and in `export_state`
- `backend::SteeringBackend`        — the device that actually puts the volts out
- `calibration::AngleCalibration`   — voltage ↔ angle map (see `AngleCalibration`)
- `xlimits::Tuple{Float64,Float64}` — allowed X voltage range, volts
- `ylimits::Tuple{Float64,Float64}` — allowed Y voltage range, volts
- `voltages::Vector{Float64}`       — last commanded `[vx, vy]`, volts
- `isopen::Bool`                    — whether `initialize` has run

A device that provides those fields gets `setvoltage`, `setangle`, `gridscan` and the
rest for free; it only has to supply its own constructor.
"""
abstract type BeamSteerer <: AbstractInstrument end

"""
`SteeringBackend` is an abstract type for whatever hardware actually emits the two
analog voltages for a `BeamSteerer` — a Triggerscope DAC pair, a National Instruments
analog-output pair, and so on.

A backend must implement three methods (see `interface_functions.jl`):

- `write_voltages!(backend, vx, vy)` — put `vx` on the X axis and `vy` on the Y axis
- `openbackend!(backend)`            — claim the hardware and park both axes at 0 V
- `closebackend!(backend)`           — park at 0 V and release the hardware

and may optionally implement `backend_limits(backend)` to report the voltage range its
hardware can actually produce, which the device constructors use as a default limit.
"""
abstract type SteeringBackend end

"""
    AngleCalibration(M; v_offset = [0.0, 0.0])

The linear map between axis voltages and beam deflection angle for a `BeamSteerer`.

`M` is a 2×2 matrix in **milliradians per volt** and `v_offset` is the voltage pair that
produces zero deflection, so that

    angles = M * (volts - v_offset)
    volts  = M \\ angles + v_offset

The off-diagonal entries carry X/Y cross-coupling: a device whose axes are perfectly
independent has a diagonal `M`, and one whose mount is rotated relative to the camera
does not. This is the same algebra as the pixel-space `calibration_matrix` produced by
`calibrate_galvo` in `dev/MINFLUX Project/galvo_calibration.jl`, with milliradians in
place of pixels.

`M` must be invertible — `setangle` cannot be solved otherwise.

# Example
```julia
# 0.45 mrad/V on X, 0.42 mrad/V on Y, no cross-coupling, zero angle at 0 V
cal = AngleCalibration([0.45 0.0; 0.0 0.42])

# measured map with cross-coupling and a non-zero rest point
cal = AngleCalibration([0.451 0.012; -0.008 0.423], v_offset = [0.13, -0.05])
```
"""
struct AngleCalibration
    M::Matrix{Float64}
    v_offset::Vector{Float64}
end

function AngleCalibration(M::AbstractMatrix{<:Real}; v_offset::AbstractVector{<:Real} = [0.0, 0.0])
    size(M) == (2, 2) || throw(ArgumentError("calibration matrix must be 2x2, got $(size(M))"))
    length(v_offset) == 2 || throw(ArgumentError("v_offset must have 2 entries, got $(length(v_offset))"))
    Mf = Matrix{Float64}(M)
    abs(Mf[1, 1] * Mf[2, 2] - Mf[1, 2] * Mf[2, 1]) > 0 ||
        throw(ArgumentError("calibration matrix is singular; angles cannot be converted back to voltages"))
    return AngleCalibration(Mf, Vector{Float64}(v_offset))
end

"""
    AngleCalibration(; mrad_per_volt_x, mrad_per_volt_y, v_offset = [0.0, 0.0])

Convenience constructor for the common uncoupled case, where each axis has a single
deflection constant in milliradians per volt and the two axes do not influence each
other.
"""
function AngleCalibration(; mrad_per_volt_x::Real, mrad_per_volt_y::Real,
                            v_offset::AbstractVector{<:Real} = [0.0, 0.0])
    return AngleCalibration([mrad_per_volt_x 0.0; 0.0 mrad_per_volt_y], v_offset = v_offset)
end
