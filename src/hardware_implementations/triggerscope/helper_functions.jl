"""
    dac_range_volts(range::Range) -> (v_min, v_max)

The output voltage span of a Triggerscope DAC range.
"""
function dac_range_volts(range::Range)
    range == ZEROTOFIVE && return (0.0, 5.0)
    range == ZEROTOTEN && return (0.0, 10.0)
    range == PLUSMINUS5 && return (-5.0, 5.0)
    range == PLUSMINUS10 && return (-10.0, 10.0)
    range == PLUSMINUS2_5 && return (-2.5, 2.5)
    throw(ArgumentError("unknown Triggerscope range $range"))
end

"""
    volttooutput(scope, dacchannel, voltage) -> Int

The 16-bit DAC code for `voltage` in the range the driver last set on `dacchannel`
(`scope.dacranges`). Throws `ArgumentError` when `voltage` is not finite or lies outside that
range; the code used to be sent anyway, so a value off the end of the range wrapped or was
clipped by the device.
"""
function volttooutput(scope::Triggerscope4,  dacchannel::Int,voltage::Float64)
    lo, hi = dac_range_volts(scope.dacranges[dacchannel])
    (isfinite(voltage) && lo <= voltage <= hi) || throw(ArgumentError(
        "Triggerscope DAC $dacchannel: $voltage V is outside its range [$lo, $hi] V ($(scope.dacranges[dacchannel]))"))
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

# LibSerialPort timeouts are a CUMULATIVE budget: every read call uses at least 1 ms of it, and once it is spent the
# next read throws `Timeout` (and the budget then reads 0 = wait forever). Set once at `openport`, the 10 s budget ran
# out after a few thousand commands, so one command in a few thousand failed and reset the port (rig, 2026-10-15,
# 1 in 2500-5000 at 400 Hz). It is re-armed here for every command, so `rwtimeout` is the limit of ONE command.
#
# The serial calls go through the four one-line wrappers below, so the tests can replace them with a recorder
# (`test/triggerscope.jl`) and run `writecommand`, `readresponse` and the command functions unmodified.
_arm_timeouts!(sp, seconds) = (set_write_timeout(sp, seconds); set_read_timeout(sp, seconds); nothing)
_flush_port!(sp) = (sp_flush(sp, SP_BUF_BOTH); nothing)
_send!(sp, commandstring) = (write(sp, commandstring); nothing)
_receive!(sp) = readline(sp)

function writecommand(scope::Triggerscope4, commandstring::String)
    try
        _arm_timeouts!(scope.sp, scope.rwtimeout)   # the reply read that follows gets the full limit too
        _flush_port!(scope.sp)
        _send!(scope.sp, commandstring)
        sleep(scope.compause)
    catch e
        closeport(scope)
        openport(scope)
        error("Triggerscope $(scope.portname): serial command failed ($(sprint(showerror, e))): port reset")
        return nothing
    end
end

function readresponse(scope::Triggerscope4)
    try
        line = _receive!(scope.sp)
        sleep(scope.compause)
        return line
    catch e
        closeport(scope)
        openport(scope)
        error("Triggerscope $(scope.portname): serial command failed ($(sprint(showerror, e))): port reset")
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
