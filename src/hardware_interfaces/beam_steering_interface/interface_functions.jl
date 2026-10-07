# Generic behaviour shared by every BeamSteerer. Concrete devices (Galvo, EOD) supply a
# type with the fields listed in the `BeamSteerer` docstring and a constructor; the
# methods below then work for them unchanged. Only the three backend methods at the top
# are per-hardware.

# ── Backend contract ─────────────────────────────────────────────────────────

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

Claim the hardware and park both axes at 0 V. Called by `initialize`.
"""
function openbackend!(backend::SteeringBackend)
    error("openbackend! not implemented for $(typeof(backend))")
end

"""
    closebackend!(backend::SteeringBackend)

Park both axes at 0 V and release the hardware. Called by `shutdown`.
"""
function closebackend!(backend::SteeringBackend)
    error("closebackend! not implemented for $(typeof(backend))")
end

"""
    backend_limits(backend::SteeringBackend)

The voltage range the backend hardware can produce, as `((xmin, xmax), (ymin, ymax))`,
or `nothing` when the backend cannot report it. Device constructors use this as the
default for `xlimits`/`ylimits` when the caller does not give explicit limits.
"""
backend_limits(backend::SteeringBackend) = nothing

"""
    resolve_limits(backend, xlimits, ylimits, unique_id)

Work out the voltage limits a device should enforce, given what the caller asked for and
what the backend says it can produce. Used by the `Galvo` and `EOD` constructors.

A `nothing` limit falls back to the backend's own range. An explicit limit is kept, but
warns when it reaches beyond what the backend can actually produce — that is a sign the
range and the limits disagree, and the hardware will clip rather than obey.
"""
function resolve_limits(backend::SteeringBackend,
    xlimits::Union{Nothing,Tuple{<:Real,<:Real}},
    ylimits::Union{Nothing,Tuple{<:Real,<:Real}},
    unique_id::AbstractString)

    hw = backend_limits(backend)

    function resolve(requested, hwlims, axis)
        if requested === nothing
            hwlims === nothing && throw(ArgumentError(
                "$unique_id: $(typeof(backend)) cannot report its voltage range, so " *
                "$(lowercase(axis))limits must be given explicitly"))
            return (Float64(hwlims[1]), Float64(hwlims[2]))
        end
        requested[1] < requested[2] || throw(ArgumentError(
            "$unique_id: $axis limits must be (min, max) with min below max, got $requested"))
        if hwlims !== nothing && (requested[1] < hwlims[1] || requested[2] > hwlims[2])
            @warn "$unique_id: $axis limits reach outside what the backend can produce; " *
                  "the hardware will clip there" requested = requested backend_range = hwlims
        end
        return (Float64(requested[1]), Float64(requested[2]))
    end

    return resolve(xlimits, hw === nothing ? nothing : hw[1], "X"),
    resolve(ylimits, hw === nothing ? nothing : hw[2], "Y")
end

# ── Lifecycle ────────────────────────────────────────────────────────────────

"""
    initialize(dev::BeamSteerer)

Open the backend, park both axes at 0 V, and mark the device ready.
"""
function MicroscopeControl.initialize(dev::BeamSteerer)
    openbackend!(dev.backend)
    dev.voltages .= 0.0
    dev.isopen = true
    @info "$(dev.unique_id) initialized" xlimits = dev.xlimits ylimits = dev.ylimits
    return nothing
end

"""
    shutdown(dev::BeamSteerer)

Park both axes at 0 V and release the backend.
"""
function MicroscopeControl.shutdown(dev::BeamSteerer)
    try
        closebackend!(dev.backend)
    finally
        dev.voltages .= 0.0
        dev.isopen = false
    end
    @info "$(dev.unique_id) shut down"
    return nothing
end

"""
    export_state(dev::BeamSteerer)

State of the steerer for HDF5 saving: the commanded voltages, the resulting angles, the
limits, and the calibration that ties the two together.
"""
function MicroscopeControl.export_state(dev::BeamSteerer)
    ax, ay = getangle(dev)
    attributes = Dict{String,Any}(
        "unique_id" => dev.unique_id,
        "device_type" => string(typeof(dev)),
        "backend_type" => string(typeof(dev.backend)),
        "voltage_x" => dev.voltages[1],
        "voltage_y" => dev.voltages[2],
        "angle_x_mrad" => ax,
        "angle_y_mrad" => ay,
        "xlimits" => collect(dev.xlimits),
        "ylimits" => collect(dev.ylimits),
        "calibration_matrix" => dev.calibration.M,
        "calibration_offset" => dev.calibration.v_offset,
    )
    return attributes, Dict{String,Any}(), Dict{String,Any}()
end

# ── Limits ───────────────────────────────────────────────────────────────────

"""
    checklimits(dev::BeamSteerer, vx::Real, vy::Real)

Throw an `ArgumentError` if either voltage falls outside the device's configured limits.
Called by `setvoltage` before anything reaches the hardware — nothing is written when one
axis is out of range, so a bad command never half-applies.
"""
function checklimits(dev::BeamSteerer, vx::Real, vy::Real)
    for (axis, v, lims) in (("X", vx, dev.xlimits), ("Y", vy, dev.ylimits))
        if !(lims[1] <= v <= lims[2])
            throw(ArgumentError(
                "$(dev.unique_id): $axis voltage $(v) V is outside the allowed range " *
                "$(lims[1]) to $(lims[2]) V. Nothing was written to the hardware."))
        end
    end
    return nothing
end

# ── Voltage ──────────────────────────────────────────────────────────────────

"""
    setvoltage(dev::BeamSteerer, vx::Real, vy::Real)

Drive the two axes to `vx` and `vy` volts.

Throws an `ArgumentError` without touching the hardware if either value is outside the
device's limits.

# Arguments
- `dev::BeamSteerer`: The steering device.
- `vx::Real`: X-axis voltage, volts.
- `vy::Real`: Y-axis voltage, volts.
"""
function DAQInterface.setvoltage(dev::BeamSteerer, vx::Real, vy::Real)
    dev.isopen || throw(ArgumentError("$(dev.unique_id) is not initialized; call initialize first"))
    checklimits(dev, vx, vy)
    write_voltages!(dev.backend, Float64(vx), Float64(vy))
    dev.voltages[1] = Float64(vx)
    dev.voltages[2] = Float64(vy)
    return nothing
end

"""
    getvoltage(dev::BeamSteerer)

The last commanded `(vx, vy)` in volts. This is the commanded value, not a hardware
readback — neither backend reads its output back.
"""
getvoltage(dev::BeamSteerer) = (dev.voltages[1], dev.voltages[2])

"""
    zeroaxes(dev::BeamSteerer)

Drive both axes to 0 V.

Note that 0 V is the electrical centre, which is the zero-deflection point only when the
calibration's `v_offset` is zero. Use `setangle(dev, 0.0, 0.0)` for the optical centre.
"""
zeroaxes(dev::BeamSteerer) = setvoltage(dev, 0.0, 0.0)

# ── Angle ────────────────────────────────────────────────────────────────────

"""
    voltage_to_angle(cal::AngleCalibration, vx::Real, vy::Real)

Deflection angle `(ax, ay)` in milliradians produced by the voltage pair `(vx, vy)`.
"""
function voltage_to_angle(cal::AngleCalibration, vx::Real, vy::Real)
    a = cal.M * ([Float64(vx), Float64(vy)] .- cal.v_offset)
    return (a[1], a[2])
end

"""
    angle_to_voltage(cal::AngleCalibration, ax::Real, ay::Real)

Voltage pair `(vx, vy)` that produces the deflection angle `(ax, ay)` in milliradians.
"""
function angle_to_voltage(cal::AngleCalibration, ax::Real, ay::Real)
    v = (cal.M \ [Float64(ax), Float64(ay)]) .+ cal.v_offset
    return (v[1], v[2])
end

"""
    angle_setpoint_voltage(dev::BeamSteerer, ax::Real, ay::Real)

The voltage pair that must be **written to the backend** to deflect the beam to `(ax,
ay)` milliradians.

For most devices this is just `angle_to_voltage(dev.calibration, ax, ay)`. It is a
separate function because a device can sit behind an amplifier, so the voltage its
calibration is expressed in is not the voltage that reaches the hardware — `EOD`
overrides this, and because `setangle` and the range check in `gridscan` both go through
here, they stay consistent with each other.
"""
angle_setpoint_voltage(dev::BeamSteerer, ax::Real, ay::Real) = angle_to_voltage(dev.calibration, ax, ay)

"""
    setangle(dev::BeamSteerer, ax::Real, ay::Real)

Deflect the beam to `ax` and `ay` **milliradians** on the two axes, using the device's
`AngleCalibration` to work out the voltages.

Throws an `ArgumentError` without touching the hardware if the required voltages fall
outside the device's limits — the message reports both the angle asked for and the
voltage it worked out to.

# Arguments
- `dev::BeamSteerer`: The steering device.
- `ax::Real`: X-axis deflection, milliradians.
- `ay::Real`: Y-axis deflection, milliradians.
"""
function setangle(dev::BeamSteerer, ax::Real, ay::Real)
    vx, vy = angle_setpoint_voltage(dev, ax, ay)
    try
        setvoltage(dev, vx, vy)
    catch e
        e isa ArgumentError || rethrow()
        throw(ArgumentError(
            "$(dev.unique_id): angle ($(ax), $(ay)) mrad needs ($(round(vx, digits=4)), " *
            "$(round(vy, digits=4))) V, which is out of range. $(e.msg)"))
    end
    return nothing
end

"""
    getangle(dev::BeamSteerer)

Deflection angle `(ax, ay)` in milliradians implied by the last commanded voltages.
"""
getangle(dev::BeamSteerer) = voltage_to_angle(dev.calibration, dev.voltages[1], dev.voltages[2])

# ── Scan point generators ────────────────────────────────────────────────────

"""
    gridpoints(step::Real, points::Int; center = (0.0, 0.0))

The `(x, y)` pairs of a square `points` × `points` grid of spacing `step`, centred on
`center`. Units are whatever you intend to scan in — volts or milliradians — since this
is pure arithmetic with no device involved.

Use it when you want the positions but not the stepping loop; `gridscan` walks the same
list against real hardware.

# Example
```julia
pts = gridpoints(0.01, 3)            # 9 points, 10 mV apart, centred on 0
pts = gridpoints(0.5, 5, center = (1.0, -1.0))
```
"""
function gridpoints(step::Real, points::Int; center::Tuple{<:Real,<:Real}=(0.0, 0.0))
    points >= 1 || throw(ArgumentError("points must be at least 1, got $points"))
    half = (points - 1) / 2
    return vec([(center[1] + (i - half) * step, center[2] + (j - half) * step)
                for j in 0:(points-1), i in 0:(points-1)])
end

# ── Scans ────────────────────────────────────────────────────────────────────

"""
    gridscan(dev::BeamSteerer, step::Real, points::Int; kwargs...)

Walk a square `points` × `points` grid of spacing `step`, pausing `settle` seconds at
each position, then return the device to where the scan started.

This generalizes `example_grid_scan` from `dev/MINFLUX Project/galvo_control.jl`: it
works for any `BeamSteerer` over any backend, and it can scan in angle as well as in
voltage.

The whole grid is range-checked before the first move, so a scan that would run off the
end of the voltage range fails immediately rather than halfway through.

# Arguments
- `dev::BeamSteerer`: The steering device.
- `step::Real`: Grid spacing, in volts when `units = :volt` and in milliradians when `units = :angle`.
- `points::Int`: Number of positions per side.

# Keywords
- `center`: Grid centre, same units as `step`. Defaults to the current position.
- `units::Symbol`: `:volt` (default) or `:angle`.
- `settle::Real`: Seconds to wait at each position before the callback runs. Default `0.2`.
- `callback`: Called as `callback(dev, x, y)` at every position after settling — grab a
  camera frame or a monitor reading here. Its return value is collected and returned.
- `return_to_start::Bool`: Put the device back where it started when the scan ends or
  throws. Default `true`.

# Returns
- A `Vector` of whatever `callback` returned at each point, in scan order, or a vector of
  the visited `(x, y)` pairs when no callback is given.

# Example
```julia
# plain sweep in volts, nothing recorded
gridscan(galvo, 0.01, 5)

# scan in angle and keep the beam centroid at each point
centroids = gridscan(eod, 0.2, 7; units = :angle, settle = 0.3) do dev, ax, ay
    find_beam_centroid(getlastframe(camera)')
end
```
"""
function gridscan(dev::BeamSteerer, step::Real, points::Int;
    center::Union{Nothing,Tuple{<:Real,<:Real}}=nothing,
    units::Symbol=:volt,
    settle::Real=0.2,
    callback=nothing,
    return_to_start::Bool=true)

    units in (:volt, :angle) || throw(ArgumentError("units must be :volt or :angle, got :$units"))
    setpoint = units === :volt ? setvoltage : setangle
    start = units === :volt ? getvoltage(dev) : getangle(dev)
    origin = center === nothing ? start : (Float64(center[1]), Float64(center[2]))

    pts = gridpoints(step, points, center=origin)

    # Check the whole grid before moving: a scan that would run off the end of the range
    # should fail now, not halfway through.
    for (x, y) in pts
        vx, vy = units === :volt ? (x, y) : angle_setpoint_voltage(dev, x, y)
        checklimits(dev, vx, vy)
    end

    results = Any[]
    try
        for (x, y) in pts
            setpoint(dev, x, y)
            sleep(settle)
            push!(results, callback === nothing ? (x, y) : callback(dev, x, y))
        end
    finally
        return_to_start && setpoint(dev, start[1], start[2])
    end

    # Narrow the Any[] to the callback's actual return type where they all agree.
    return isempty(results) ? results : identity.(results)
end

"""
    gridscan(callback::Function, dev::BeamSteerer, step::Real, points::Int; kwargs...)

`do`-block form of [`gridscan`](@ref):

```julia
gridscan(galvo, 0.01, 5) do dev, x, y
    getlastframe(camera)
end
```
"""
function gridscan(callback::Function, dev::BeamSteerer, step::Real, points::Int; kwargs...)
    return gridscan(dev, step, points; callback=callback, kwargs...)
end
