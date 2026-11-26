#these are Julia implementations of the direct control functions on the Triggerscope
#Each function should generate an ASCII String of the format of the command

"""
    acknowledgetest(scope::Triggerscope4) -> String

Send the acknowledgement command `*` and return the device's response line, which [`initialize`](@ref)
logs as the Triggerscope version. Needs an open port.
"""
function acknowledgetest(scope::Triggerscope4)
    commandstring = "*\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    setdac(scope::Triggerscope4, dacnum::Int, voltvalue::Float64) -> String

Set DAC channel `dacnum` to `voltvalue` volts and return the response line. The voltage is converted to a
16-bit code (0 to 65535) with the range held in `scope.dacranges[dacnum]` and sent as `DAC<n>,<code>`.
`[limitation]` The conversion uses the range stored in the object, not one read from the device, and a
voltage outside that range is not clamped or checked: the code is sent as computed.
"""
function setdac(scope::Triggerscope4, dacnum::Int, voltvalue::Float64)
    #convert the voltage value to a 16 bit integer value depending on range
    dacoutput = volttooutput(scope, dacnum, voltvalue)

    #create the command string
    commandstring = "DAC" * string(dacnum) * "," * string(dacoutput) * "\n"

    #write the command to the serial port
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    focus(scope::Triggerscope4, focusval::Int) -> String

Send `FOCUS,<focusval>` and return the response line. The value is passed to the device unchanged; the
code gives no unit or range (the source comment says it sets the DAC assigned to focus).
"""
function focus(scope::Triggerscope4, focusval::Int)
    #create the command string
    #Sets "dac assigned" to focus
    commandstring = "FOCUS," * string(focusval) * "\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    setttl(scope::Triggerscope4, channel::Int, ttlval::Bool) -> String

Set TTL output `channel` high (`true`) or low (`false`) by sending `TTL<channel>,<0 or 1>`, and return the
response line. `scope.ttlvalues` is not updated.
"""
function setttl(scope::Triggerscope4, channel::Int, ttlval::Bool)
    #create the command string
    #Sets ttl output to 0 or 1 "True or false"
    commandstring = "TTL" *string(channel) * "," * string(Int(ttlval)) * "\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    setrange(scope::Triggerscope4, dacchannel::Int, range::Range) -> String

Set the output range of DAC channel `dacchannel` by sending `RANGE<channel>,<code>` (the integer value of
`range`) and return the response line. `scope.dacranges[dacchannel]` is updated before the command is sent,
so it changes even if the write then fails. Later voltage conversions use the new range.
"""
function setrange(scope::Triggerscope4, dacchannel::Int, range::Range)
    #create the command string
    scope.dacranges[dacchannel] = range  # Update the range in the scope object
    commandstring = "RANGE" * string(dacchannel) * "," * string(Int(scope.dacranges[dacchannel])) * "\n"

    #write the command to the serial port
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    getstatus(scope::Triggerscope4) -> String

Send `STAT?` and return the response line, unparsed.
"""
function getstatus(scope::Triggerscope4)
    #create the command string
    commandstring = "STAT?\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    runtest(scope::Triggerscope4) -> String

Send `TEST?` and return the response line, unparsed. What the device does during the test is defined by
the vendor, not by this code.
"""
function runtest(scope::Triggerscope4)
    #create the command string
    commandstring = "TEST?\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    reset(scope::Triggerscope4) -> String

Send `RESET` and return the response line. Extends `Base.reset`; it is not exported from the Triggerscope
module for that reason.
"""
function Base.reset(scope::Triggerscope4)
    #create the command string
    commandstring = "RESET\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    savesettings(scope::Triggerscope4) -> String

Send `SAVESETTINGS` and return the response line. What the device stores is defined by the vendor, not
by this code.
"""
function savesettings(scope::Triggerscope4)
    #create the command string
    commandstring = "SAVESETTINGS\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end
