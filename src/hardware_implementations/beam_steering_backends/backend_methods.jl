# The backend contract from BeamSteeringInterface, implemented for the Triggerscope4 DAC
# pair and for an NI-DAQmx analog-output pair.

# A park that did not reach the hardware is reported after the hardware is released, so a
# failed write cannot also leak the serial port or the NI tasks.
park_failed(what::AbstractString, e) = ErrorException(
    "Could not park $what at 0 V before releasing it; the outputs may still hold their last " *
    "voltage. Cause: $(sprint(showerror, e))")

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

# The DAC sends round((v - vmin) / step) as its code. Moving each end of the limit inward
# to a whole code makes every voltage inside the limit round to a code inside it.
function BeamSteeringInterface.snap_limits(backend::TriggerscopeBackend, lims::Tuple{Float64,Float64})
    vmin, _ = rangelimits(backend.range)
    step = min_voltage_step(backend)
    # The tolerance keeps a limit already on the grid, up to float error, where it is.
    lo = ceil((lims[1] - vmin) / step - 1e-9)
    hi = floor((lims[2] - vmin) / step + 1e-9)
    return (vmin + lo * step, vmin + hi * step)
end

# No CLEAR_ALL here: it erases the board's sequence tables, which another device on a
# shared Triggerscope may have programmed, and this backend uses no sequences.
function BeamSteeringInterface.openbackend!(backend::TriggerscopeBackend)
    if backend.owns_device
        initialize(backend.scope)
        # The board resets when the serial port opens and ignores commands until it boots.
        sleep(backend.boot_delay)
    end
    try
        setrange(backend.scope, backend.x_channel, backend.range)
        setrange(backend.scope, backend.y_channel, backend.range)
        write_voltages!(backend, 0.0, 0.0)
    catch
        backend.owns_device && shutdown(backend.scope)
        rethrow()
    end
    return nothing
end

function BeamSteeringInterface.closebackend!(backend::TriggerscopeBackend)
    park_error = try
        write_voltages!(backend, 0.0, 0.0)
        nothing
    catch e
        e
    end
    backend.owns_device && shutdown(backend.scope)
    park_error === nothing || throw(park_failed("the Triggerscope DACs", park_error))
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

# Stop and clear one task, each in its own `try`, so a failed stop still clears it.
function release_task(task, channel)
    try
        stop!(task)
    catch e
        @warn "Error stopping the NI analog-output task on $channel" exception = e
    end
    try
        clear!(task)
    catch e
        @warn "Error clearing the NI analog-output task on $channel" exception = e
    end
    return nothing
end

function BeamSteeringInterface.openbackend!(backend::DAQmxBackend)
    (backend.x_task === nothing && backend.y_task === nothing) || throw(ArgumentError(
        "the NI analog-output tasks on $(backend.x_channel) and $(backend.y_channel) are already open; " *
        "shut the device down first"))
    # Tasks are created and started once and held for the life of the device, so each
    # move costs one write_scalar rather than a task setup and teardown.
    x_task = AOTask(backend.x_channel, min_val=backend.vmin, max_val=backend.vmax)
    y_task = nothing
    try
        y_task = AOTask(backend.y_channel, min_val=backend.vmin, max_val=backend.vmax)
        start!(x_task)
        start!(y_task)
        backend.x_task = x_task
        backend.y_task = y_task
        write_voltages!(backend, 0.0, 0.0)
    catch
        backend.x_task = nothing
        backend.y_task = nothing
        release_task(x_task, backend.x_channel)
        y_task === nothing || release_task(y_task, backend.y_channel)
        rethrow()
    end
    return nothing
end

function BeamSteeringInterface.closebackend!(backend::DAQmxBackend)
    park_error = try
        write_voltages!(backend, 0.0, 0.0)
        nothing
    catch e
        e
    end
    backend.x_task === nothing || release_task(backend.x_task, backend.x_channel)
    backend.y_task === nothing || release_task(backend.y_task, backend.y_channel)
    backend.x_task = nothing
    backend.y_task = nothing
    park_error === nothing || throw(park_failed("the NI analog outputs", park_error))
    return nothing
end

function BeamSteeringInterface.write_voltages!(backend::DAQmxBackend, vx::Float64, vy::Float64)
    (backend.x_task === nothing || backend.y_task === nothing) &&
        throw(ArgumentError("NI analog-output tasks are not open; call initialize on the device first"))
    write_scalar(backend.x_task, vx)
    write_scalar(backend.y_task, vy)
    return nothing
end
