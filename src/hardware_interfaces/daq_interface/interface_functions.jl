"""
    showdevices(daq::DAQ)

List available devices.

# Arguments
- `daq::DAQ`: A DAQ type.
"""
function showdevices(daq::DAQ)
    @error "showdevices not implemented"
end

"""
    showchannels(daq::DAQ,channeltype::String,device::String)

List available channels of a given channel type and device. 

# Arguments
- `daq::DAQ`: A DAQ type.
- `channeltype::String`: A channel type. Options are "AI","AO","DI","DO","CI","CO".
- `device::String`: A device name, obtained from `showdevices`.
"""
function showchannels(daq::DAQ,channeltype::String,device::String)
    @error "showchannels not implemented"
end

"""
    createtask(daq::DAQ,tasktype::String,channel::String)

Create a task of a given task type and channel.

# Arguments
- `daq::DAQ`: A DAQ type.
- `tasktype::String`: A task type. Options are "AI","AO","DI","DO".
- `channel::String`: A channel name, obtained from `showchannels`.

# Returns
- `t::Any`: A Any type.
"""
function createtask(daq::DAQ,tasktype::String,channel::String)
    @error "createtask not implemented"
end

"""
    addchannel!(daq::DAQ,t::Any,tasktype::String, channel::String)

Add a channel to a task.

# Arguments
- `daq::DAQ`: A DAQ type.
- `t::Any`: A Any type.
- `tasktype::String`: A task type. Options are "AI","AO","DI","DO".
- `channel::String`: A channel name, obtained from `showchannels`.
"""
function addchannel!(daq::DAQ,t::Any,tasktype::String, channel::String)
    @error "addchannel! not implemented"
end

"""
    setvoltage(daq::DAQ,t::Any,voltage::Float64)

Set the voltage of a output task.

# Arguments
- `daq::DAQ`: A DAQ type.
- `t::Any`: A Any type.
- `voltage::Float64`: The voltage to set the task to, unit: volt. If tasktype is "DO", the voltage should be 0 or 1.

# Returns
- `ret::Int`: The number of samples written to the task.
"""
function setvoltage(daq::DAQ,t::Any,voltage::Any)
    @error "setvoltage not implemented"
end

"""
    readvoltage(daq::DAQ,t::Any)

Read the voltage of a input task.

# Arguments
- `daq::DAQ`: A DAQ type.
- `t::Any`: A Any type.

# Returns
- `voltage::Float64`: The voltage read from the task, unit: volt.
"""
function readvoltage(daq::DAQ,t::Any)
    @error "readvoltage not implemented"
end

"""
    deletetask(daq::DAQ,t::Any)

Delete a task.

# Arguments
- `daq::DAQ`: A DAQ type.
- `t::Any`: A Any type.
"""
function deletetask(daq::DAQ,t::Any)
    @error "deletetask not implemented"
end 

"""
    export_state(daq::DAQ)

Export the state of the DAQ.

# Arguments
- `daq::DAQ`: A DAQ type.

# Returns

"""
function export_state(daq::DAQ)
    @error "export_state not implemented"
end
