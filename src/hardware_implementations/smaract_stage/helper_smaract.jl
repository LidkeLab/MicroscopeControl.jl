
function _check!(errcode::SA_CTL_Result_t; msg::String = "Operation failed")
    if errcode != SA_CTL_ERROR_NONE
        sdk_msg = unsafe_string(SA_CTL_GetResultInfo(errcode))
        error("$msg  [SDK: $sdk_msg  (0x$(string(errcode, base=16)))]")
    end
end

# Property read/write convenience wrappers
function _get_i32(stage::MCS2Stage, ch::Int32, pkey)
    val = Ref{Int32}()
    _check!(SA_CTL_GetProperty_i32(stage.dHandle[], ch, pkey, val, Ref{Csize_t}(1)),
            msg = "GetProperty_i32 ch=$ch pkey=0x$(string(pkey,base=16))")
    return val[]
end

function _get_i64(stage::MCS2Stage, ch::Int32, pkey)
    val = Ref{Int64}()
    _check!(SA_CTL_GetProperty_i64(stage.dHandle[], ch, pkey, val, Ref{Csize_t}(1)),
            msg = "GetProperty_i64 ch=$ch pkey=0x$(string(pkey,base=16))")
    return val[]
end

function _set_i32(stage::MCS2Stage, ch::Int32, pkey, value::Int32)
    _check!(SA_CTL_SetProperty_i32(stage.dHandle[], ch, pkey, value),
            msg = "SetProperty_i32 ch=$ch pkey=0x$(string(pkey,base=16))")
end

function _set_i64(stage::MCS2Stage, ch::Int32, pkey, value::Int64)
    _check!(SA_CTL_SetProperty_i64(stage.dHandle[], ch, pkey, value),
            msg = "SetProperty_i64 ch=$ch pkey=0x$(string(pkey,base=16))")
end

# Query current position from hardware and update stage struct

function query_positions!(stage::MCS2Stage)
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        stage.pos_pm[i] = _get_i64(stage, ch, SA_CTL_PKEY_POSITION)
    end
    @info "Positions (µm): $(round.(stage.pos_pm ./ 1e6, digits=3))"
end

# Query and cache channel state flags

function query_channel_states!(stage::MCS2Stage)
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        state = _get_i32(stage, ch, SA_CTL_PKEY_CHANNEL_STATE)
        stage.is_calibrated[i] = (state & SA_CTL_CH_STATE_BIT_IS_CALIBRATED) != 0
        stage.is_referenced[i] = (state & SA_CTL_CH_STATE_BIT_IS_REFERENCED)  != 0
    end
end

# Set velocity and acceleration

function set_velocity!(stage::MCS2Stage, vel_pm_s::Int64)
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        _set_i64(stage, ch, SA_CTL_PKEY_MOVE_VELOCITY, vel_pm_s)
        stage.velocity_pm_s[i] = vel_pm_s
    end
    @info "Velocity set to $(vel_pm_s / 1e9) mm/s"
end

function set_acceleration!(stage::MCS2Stage, accel_pm_s2::Int64)
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        _set_i64(stage, ch, SA_CTL_PKEY_MOVE_ACCELERATION, accel_pm_s2)
        stage.accel_pm_s2[i] = accel_pm_s2
    end
    @info "Acceleration set to $(accel_pm_s2 / 1e9) mm/s²"
end

# Referencing

function find_reference!(stage::MCS2Stage, ch_index::Int; timeout_s::Float64 = 60.0)
    ch = stage.channel_ids[ch_index]

    if !stage.connected[ch_index]
        @warn "Channel $ch has no positioner attached — skipping referencing."
        return
    end

    @info "Referencing channel $ch ..."

    # Default referencing options (0 = forward, no special flags)
    _set_i32(stage, ch, SA_CTL_PKEY_REFERENCING_OPTIONS, Int32(0))

    _check!(SA_CTL_Reference(stage.dHandle[], ch, Int32(0)),
            msg = "Failed to start referencing on channel $ch")

    t0 = time()
    while true
        state        = _get_i32(stage, ch, SA_CTL_PKEY_CHANNEL_STATE)
        referencing  = (state & SA_CTL_CH_STATE_BIT_REFERENCING) != 0
        referencing  || break
        time() - t0 > timeout_s && error("Referencing timeout on channel $ch after $(timeout_s)s")
        sleep(0.1)
    end

    stage.is_referenced[ch_index] = true
    @info "Channel $ch referenced."
end

# Absolute move for a single channel

function move_abs!(stage::MCS2Stage, ch_index::Int, target_pm::Int64;
                   timeout_s::Float64 = 30.0)
    ch = stage.channel_ids[ch_index]

    if !stage.connected[ch_index]
        @warn "Channel $ch has no positioner attached — move ignored."
        return
    end

    # Always set MOVE_MODE before moving. Without this the device uses whatever mode was 
    # last active, which could be relative or step mode — leading to completely wrong positions.
    _set_i32(stage, ch, SA_CTL_PKEY_MOVE_MODE, Int32(SA_CTL_MOVE_MODE_CL_ABSOLUTE))

    @info "Moving channel $ch to $(target_pm / 1e6) µm ..."
    _check!(SA_CTL_Move(stage.dHandle[], ch, target_pm, Int32(0)),
            msg = "Move command failed on channel $ch")

    # Poll until not moving
    t0 = time()
    while true
        state  = _get_i32(stage, ch, SA_CTL_PKEY_CHANNEL_STATE)
        moving = (state & SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING) != 0
        moving || break
        if time() - t0 > timeout_s
            SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
            error("Move timeout on channel $ch — stop sent")
        end
        sleep(0.05)
    end

    # Refresh position
    stage.pos_pm[ch_index] = _get_i64(stage, ch, SA_CTL_PKEY_POSITION)
    @info "Channel $ch at $(stage.pos_pm[ch_index] / 1e6) µm"
end


"""
    move_all!(stage, targets_pm)

Sends absolute move commands to all CONNECTED channels simultaneously,
then waits for all of them to finish. `targets_pm` is a vector of Int64
positions, one per channel — entries for disconnected channels (e.g.
channel 2 on an XY-only stage) are simply ignored.
"""
function move_all!(stage::MCS2Stage, targets_pm::Vector{Int64}; timeout_s::Float64 = 30.0)
    length(targets_pm) == stage.n_channels ||
        error("targets_pm length $(length(targets_pm)) ≠ n_channels $(stage.n_channels)")

    # Set mode and fire moves only for connected channels
    moving_channels = Int32[]
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        _set_i32(stage, ch, SA_CTL_PKEY_MOVE_MODE, Int32(SA_CTL_MOVE_MODE_CL_ABSOLUTE))
        _check!(SA_CTL_Move(stage.dHandle[], ch, targets_pm[i], Int32(0)),
                msg = "Move command failed on channel $ch")
        push!(moving_channels, ch)
    end

    # Wait for those channels to finish
    t0 = time()
    @async begin
    while true
        all_done = true
        for ch in moving_channels
            state  = _get_i32(stage, ch, SA_CTL_PKEY_CHANNEL_STATE)
            moving = (state & SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING) != 0
            moving && (all_done = false; break)
        end
        all_done && break
        if time() - t0 > timeout_s
            for ch in moving_channels
                SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
            end
            error("Move-all timeout after $(timeout_s)s — all channels stopped")
        end
        sleep(0.05)
    end
    end
    # Refresh all positions
    query_positions!(stage)
end

# Stop a single channel
"""
    stop_channel!(stage, ch_index)

Immediately stops motion on one channel (1-based index). No-op if the
channel has no positioner attached.
"""
function stop_channel!(stage::MCS2Stage, ch_index::Int)
    stage.connected[ch_index] || return
    ch = stage.channel_ids[ch_index]
    SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
    @info "Stop sent to channel $ch"
end

"""
    stop_all!(stage)

Stops all CONNECTED channels.
"""
function stop_all!(stage::MCS2Stage)
    for (i, ch) in enumerate(stage.channel_ids)
        stage.connected[i] || continue   # skip channels with no positioner
        SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
    end
    @info "Stop sent to all connected channels"
end
 
# Find physical travel range via end-stop detection
"""
    find_travel_range!(stage, ch_index; overshoot_pm=70_000_000_000, timeout_s=60.0)
 
Discovers the PHYSICAL travel range of one channel by driving it to each
mechanical end stop and recording where it actually stops.
 
This is different from `stage.min_pm` / `stage.max_pm`, which are SOFTWARE
limits (see SA_CTL_PKEY_RANGE_LIMIT_MIN/MAX in the manual). By default those
are 0/0 — "no software limit configured" — NOT "zero physical range". The
MCS2 has no limit-switch property to query directly; instead the controller
detects a mechanical end stop *while moving* and sets the
END_STOP_REACHED state bit.

 
"""
function find_travel_range!(stage::MCS2Stage, ch_index::Int;
                            overshoot_pm::Int64 = 70_000_000_000,
                            timeout_s::Float64 = 60.0)
    ch = stage.channel_ids[ch_index]
 
    if !stage.connected[ch_index]
        @warn "Channel $ch has no positioner attached — cannot find travel range."
        return (Int64(0), Int64(0))
    end
    if !stage.is_referenced[ch_index]
        error("Channel $ch is not referenced. Call find_reference!(stage, $ch_index) first.")
    end
 
    # --- Drive to negative end stop ----------------------------------------
    @info "Channel $ch: driving to negative end stop ..."
    _drive_to_endstop!(stage, ch, -overshoot_pm, timeout_s)
    min_pm = _get_i64(stage, ch, SA_CTL_PKEY_POSITION)
    @info "Channel $ch: negative end stop at $(min_pm / 1e6) µm"
 
    # --- Drive to positive end stop ----------------------------------------
    @info "Channel $ch: driving to positive end stop ..."
    _drive_to_endstop!(stage, ch, overshoot_pm, timeout_s)
    max_pm = _get_i64(stage, ch, SA_CTL_PKEY_POSITION)
    @info "Channel $ch: positive end stop at $(max_pm / 1e6) µm"
 
    range_mm = (max_pm - min_pm) / 1e9
    @info "Channel $ch: physical travel range ≈ $(range_mm) mm"
 
    # Update the stage struct with the discovered physical limits.
    stage.min_pm[ch_index] = min_pm
    stage.max_pm[ch_index] = max_pm
 
    return (min_pm, max_pm)
end
 
"""
    _drive_to_endstop!(stage, ch, target_pm, timeout_s)
 
Internal helper for `find_travel_range!`. Sends an absolute move to
`target_pm` (deliberately beyond the real travel range) and waits until
the channel stops — either because it arrived (won't happen here) or
because END_STOP_REACHED / MOVEMENT_FAILED was set.
 
Unlike `move_abs!`, this does NOT treat a stopped/failed move as an error —
hitting the end stop is the expected and desired outcome.
"""
function _drive_to_endstop!(stage::MCS2Stage, ch::Int32, target_pm::Int64, timeout_s::Float64)
    _set_i32(stage, ch, SA_CTL_PKEY_MOVE_MODE, Int32(SA_CTL_MOVE_MODE_CL_ABSOLUTE))
    _check!(SA_CTL_Move(stage.dHandle[], ch, target_pm, Int32(0)),
            msg = "Move command failed on channel $ch")
 
    t0 = time()
    while true
        state  = _get_i32(stage, ch, SA_CTL_PKEY_CHANNEL_STATE)
        moving = (state & SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING) != 0
        moving || break
        if time() - t0 > timeout_s
            SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
            error("Channel $ch: timed out finding end stop after $(timeout_s)s")
        end
        sleep(0.05)
    end
 
    SA_CTL_Stop(stage.dHandle[], ch, Int32(0))
end