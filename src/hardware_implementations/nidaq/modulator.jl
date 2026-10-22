"""
    NIDAQModulator(; channel, v_range, per_volt, daq = NIdaq())

An [`AbstractModulationControl`](@ref) that drives a light's analogue input from one NI-DAQmx analogue
output `channel` (`"Dev1/ao1"`). `v_range = (v_min, v_max)` is the range the output is created with, passed to
DAQmx through `createtask(daq, "AO", channel; min_val, max_val)` so DAQmx refuses a range the card lacks (a
USB-6008 has no 0-10 V output range: error -200077); it is also the reach of `setpower`. `per_volt` is required
and positive, in the light's unit per volt (mW/V in closed loop, mA/V in open loop): measure it as in the TCube
`CALIBRATION.md`, "MOD IN scale".

Construction is pure. `initialize` makes ONE analogue-output task and writes 0 V; `shutdown` writes 0 V, then
deletes the task; a failed `initialize` deletes the task it made. Pass it to a light as `modulator = ...`; the
light opens and closes it.

`setpower(mc, p)` writes `p / per_volt` volts, and throws `ArgumentError`, before any write, when that is not
finite or lies outside `v_range`.
"""
mutable struct NIDAQModulator <: AbstractModulationControl
    daq::DAQ
    channel::String
    v_min::Float64
    v_max::Float64
    per_volt::Float64
    task::Any   # nothing until initialize; the DAQ's own task object after
    configured::Bool   # whether `task` has its channel (a task that could not be set up or released has not)
end

function NIDAQModulator(; channel::AbstractString, v_range::Tuple{<:Real,<:Real}, per_volt::Real, daq::DAQ=NIdaq())
    v_min, v_max = Float64(v_range[1]), Float64(v_range[2])
    (isfinite(v_min) && isfinite(v_max) && v_min <= 0.0 <= v_max && v_min < v_max) || throw(ArgumentError(
        "NIDAQModulator: v_range = $(v_range) must be finite with v_min < v_max and contain 0 V (level 0 is 0 V)"))
    (isfinite(per_volt) && per_volt > 0) || throw(ArgumentError(
        "NIDAQModulator: per_volt is the light's unit per volt and must be finite and positive, got $(per_volt)"))
    isempty(channel) && throw(ArgumentError("NIDAQModulator: channel names the analogue output, e.g. \"Dev1/ao1\""))
    return NIDAQModulator(daq, String(channel), v_min, v_max, Float64(per_volt), nothing, false)
end

output_id(m::NIDAQModulator) = "NIDAQ $(m.channel)"

"The voltage `setpower(m, p)` writes; `ArgumentError` when `p` is not a finite level of at least 0 or has no voltage the output can make."
function volts(m::NIDAQModulator, p::Float64)
    (isfinite(p) && p >= 0) || throw(ArgumentError(
        "NIDAQModulator $(m.channel): a level is finite and at least 0 (0 is 0 V), got $p"))
    v = p / m.per_volt
    (isfinite(v) && m.v_min <= v <= m.v_max) || throw(ArgumentError(
        "NIDAQModulator $(m.channel): level $p needs $v V ($(m.per_volt) per V), outside the output's range [$(m.v_min), $(m.v_max)] V"))
    return v
end

holds_resources(m::NIDAQModulator) = m.task !== nothing

function setpower(m::NIDAQModulator, p::Float64)
    (m.task === nothing || !m.configured) && error("NIDAQModulator $(m.channel): setpower before initialize (or after shutdown, or with the task not set up)")
    v = volts(m, p)
    setvoltage(m.daq, m.task, v)
    return nothing
end

# The task handle is kept (`m.task`) from the moment it exists until the DAQ has deleted it, so a cleanup that fails
# leaves it for `shutdown` to retry and `holds_resources` true, which keeps the light's claim.
function initialize(m::NIDAQModulator)
    if m.task !== nothing && m.configured   # opened already: one task for life, so only the level is put back to 0 V
        setvoltage(m.daq, m.task, 0.0)
        return nothing
    end
    if m.task === nothing
        try
            m.task = createtask(m.daq, "AO", m.channel; min_val=m.v_min, max_val=m.v_max)
            m.configured = true
        catch e
            if e isa DAQInterface.UnreleasedTask   # the task exists, half set up, and could not be cleared: keep it for shutdown
                m.task = e.task
                m.configured = false
                throw(e.cause)
            end
            rethrow()
        end
    else
        # A task left over from an earlier failed setup: release it before making a new one.
        deletetask(m.daq, m.task)
        m.task = nothing
        return initialize(m)
    end
    try
        setvoltage(m.daq, m.task, 0.0)
    catch
        try
            deletetask(m.daq, m.task)
            m.task = nothing
            m.configured = false
        catch derr
            @error "NIDAQModulator $(m.channel): deleting the task failed while cleaning up a failed initialize; shutdown retries it" exception = derr
        end
        rethrow()
    end
    return nothing
end

# The zero write and the delete must both succeed before the task and the claim are given up; either failing keeps
# them, and the next `shutdown` retries from the zero (a task that never had its channel has no level to zero).
function shutdown(m::NIDAQModulator)
    m.task === nothing && return nothing
    m.configured && setvoltage(m.daq, m.task, 0.0)
    deletetask(m.daq, m.task)
    m.task = nothing
    m.configured = false
    return nothing
end

function export_state(m::NIDAQModulator)
    attributes = Dict{String,Any}("modulator_type" => "NIDAQModulator", "output_id" => output_id(m),
        "channel" => m.channel, "v_min" => m.v_min, "v_max" => m.v_max, "per_volt" => m.per_volt)
    return attributes, nothing, Dict{String,Any}("daq" => export_state(m.daq))
end
