
mutable struct MCS2Stage <: Stage
    stagelabel       :: String
    n_channels       :: Int
    channel_ids      :: Vector{Int32}
    connectionstatus :: Bool
    dHandle          :: Ref{SA_CTL_DeviceHandle_t}
    servostatus      :: Vector{Bool}

    pos_pm           :: Vector{Int64}   # picometres
    min_pm           :: Vector{Int64}
    max_pm           :: Vector{Int64}
    home_pm          :: Vector{Int64}

    velocity_pm_s    :: Vector{Int64}   # pm/s  (1 mm/s = 1_000_000_000)
    accel_pm_s2      :: Vector{Int64}   # pm/s²

    is_calibrated    :: Vector{Bool}
    is_referenced    :: Vector{Bool}
    connected        :: Vector{Bool}   # true = positioner attached & usable

    dimensions       :: Int
    real_x           :: Float64
    real_y           :: Float64
    real_z           :: Float64
    targ_x           :: Float64
    targ_y           :: Float64
    targ_z           :: Float64
    range_x          :: Tuple{Float64, Float64}
    range_y          :: Tuple{Float64, Float64}
    range_z          :: Tuple{Float64, Float64}
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
    servostatus      :: Vector{Bool}       = fill(false, 3),

    pos_pm           :: Vector{Int64}      = zeros(Int64, 3),
    min_pm           :: Vector{Int64}      = fill(Int64(-10_000_000_000), 3),  # –10 mm
    max_pm           :: Vector{Int64}      = fill(Int64( 10_000_000_000), 3),  # +10 mm
    home_pm          :: Vector{Int64}      = zeros(Int64, 3),

    velocity_pm_s    :: Vector{Int64}      = fill(Int64(1_000_000_000), 3),    # 1 mm/s
    accel_pm_s2      :: Vector{Int64}      = fill(Int64(10_000_000_000), 3),   # 10 mm/s²

    is_calibrated    :: Vector{Bool}       = fill(false, 3),
    is_referenced    :: Vector{Bool}       = fill(false, 3),
    connected        :: Vector{Bool}       = fill(true, 3),
    dimensions       :: Union{Int, Nothing} = nothing,
    
    real_x           :: Float64             = 0.0,
    real_y           :: Float64             = 0.0,
    real_z           :: Float64             = 0.0,
    targ_x           :: Float64             = 0.0,
    targ_y           :: Float64             = 0.0,
    targ_z           :: Float64             = 0.0,
    range_x          :: Union{Tuple{Float64,Float64}, Nothing} = nothing,
    range_y          :: Union{Tuple{Float64,Float64}, Nothing} = nothing,
    range_z          :: Union{Tuple{Float64,Float64}, Nothing} = nothing)

    dims = dimensions === nothing ? min(n_channels, 3) : dimensions
    
    rx = range_x === nothing ? (min_pm[1] / 1e6, max_pm[1] / 1e6) : range_x
    ry = range_y === nothing ? (min_pm[2] / 1e6, max_pm[2] / 1e6) : range_y
    rz = if range_z !== nothing
        range_z
    elseif n_channels >= 3
        (min_pm[3] / 1e6, max_pm[3] / 1e6)
    else
        (0.0, 0.0)
    end

    return MCS2Stage(
        stagelabel, n_channels, channel_ids, connectionstatus, dHandle, servostatus, pos_pm, min_pm, max_pm, home_pm, velocity_pm_s, accel_pm_s2,
        is_calibrated, is_referenced, connected, dims, real_x, real_y, real_z, targ_x, targ_y, targ_z, rx, ry, rz
    )
end
