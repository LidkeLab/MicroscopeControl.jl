"""
    channelfunctions

A dictionary defines functions of corresponding channel types.
`channeltype`: "AI","AO","DI","DO","CI","CO"
"""
channelfunctions = Dict{String,Function}(
    "AI" => analog_input_channels,
    "AO" => analog_output_channels,
    "DI" => digital_input_channels,
    "DO" => digital_output_channels,
    "CI" => counter_input_channels,
    "CO" => counter_output_channels,
)

"""
    taskfunctions

A dictionary defines functions of corresponding task types.
`tasktype`: "AI","AO","DI","DO"
"""
taskfunctions = Dict{String,Function}(
    "AI" => analog_input,
    "AO" => analog_output,
    "DI" => digital_input,
    "DO" => digital_output,
)

"""
    showdevices(daq::NIdaq)

List available devices.

# Arguments
- `daq::NIdaq`: A NIdaq type.
"""
function DAQInterface.showdevices(daq::NIdaq)
    devices()
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
- `t::NIDAQ.Task`: A NIDAQ.Task type.
"""
function DAQInterface.createtask(daq::NIdaq,tasktype::String,channel::String)
    t = taskfunctions[tasktype](channel)
    return t
end

function DAQInterface.addchannel!(daq::NIdaq,t::NIDAQ.Task,tasktype::String, channel::String)
    taskfunctions[tasktype](t,channel)
    return nothing
end


"""
    setvoltage(daq::NIdaq,t::NIDAQ.Task,voltage::Float64)

Set the voltage of a output task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQ.Task`: A NIDAQ.Task type.
- `voltage::Float64`: The voltage to set the task to, unit: volt. If tasktype is "DO", the voltage should be 0 or 1.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function DAQInterface.setvoltage(daq::NIdaq,t::NIDAQ.Task,voltage::Float64)
    if typeof(t) == NIDAQ.DOTask
        voltage = UInt8(voltage)
    end
    start(t)
    ret = NIDAQ.write(t,[voltage])
    stop(t)
    return ret
end

function DAQInterface.setvoltage(daq::NIdaq,t::NIDAQ.Task,voltage::Array{Float64})
    if typeof(t) == NIDAQ.DOTask
        voltage = UInt8.(voltage)
    end
    start(t)
    ret = NIDAQ.write(t,voltage)
    stop(t)
    return ret
end

"""
    readvoltage(daq::NIdaq,t::NIDAQ.Task)

Read the voltage of a input task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQ.Task`: A NIDAQ.Task type.

# Returns
- `voltage::Float64`: The voltage read from the task, unit: volt.
"""
function DAQInterface.readvoltage(daq::NIdaq,t::NIDAQ.Task)
    start(t)
    voltage = NIDAQ.read(t)
    stop(t)
    return voltage
end

"""
    deletetask(daq::NIdaq,t::NIDAQ.Task)

Delete a task.

# Arguments
- `daq::NIdaq`: A NIdaq type.
- `t::NIDAQ.Task`: A NIDAQ.Task type.
"""
function DAQInterface.deletetask(daq::NIdaq,t::NIDAQ.Task)
    clear(t)
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