"""
This builds a generic interface for National Instruments DAQ cards
"""
module DAQInterface

using GLMakie
using Images
using ...MicroscopeControl

# import ...MicroscopeControl: AbstractInstrument, export_state, initialize, shutdown
import ...MicroscopeControl: gui

export DAQ
export showdevices, showchannels, createtask, setvoltage, readvoltage, deletetask, addchannel!
export gui

include("interface_types.jl")

"""
    UnreleasedTask(task, cause)

Thrown by a `createtask` whose channel setup failed AND whose cleanup of the allocated task failed too: `task` is the
handle that is still allocated and must be deleted later (`deletetask`), `cause` the setup error. A caller that owns
the output keeps `task` so a later `shutdown` can retry. Public, not exported.
"""
struct UnreleasedTask <: Exception
    task::Any
    cause::Any
end
Base.showerror(io::IO, e::UnreleasedTask) = print(io, "a DAQ task could not be released after a failed setup (",
    sprint(showerror, e.cause), "); the task handle is kept for a retry")

include("interface_functions.jl")
include("gui.jl")

end
