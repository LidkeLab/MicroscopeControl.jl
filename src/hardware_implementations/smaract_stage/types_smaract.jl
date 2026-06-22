# types_smaract.jl  —  Data type definitions for the SmarAct MCS2 stage
# The connection handle is SA_CTL_DeviceHandle_t (UInt32).
# The GUI converts to µm for display.
# `n_channels` records how many physical channels are active so the
# GUI can build the right number of axis rows dynamically.

mutable struct MCS2Stage
    stagelabel       :: String
    n_channels       :: Int
    channel_ids      :: Vector{Int32}
    connectionstatus :: Bool
    dHandle          :: Ref{SA_CTL_DeviceHandle_t}

    pos_pm           :: Vector{Int64}   # picometres
    min_pm           :: Vector{Int64}
    max_pm           :: Vector{Int64}
    home_pm          :: Vector{Int64}

    velocity_pm_s    :: Vector{Int64}   # pm/s  (1 mm/s = 1_000_000_000)
    accel_pm_s2      :: Vector{Int64}   # pm/s²

    is_calibrated    :: Vector{Bool}
    is_referenced    :: Vector{Bool}
    connected        :: Vector{Bool}   # true = positioner attached & usable
end

"""
    MCS2Stage(; kwargs...) -> MCS2Stage

Keyword-argument constructor with safe defaults for a 3-channel MCS2.
All positions default to 0; call `initialize!(stage)` to populate them
from the device.
"""
function MCS2Stage(;
    stagelabel       :: String             = "SmarAct MCS2",
    n_channels       :: Int                = 3,
    channel_ids      :: Vector{Int32}      = Int32[0, 1, 2],
    connectionstatus :: Bool               = false,
    dHandle          :: Ref{SA_CTL_DeviceHandle_t} = Ref{SA_CTL_DeviceHandle_t}(0),

    pos_pm           :: Vector{Int64}      = zeros(Int64, 3),
    min_pm           :: Vector{Int64}      = fill(Int64(-10_000_000_000), 3),  # –10 mm
    max_pm           :: Vector{Int64}      = fill(Int64( 10_000_000_000), 3),  # +10 mm
    home_pm          :: Vector{Int64}      = zeros(Int64, 3),

    velocity_pm_s    :: Vector{Int64}      = fill(Int64(1_000_000_000), 3),    # 1 mm/s
    accel_pm_s2      :: Vector{Int64}      = fill(Int64(10_000_000_000), 3),   # 10 mm/s²

    is_calibrated    :: Vector{Bool}       = fill(false, 3),
    is_referenced    :: Vector{Bool}       = fill(false, 3),

    connected        :: Vector{Bool}       = fill(true, 3))

    return MCS2Stage(
        stagelabel, n_channels, channel_ids, connectionstatus, dHandle,
        pos_pm, min_pm, max_pm, home_pm,
        velocity_pm_s, accel_pm_s2,
        is_calibrated, is_referenced, connected
    )
end
