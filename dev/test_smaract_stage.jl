using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))
using MicroscopeControl

include(joinpath(@__DIR__, "smaract_rig_config.jl"))
const M = MicroscopeControl.HardwareImplementations.MCS2Stage_mod

stage = MCS2Stage(
    stagelabel = "SmarAct MCS2",
    n_channels = 3,
    channel_ids = Int32[0, 1, 2],
)

# initialize does NOT move the stage: it opens the device, reads the channel
# count, sets amplifier parameters, reads travel limits and queries state.
initialize(stage)

# Referencing is lost on a controller power cycle, and an unreferenced channel
# reports positions against an arbitrary zero — absolute moves made on that
# assumption can drive straight into an end stop. Check before commanding.
if !all(stage.is_referenced[stage.connected])
    @warn "Not all connected channels are referenced: $(stage.is_referenced). " *
          "Reference them before commanding absolute moves."
end

# Range limits are volatile — the controller forgets them on a power cycle and
# initialize! only reads them back, so whatever the last session wrote is still
# in there. Write the rig's safe window to the controller, then mirror it into
# the µm fields the GUI uses for its bounds.
for (i, axis) in ((1, :X), (2, :Y))
    stage.connected[i] || continue
    lo_pm, hi_pm = rig_window_pm(axis)
    M.set_range_limits!(stage, i, lo_pm, hi_pm)
end

stage.range_x = rig_window_um(:X)
stage.range_y = rig_window_um(:Y)

# move_um!(stage, [10.0, 5.0, 0.0])

# Opening the GUI is deliberately left to the caller — run this file to set the
# stage up, then open the panel by hand once the limits above look right:
#
#   MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)
#
# (qualified because `gui` is ambiguous at the top level — each hardware
# interface defines its own).
