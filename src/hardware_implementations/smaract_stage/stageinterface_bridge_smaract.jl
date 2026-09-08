const PM_PER_UM = 1e6

"""
    initialize(stage::MCS2Stage)

Generic-interface entry point. Calls the existing `initialize!(stage)`,
then populates the Float64 µm fields (`real_x/y`, `targ_x/y`, `range_x/y`)
that the shared gui expects.
"""
function initialize(stage::MCS2Stage)
    initialize!(stage)

    stage.range_x = (stage.min_pm[1] / PM_PER_UM, stage.max_pm[1] / PM_PER_UM)
    stage.range_y = (stage.min_pm[2] / PM_PER_UM, stage.max_pm[2] / PM_PER_UM)
    if stage.n_channels >= 3
        stage.range_z = (stage.min_pm[3] / PM_PER_UM, stage.max_pm[3] / PM_PER_UM)
    end

    getposition(stage)   # sync real_x/real_y from the freshly-queried pos_pm
    stage.targ_x, stage.targ_y = stage.real_x, stage.real_y
    if stage.n_channels >= 3
        stage.targ_z = stage.real_z
    end

    # Sync servostatus (closed-loop on/off) from the actual hardware state,
    # for every connected channel (skip channels with no positioner)
    for i in 1:stage.n_channels
        stage.connected[i] || continue
        stage.servostatus[i] = _get_i32(stage, stage.channel_ids[i], SA_CTL_PKEY_CONTROL_LOOP_INPUT) != SA_CTL_CONTROL_LOOP_INPUT_DISABLED
    end
end

"""
    shutdown(stage::MCS2Stage)

Generic-interface entry point; thin wrapper around `shutdown!(stage)`.
"""
function shutdown(stage::MCS2Stage)
    shutdown!(stage)
end

"""
    _apply_move!(stage::MCS2Stage, targets_um::Vector{Float64})

Shared implementation behind both `StageInterface.move` methods below.
`targets_um[i]` corresponds to `stage.channel_ids[i]`, in micrometres.
Channels with no positioner attached (`stage.connected[i] == false`) keep
their current position — same "skip disconnected channels" convention as
`_apply_servo!` and the rest of helper_smaract.jl.
"""
function _apply_move!(stage::MCS2Stage, targets_um::Vector{Float64})
    targets_pm = copy(stage.pos_pm)

    for i in eachindex(targets_um)
        stage.connected[i] || continue   # skip channels with no positioner
        targets_pm[i] = round(Int64, targets_um[i] * PM_PER_UM)
    end

    move!(stage, targets_pm)

    if stage.connected[1]
        stage.targ_x = targets_um[1]
        stage.real_x = stage.pos_pm[1] / PM_PER_UM
    end
    if stage.connected[2]
        stage.targ_y = targets_um[2]
        stage.real_y = stage.pos_pm[2] / PM_PER_UM
    end
    if length(targets_um) >= 3 && stage.connected[3]
        stage.targ_z = targets_um[3]
        stage.real_z = stage.pos_pm[3] / PM_PER_UM
    end
end

"""
    StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64)

Used by gui2d. x, y in micrometres. See `_apply_move!`.
"""
function StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64)
    _apply_move!(stage, Float64[x, y])
end

"""
    StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64, z::Float64)

Used by gui3d (the one your 3-channel stage's gui actually calls, since
`stage.dimensions == 3` routes it through gui3d). x, y, z in micrometres.
See `_apply_move!`.
"""
function StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64, z::Float64)
    _apply_move!(stage, Float64[x, y, z])
end

"""
    StageInterface.getposition(stage::MCS2Stage)

Refreshes `stage.pos_pm` from the hardware and mirrors channels 1/2 (and 3,
if present) into `real_x`/`real_y`/`real_z` (µm).
"""
function StageInterface.getposition(stage::MCS2Stage)
    getposition!(stage)

    stage.real_x = stage.pos_pm[1] / PM_PER_UM
    stage.real_y = stage.pos_pm[2] / PM_PER_UM
    if stage.n_channels >= 3
        stage.real_z = stage.pos_pm[3] / PM_PER_UM
    end
end

"""
    StageInterface.stopmotion(stage::MCS2Stage)

Thin wrapper around `stopmotion!(stage)`.
"""
function StageInterface.stopmotion(stage::MCS2Stage)
    stopmotion!(stage)
end

"""
    StageInterface.home(stage::MCS2Stage)

Thin wrapper around `home!(stage)`; syncs `targ_x`/`targ_y` (and `targ_z`,
if a third channel exists) to the configured home position afterwards.
"""
function StageInterface.home(stage::MCS2Stage)
    home!(stage)

    stage.targ_x = stage.home_pm[1] / PM_PER_UM
    stage.targ_y = stage.home_pm[2] / PM_PER_UM
    if stage.n_channels >= 3
        stage.targ_z = stage.home_pm[3] / PM_PER_UM
    end

    getposition(stage)   # refresh real_x/real_y once the move settles
end

"""
    _apply_servo!(stage::MCS2Stage, toggles::Vector{Bool})

Shared implementation behind both `StageInterface.servo` methods below.
`toggles[i]` corresponds to `stage.channel_ids[i]`. Channels with no
positioner physically attached (`stage.connected[i] == false`, populated
from the real CHANNEL_STATE query during `initialize!`) are silently
skipped — same "skip disconnected channels" convention already used
throughout helper_smaract.jl (move_all!, stop_all!, etc.), rather than
forcing a fixed dimensionality on the stage.
"""
function _apply_servo!(stage::MCS2Stage, toggles::Vector{Bool})
    for i in eachindex(toggles)
        stage.connected[i] || continue   # skip channels with no positioner

        ch = stage.channel_ids[i]
        _set_i32(stage, ch, SA_CTL_PKEY_CONTROL_LOOP_INPUT,
                 toggles[i] ? Int32(SA_CTL_CONTROL_LOOP_INPUT_SENSOR) : Int32(SA_CTL_CONTROL_LOOP_INPUT_DISABLED))

        stage.servostatus[i] = toggles[i]
    end
end

"""
    StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool)

Used by gui2d. See `_apply_servo!` — channels with no positioner attached
are skipped automatically.
"""
function StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool)
    _apply_servo!(stage, Bool[xtoggle, ytoggle])
end

"""
    StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)

Used by gui3d (this is the one your 3-channel stage's gui actually calls,
since `stage.dimensions == 3` routes it through gui3d). See `_apply_servo!`
— channels with no positioner attached are skipped automatically.
"""
function StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool, ztoggle::Bool)
    _apply_servo!(stage, Bool[xtoggle, ytoggle, ztoggle])
end