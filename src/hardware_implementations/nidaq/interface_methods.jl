"""
    channelfunctions

A dictionary defines functions of corresponding channel types.
`channeltype`: "AI","AO","DI","DO","CI","CO"
"""
channelfunctions = Dict{String,Function}(
    "AI" => DAQmx.ai_channels,
    "AO" => DAQmx.ao_channels,
    "DI" => DAQmx.di_lines,
    "DO" => DAQmx.do_lines,
    "CI" => DAQmx.ci_channels,
    "CO" => DAQmx.co_channels,
)

"""
    taskfunctions

A dictionary defines types of corresponding task types.
`tasktype`: "AI","AO","DI","DO"
"""
taskfunctions = Dict{String,Type}(
    "AI" => DAQmx.AITask,
    "AO" => DAQmx.AOTask,
    "DI" => DAQmx.DITask,
    "DO" => DAQmx.DOTask,
)

"""
    showdevices(daq::NIdaq)

List available devices.

# Arguments
- `daq::NIdaq`: A NIdaq type.
"""
function DAQInterface.showdevices(daq::NIdaq)
    DAQmx.device_names()
end

"""
    showchannels(daq::NIdaq,channeltype::String,device::String)

List available channels of a given channel type and device.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `channeltype::String`: A channel type. Options are "AI","AO","DI","DO","CI","CO".
- `device::String`: A device name, obtained from `showdevices`.
"""
function DAQInterface.showchannels(daq::NIdaq,channeltype::String,device::String)
    channelfunctions[channeltype](device)
end

"""
    createtask(daq::NIdaq,tasktype::String,channel::String)

Create a task of a given task type and channel.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `tasktype::String`: A task type. Options are "AI","AO","DI","DO".
- `channel::String`: A channel name, obtained from `showchannels`.

# Returns
- `t::DAQmx.Task`: A DAQmx Task type.
"""
function DAQInterface.createtask(daq::NIdaq, tasktype::String, channel::String)
    # Extract device name from channel (e.g., "Dev1/ao0" -> "Dev1")
    device = String(split(channel, "/")[1])

    if tasktype == "AI"
        # Query device's AI voltage range
        ranges = DAQmx.ai_voltage_ranges(device)
        if isempty(ranges)
            # Use default range if none available
            return DAQmx.AITask(channel)
        end
        # Use the widest range (last row)
        min_val, max_val = ranges[end, :]
        task = DAQmx.AITask()
        DAQmx.add_ai_voltage!(task, channel; min_val=min_val, max_val=max_val)
        return task
    elseif tasktype == "AO"
        # Query device's AO voltage range
        ranges = DAQmx.ao_voltage_ranges(device)
        if isempty(ranges)
            # Use default range if none available
            return DAQmx.AOTask(channel)
        end
        # Use the first (typically only) range
        min_val, max_val = ranges[1, :]
        task = DAQmx.AOTask()
        DAQmx.add_ao_voltage!(task, channel; min_val=min_val, max_val=max_val)
        return task
    elseif tasktype == "DI"
        return DAQmx.DITask(channel)
    elseif tasktype == "DO"
        return DAQmx.DOTask(channel)
    else
        error("Unknown task type: $tasktype")
    end
end

"""
    addchannel!(daq::NIdaq, t::DAQmx.Task, tasktype::String, channel::String)

Add a channel to an existing task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.Task`: A DAQmx Task.
- `tasktype::String`: A task type. Options are "AI","AO","DI","DO".
- `channel::String`: A channel name, obtained from `showchannels`.
"""
function DAQInterface.addchannel!(daq::NIdaq, t::DAQmx.Task, tasktype::String, channel::String)
    if tasktype == "AI"
        DAQmx.add_ai_voltage!(t, channel)
    elseif tasktype == "AO"
        DAQmx.add_ao_voltage!(t, channel)
    elseif tasktype == "DI"
        DAQmx.add_di_chan!(t, channel)
    elseif tasktype == "DO"
        DAQmx.add_do_chan!(t, channel)
    else
        error("Unknown task type: $tasktype")
    end
    return nothing
end


"""
    setvoltage(daq::NIdaq,t::DAQmx.AOTask,voltage::Float64)

Set the voltage of an analog output task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.AOTask`: A DAQmx AOTask type.
- `voltage::Float64`: The voltage to set the task to, unit: volt.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::DAQmx.AOTask, voltage::Float64)
    DAQmx.write_scalar(t, voltage; auto_start=true)
    return 1
end

"""
    do_port_word(channels::Vector{String}, value::Float64) -> UInt32

The `UInt32` to hand `DAQmxWriteDigitalScalarU32` for a digital output task
holding `channels`, given a requested `value`.

Digital scalar writes are **port format**: bit `n` is line `n` of the port,
even when the task holds a single line. So a task on `Dev1/port0/line1`
written with `1` drives nothing — bit 0 is line 0, which is not in the task.
Only line 0 ever worked. Confirmed on hardware (NI-DAQmx 23.5, USB-6008): a
TTL shutter on `port0/line1` did not respond to `1`, and did respond to `2`.

So the word depends on what the task actually holds:
- one **line** channel (`.../portN/lineK`) — the value is a level, and the
  word is `UInt32(value != 0) << K`. Any value other than `0` or `1` is
  rejected: it is almost certainly a caller pre-shifting to work around this
  very defect, and shifting it again would drive a *different* line.
- one **port** channel (`.../portN`) — the value is already a port word and is
  passed through. The old behaviour was correct for this case.
- more than one channel — rejected. A single scalar across several lines is
  ambiguous, and guessing is what produced the defect.

This is split out from `setvoltage` so it can be tested without a DAQ.
"""
function do_port_word(channels::Vector{String}, value::Float64)
    length(channels) == 1 || error(
        "setvoltage(::NIdaq, ::DOTask, value): the task holds $(length(channels)) channels " *
        "($(join(channels, ", "))). A single scalar across several digital lines is ambiguous; " *
        "use one task per line, or write the port word to a port-wide task.")
    channel = channels[1]
    m = match(r"/line(\d+)$", channel)
    if m === nothing
        # A port-wide task: the caller's value IS the port word.
        return UInt32(value)
    end
    (value == 0 || value == 1) || error(
        "setvoltage(::NIdaq, ::DOTask, value): $(channel) is a single line, so value must be " *
        "0 or 1, got $(value). If you are pre-shifting a port word to work around digital " *
        "writes not reaching lines above line 0, stop: that is fixed, and shifting again would " *
        "drive a different line.")
    return UInt32(value != 0) << parse(Int, m.captures[1])
end

"""
    setvoltage(daq::NIdaq,t::DAQmx.DOTask,voltage::Float64)

Set the state of a digital output task. For a single-line task `voltage` is a
level, `0` or `1`; for a port-wide task it is the port word. See
[`do_port_word`](@ref), which explains why those differ.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.DOTask`: A DAQmx DOTask type.
- `voltage::Float64`: `0` or `1` for a line task; the port word for a port task.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::DAQmx.DOTask, voltage::Float64)
    DAQmx.write_scalar(t, do_port_word(DAQmx.channel_names(t), voltage); auto_start=true)
    return 1
end

"""
    setvoltage(daq::NIdaq,t::DAQmx.AOTask,voltage::Array{Float64})

Set the voltage of an analog output task with an array of values.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.AOTask`: A DAQmx AOTask type.
- `voltage::Array{Float64}`: The voltages to set, unit: volt.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::DAQmx.AOTask, voltage::Array{Float64})
    write(t, voltage; auto_start=true)
end

"""
    setvoltage(daq::NIdaq,t::DAQmx.DOTask,voltage::Array{Float64})

Set the voltage of a digital output task with an array of values.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.DOTask`: A DAQmx DOTask type.
- `voltage::Array{Float64}`: The voltages to set (0 or 1).

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::DAQmx.DOTask, voltage::Array{Float64})
    write(t, UInt8.(voltage); auto_start=true)
end

"""
    readvoltage(daq::NIdaq,t::DAQmx.AITask)

Read the voltage of an analog input task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.AITask`: A DAQmx AITask type.

# Returns
- `voltage::Float64`: The voltage read from the task, unit: volt.
"""
function DAQInterface.readvoltage(daq::NIdaq, t::DAQmx.AITask)
    DAQmx.start!(t)
    voltage = DAQmx.read_scalar(t)
    DAQmx.stop!(t)
    return voltage
end

"""
    readvoltage(daq::NIdaq,t::DAQmx.DITask)

Read the voltage of a digital input task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.DITask`: A DAQmx DITask type.

# Returns
- `voltage::Float64`: The voltage read from the task (0 or 1).
"""
function DAQInterface.readvoltage(daq::NIdaq, t::DAQmx.DITask)
    DAQmx.start!(t)
    voltage = Float64(DAQmx.read_scalar(t))
    DAQmx.stop!(t)
    return voltage
end

"""
    deletetask(daq::NIdaq,t::DAQmx.Task)

Delete a task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::DAQmx.Task`: A DAQmx Task type.
"""
function DAQInterface.deletetask(daq::NIdaq, t::DAQmx.Task)
    DAQmx.clear!(t)
end

"""
    export_state(daq::NIdaq)
"""
function export_state(daq::NIdaq)
    attributes = Dict("unique_id" => daq.unique_id)
    data = nothing
    children = Dict()
    return attributes, data, children
end

"""
    initialize(daq::NIdaq)

No-op. DAQmx tasks are created and deleted per operation via `createtask`
and `deletetask`, so `NIdaq` has no persistent hardware connection to open.
"""
function initialize(daq::NIdaq)
    return nothing
end

"""
    shutdown(daq::NIdaq)

No-op. DAQmx tasks are created and deleted per operation via `createtask`
and `deletetask`, so `NIdaq` has no persistent hardware connection to close.
"""
function shutdown(daq::NIdaq)
    return nothing
end
