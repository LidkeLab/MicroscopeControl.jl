#These are functions that are used to interact with DAQ devices, these must be implemented for each device and are general

# #Start and Stop the Device
# function initialize(trig::TRIG)
#     @error "initialize not implemented"
# end

# function shutdown(trig::TRIG)
#     @error "shutdown not implemented"
# end

"""
    Base.reset(trig::TRIG)

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

#Functions to set and read values from the DAQ device
"""
    TrigInterface.setoutputvalue(trig::TRIG, output::Output, channel::Int, value)

Command `channel` of the output group `output` to `value` (volts for an analog group, `Bool` for a digital one)
and record it in `output.values`. Not exported.
"""
function setoutputvalue(trig::TRIG, output::Output, channel::Int, value::Any)
    error("setoutputvalue not implemented for $(typeof(trig))")
end

"""
    TrigInterface.setoutputrange(trig::TRIG, output::Output, channel::Int, range)

Set the output range of `channel` in `output`, for groups whose range can change (`output.israngevariable`).
Not exported.
"""
function setoutputrange(trig::TRIG, output::Output, channel::Int, range::Any)
    error("setoutputrange not implemented for $(typeof(trig))")
end

"""
    TrigInterface.getoutputvalue(trig::TRIG, output::Output, channel::Int)

The value last commanded on `channel` of `output`. Not exported.
"""
function getoutputvalue(trig::TRIG, output::Output, channel::Int)
    error("getoutputvalue not implemented for $(typeof(trig))")
end

"""
    TrigInterface.getinputvalue(trig::TRIG, input::Input, channel::Int)

The value of `channel` of the input group `input`. Not exported. `[limitation]` `Triggerscope4` cannot read its
inputs this way: its method logs an error and returns the stored `input.values[channel]`.
"""
function getinputvalue(trig::TRIG, input::Input, channel::Int)
    error("getinputvalue not implemented for $(typeof(trig))")
end

