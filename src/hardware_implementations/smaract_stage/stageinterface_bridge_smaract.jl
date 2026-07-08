
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

    # Sync servostatus (closed-loop on/off) from the actual hardware state
    stage.servostatus[1] = _get_i32(stage, stage.channel_ids[1], SA_CTL_PKEY_CONTROL_LOOP_INPUT) != SA_CTL_CONTROL_LOOP_INPUT_DISABLED
    stage.servostatus[2] = _get_i32(stage, stage.channel_ids[2], SA_CTL_PKEY_CONTROL_LOOP_INPUT) != SA_CTL_CONTROL_LOOP_INPUT_DISABLED
end

"""
    shutdown(stage::MCS2Stage)

Generic-interface entry point; thin wrapper around `shutdown!(stage)`.
"""
function shutdown(stage::MCS2Stage)
    shutdown!(stage)
end

"""
    StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64)

x, y are target positions in micrometres. Converts to picometres, moves
channels 1 and 2 (leaving any other channel where it is), and updates the
Float64 target fields the gui displays.
"""
function StageInterface.move(stage::MCS2Stage, x::Float64, y::Float64)
    targets_pm    = copy(stage.pos_pm)
    targets_pm[1] = round(Int64, x * PM_PER_UM)
    targets_pm[2] = round(Int64, y * PM_PER_UM)

    move!(stage, targets_pm)

    stage.targ_x = x
    stage.targ_y = y
    stage.real_x = stage.pos_pm[1] / PM_PER_UM
    stage.real_y = stage.pos_pm[2] / PM_PER_UM
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
    StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool)

MCS2 has no literal "servo" concept, but SA_CTL_PKEY_CONTROL_LOOP_INPUT is
functionally equivalent: SENSOR = closed-loop position control ("servo on"),
DISABLED = open-loop ("servo off"). Toggles channels 1 (X) and 2 (Y)
independently and updates `stage.servostatus` so the gui button reflects it.
"""
function StageInterface.servo(stage::MCS2Stage, xtoggle::Bool, ytoggle::Bool)
    ch_x = stage.channel_ids[1]
    ch_y = stage.channel_ids[2]

    _set_i32(stage, ch_x, SA_CTL_PKEY_CONTROL_LOOP_INPUT,
             xtoggle ? Int32(SA_CTL_CONTROL_LOOP_INPUT_SENSOR) : Int32(SA_CTL_CONTROL_LOOP_INPUT_DISABLED))
    _set_i32(stage, ch_y, SA_CTL_PKEY_CONTROL_LOOP_INPUT,
             ytoggle ? Int32(SA_CTL_CONTROL_LOOP_INPUT_SENSOR) : Int32(SA_CTL_CONTROL_LOOP_INPUT_DISABLED))

    stage.servostatus[1] = xtoggle
    stage.servostatus[2] = ytoggle
end