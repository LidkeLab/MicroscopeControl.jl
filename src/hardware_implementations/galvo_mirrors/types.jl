"""
    Galvo(backend; kwargs...)

A two-axis galvanometer mirror pair.

The galvo is defined entirely by its backend (which DAC or analog-output pair drives the
two mirrors), the voltage range it is safe to drive them over, and the calibration that
turns a deflection angle into those voltages. Steering it is then
[`setvoltage`](@ref) or [`setangle`](@ref), and scanning it is [`gridscan`](@ref) —
all inherited from the `BeamSteerer` interface, so the same script works whether the
mirrors hang off a Triggerscope or an NI card.

Note that the angle this reports is whatever the calibration was measured in. A
galvanometer deflects the *beam* by twice the mechanical mirror rotation, so a
calibration taken by watching the beam move on a camera is already an optical-angle
calibration and needs no extra factor of two.

# Arguments
- `backend::SteeringBackend`: What drives the two mirror axes — a `TriggerscopeBackend`
  or a `DAQmxBackend`.

# Keywords
- `calibration::AngleCalibration`: Voltage ↔ angle map in mrad/V. Defaults to the
  identity, which makes `setangle` numerically the same as `setvoltage`; pass a measured
  calibration before relying on angles.
- `xlimits`, `ylimits`: Allowed voltage range per axis. Default to whatever the backend
  reports it can produce, and narrowing them is the way to keep a scan inside the range
  where your mirrors stay linear.
- `unique_id::String`: Name used in logs and `export_state`. Default `"Galvo"`.

# Example
```julia
scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)
galvo = Galvo(TriggerscopeBackend(scope, x_channel = 1, y_channel = 2),
              calibration = AngleCalibration([0.45 0.0; 0.0 0.42]),
              xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0))
initialize(galvo)
setvoltage(galvo, 0.2, -0.2)
setangle(galvo, 0.5, 0.0)
shutdown(galvo)
```
"""
mutable struct Galvo <: BeamSteerer
    unique_id::String
    backend::SteeringBackend
    calibration::AngleCalibration
    xlimits::Tuple{Float64,Float64}
    ylimits::Tuple{Float64,Float64}
    voltages::Vector{Float64}
    isopen::Bool
end

function Galvo(backend::SteeringBackend;
    calibration::AngleCalibration=AngleCalibration([1.0 0.0; 0.0 1.0]),
    xlimits::Union{Nothing,Tuple{<:Real,<:Real}}=nothing,
    ylimits::Union{Nothing,Tuple{<:Real,<:Real}}=nothing,
    unique_id::String="Galvo")

    xlim, ylim = resolve_limits(backend, xlimits, ylimits, unique_id)
    return Galvo(unique_id, backend, calibration, xlim, ylim, [0.0, 0.0], false)
end
