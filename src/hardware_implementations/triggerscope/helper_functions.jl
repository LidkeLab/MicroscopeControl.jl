function volttooutput(scope::Triggerscope4,  dacchannel::Int,voltage::Float64)
    if scope.dacranges[dacchannel] == ZEROTOFIVE
        return round(Int, voltage * 65535 / 5)
    elseif scope.dacranges[dacchannel] == ZEROTOTEN
        return round(Int, voltage * 65535 / 10)
    elseif scope.dacranges[dacchannel] == PLUSMINUS5
        return round(Int, (voltage + 5) * 65535 / 10)
    elseif scope.dacranges[dacchannel] == PLUSMINUS10
        return round(Int, (voltage + 10) * 65535 / 20)
    elseif scope.dacranges[dacchannel] == PLUSMINUS2_5
        return round(Int, (voltage + 2.5) * 65535 / 5)
    else
        @error "Invalid range"
    end
end

function writecommand(scope::Triggerscope4, commandstring::String)
    sp_flush(scope.sp, SP_BUF_BOTH)
    write(scope.sp, commandstring)
    sleep(scope.compause)
end

function readresponse(scope::Triggerscope4)
    line = readline(scope.sp)
    sleep(scope.compause)
    return line
end

function openport(scope::Triggerscope4)
    scope.sp = LibSerialPort.open(scope.portname, scope.baudrate)
    sleep(scope.compause)
end

function closeport(scope::Triggerscope4)
    close(scope.sp)
end

# selects the best range given the min and max values of a channel
function selectVoltRange(valueMin, valueMax)
    if valueMin >= 0.0
        if valueMax <= 5.0
            return ZEROTOFIVE
        else 
            return ZEROTOTEN
        end
    elseif valueMin >= -2.5
        if valueMax <= 2.5
            return PLUSMINUS2_5
        elseif valueMax <= 5.0
            return PLUSMINUS5
        else 
            return PLUSMINUS10
        end
    elseif valueMin >= -5.0
        if valueMax <= 5.0
            return PLUSMINUS5
        else 
            return PLUSMINUS10
        end
    else 
        return PLUSMINUS10
    end
end
