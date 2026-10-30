# The backend contract: what a SteeringBackend implements. The three required methods
# throw here; the two optional ones have a default. The BeamSteerer behaviour every device
# inherits is in shared_methods.jl.

"""
    write_voltages!(backend::SteeringBackend, vx::Float64, vy::Float64)

Put `vx` volts on the X axis and `vy` volts on the Y axis. Called by `setvoltage` after
the limit check, so a backend does not need to range-check again.
"""
function write_voltages!(backend::SteeringBackend, vx::Float64, vy::Float64)
    error("write_voltages! not implemented for $(typeof(backend))")
end

"""
    openbackend!(backend::SteeringBackend)

Claim the hardware and park both axes at 0 V. Called by `initialize`. Refuses a backend
that is already open, and releases whatever it claimed when it fails partway.
"""
function openbackend!(backend::SteeringBackend)
    error("openbackend! not implemented for $(typeof(backend))")
end

"""
    closebackend!(backend::SteeringBackend)

Park both axes at 0 V and release the hardware. Called by `shutdown`. The hardware is
released even when the park fails, and the park failure is then thrown, since the outputs
may still hold their last voltage.
"""
function closebackend!(backend::SteeringBackend)
    error("closebackend! not implemented for $(typeof(backend))")
end

"""
    backend_limits(backend::SteeringBackend)

The voltage range the backend hardware can produce, as `((xmin, xmax), (ymin, ymax))`,
or `nothing` when the backend cannot report it. Device constructors use this as the
default for `xlimits`/`ylimits`, and refuse an explicit limit outside it.
"""
backend_limits(backend::SteeringBackend) = nothing

"""
    snap_limits(backend::SteeringBackend, lims::Tuple{Float64,Float64})

Move a `(min, max)` limit inward onto voltages the backend can produce exactly. Default:
unchanged, for a backend that does not quantize.

A quantizing backend (a DAC) rounds each command to its nearest code. With both ends of a
limit on that grid, rounding is monotonic, so no command inside the limit can round to a
code outside it.
"""
snap_limits(backend::SteeringBackend, lims::Tuple{Float64,Float64}) = lims
