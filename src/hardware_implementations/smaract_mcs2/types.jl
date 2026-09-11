#=
Type definition for a stage driven by a SmarAct MCS2 controller.

Field names follow the convention the stage GUI in StageInterface expects
(`real_*`, `targ_*`, `range_*`, `dimensions`, `connectionstatus`).
=#

"""
    MCS2Stage

A translation stage driven by a SmarAct MCS2 controller. Defaults describe the
SOM-MS-8070 XY microscope stage (SLC linear positioners, 51 mm x / 46 mm y
travel) on channels 0 and 1.

All positions, velocities and accelerations in this interface are in **microns**
(the controller itself works in picometres; conversion happens at the API
boundary).

# Fields
- `stagelabel::String`: Human readable name.
- `units::String`: Position units; always `"Microns"` for this driver.
- `id::UInt32`: Device handle returned by `SA_CTL_Open`. Valid only while connected.
- `locator::String`: Controller locator, e.g. `"usb:sn:MCS2-00001234"`. Empty
  means "use the first controller found".
- `dimensions::Int`: Number of axes driven (2 for an XY stage).
- `channels::Vector{Int}`: Controller channel index for each axis, in x, y, z order.
- `connectionstatus::Bool`: Whether `initialize` has successfully opened the device.
- `real_x/real_y/real_z::Float64`: Last position read back from the controller.
- `targ_x/targ_y/targ_z::Float64`: Last commanded target.
- `range_x/range_y/range_z::Tuple{Float64,Float64}`: Software travel limits used
  to reject out-of-range move commands.
- `velocity::Vector{Float64}`: Closed-loop move velocity per axis. `0` means
  unlimited (the controller moves as fast as it can).
- `acceleration::Vector{Float64}`: Closed-loop move acceleration per axis. `0`
  disables acceleration control.
- `holdtime::Int`: Milliseconds the controller actively holds position after a
  move. `0` disables holding, `-1` holds until the next `stopmotion`. Not
  persistent - reapplied on every `initialize`.
- `maxclfrequency::Int`: Maximum closed-loop driving frequency in Hz for
  stick-slip positioners. Not persistent - reapplied on every `initialize`.
- `movetimeout::Float64`: Seconds `waitformotion` waits before giving up.
- `referenced::Vector{Bool}`: Whether each axis has a valid position reference.
  Updated by `updatestatus!`, `findreference` and `initialize`.
- `calibrated::Vector{Bool}`: Whether each axis has valid calibration data stored.

# Notes on `range_*`
The MCS2 has no way to report the mechanical travel of a positioner, so these
defaults assume the reference mark sits at mid-travel and are only a Julia-side
guard. If software travel limits are configured in the controller
(`SA_CTL_PKEY_RANGE_LIMIT_MIN`/`MAX`) `initialize` reads those instead; see
[`setrangelimits!`](@ref) to write them.
"""
Base.@kwdef mutable struct MCS2Stage <: Stage
    stagelabel::String = "SmarAct SOM-MS-8070"
    units::String = "Microns"
    id::UInt32 = UInt32(0)
    locator::String = ""
    dimensions::Int = 2
    channels::Vector{Int} = [0, 1]
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    real_z::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    targ_z::Float64 = 0.0
    range_x::Tuple{Float64,Float64} = (-25_500.0, 25_500.0)
    range_y::Tuple{Float64,Float64} = (-23_000.0, 23_000.0)
    range_z::Tuple{Float64,Float64} = (0.0, 0.0)
    velocity::Vector{Float64} = [1000.0, 1000.0, 1000.0]
    acceleration::Vector{Float64} = [10_000.0, 10_000.0, 10_000.0]
    holdtime::Int = 1000
    maxclfrequency::Int = 6000
    movetimeout::Float64 = 60.0
    referenced::Vector{Bool} = [false, false, false]
    calibrated::Vector{Bool} = [false, false, false]
end

"""
    channelof(stage, axis) -> Int

Controller channel index driving `axis`, where `axis` is `1`, `2`, `3` or
`:x`, `:y`, `:z`.
"""
function channelof(stage::MCS2Stage, axis::Integer)
    checkaxis(stage, axis)
    return stage.channels[axis]
end

channelof(stage::MCS2Stage, axis::Symbol) = channelof(stage, axisindex(axis))

"""
    axisindex(axis) -> Int

Map `:x`, `:y`, `:z` onto `1`, `2`, `3`.
"""
function axisindex(axis::Symbol)
    axis === :x && return 1
    axis === :y && return 2
    axis === :z && return 3
    throw(ArgumentError("unknown axis $axis, expected :x, :y or :z"))
end

axisindex(axis::Integer) = Int(axis)

"""
    axes(stage) -> UnitRange{Int}

Axis indices this stage drives.
"""
stageaxes(stage::MCS2Stage) = 1:stage.dimensions

function checkaxis(stage::MCS2Stage, axis::Integer)
    1 <= axis <= stage.dimensions ||
        throw(ArgumentError("axis $axis out of range for a $(stage.dimensions)D stage"))
    axis <= length(stage.channels) ||
        throw(ArgumentError("no channel configured for axis $axis"))
    return nothing
end

"""
    positionrange(stage, axis) -> Tuple{Float64,Float64}

Software travel limits for `axis`, in microns.
"""
function positionrange(stage::MCS2Stage, axis::Integer)
    axis == 1 && return stage.range_x
    axis == 2 && return stage.range_y
    axis == 3 && return stage.range_z
    throw(ArgumentError("axis $axis out of range"))
end

function setpositionrange!(stage::MCS2Stage, axis::Integer, range::Tuple{Real,Real})
    limits = (Float64(range[1]), Float64(range[2]))
    axis == 1 && return stage.range_x = limits
    axis == 2 && return stage.range_y = limits
    axis == 3 && return stage.range_z = limits
    throw(ArgumentError("axis $axis out of range"))
end

"Read the cached position of `axis` from the stage struct."
function cachedposition(stage::MCS2Stage, axis::Integer)
    axis == 1 && return stage.real_x
    axis == 2 && return stage.real_y
    axis == 3 && return stage.real_z
    throw(ArgumentError("axis $axis out of range"))
end

function setcachedposition!(stage::MCS2Stage, axis::Integer, value::Real)
    axis == 1 && return stage.real_x = Float64(value)
    axis == 2 && return stage.real_y = Float64(value)
    axis == 3 && return stage.real_z = Float64(value)
    throw(ArgumentError("axis $axis out of range"))
end

function settarget!(stage::MCS2Stage, axis::Integer, value::Real)
    axis == 1 && return stage.targ_x = Float64(value)
    axis == 2 && return stage.targ_y = Float64(value)
    axis == 3 && return stage.targ_z = Float64(value)
    throw(ArgumentError("axis $axis out of range"))
end

"Throw unless the stage has an open connection to a controller."
function checkconnected(stage::MCS2Stage)
    stage.connectionstatus ||
        error("MCS2 stage is not connected - call initialize(stage) first")
    return nothing
end
