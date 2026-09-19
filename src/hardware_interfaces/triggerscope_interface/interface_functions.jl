#These are functions that are used to interact with DAQ devices, these must be implemented for each device and are general

# #Start and Stop the Device
# function initialize(trig::TRIG)
#     @error "initialize not implemented"
# end

# function shutdown(trig::TRIG)
#     @error "shutdown not implemented"
# end

"""
    reset(trig::TRIG)

Reset the trigger/DAQ device to its default state.

Extends `Base.reset` (rather than a locally-exported generic) because
`reset` is already an exported Base binding; a same-named export here would
just recreate the top-level ambiguity this generic is meant to resolve.

# Arguments
- `trig::TRIG`: A TRIG type.
"""
function Base.reset(trig::TRIG)
    error("reset not implemented for $(typeof(trig))")
end

#=
These functions are redundant when using the Output and Input objects

#Query the Datatypes, Ranges, Number of Channels; Channel names set to datatype + channel number
function getdatatypes(daq::DAQ)
    @error "getdatatypes not implemented"
end

function getranges(daq::DAQ)
    @error "getranges not implemented"
end

function getnumchannels(daq::DAQ)
    @error "getnumchannels not implemented"
end
=#

#Functions to set and read values from the DAQ device
function setoutputvalue(trig::TRIG, output::Output, channel::Int, value::Any)
    error("setoutputvalue not implemented for $(typeof(trig))")
end

function setoutputrange(trig::TRIG, output::Output, channel::Int, range::Any)
    error("setoutputrange not implemented for $(typeof(trig))")
end

function getoutputvalue(trig::TRIG, output::Output, channel::Int)
    error("getoutputvalue not implemented for $(typeof(trig))")
end

function getinputvalue(trig::TRIG, input::Input, channel::Int)
    error("getinputvalue not implemented for $(typeof(trig))")
end

