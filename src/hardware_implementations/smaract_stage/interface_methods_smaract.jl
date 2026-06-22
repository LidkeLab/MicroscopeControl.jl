#   initialize(stage)    → find USB device, connect, set reference,
#                          query limits, set velocity
#   shutdown(stage)      → disconnect if connected
#   move(stage, pos)     → absolute move + getposition
#   getposition(stage)   → query POS and update stage.pos
#   home(stage)          → move to homepos
#   stopmotion(stage)    → halt
#   export_state(stage)  → return Dict of all state for logging/saving

"""
    initialize!(stage::MCS2Stage)

Discovers the first available MCS2 device, opens it, configures all
channels (CLF, hold time, velocity, acceleration), and reads travel limits.

After this call, `stage.connectionstatus == true` and `stage.pos_pm` holds
the current hardware positions.
"""
function initialize!(stage::MCS2Stage)
    if stage.connectionstatus
        @error "Stage already initialized — call shutdown!(stage) first."
        return
    end

    # Find devices 
    bufsize = 1024
    device_buf = Vector{Cchar}(undef, bufsize)
    device_len = Ref{Csize_t}(bufsize)

    result = SA_CTL_FindDevices("", device_buf, device_len)
    if result != SA_CTL_ERROR_NONE
        @error "SA_CTL_FindDevices failed: $(unsafe_string(SA_CTL_GetResultInfo(result)))"
        return
    end

    locator = unsafe_string(pointer(device_buf))
    if isempty(locator)
        @error "No SmarAct MCS2 devices found.  Check USB/Ethernet connection."
        return
    end
    @info "Device found: $locator"

    # Open device
    result = SA_CTL_Open(stage.dHandle, locator, C_NULL)
    if result != SA_CTL_ERROR_NONE
        @error "SA_CTL_Open failed: $(unsafe_string(SA_CTL_GetResultInfo(result)))"
        return
    end
    stage.connectionstatus = true
    @info "Device opened.  Handle: $(stage.dHandle[])"

    # Read actual channel count and trim struct if needed
    n_ch_ref = Ref{Int32}()
    SA_CTL_GetProperty_i32(stage.dHandle[], Int32(0),
                           SA_CTL_PKEY_NUMBER_OF_CHANNELS, n_ch_ref, Ref{Csize_t}(1))
    hw_channels = Int(n_ch_ref[])
    if hw_channels < stage.n_channels
        @warn "Device has $hw_channels channels; stage configured for $(stage.n_channels). Truncating."
        stage.n_channels  = hw_channels
        resize!(stage.channel_ids,  hw_channels)
        resize!(stage.pos_pm,       hw_channels)
        resize!(stage.min_pm,       hw_channels)
        resize!(stage.max_pm,       hw_channels)
        resize!(stage.home_pm,      hw_channels)
        resize!(stage.velocity_pm_s, hw_channels)
        resize!(stage.accel_pm_s2,  hw_channels)
        resize!(stage.is_calibrated, hw_channels)
        resize!(stage.is_referenced, hw_channels)
        resize!(stage.connected,     hw_channels)
    end

    # Per-channel setup 
    for (i, ch) in enumerate(stage.channel_ids)
        # Detect whether a positioner is physically attached
        ch_state = Ref{Int32}()
        state_result = SA_CTL_GetProperty_i32(stage.dHandle[], ch,
                               SA_CTL_PKEY_CHANNEL_STATE, ch_state, Ref{Csize_t}(1))
        if state_result != SA_CTL_ERROR_NONE
            @warn "Channel $ch: could not read CHANNEL_STATE ($(unsafe_string(SA_CTL_GetResultInfo(state_result)))) — marking as not connected."
            stage.connected[i] = false
            continue
        end
        sensor_present = (ch_state[] & SA_CTL_CH_STATE_BIT_SENSOR_PRESENT) != 0
        stage.connected[i] = sensor_present

        if !sensor_present
            @info "Channel $ch: no positioner detected — skipping motion setup. (Shown as N/C in GUI.)"
            continue
        end

        # Amplifier-side settings (safe to set; channel is connected)
        try
            SA_CTL_SetProperty_i32(stage.dHandle[], ch,
                                   SA_CTL_PKEY_MAX_CL_FREQUENCY, Int32(6000))
            SA_CTL_SetProperty_i32(stage.dHandle[], ch,
                                   SA_CTL_PKEY_HOLD_TIME, Int32(1000))
            SA_CTL_SetProperty_i64(stage.dHandle[], ch,
                                   SA_CTL_PKEY_MOVE_VELOCITY,     stage.velocity_pm_s[i])
            SA_CTL_SetProperty_i64(stage.dHandle[], ch,
                                   SA_CTL_PKEY_MOVE_ACCELERATION, stage.accel_pm_s2[i])
        catch e
            @warn "Channel $ch: failed to set motion parameters ($e). Marking as not connected."
            stage.connected[i] = false
            continue
        end

        # Travel limits (sensor-dependent; only read if sensor present) 
        lim_min = Ref{Int64}()
        lim_max = Ref{Int64}()
        r1 = SA_CTL_GetProperty_i64(stage.dHandle[], ch,
                               SA_CTL_PKEY_RANGE_LIMIT_MIN, lim_min, Ref{Csize_t}(1))
        r2 = SA_CTL_GetProperty_i64(stage.dHandle[], ch,
                               SA_CTL_PKEY_RANGE_LIMIT_MAX, lim_max, Ref{Csize_t}(1))
        if r1 == SA_CTL_ERROR_NONE && r2 == SA_CTL_ERROR_NONE
            stage.min_pm[i] = lim_min[]
            stage.max_pm[i] = lim_max[]
        else
            @warn "Channel $ch: could not read travel range — leaving default limits."
        end
    end

    # Query initial positions and state
    query_positions!(stage)
    query_channel_states!(stage)

    @info "$(stage.stagelabel) initialized ($(stage.n_channels) channel(s))."
end


"""
    shutdown!(stage::MCS2Stage)

Closes the device connection.  Safe to call even if not connected.
"""
function shutdown!(stage::MCS2Stage)
    if !stage.connectionstatus
        @info "Stage not connected — nothing to shut down."
        return
    end
    result = SA_CTL_Close(stage.dHandle[])
    if result != SA_CTL_ERROR_NONE
        @warn "SA_CTL_Close error: $(unsafe_string(SA_CTL_GetResultInfo(result)))"
    else
        @info "$(stage.stagelabel) disconnected."
    end
    stage.connectionstatus = false
end


"""
    move!(stage, targets_pm::Vector{Int64})

Moves all channels to absolute positions given in picometres, then
refreshes `stage.pos_pm`.
"""
function move!(stage::MCS2Stage, targets_pm::Vector{Int64})
    move_all!(stage, targets_pm)
    # move_all! already calls query_positions! internally
end

"""
    move_um!(stage, targets_um::Vector{Float64})

Convenience overload: supply positions in micrometres (Float64).
Internally converts to Int64 picometres.
"""
function move_um!(stage::MCS2Stage, targets_um::Vector{Float64})
    targets_pm = round.(Int64, targets_um .* 1e6)
    move!(stage, targets_pm)
end


"""
    getposition!(stage) -> Vector{Int64}

Queries the current position of all channels, updates `stage.pos_pm`,
and returns the values in picometres.
"""
function getposition!(stage::MCS2Stage) :: Vector{Int64}
    query_positions!(stage)
    return copy(stage.pos_pm)
end


"""
    home!(stage)

Moves all channels to `stage.home_pm` (default: all zeros).
"""
function home!(stage::MCS2Stage)
    @info "Moving to home position ..."
    move!(stage, stage.home_pm)
end 


"""
    stopmotion!(stage)

Immediately stops all channels.
"""
function stopmotion!(stage::MCS2Stage)
    stop_all!(stage)
end


"""
    export_state(stage::MCS2Stage) -> (attributes, data, children)

Returns a tuple of (Dict, nothing, Dict) for compatibility with the
MicroscopeControl state serialisation convention used by the PI module.
"""
function export_state(stage::MCS2Stage)
    attributes = Dict{String, Any}(
        "stage_label"     => stage.stagelabel,
        "n_channels"      => stage.n_channels,
        "channel_ids"     => copy(stage.channel_ids),
        "connected"       => stage.connectionstatus,
        "handle"          => stage.dHandle[],
        "position_pm"     => copy(stage.pos_pm),
        "position_um"     => stage.pos_pm ./ 1e6,
        "min_pm"          => copy(stage.min_pm),
        "max_pm"          => copy(stage.max_pm),
        "home_pm"         => copy(stage.home_pm),
        "velocity_pm_s"   => copy(stage.velocity_pm_s),
        "accel_pm_s2"     => copy(stage.accel_pm_s2),
        "is_calibrated"   => copy(stage.is_calibrated),
        "is_referenced"   => copy(stage.is_referenced),
    )
    return attributes, nothing, Dict{String,Any}()
end
