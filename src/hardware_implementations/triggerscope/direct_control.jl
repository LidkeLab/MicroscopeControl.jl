#these are Julia implementations of the direct control functions on the Triggerscope
#Each function should generate an ASCII String of the format of the command

"""
Runs the acknowledgement test on the Triggerscope
"""
function acknowledgetest(scope::Triggerscope4)
    commandstring = "*\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

"""
Recieves a DAC number and a voltage value and sets the DAC to that value after converting the voltage to a 16 bit integer value
"""
function setdac(scope::Triggerscope4, dacnum::Int, voltvalue::Float64)
    # The conversion reads the DAC's range, so it is under the same lock as the command: another task's `setrange`
    # cannot land between the encoding and the write (0 V encoded for +-10 V is not 0 V on a 0-10 V DAC).
    return lock(scope.lock) do   # the encoding, the write and its reply together: the LCAs and a MOD IN output may share this scope
        #convert the voltage value to a 16 bit integer value depending on range
        dacoutput = volttooutput(scope, dacnum, voltvalue)

        #create the command string
        commandstring = "DAC" * string(dacnum) * "," * string(dacoutput) * "\n"

        #write the command to the serial port
        transact(scope, commandstring)
    end
end

function focus(scope::Triggerscope4, focusval::Int)
    #create the command string
    #Sets "dac assigned" to focus
    commandstring = "FOCUS," * string(focusval) * "\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

function setttl(scope::Triggerscope4, channel::Int, ttlval::Bool)
    #create the command string
    #Sets ttl output to 0 or 1 "True or false"
    commandstring = "TTL" *string(channel) * "," * string(Int(ttlval)) * "\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

function setrange(scope::Triggerscope4, dacchannel::Int, range::Range)
    return lock(scope.lock) do   # the cached range, the write and its reply together: the LCAs and a MOD IN output may share this scope
        #create the command string
        commandstring = "RANGE" * string(dacchannel) * "," * string(Int(range)) * "\n"

        # The cache changes only once the transaction has completed. A failure leaves the device's range ambiguous (the
        # command may have been applied), so the DAC is marked unknown and refuses writes until a RANGE succeeds.
        response = try
            transact(scope, commandstring)
        catch
            push!(scope.range_unknown, dacchannel)
            rethrow()
        end
        scope.dacranges[dacchannel] = range  # Update the range in the scope object
        delete!(scope.range_unknown, dacchannel)
        response
    end
end

function getstatus(scope::Triggerscope4)
    #create the command string
    commandstring = "STAT?\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

function runtest(scope::Triggerscope4)
    #create the command string
    commandstring = "TEST?\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

function Base.reset(scope::Triggerscope4)
    #create the command string
    commandstring = "RESET\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end

function savesettings(scope::Triggerscope4)
    #create the command string
    commandstring = "SAVESETTINGS\n"
    return lock(scope.lock) do   # the write and its reply together: the LCAs and a MOD IN output may share this scope
        writecommand(scope, commandstring)
        readresponse(scope)
    end
end
