"""
    channelfunctions

A dictionary defines functions of corresponding channel types.
`channeltype`: "AI","AO","DI","DO","CI","CO"
"""
channelfunctions = Dict{String,Function}(
    "AI" => NIDAQmx.ai_channels,
    "AO" => NIDAQmx.ao_channels,
    "DI" => NIDAQmx.di_lines,
    "DO" => NIDAQmx.do_lines,
    "CI" => NIDAQmx.ci_channels,
    "CO" => NIDAQmx.co_channels,
)

"""
    taskfunctions

A dictionary defines types of corresponding task types.
`tasktype`: "AI","AO","DI","DO"
"""
taskfunctions = Dict{String,Type}(
    "AI" => NIDAQmx.AITask,
    "AO" => NIDAQmx.AOTask,
    "DI" => NIDAQmx.DITask,
    "DO" => NIDAQmx.DOTask,
)

"""
    showdevices(daq::NIdaq)

List available devices.

# Arguments
- `daq::NIdaq`: A NIdaq type.
"""
function DAQInterface.showdevices(daq::NIdaq)
    NIDAQmx.device_names()
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
- `t::NIDAQmx.Task`: A NIDAQmx Task type.
"""
function DAQInterface.createtask(daq::NIdaq, tasktype::String, channel::String)
    # Extract device name from channel (e.g., "Dev1/ao0" -> "Dev1")
    device = String(split(channel, "/")[1])

    if tasktype == "AI"
        # Query device's AI voltage range
        ranges = NIDAQmx.ai_voltage_ranges(device)
        if isempty(ranges)
            # Use default range if none available
            return NIDAQmx.AITask(channel)
        end
        # Use the widest range (last row)
        min_val, max_val = ranges[end, :]
        task = NIDAQmx.AITask()
        NIDAQmx.add_ai_voltage!(task, channel; min_val=min_val, max_val=max_val)
        return task
    elseif tasktype == "AO"
        # Query device's AO voltage range
        ranges = NIDAQmx.ao_voltage_ranges(device)
        if isempty(ranges)
            # Use default range if none available
            return NIDAQmx.AOTask(channel)
        end
        # Use the first (typically only) range
        min_val, max_val = ranges[1, :]
        task = NIDAQmx.AOTask()
        NIDAQmx.add_ao_voltage!(task, channel; min_val=min_val, max_val=max_val)
        return task
    elseif tasktype == "DI"
        return NIDAQmx.DITask(channel)
    elseif tasktype == "DO"
        return NIDAQmx.DOTask(channel)
    else
        error("Unknown task type: $tasktype")
    end
end

"""
    addchannel!(daq::NIdaq, t::NIDAQmx.Task, tasktype::String, channel::String)

Add a channel to an existing task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.Task`: A NIDAQmx Task.
- `tasktype::String`: A task type. Options are "AI","AO","DI","DO".
- `channel::String`: A channel name, obtained from `showchannels`.
"""
function DAQInterface.addchannel!(daq::NIdaq, t::NIDAQmx.Task, tasktype::String, channel::String)
    if tasktype == "AI"
        NIDAQmx.add_ai_voltage!(t, channel)
    elseif tasktype == "AO"
        NIDAQmx.add_ao_voltage!(t, channel)
    elseif tasktype == "DI"
        NIDAQmx.add_di_chan!(t, channel)
    elseif tasktype == "DO"
        NIDAQmx.add_do_chan!(t, channel)
    else
        error("Unknown task type: $tasktype")
    end
    return nothing
end


"""
    setvoltage(daq::NIdaq,t::NIDAQmx.AOTask,voltage::Float64)

Set the voltage of an analog output task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.AOTask`: A NIDAQmx AOTask type.
- `voltage::Float64`: The voltage to set the task to, unit: volt.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::NIDAQmx.AOTask, voltage::Float64)
    NIDAQmx.write_scalar(t, voltage; auto_start=true)
    return 1
end

"""
    setvoltage(daq::NIdaq,t::NIDAQmx.DOTask,voltage::Float64)

Set the voltage of a digital output task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.DOTask`: A NIDAQmx DOTask type.
- `voltage::Float64`: The voltage to set (0 or 1).

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::NIDAQmx.DOTask, voltage::Float64)
    NIDAQmx.write_scalar(t, UInt32(voltage); auto_start=true)
    return 1
end

"""
    setvoltage(daq::NIdaq,t::NIDAQmx.AOTask,voltage::Array{Float64})

Set the voltage of an analog output task with an array of values.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.AOTask`: A NIDAQmx AOTask type.
- `voltage::Array{Float64}`: The voltages to set, unit: volt.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::NIDAQmx.AOTask, voltage::Array{Float64})
    write(t, voltage; auto_start=true)
end

"""
    setvoltage(daq::NIdaq,t::NIDAQmx.DOTask,voltage::Array{Float64})

Set the voltage of a digital output task with an array of values.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.DOTask`: A NIDAQmx DOTask type.
- `voltage::Array{Float64}`: The voltages to set (0 or 1).

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq, t::NIDAQmx.DOTask, voltage::Array{Float64})
    write(t, UInt8.(voltage); auto_start=true)
end

"""
    readvoltage(daq::NIdaq,t::NIDAQmx.AITask)

Read the voltage of an analog input task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.AITask`: A NIDAQmx AITask type.

# Returns
- `voltage::Float64`: The voltage read from the task, unit: volt.
"""
function DAQInterface.readvoltage(daq::NIdaq, t::NIDAQmx.AITask)
    NIDAQmx.start!(t)
    voltage = NIDAQmx.read_scalar(t)
    NIDAQmx.stop!(t)
    return voltage
end

"""
    readvoltage(daq::NIdaq,t::NIDAQmx.DITask)

Read the voltage of a digital input task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.DITask`: A NIDAQmx DITask type.

# Returns
- `voltage::Float64`: The voltage read from the task (0 or 1).
"""
function DAQInterface.readvoltage(daq::NIdaq, t::NIDAQmx.DITask)
    NIDAQmx.start!(t)
    voltage = Float64(NIDAQmx.read_scalar(t))
    NIDAQmx.stop!(t)
    return voltage
end

"""
    deletetask(daq::NIdaq,t::NIDAQmx.Task)

Delete a task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQmx.Task`: A NIDAQmx Task type.
"""
function DAQInterface.deletetask(daq::NIdaq, t::NIDAQmx.Task)
    NIDAQmx.clear!(t)
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
