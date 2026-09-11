#=
Queries against an open MCS2 controller: device identity, channel state and the
derived status flags cached on the stage struct.
=#

"""
    findmcs2devices() -> Vector{String}

Locator strings for every MCS2 controller the SDK can see, e.g.
`"usb:sn:MCS2-00001234"`. Pass one to [`MCS2Stage`](@ref) as `locator` to pin a
particular controller when more than one is attached.

```julia
julia> findmcs2devices()
1-element Vector{String}:
 "usb:sn:MCS2-00001234"
```
"""
findmcs2devices() = finddevices()

"""
    mcs2version() -> String

Version of the installed SmarActCTL library. Useful as a first check that the
SDK is installed and reachable from Julia.
"""
mcs2version() = libraryversion()

"""
    numchannels(stage) -> Int

Number of positioner channels the connected controller provides.
"""
function numchannels(stage::MCS2Stage)
    checkconnected(stage)
    return Int(get_i32(stage.id, 0, SA_CTL_PKEY_NUMBER_OF_CHANNELS))
end

"""
    devicename(stage) -> String

Name the controller reports for itself.
"""
function devicename(stage::MCS2Stage)
    checkconnected(stage)
    return get_str(stage.id, 0, SA_CTL_PKEY_DEVICE_NAME)
end

"""
    serialnumber(stage) -> String

Serial number of the connected controller.
"""
function serialnumber(stage::MCS2Stage)
    checkconnected(stage)
    return get_str(stage.id, 0, SA_CTL_PKEY_DEVICE_SERIAL_NUMBER)
end

"""
    positionertype(stage, axis) -> Tuple{Int,String}

Positioner type code and name configured for `axis`. The type must match the
positioner that is physically connected, otherwise closed-loop moves and
calibration misbehave; it is set once with the MCS2 Service Tool and stored in
the controller.
"""
function positionertype(stage::MCS2Stage, axis::Integer=1)
    checkconnected(stage)
    channel = channelof(stage, axisindex(axis))
    code = get_i32(stage.id, channel, SA_CTL_PKEY_POSITIONER_TYPE)
    name = get_str(stage.id, channel, SA_CTL_PKEY_POSITIONER_TYPE_NAME)
    return Int(code), name
end

"""
    channeltype(stage, axis) -> Int32

Driver type of the channel: `SA_CTL_STICK_SLIP_PIEZO_DRIVER`,
`SA_CTL_MAGNETIC_DRIVER` or `SA_CTL_PIEZO_SCANNER_DRIVER`.
"""
function channeltype(stage::MCS2Stage, axis::Integer=1)
    checkconnected(stage)
    return get_i32(stage.id, channelof(stage, axisindex(axis)), SA_CTL_PKEY_CHANNEL_TYPE)
end

"""
    channelstate(stage, axis) -> Int32

Raw channel state bitfield for `axis`. Compare against the
`SA_CTL_CH_STATE_BIT_*` constants, or use [`channelstatus`](@ref) for a
readable version.
"""
function channelstate(stage::MCS2Stage, axis::Integer)
    checkconnected(stage)
    return get_i32(stage.id, channelof(stage, axisindex(axis)), SA_CTL_PKEY_CHANNEL_STATE)
end

"""
    channelstatus(stage, axis) -> Vector{String}

Names of the state bits currently set on `axis`.

```julia
julia> channelstatus(stage, :x)
3-element Vector{String}:
 "sensorPresent"
 "isCalibrated"
 "isReferenced"
```
"""
function channelstatus(stage::MCS2Stage, axis::Integer)
    state = channelstate(stage, axis)
    return String[name for (bit, name) in CHANNEL_STATE_NAMES if state & bit != 0]
end

channelstatus(stage::MCS2Stage, axis::Symbol) = channelstatus(stage, axisindex(axis))
channelstate(stage::MCS2Stage, axis::Symbol) = channelstate(stage, axisindex(axis))

hasstatebit(stage::MCS2Stage, axis::Integer, bit::Int32) = channelstate(stage, axis) & bit != 0

"""
    isreferenced(stage) -> Vector{Bool}

Whether each axis has established an absolute position reference. The sensors
are incremental, so this is `false` for every axis after a controller power
cycle until [`findreference`](@ref) has run.
"""
isreferenced(stage::MCS2Stage) =
    Bool[hasstatebit(stage, axis, SA_CTL_CH_STATE_BIT_IS_REFERENCED) for axis in stageaxes(stage)]

"""
    iscalibrated(stage) -> Vector{Bool}

Whether each axis has valid calibration data stored in the controller.
Calibration is persistent, so this normally only needs doing once per
mechanical setup - see [`calibrate`](@ref).
"""
iscalibrated(stage::MCS2Stage) =
    Bool[hasstatebit(stage, axis, SA_CTL_CH_STATE_BIT_IS_CALIBRATED) for axis in stageaxes(stage)]

"""
    hassensor(stage) -> Vector{Bool}

Whether a position sensor is detected on each axis. Closed-loop moves need one.
"""
hassensor(stage::MCS2Stage) =
    Bool[hasstatebit(stage, axis, SA_CTL_CH_STATE_BIT_SENSOR_PRESENT) for axis in stageaxes(stage)]

"""
    ismoving(stage) -> Vector{Bool}

Whether each axis is currently executing a move, calibration or referencing
sequence.
"""
function ismoving(stage::MCS2Stage)
    busy = SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING |
           SA_CTL_CH_STATE_BIT_CALIBRATING |
           SA_CTL_CH_STATE_BIT_REFERENCING
    return Bool[channelstate(stage, axis) & busy != 0 for axis in stageaxes(stage)]
end

"""
    updatestatus!(stage) -> MCS2Stage

Refresh the cached `referenced` and `calibrated` flags from the controller.
"""
function updatestatus!(stage::MCS2Stage)
    for axis in stageaxes(stage)
        state = channelstate(stage, axis)
        stage.referenced[axis] = state & SA_CTL_CH_STATE_BIT_IS_REFERENCED != 0
        stage.calibrated[axis] = state & SA_CTL_CH_STATE_BIT_IS_CALIBRATED != 0
    end
    return stage
end

"""
    deviceinfo(stage)

Print an overview of the connected controller and of every axis this stage
drives: positioner type, channel state, position and travel limits.
"""
function deviceinfo(stage::MCS2Stage)
    checkconnected(stage)
    println("SmarActCTL library : ", mcs2version())
    println("Locator            : ", stage.locator)
    println("Device name        : ", devicename(stage))
    println("Serial number      : ", serialnumber(stage))
    println("Channels available : ", numchannels(stage))
    println()
    for axis in stageaxes(stage)
        code, name = positionertype(stage, axis)
        lo, hi = positionrange(stage, axis)
        println("Axis $(("x", "y", "z")[axis]) (channel $(channelof(stage, axis)))")
        println("  positioner type : $name ($code)")
        println("  position        : $(round(getaxisposition(stage, axis), digits=4)) um")
        println("  software range  : ($(lo), $(hi)) um")
        println("  state           : ", join(channelstatus(stage, axis), ", "))
    end
    return nothing
end
