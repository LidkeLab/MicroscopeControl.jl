#=
StageInterface implementation for the SmarAct MCS2.

These are the methods the rest of MicroscopeControl (and the stage GUI) calls;
the MCS2-specific extras live in movement.jl and device_information.jl.
=#

"""
    initialize(stage::MCS2Stage) -> MCS2Stage

Open a connection to the MCS2 controller and apply the motion settings held on
`stage`.

If `stage.locator` is empty the first controller returned by
[`findmcs2devices`](@ref) is used, and the locator actually used is written
back to `stage.locator`.

Initialization never moves the stage. Because the position sensors are
incremental, the axes have no absolute position after a controller power cycle;
a warning is emitted in that case and [`findreference`](@ref) has to be run
before closed-loop moves mean anything.

Per axis this sets the move mode to closed-loop absolute, applies
`stage.velocity` and `stage.acceleration`, and - for stick-slip positioners -
`stage.maxclfrequency` and `stage.holdtime`, neither of which the controller
retains across a power cycle. Software travel limits configured in the
controller are read back into `stage.range_*`.
"""
function initialize(stage::MCS2Stage)
    if stage.connectionstatus
        @warn "MCS2 stage is already connected; call shutdown(stage) first"
        return stage
    end

    locator = stage.locator
    if isempty(locator)
        available = finddevices()
        isempty(available) && error(
            "No MCS2 controller found. Check that it is powered on and connected, " *
            "then try findmcs2devices().")
        length(available) > 1 &&
            @info "Several MCS2 controllers found, using the first" available
        locator = first(available)
    end

    stage.id = opendevice(locator)
    stage.locator = locator
    stage.connectionstatus = true
    @info "MCS2 connected" locator device = devicename(stage) serial = serialnumber(stage)

    try
        available = numchannels(stage)
        maximum(stage.channels[stageaxes(stage)]) < available || error(
            "Stage is configured for channels $(stage.channels[stageaxes(stage)]) but the " *
            "controller only provides $available channel(s) (0 to $(available - 1))")

        for axis in stageaxes(stage)
            configureaxis!(stage, axis)
        end

        updatestatus!(stage)
        getposition(stage)

        unreferenced = [axis for axis in stageaxes(stage) if !stage.referenced[axis]]
        isempty(unreferenced) || @warn(
            "MCS2 axes $(join(("x", "y", "z")[unreferenced], ", ")) are not referenced; " *
            "positions are relative to power-up. Run findreference(stage) - this moves the stage.")
    catch
        # Do not leave a half-configured device open.
        closedevice(stage.id)
        stage.connectionstatus = false
        rethrow()
    end

    return stage
end

"""
    configureaxis!(stage, axis)

Apply the per-axis settings held on `stage` to the controller. Called by
[`initialize`](@ref) for each axis.
"""
function configureaxis!(stage::MCS2Stage, axis::Integer)
    channel = channelof(stage, axis)
    state = channelstate(stage, axis)

    state & SA_CTL_CH_STATE_BIT_SENSOR_PRESENT != 0 || @warn(
        "MCS2 channel $channel reports no position sensor; closed-loop moves will fail")

    baseunit = get_i32(stage.id, channel, SA_CTL_PKEY_POS_BASE_UNIT)
    baseunit == SA_CTL_UNIT_METER || @warn(
        "MCS2 channel $channel is not a linear positioner (base unit $baseunit); " *
        "this driver assumes positions are in picometres")

    type = get_i32(stage.id, channel, SA_CTL_PKEY_CHANNEL_TYPE)
    if type == SA_CTL_STICK_SLIP_PIEZO_DRIVER
        # Neither property is persistent, so they are reapplied on every connect.
        set_i32(stage.id, channel, SA_CTL_PKEY_MAX_CL_FREQUENCY, stage.maxclfrequency)
        set_i32(stage.id, channel, SA_CTL_PKEY_HOLD_TIME, stage.holdtime)
    elseif type == SA_CTL_PIEZO_SCANNER_DRIVER || type == SA_CTL_MAGNETIC_DRIVER
        set_i32(stage.id, channel, SA_CTL_PKEY_AMPLIFIER_ENABLED, SA_CTL_TRUE)
        type == SA_CTL_PIEZO_SCANNER_DRIVER &&
            set_i32(stage.id, channel, SA_CTL_PKEY_HOLD_TIME, stage.holdtime)
    end

    set_i32(stage.id, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_ABSOLUTE)
    set_i64(stage.id, channel, SA_CTL_PKEY_MOVE_VELOCITY, um2pm(stage.velocity[axis]))
    set_i64(stage.id, channel, SA_CTL_PKEY_MOVE_ACCELERATION, um2pm(stage.acceleration[axis]))

    # Prefer travel limits the controller already knows about over the defaults.
    limits = getrangelimits(stage, axis)
    limits[1] < limits[2] && setpositionrange!(stage, axis, limits)

    return stage
end

"""
    shutdown(stage::MCS2Stage)

Stop any motion and close the connection to the controller. The positioners
hold their mechanical position when de-energised, so this does not move the
stage.
"""
function shutdown(stage::MCS2Stage)
    stage.connectionstatus || return nothing
    try
        for axis in stageaxes(stage)
            stopcommand(stage.id, channelof(stage, axis))
        end
    catch err
        @warn "MCS2 failed to stop motion during shutdown" exception = err
    end
    closedevice(stage.id)
    stage.connectionstatus = false
    stage.id = UInt32(0)
    @info "MCS2 disconnected"
    return nothing
end

"""
    move(stage::MCS2Stage, x, y; wait=false)
    move(stage::MCS2Stage, x, y, z; wait=false)

Closed-loop absolute move to the given position in microns.

The command returns as soon as the controller has accepted it. Pass
`wait=true`, or call [`waitformotion`](@ref), to block until the stage has
settled.

Targets outside `stage.range_*` are rejected before anything is sent, and no
axis moves if any target is out of range.
"""
function StageInterface.move(stage::MCS2Stage, x::Real, y::Real; wait::Bool=false)
    stage.dimensions == 2 ||
        throw(ArgumentError("stage has $(stage.dimensions) axes; pass one target per axis"))
    return movetargets(stage, (Float64(x), Float64(y)); wait)
end

function StageInterface.move(stage::MCS2Stage, x::Real, y::Real, z::Real; wait::Bool=false)
    stage.dimensions == 3 ||
        throw(ArgumentError("stage has $(stage.dimensions) axes; pass one target per axis"))
    return movetargets(stage, (Float64(x), Float64(y), Float64(z)); wait)
end

# The StageInterface stub is declared as move(::Stage, ::Float64, ::Float64, ::Float64),
# which is neither more nor less specific than the Real method above; this exact
# signature resolves the ambiguity for the all-Float64 call the GUI makes.
function StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64, z::Float64; wait::Bool=false)
    stage.dimensions == 3 ||
        throw(ArgumentError("stage has $(stage.dimensions) axes; pass one target per axis"))
    return movetargets(stage, (x, y, z); wait)
end

function StageInterface.move(stage::MCS2Stage, x::Real; wait::Bool=false)
    stage.dimensions == 1 ||
        throw(ArgumentError("stage has $(stage.dimensions) axes; pass one target per axis"))
    return movetargets(stage, (Float64(x),); wait)
end

"Validate every target, then start all axes."
function movetargets(stage::MCS2Stage, targets::Tuple; wait::Bool=false)
    checkconnected(stage)
    for (axis, target) in enumerate(targets)
        checkaxis(stage, axis)
        lo, hi = positionrange(stage, axis)
        lo <= target <= hi || error(
            "MCS2 target $(target) um is outside the travel limits ($lo, $hi) um " *
            "for axis $(("x", "y", "z")[axis])")
    end

    for (axis, target) in enumerate(targets)
        channel = channelof(stage, axis)
        set_i32(stage.id, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_ABSOLUTE)
        movecommand(stage.id, channel, um2pm(target))
        settarget!(stage, axis, target)
    end

    wait && waitformotion(stage)
    return stage
end

"""
    getposition(stage::MCS2Stage) -> Tuple

Read the current position of every axis, in microns, and update `stage.real_*`.
Returns `(x, y)` for a 2D stage and `(x, y, z)` for a 3D one.
"""
function StageInterface.getposition(stage::MCS2Stage)
    checkconnected(stage)
    return ntuple(axis -> getaxisposition(stage, axis), stage.dimensions)
end

"""
    getrange(stage::MCS2Stage) -> Tuple

Software travel limits per axis, in microns, as `((xmin, xmax), (ymin, ymax))`.

These come from the controller when travel limits are configured there,
otherwise from the defaults on the struct - the MCS2 cannot report the
mechanical travel of a positioner. See [`setrangelimits!`](@ref).
"""
function StageInterface.getrange(stage::MCS2Stage)
    if stage.connectionstatus
        for axis in stageaxes(stage)
            limits = getrangelimits(stage, axis)
            limits[1] < limits[2] && setpositionrange!(stage, axis, limits)
        end
    end
    return ntuple(axis -> positionrange(stage, axis), stage.dimensions)
end

"""
    stopmotion(stage::MCS2Stage)

Stop all axes. With acceleration control enabled the first call decelerates to
a halt; a second call while still moving triggers an emergency stop. This also
releases the position hold started by a closed-loop move.
"""
function StageInterface.stopmotion(stage::MCS2Stage)
    checkconnected(stage)
    for axis in stageaxes(stage)
        stopcommand(stage.id, channelof(stage, axis))
    end
    @info "MCS2 motion stopped"
    return nothing
end

"""
    home(stage::MCS2Stage; wait=false)

Move every axis to position zero, i.e. the origin established by referencing
(and shifted by any [`zeroposition!`](@ref) offset).

This is a normal closed-loop move, not a referencing run - use
[`findreference`](@ref) for that.
"""
function StageInterface.home(stage::MCS2Stage; wait::Bool=false)
    checkconnected(stage)
    updatestatus!(stage)
    all(stage.referenced[stageaxes(stage)]) || @warn(
        "MCS2 stage is not referenced; position zero is wherever the controller powered up")
    return movetargets(stage, ntuple(_ -> 0.0, stage.dimensions); wait)
end

"""
    servo(stage::MCS2Stage, toggles...)

Not applicable: MCS2 closed-loop control is selected per move through the move
mode, and there is no separate servo to switch on or off.
"""
function StageInterface.servo(stage::MCS2Stage, ::Bool, ::Bool)
    @error "$(stage.stagelabel) has no separate servo control; closed loop is selected by the move mode"
end

function StageInterface.servo(stage::MCS2Stage, ::Bool, ::Bool, ::Bool)
    @error "$(stage.stagelabel) has no separate servo control; closed loop is selected by the move mode"
end

"""
    driftcorrection(stage::MCS2Stage, toggles...)

Not applicable: the MCS2 has no drift correction feature.
"""
function StageInterface.driftcorrection(stage::MCS2Stage, ::Bool, ::Bool)
    @error "Drift correction is not supported by $(stage.stagelabel)"
end

function StageInterface.driftcorrection(stage::MCS2Stage, ::Bool, ::Bool, ::Bool)
    @error "Drift correction is not supported by $(stage.stagelabel)"
end

"""
    export_state(stage::MCS2Stage)

Attributes, data and children for HDF5 serialization, per the
`AbstractInstrument` contract.
"""
function export_state(stage::MCS2Stage)
    attributes = Dict{String,Any}(
        "stage_label" => stage.stagelabel,
        "units" => stage.units,
        "locator" => stage.locator,
        "dimensions" => stage.dimensions,
        "channels" => copy(stage.channels),
        "connected" => stage.connectionstatus,
        "position_x" => stage.real_x,
        "position_y" => stage.real_y,
        "target_x" => stage.targ_x,
        "target_y" => stage.targ_y,
        "range_x" => collect(stage.range_x),
        "range_y" => collect(stage.range_y),
        "velocity" => copy(stage.velocity),
        "acceleration" => copy(stage.acceleration),
        "hold_time_ms" => stage.holdtime,
        "max_cl_frequency_hz" => stage.maxclfrequency,
        "referenced" => copy(stage.referenced),
        "calibrated" => copy(stage.calibrated),
    )

    if stage.dimensions == 3
        attributes["position_z"] = stage.real_z
        attributes["target_z"] = stage.targ_z
        attributes["range_z"] = collect(stage.range_z)
    end

    data = nothing
    children = Dict{String,Any}()

    return attributes, data, children
end
