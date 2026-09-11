#=
Motion and motion configuration for the MCS2.

Everything here works in microns and takes axis numbers (1, 2, 3) or symbols
(:x, :y, :z); the picometre conversion and channel lookup happen on the way to
`ctl_api.jl`.

The SDK's motion commands are all non-blocking. Functions that move the stage
therefore take a `wait` keyword: `wait=true` polls the channel state until the
axes come to rest.
=#

# --- Position readback -------------------------------------------------------

"""
    getaxisposition(stage, axis) -> Float64

Current position of a single axis in microns, read from the controller.
"""
function getaxisposition(stage::MCS2Stage, axis::Integer)
    checkconnected(stage)
    idx = axisindex(axis)
    position = pm2um(get_i64(stage.id, channelof(stage, idx), SA_CTL_PKEY_POSITION))
    setcachedposition!(stage, idx, position)
    return position
end

getaxisposition(stage::MCS2Stage, axis::Symbol) = getaxisposition(stage, axisindex(axis))

# --- Waiting -----------------------------------------------------------------

"""
    waitformotion(stage; timeout=stage.movetimeout, poll=0.01, settle=0.05)

Block until every axis has finished moving, referencing or calibrating.

Motion commands are queued asynchronously, so the channel state can still read
"idle" for a moment after one is issued. `settle` seconds are allowed to pass
before the first poll to avoid returning from a move that has not started yet.

Throws if `timeout` seconds elapse first; the stage is left moving, so call
[`stopmotion`](@ref) if that is not what you want. Warns about any axis that
finished on an end stop, a range limit, a following error or an outright
movement failure.
"""
function waitformotion(stage::MCS2Stage; timeout::Real=stage.movetimeout,
    poll::Real=0.01, settle::Real=0.05)
    checkconnected(stage)
    settle > 0 && sleep(settle)
    deadline = time() + timeout
    while any(ismoving(stage))
        if time() > deadline
            error("MCS2 stage still moving after $(timeout) s; " *
                  "increase stage.movetimeout or call stopmotion(stage)")
        end
        sleep(poll)
    end
    warnonfaults(stage)
    return stage
end

const MOTION_FAULT_BITS = [
    SA_CTL_CH_STATE_BIT_MOVEMENT_FAILED => "movement failed",
    SA_CTL_CH_STATE_BIT_END_STOP_REACHED => "end stop reached",
    SA_CTL_CH_STATE_BIT_RANGE_LIMIT_REACHED => "range limit reached",
    SA_CTL_CH_STATE_BIT_FOLLOWING_LIMIT_REACHED => "following error limit reached",
    SA_CTL_CH_STATE_BIT_POSITIONER_OVERLOAD => "positioner overload",
    SA_CTL_CH_STATE_BIT_POSITIONER_FAULT => "positioner fault",
    SA_CTL_CH_STATE_BIT_OVER_TEMPERATURE => "over temperature",
]

"Warn about fault bits left set on any axis after a movement."
function warnonfaults(stage::MCS2Stage)
    for axis in stageaxes(stage)
        state = channelstate(stage, axis)
        for (bit, description) in MOTION_FAULT_BITS
            if state & bit != 0
                @warn "MCS2 axis $(("x", "y", "z")[axis]) (channel $(channelof(stage, axis))): $description"
            end
        end
    end
    return nothing
end

# --- Moves -------------------------------------------------------------------

"""
    moveaxis(stage, axis, position; wait=false)

Closed-loop absolute move of a single axis to `position` microns.

The target is checked against the software travel limits in `stage.range_*`
before anything is sent to the controller.
"""
function moveaxis(stage::MCS2Stage, axis::Integer, position::Real; wait::Bool=false)
    checkconnected(stage)
    idx = axisindex(axis)
    checkaxis(stage, idx)
    lo, hi = positionrange(stage, idx)
    lo <= position <= hi ||
        error("MCS2 target $(position) um is outside the travel limits ($lo, $hi) um " *
              "for axis $(("x", "y", "z")[idx])")

    channel = channelof(stage, idx)
    set_i32(stage.id, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_ABSOLUTE)
    movecommand(stage.id, channel, um2pm(position))
    settarget!(stage, idx, position)
    wait && waitformotion(stage)
    return stage
end

moveaxis(stage::MCS2Stage, axis::Symbol, position::Real; kwargs...) =
    moveaxis(stage, axisindex(axis), position; kwargs...)

"""
    moverelative(stage, distances...; wait=false)

Closed-loop relative move. Give one distance per axis, in microns.

The resulting absolute target is checked against the software travel limits
before the command is sent.

```julia
moverelative(stage, 10.0, -5.0)   # 10 um in +x, 5 um in -y
```
"""
function moverelative(stage::MCS2Stage, distances::Real...; wait::Bool=false)
    checkconnected(stage)
    length(distances) == stage.dimensions ||
        throw(ArgumentError("expected $(stage.dimensions) distances, got $(length(distances))"))

    # Validate every axis against its limits before moving any of them.
    targets = ntuple(i -> getaxisposition(stage, i) + distances[i], length(distances))
    for (axis, target) in enumerate(targets)
        lo, hi = positionrange(stage, axis)
        lo <= target <= hi ||
            error("MCS2 relative move would leave axis $(("x", "y", "z")[axis]) at " *
                  "$(target) um, outside the travel limits ($lo, $hi) um")
    end

    for (axis, distance) in enumerate(distances)
        channel = channelof(stage, axis)
        set_i32(stage.id, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_RELATIVE)
        movecommand(stage.id, channel, um2pm(distance))
        settarget!(stage, axis, targets[axis])
    end
    wait && waitformotion(stage)
    return stage
end

# --- Referencing and calibration --------------------------------------------

"""
    findreference(stage; wait=true, autozero=false, reverse=false)

Run the referencing sequence on every axis so the controller knows where it is
in absolute terms.

**This moves the stage.** The positioners use incremental sensors, so this has
to run once after each controller power cycle before closed-loop moves are
meaningful. Make sure the stage can travel freely - the sequence drives until
it finds the reference mark.

- `autozero=true` sets the position to zero at the reference mark, otherwise
  the controller's stored scale offset applies.
- `reverse=true` searches in the negative direction first.
- `wait=false` returns as soon as the sequence is started.
"""
function findreference(stage::MCS2Stage; wait::Bool=true, autozero::Bool=false,
    reverse::Bool=false)
    checkconnected(stage)
    options = Int32(0)
    autozero && (options |= SA_CTL_REF_OPT_BIT_AUTO_ZERO)
    reverse && (options |= SA_CTL_REF_OPT_BIT_START_DIR)

    for axis in stageaxes(stage)
        channel = channelof(stage, axis)
        set_i32(stage.id, channel, SA_CTL_PKEY_REFERENCING_OPTIONS, options)
        referencecommand(stage.id, channel)
    end
    @info "MCS2 referencing sequence started on $(stage.dimensions) axes"

    if wait
        waitformotion(stage)
        updatestatus!(stage)
        getposition(stage)
        all(stage.referenced[stageaxes(stage)]) ||
            @warn "MCS2 referencing finished but not every axis reports isReferenced" stage.referenced
    end
    return stage
end

"""
    calibrate(stage; wait=true)

Run the calibration sequence on every axis, which measures the sensor
characteristics and stores the result in the controller's non-volatile memory.

**This moves the stage by up to several mm**, so do not start it near an end
stop. Calibration only needs repeating when the mechanical setup changes (a
different positioner, or a change of positioner type); the result survives a
power cycle. Check [`iscalibrated`](@ref) to see whether it is needed.
"""
function calibrate(stage::MCS2Stage; wait::Bool=true)
    checkconnected(stage)
    for axis in stageaxes(stage)
        channel = channelof(stage, axis)
        set_i32(stage.id, channel, SA_CTL_PKEY_CALIBRATION_OPTIONS, Int32(0))
        calibratecommand(stage.id, channel)
    end
    @info "MCS2 calibration sequence started on $(stage.dimensions) axes"

    if wait
        waitformotion(stage)
        updatestatus!(stage)
    end
    return stage
end

# --- Motion configuration ----------------------------------------------------

"""
    setvelocity!(stage, velocity; axis=nothing)

Set the closed-loop move velocity in microns/second, for one axis or for all of
them. A velocity of `0` disables velocity control, letting the positioner move
as fast as it can.
"""
function setvelocity!(stage::MCS2Stage, velocity::Real; axis=nothing)
    checkconnected(stage)
    velocity >= 0 || throw(ArgumentError("velocity must be non-negative"))
    for i in (axis === nothing ? stageaxes(stage) : (axisindex(axis),))
        checkaxis(stage, i)
        set_i64(stage.id, channelof(stage, i), SA_CTL_PKEY_MOVE_VELOCITY, um2pm(velocity))
        stage.velocity[i] = Float64(velocity)
    end
    return stage
end

"""
    setacceleration!(stage, acceleration; axis=nothing)

Set the closed-loop move acceleration in microns/second^2, for one axis or for
all of them. An acceleration of `0` disables acceleration control.
"""
function setacceleration!(stage::MCS2Stage, acceleration::Real; axis=nothing)
    checkconnected(stage)
    acceleration >= 0 || throw(ArgumentError("acceleration must be non-negative"))
    for i in (axis === nothing ? stageaxes(stage) : (axisindex(axis),))
        checkaxis(stage, i)
        set_i64(stage.id, channelof(stage, i), SA_CTL_PKEY_MOVE_ACCELERATION, um2pm(acceleration))
        stage.acceleration[i] = Float64(acceleration)
    end
    return stage
end

"""
    setholdtime!(stage, milliseconds; axis=nothing)

How long the controller actively holds position after reaching a target.
`0` disables holding, `-1` (`SA_CTL_INFINITE`) holds until [`stopmotion`](@ref).

This property is not persistent - the controller resets it at power-up, and
`initialize` reapplies `stage.holdtime`.
"""
function setholdtime!(stage::MCS2Stage, milliseconds::Integer; axis=nothing)
    checkconnected(stage)
    for i in (axis === nothing ? stageaxes(stage) : (axisindex(axis),))
        checkaxis(stage, i)
        set_i32(stage.id, channelof(stage, i), SA_CTL_PKEY_HOLD_TIME, milliseconds)
    end
    stage.holdtime = Int(milliseconds)
    return stage
end

"""
    setrangelimits!(stage, axis, (min, max))

Write software travel limits, in microns, into the controller for `axis` and
mirror them into `stage.range_*`. The controller then refuses closed-loop
targets outside the limits itself, which protects the stage even when it is
driven from something other than this driver.

Pass `(0, 0)` to disable the controller-side limit; the Julia-side check in
`stage.range_*` still applies.
"""
function setrangelimits!(stage::MCS2Stage, axis, range::Tuple{Real,Real})
    checkconnected(stage)
    idx = axisindex(axis)
    checkaxis(stage, idx)
    range[1] <= range[2] ||
        throw(ArgumentError("range minimum must not exceed the maximum"))
    channel = channelof(stage, idx)
    set_i64(stage.id, channel, SA_CTL_PKEY_RANGE_LIMIT_MIN, um2pm(range[1]))
    set_i64(stage.id, channel, SA_CTL_PKEY_RANGE_LIMIT_MAX, um2pm(range[2]))
    setpositionrange!(stage, idx, range)
    return stage
end

"""
    getrangelimits(stage, axis) -> Tuple{Float64,Float64}

Software travel limits currently configured in the controller for `axis`, in
microns. `(0.0, 0.0)` means no controller-side limit is set.
"""
function getrangelimits(stage::MCS2Stage, axis)
    checkconnected(stage)
    idx = axisindex(axis)
    checkaxis(stage, idx)
    channel = channelof(stage, idx)
    return (pm2um(get_i64(stage.id, channel, SA_CTL_PKEY_RANGE_LIMIT_MIN)),
        pm2um(get_i64(stage.id, channel, SA_CTL_PKEY_RANGE_LIMIT_MAX)))
end

"""
    setactuatormode!(stage, mode; axis=nothing)

Select the actuator drive mode for stick-slip positioners:
`SA_CTL_ACTUATOR_MODE_NORMAL`, `SA_CTL_ACTUATOR_MODE_QUIET` (much less audible
noise, lower speed) or `SA_CTL_ACTUATOR_MODE_LOW_VIBRATION`.
"""
function setactuatormode!(stage::MCS2Stage, mode::Integer; axis=nothing)
    checkconnected(stage)
    for i in (axis === nothing ? stageaxes(stage) : (axisindex(axis),))
        checkaxis(stage, i)
        set_i32(stage.id, channelof(stage, i), SA_CTL_PKEY_ACTUATOR_MODE, mode)
    end
    return stage
end

"""
    zeroposition!(stage; axis=nothing)

Define the current position as zero by adjusting the controller's logical scale
offset. Useful for setting a sample-relative origin after referencing.

The offset is stored in the controller, so it survives a power cycle and
applies to the next referencing run as well.
"""
function zeroposition!(stage::MCS2Stage; axis=nothing)
    checkconnected(stage)
    for i in (axis === nothing ? stageaxes(stage) : (axisindex(axis),))
        checkaxis(stage, i)
        channel = channelof(stage, i)
        offset = get_i64(stage.id, channel, SA_CTL_PKEY_LOGICAL_SCALE_OFFSET)
        position = get_i64(stage.id, channel, SA_CTL_PKEY_POSITION)
        set_i64(stage.id, channel, SA_CTL_PKEY_LOGICAL_SCALE_OFFSET, offset - position)
        setcachedposition!(stage, i, 0.0)
        settarget!(stage, i, 0.0)
    end
    return stage
end
