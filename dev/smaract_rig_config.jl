# Shared SmarAct MCS2 rig constants for the dev scripts.
#
# One definition of the travel window, so the smoke test, the driver test and
# the motion characterisation cannot drift apart. Plain constants, no package
# dependency — `include` it from any of them.

const RIG_X_CHANNEL = Int32(0)
const RIG_Y_CHANNEL = Int32(1)

# ---------------------------------------------------------------------------
# Safe working window, µm — PROVISIONAL
#
# These are NOT the vendor travel spec. They are the largest window that every
# observation to date agrees is reachable, and they are deliberately
# pessimistic. Replace them with the real figures from
# `D:\Positioners\OperationParameters\Operation_Parameters_101-110-002740.pdf`
# as soon as someone reads it.
#
# Why they are not simply the end-stop scan results:
#
#   2026-09-23  scan reported   X -261.2 … +186.6, Y -294.5 … +177.3 µm
#   2026-09-24  X actually stopped as early as -225.8 and +181.7 µm, then
#               crept to -244.2 and +223.1 over repeated attempts
#
# The stop is not at a repeatable position — a stick-slip actuator driven into
# it forces its way further each time, and every such move set MOVEMENT_FAILED
# alongside END_STOP_REACHED, meaning the closed loop gave up rather than
# arriving anywhere. So the scan measures how hard it was pushed, not where
# the stage ends.
#
# X: earliest stop actually observed (-225.8, +181.7), inset 10 µm.
# Y: never re-tested, so the X discrepancy (35.4 µm low side, 4.9 µm high
#    side) is applied to the Y scan figures, then inset 10 µm.
const RIG_SAFE_WINDOW_UM = (X = (-215.0, 171.0),
                            Y = (-249.0, 162.0))

rig_window_um(axis::Symbol) = RIG_SAFE_WINDOW_UM[axis]
rig_window_pm(axis::Symbol) = round.(Int64, RIG_SAFE_WINDOW_UM[axis] .* 1e6)

"Axis symbol (:X / :Y) for a 1-based stage channel index."
rig_axis(i::Integer) = i == 1 ? :X : i == 2 ? :Y : error("No axis mapping for channel index $i")
