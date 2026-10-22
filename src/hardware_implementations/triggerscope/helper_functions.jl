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
    try
        sp_flush(scope.sp, SP_BUF_BOTH)
        write(scope.sp, commandstring)
        sleep(scope.compause)
    catch e
        closeport(scope)
        openport(scope)
        error("Failed to read response from scope: Resetting port ")
        return nothing
    end
end

function readresponse(scope::Triggerscope4)
    try
        line = readline(scope.sp)
        sleep(scope.compause)
        return line
    catch e
        closeport(scope)
        openport(scope)
        error("Failed to read response from scope: Resetting port ")
        return nothing
    end
end

function openport(scope::Triggerscope4)
    # Open the serial port
    scope.sp = open(scope.portname, scope.baudrate)

    LibSerialPort.sp_set_dtr(scope.sp.ref, SP_DTR_ON)
    
    set_read_timeout(scope.sp, scope.rwtimeout)
    set_write_timeout(scope.sp, scope.rwtimeout)
    
    # Flush buffers
    sp_flush(scope.sp, SP_BUF_BOTH)
    
    # Wait for device to stabilize
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
