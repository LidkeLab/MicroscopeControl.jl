"""
    Struct for SOM-MS-8070 Stage linear actuator (2 axes)
"""

mutable struct MCS2Stage
    stagelabel      :: String
    n_channels      :: Int
    channel_ids     :: Vector{Int32}
    connectionstatus:: Bool
    dHandle         :: Ref{SA_CTL_DeviceHandle_t}
    pos             :: Vector{Int64}    # picometers
    min_pos         :: Vector{Int64}
    max_pos         :: Vector{Int64}
    home            :: Vector{Int64}
    velocity        :: Vector{Int64}
    acceleration    :: Vector{Int64}
    is_calibrated   :: Vector{Bool}
    is_referenced   :: Vector{Bool}
    is_connected    :: Vector{Bool}     # channel is connected & usable
end

"""
    Constructor for the MCS2Stage type
"""

function MCS2Stage(;
    stagelabel      :: String = "SmarAct MCS2",
    n_channels      :: Int = 3,
    channel_ids     :: Vector{Int32} = Int32[0, 1, 2],
    connectionstatus:: Bool = false,
    dHandle         :: Ref{SA_CTL_DeviceHandle_t} = Ref{SA_CTL_DeviceHandle_t}(0),
    pos             :: Vector{Int64} = zeros(Int64, 3),
    min_pos         :: Vector{Int64} = fill(Int64(-20_000_000_000), 3),     # -20 mm
    max_pos         :: Vector{Int64} = fill(Int64(20_000_000_000), 3),      # 20 mm
    home            :: Vector{Int64} = zeros(Int64, 3),
    velocity        :: Vector{Int64} = fill(Int64(1_000_000_000), 3),       # 1 mm/s
    acceleration    :: Vector{Int64} = fill(Int64(1_000_000_000), 3),       # 1 mm/s²,
    is_calibrated   :: Vector{Bool} = fill(false, 3),
    is_referenced   :: Vector{Bool} = fill(false, 3),
    is_connected    :: Vector{Bool} = fill(false, 3))
    
    return MCS2Stage(  
        stagelabel, n_channels, channel_ids, connectionstatus, dHandle, pos, min_pos, max_pos, home, 
        velocity, acceleration, is_calibrated, is_referenced, is_connected
    )
end
