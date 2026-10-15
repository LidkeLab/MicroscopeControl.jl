# The three-method backend contract from BeamSteeringInterface, implemented for the
# Triggerscope4 DAC pair and for an NI-DAQmx analog-output pair.

# ── Triggerscope ─────────────────────────────────────────────────────────────

"""
    rangelimits(range::Range)

The `(min, max)` output voltage of a Triggerscope DAC range.
"""
rangelimits(range::Range) = RANGE_LIMITS[range]

const RANGE_LIMITS = Dict{Range,Tuple{Float64,Float64}}(
    ZEROTOFIVE => (0.0, 5.0),
    ZEROTOTEN => (0.0, 10.0),
    PLUSMINUS5 => (-5.0, 5.0),
    PLUSMINUS10 => (-10.0, 10.0),
    PLUSMINUS2_5 => (-2.5, 2.5),
)

"""
    min_voltage_step(backend::TriggerscopeBackend)

The smallest voltage change the 16-bit Triggerscope DAC can actually address at the
backend's configured range — about 305 µV on ±10 V, about 76 µV on ±2.5 V.

Useful as the default step for a fine scan: a smaller step commands a voltage the DAC
rounds back to the one you were already at.
"""
function min_voltage_step(backend::TriggerscopeBackend)
    vmin, vmax = rangelimits(backend.range)
    return (vmax - vmin) / (2^backend.scope.dacresolution - 1)
end

function BeamSteeringInterface.backend_limits(backend::TriggerscopeBackend)
    lims = rangelimits(backend.range)
    return (lims, lims)
end

function BeamSteeringInterface.openbackend!(backend::TriggerscopeBackend)
    if backend.owns_device
        initialize(backend.scope)
        # The board resets when the serial port opens and ignores commands until it boots.
        sleep(backend.boot_delay)
    end
    clearall(backend.scope)
    setrange(backend.scope, backend.x_channel, backend.range)
    setrange(backend.scope, backend.y_channel, backend.range)
    write_voltages!(backend, 0.0, 0.0)
    return nothing
end

function BeamSteeringInterface.closebackend!(backend::TriggerscopeBackend)
    try
        write_voltages!(backend, 0.0, 0.0)
    catch e
        @warn "Could not park the Triggerscope DACs at 0 V before closing" exception = e
    end
    backend.owns_device && shutdown(backend.scope)
    return nothing
end

function BeamSteeringInterface.write_voltages!(backend::TriggerscopeBackend, vx::Float64, vy::Float64)
    setdac(backend.scope, backend.x_channel, vx)
    setdac(backend.scope, backend.y_channel, vy)
    return nothing
end

# ── NI-DAQmx ─────────────────────────────────────────────────────────────────

function BeamSteeringInterface.backend_limits(backend::DAQmxBackend)
    lims = (backend.vmin, backend.vmax)
    return (lims, lims)
end

function BeamSteeringInterface.openbackend!(backend::DAQmxBackend)
    # Tasks are created and started once and held for the life of the device, so each
    # move costs one write_scalar rather than a task setup and teardown.
    backend.x_task = AOTask(backend.x_channel, min_val=backend.vmin, max_val=backend.vmax)
    backend.y_task = AOTask(backend.y_channel, min_val=backend.vmin, max_val=backend.vmax)
    start!(backend.x_task)
    start!(backend.y_task)
    write_voltages!(backend, 0.0, 0.0)
    return nothing
end

function BeamSteeringInterface.closebackend!(backend::DAQmxBackend)
    try
        write_voltages!(backend, 0.0, 0.0)
    catch e
        @warn "Could not park the NI analog outputs at 0 V before closing" exception = e
    end
    for task in (backend.x_task, backend.y_task)
        task === nothing && continue
        try
            stop!(task)
            clear!(task)
        catch e
            @warn "Error releasing an NI analog-output task" exception = e
        end
    end
    backend.x_task = nothing
    backend.y_task = nothing
    return nothing
end

function BeamSteeringInterface.write_voltages!(backend::DAQmxBackend, vx::Float64, vy::Float64)
    (backend.x_task === nothing || backend.y_task === nothing) &&
        throw(ArgumentError("NI analog-output tasks are not open; call initialize on the device first"))
    write_scalar(backend.x_task, vx)
    write_scalar(backend.y_task, vy)
    return nothing
end
