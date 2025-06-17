#These are julia implementations of the sequence control functions on the Triggerscope in the order they appear in the DAC documentation 
#Each function should generate an ASCII String of the format of the command

#arms the triggerscope with the script written to it
function arm(scope::Triggerscope4)
    #Build string
    commandstring = "ARM\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

#Clears the program written to the triggerscope
function clearall(scope::Triggerscope4)
    #Build string
    commandstring = "CLEAR_ALL\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end
#Focus settings for the triggerscope, see manual for more information
function progfocus(scope::Triggerscope4, startpos::Int, stepsize::Int, numsteps::Int, direction::Bool, priority::Bool)
    #Build string
    commandstring = "PROG_FOCUS," * string(startpos) * "," * string(stepsize) * "," * string(numsteps) * "," * string(Int(direction)) * "," * string(Int(priority)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function progttl(scope::Triggerscope4, programline::Int, ttlnum::Int, ttlval::Bool)
    #Build string
    commandstring = "PROG_TTL," * string(programline) * "," * string(ttlnum) * "," * string(Int(ttlval)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    scope.ttloutputs[ttlnum] = ttlval
    return readresponse(scope)
end

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
function cleartable(scope::Triggerscope4)
    #Build string
    commandstring = "CLEARTABLE\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

#Add delay to specific line (in ms)
# NOTE: Problems with both matlab and julia prog_delay with both 4 and 3B models
function progdelay(scope::Triggerscope4, programline::Int, delayms::Int)
    #Build string
    commandstring = "PROG_DEL," * string(programline) * "," * string(delayms) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end
"""
Can have two waveforms per line (0, 1)

Waveforms are as follows:
1: Sine
2: Sawtooth
3: Triangle
4: Square

Duty cycle in percent, phase in degrees
"""
# NOTE: Does not appear to function, also not present in offical documentation
function progwave(scope::Triggerscope4, arrayindex::Bool, dacnum::Int, waveform::Int, centervolt::Float64, dutycycle::Int, phase::Int, trigtype::Int; programstep::Int = 0)
    #Build string
    commandstring = "PROG_WAVE," * string(Int(arrayindex)) * "," * string(dacnum) * "," * string(waveform) * "," * string(volttooutput(scope, dacnum, centervolt)) * "," * string(dutycycle) * "," * string(phase) * "," * string(trigtype) * "," * string(programstep) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
    
end

function timecycles(scope::Triggerscope4, cycles::Int)
    #Build string
    commandstring = "TIMECYCLES," * string(cycles) * "\n"
    #Write command
    writecommand(scope, commandstring)
    return readresponse(scope)
end

function trigmode(scope::Triggerscope4, mode::TriggerMode)
    #Build string
    commandstring = "TRIGMODE," * string(Int(mode)) * "\n"
    #Write command
    writecommand(scope, commandstring)
    scope.trigmode = mode
    return readresponse(scope)
end

"""
    genprogarray(scope::Triggerscope4, signalArr::SignalArray, NLoops::Int, Arm::bool)

Programs an array of commands to the scanner's scope

# Arguments
- `scope::Triggerscope4`: The triggerscope object
- `signalArr::SignalArray`: The array of commands to be sent
- `NLoops::Int`: The number of times the program should loop
- `Arm::bool`: If the "ARM" command should be run after the program
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
    for (c, command) in enumerate(signalArr.commands)
        if command.commandType == DAC
            if typeof(command.value) != Float64 
                @error "Value for DAC must be Float64" 
            end
            progdac(scope, c, command.channel, command.value)
        elseif command.commandType == TTL
            if typeof(command.value) != Bool 
                @error "Value for TTL must be Bool" 
            end
            progttl(scope, c, command.channel, command.value)
        end
    end

    if arm(scope) end
end