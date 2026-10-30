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
(`scope.dacranges`). Throws `ArgumentError` when `voltage` is not finite or its rounded code
falls outside 0-65535; such a code used to be sent anyway, and the device wrapped or clipped it.
Every voltage that gave a valid code before still gives the same one, including a value a hair
past an end that rounds to the end code (`nextfloat(5.0)` on 0-5 V gives 65535).

Call it with `scope.lock` held, in the same transaction as the command that sends the code: the
range it reads must still be the board's range when the code arrives.
"""
function volttooutput(scope::Triggerscope4,  dacchannel::Int,voltage::Float64)
    range = scope.dacranges[dacchannel]
    lo, hi = dac_range_volts(range)
    code = isfinite(voltage) ? round((voltage - lo) * 65535 / (hi - lo)) : NaN
    0 <= code <= 65535 || throw(ArgumentError(
        "Triggerscope DAC $dacchannel: $voltage V gives a code outside 0-65535 on its range [$lo, $hi] V ($range)"))
    return Int(code)
end

# LibSerialPort timeouts are a CUMULATIVE budget: every read call uses at least 1 ms of it, and once it is spent the
# next read throws `Timeout` (and the budget then reads 0 = wait forever). Set once at `openport`, the 10 s budget ran
# out after a few thousand commands, so one command in a few thousand failed and reset the port (rig, 2026-10-15,
# 1 in 2500-5000 at 400 Hz). It is re-armed here for every command, so `rwtimeout` is the limit of ONE command.
#
# The serial calls go through the five one-line wrappers below, so the tests can replace them with a recorder
# (`test/triggerscope.jl`) and run the constructor, `writecommand`, `readresponse` and the command functions
# unmodified, without touching the host's serial layer on any platform.
_new_port(portname) = LibSerialPort.SerialPort(portname)   # the constructor's port object, not yet opened
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
