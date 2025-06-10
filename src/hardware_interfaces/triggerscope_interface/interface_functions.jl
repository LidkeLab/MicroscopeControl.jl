#These are functions that are used to interact with DAQ devices, these must be implemented for each device and are general

# #Start and Stop the Device
# function initialize(trig::TRIG)
#     @error "initialize not implemented"
# end

# function shutdown(trig::TRIG)
#     @error "shutdown not implemented"
# end

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
    @error "setvalue not implemented"
end

function setoutputrange(trig::TRIG, output::Output, channel::Int, range::Any)
    @error "setrange not implemented"
end

function getoutputvalue(trig::TRIG, output::Output, channel::Int)
    @error "getvalue not implemented"
end

function getinputvalue(trig::TRIG, input::Input, channel::Int)
    @error "getvalue not implemented"
end

