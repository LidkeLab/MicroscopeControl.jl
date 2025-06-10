#these are Julia implementations of the direct control functions on the Triggerscope
#Each function should generate an ASCII String of the format of the command

"""
Runs tha acknowledgement test on the Triggerscope
"""
function acknowledgetest(scope::Triggerscope4)
    commandstring = "*\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
Recieves a DAC number and a voltage value and sets the DAC to that value after converting the voltage to a 16 bit integer value
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

function focus(scope::Triggerscope4, focusval::Int)
    #create the command string
    #Sets "dac assigned" to focus
    commandstring = "FOCUS," * string(focusval) * "\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function setttl(scope::Triggerscope4, channel::Int, ttlval::Bool)
    #create the command string
    #Sets ttl output to 0 or 1 "True or false"
    commandstring = "TTL," *string(channel) * "," * string(Int(ttlval)) * "\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function setrange(scope::Triggerscope4, dacchannel::Int, range::Range)
    #create the command string
    commandstring = "RANGE" * string(dacchannel) * "," * string(Int(scope.dacranges[dacchannel])) * "\n"

    #write the command to the serial port
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function getstatus(scope::Triggerscope4)
    #create the command string
    commandstring = "STAT?\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function runtest(scope::Triggerscope4)
    #create the command string
    commandstring = "TEST?\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function reset(scope::Triggerscope4)
    #create the command string
    commandstring = "RESET\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function savesettings(scope::Triggerscope4)
    #create the command string
    commandstring = "SAVESETTINGS\n"
    writecommand(scope, commandstring)
    return readresponse(scope)
end
