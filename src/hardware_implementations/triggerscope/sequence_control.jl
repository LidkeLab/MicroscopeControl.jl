#These are julia implementations of the sequence control functions on the Triggerscope in the order they appear in the DAC documentation 
#Each function should generate an ASCII String of the format of the command

#arms the triggerscope with the script written to it
"""
    arm(scope::Triggerscope4) -> String

Send `ARM` to arm the program written to the device (see `progdac`, `progttl`, [`trigmode`](@ref)) and
return the response line.
"""
function arm(scope::Triggerscope4)
    #Build string
    commandstring = "ARM\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

#Clears the program written to the triggerscope
"""
    clearall(scope::Triggerscope4) -> String

Send `CLEAR_ALL`, which clears the program held on the device, and return the response line.
"""
function clearall(scope::Triggerscope4)
    #Build string
    commandstring = "CLEAR_ALL\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end
#Focus settings for the triggerscope, see manual for more information
"""
    progfocus(scope::Triggerscope4, startpos::Int, stepsize::Int, numsteps::Int, direction::Bool,
              priority::Bool) -> String

Send `PROG_FOCUS,<startpos>,<stepsize>,<numsteps>,<direction>,<priority>` (the two `Bool`s as 0 or 1) and
return the response line. All values are passed to the device unchanged; the code gives no units.
The source comment refers to the vendor manual for their meaning.
"""
function progfocus(scope::Triggerscope4, startpos::Int, stepsize::Int, numsteps::Int, direction::Bool, priority::Bool)
    #Build string
    commandstring = "PROG_FOCUS," * string(startpos) * "," * string(stepsize) * "," * string(numsteps) * "," * string(Int(direction)) * "," * string(Int(priority)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    progttl(scope::Triggerscope4, programline::Int, ttlnum::Int, ttlval::Bool) -> String

Program TTL output `ttlnum` to go high or low at program line `programline` by sending
`PROG_TTL,<line>,<ttl>,<0 or 1>`. `[limitation]` After the command is written the function assigns into
`scope.ttloutputs`, which is an `Int` (the output count) rather than a vector, so the call throws a
`MethodError` and never returns the response line; the command itself has already been sent.
"""
function progttl(scope::Triggerscope4, programline::Int, ttlnum::Int, ttlval::Bool)
    #Build string
    commandstring = "PROG_TTL," * string(programline) * "," * string(ttlnum) * "," * string(Int(ttlval)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    scope.ttloutputs[ttlnum] = ttlval
    return readresponse(scope)
end

"""
    progdac(scope::Triggerscope4, programline::Int, dacnum::Int, voltage::Float64) -> String

Program DAC channel `dacnum` to `voltage` volts at program line `programline` by sending
`PROG_DAC,<line>,<dac>,<code>`, and return the response line. The 16-bit code comes from the range in
`scope.dacranges[dacnum]` (see [`setdac`](@ref)); `scope.dacvalues[dacnum]` is set to that code. The
voltage is not range-checked.
"""
function progdac(scope::Triggerscope4, programline::Int, dacnum::Int, voltage::Float64)
    dac_code = volttooutput(scope, dacnum, voltage)
    #Build string
    commandstring = "PROG_DAC," * string(programline) * "," * string(dacnum) * "," * string(dac_code) * "\n"
    #Write command
    writecommand(scope, commandstring)
    scope.dacvalues[dacnum] = dac_code
    return readresponse(scope)
end

#"Clears active program table"
"""
    cleartable(scope::Triggerscope4) -> String

Send `CLEARTABLE`, which clears the active program table, and return the response line.
"""
function cleartable(scope::Triggerscope4)
    #Build string
    commandstring = "CLEARTABLE\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

#Add delay to specific line (in ms)
# NOTE: Problems with both matlab and julia prog_delay with both 4 and 3B models
"""
    progdelay(scope::Triggerscope4, programline::Int, delayms::Int) -> String

Add a delay of `delayms` milliseconds to program line `programline` by sending `PROG_DEL,<line>,<ms>`,
and return the response line. `[limitation]` A source comment notes problems with this command on both
the Triggerscope 4 and 3B, in both the Julia and the MATLAB implementations.
"""
function progdelay(scope::Triggerscope4, programline::Int, delayms::Int)
    #Build string
    commandstring = "PROG_DEL," * string(programline) * "," * string(delayms) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end
# NOTE: Does not appear to function, also not present in offical documentation
"""
    progwave(scope::Triggerscope4, arrayindex::Bool, dacnum::Int, waveform::Int, centervolt::Float64,
             dutycycle::Int, phase::Int, trigtype::Int; programstep::Int=0) -> String

Program a waveform on DAC channel `dacnum` by sending `PROG_WAVE,...` and return the response line.
A program line holds two waveforms; `arrayindex` (sent as 0 or 1) selects which. `waveform` is 1 sine,
2 sawtooth, 3 triangle, 4 square; `centervolt` (V) is converted to a DAC code with the channel's stored
range; `dutycycle` is in percent and `phase` in degrees. `trigtype` and `programstep` are passed to the
device unchanged. `[limitation]` A source comment says the command does not appear to function and is not in
the official documentation.
"""
function progwave(scope::Triggerscope4, arrayindex::Bool, dacnum::Int, waveform::Int, centervolt::Float64, dutycycle::Int, phase::Int, trigtype::Int; programstep::Int = 0)
    #Build string
    commandstring = "PROG_WAVE," * string(Int(arrayindex)) * "," * string(dacnum) * "," * string(waveform) * "," * string(volttooutput(scope, dacnum, centervolt)) * "," * string(dutycycle) * "," * string(phase) * "," * string(trigtype) * "," * string(programstep) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
    
end

"""
    timecycles(scope::Triggerscope4, cycles::Int) -> String

Send `TIMECYCLES,<cycles>` and return the response line. The value is passed to the device unchanged;
[`progarray`](@ref) passes its loop count here.
"""
function timecycles(scope::Triggerscope4, cycles::Int)
    #Build string
    commandstring = "TIMECYCLES," * string(cycles) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

"""
    trigmode(scope::Triggerscope4, mode::TriggerMode) -> String

Send `TRIGMODE,<code>` with the integer value of `mode` and return the response line.
`scope.trigmode` is set to `mode` after the write and before the response is read.
"""
function trigmode(scope::Triggerscope4, mode::TriggerMode)
    #Build string
    commandstring = "TRIGMODE," * string(Int(mode)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    scope.trigmode = mode
    return readresponse(scope)
end

"""
    progarray(scope::Triggerscope4, signalArr::SignalArray, NLoops::Int, arm::Bool)

Intended to program a [`SignalArray`](@ref) onto the device and optionally arm it: clear the device,
set the trigger mode, save settings, reset, set the cycle count to `NLoops`, set DAC ranges from the
voltages used, then send each command with `progdac` or `progttl`. `[limitation]` As written the function
cannot complete. It first calls [`trigmode`](@ref) with an `Int`, which has no method (a `MethodError`),
after `clearall` has already been sent; the later range-selection and programming loops also reference
variables and fields that do not exist (`dacChannelVals` outside its loop, `command.progLine`).
"""
function progarray(scope::Triggerscope4, signalArr::SignalArray, NLoops::Int, arm::Bool)
    # Basic Setting init
    clearall(scope)
    trigmode(scope, Int(signalArr.trigMode))
    savesettings(scope)
    reset(scope)
    timecycles(scope, NLoops)

    # Select appropriate ranges
    # I know this is horribly inefficient code, because it requires generating a 
    # large array when it is not always needed and there are so many loops,
    # but I am not clever enough to find a way to accomplish this otherwise. 
    # Please replace if you have ideas
    for command in signalArr.commands
        # each arr represents one of the 16 avaliable DAC channels
        dacChannelVals = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
        if command.commandType == DAC
            push!(dacChannelVals[command.channel, command.value])
        end
    end
    # go through every channel to find maxes and mins to give to helper func selectVoltRange()
    for (i, channelVals) in enumerate(dacChannelVals)
        if !isempty(channelVals)
            range = selectVoltRange(min(channelVals), max(channelVals))
            setrange(scope, i, range)
        end
    end

    # Go through and program the command sequence
    for command in enumerate(signalArr.commands)
        if command.commandType == DAC
            if typeof(command.value) != Float64 
                @error "Value for DAC must be Float64" 
            end
            progdac(scope, command.progLine, command.channel, command.value)
        elseif command.commandType == TTL
            if typeof(command.value) != Bool 
                @error "Value for TTL must be Bool" 
            end
            progttl(scope, command.progLine, command.channel, command.value)
        end
    end

    if arm(scope) end
end