
function initialize(fpga::XEM)
    # open the device handle
    fpga.devicehandle = okFrontPanel_Construct()
    num = okFrontPanel_GetDeviceCount(fpga.devicehandle)
    if num == 0
        println("No fpga board found.")
        return
    end

    # find device model and serial number
    fpga.fpgalabel = string(okFrontPanel_GetDeviceListModel(fpga.devicehandle,0))
    println("FPGA board found: "*fpga.fpgalabel)

    buffersize = 128
    serialstring = zeros(UInt8, buffersize)
    okFrontPanel_GetDeviceListSerial(fpga.devicehandle,0,serialstring)
    serialstring = filter(x -> x != 0x00, serialstring)

    # open the device
    err = okFrontPanel_OpenBySerial(fpga.devicehandle,serialstring)
    if err != ok_ErrorCode(0)
        println("Failed to open FPGA board: "*string(err))
        return
    end
    fpga.serialnumber = String(serialstring)
    println("FPGA board serial number: "*fpga.serialnumber)

    # configure the FPGA
    err = okFrontPanel_ConfigureFPGA(fpga.devicehandle, fpga.bitfile)
    if err != ok_ErrorCode(0)
        println("Failed to configure FPGA: "*string(err))
        return
    end

    println("FPGA is initialized.")
    return nothing
end

"""
    setupIO(fpga::XEM) -> nothing

Create the two NI digital-output tasks the FPGA board is driven through. With `devs` the DAQ devices found
by `showdevices`, `showchannels(daq, "DO", devs[1])` lists the digital-output channels of the first device:
the exposure-trigger task takes channels 4, 3, 2 and 1 of that list (added in that order) and the enable
task takes channel 5. The tasks are stored in `fpga.task_trigger` and `fpga.task_enable`. Needs NI-DAQmx;
nothing is sent to the FPGA.
"""
function setupIO(fpga::XEM)
    devs = NIDAQcard.showdevices(fpga.daq)
    channelsDO = NIDAQcard.showchannels(fpga.daq,"DO",devs[1])
    task_trigger = NIDAQcard.createtask(fpga.daq,"DO",channelsDO[4])
    for i in 3:-1:1
        NIDAQcard.addchannel!(fpga.daq,task_trigger, "DO", channelsDO[i])
    end
    task_enable = NIDAQcard.createtask(fpga.daq,"DO",channelsDO[5])

    fpga.task_trigger = task_trigger
    fpga.task_enable = task_enable

    return nothing
end

"""
    setexposure(fpga::XEM, exposure_time::Float64) -> Matrix{Float64}
    setexposure(fpga::XEM, volt_digit::Array{Float64}) -> nothing

First form: set the exposure `exposure_time` (us) on the FPGA through the four trigger lines. With
`div = ceil(exposure_time / fpga.exposure_bit)`, it finds `i` in 0:15 with `2^i <= div < 2^(i+1)`, stores the
exposure actually set, `2^i * fpga.exposure_bit` us, in `fpga.exposure_time` (printed), keeps the four
low bits of `i` as the string `fpga.volt_bit`, and writes the digits `[8, 4, 2, 1]` (each kept where its bit
is 1, else 0) to `fpga.task_trigger`. It returns the 1 by 4 digit matrix. So the exposure is rounded to a
power-of-two multiple of `exposure_bit`, not the requested value.
`[limitation]` A request with `div` below 1 or at or above 65536 matches no `i` and the call fails with an
error before anything is written.

Second form: write `volt_digit` to `fpga.task_trigger` as is, without touching `fpga.exposure_time` or
`fpga.volt_bit`. Requires [`setupIO`](@ref) first.
"""
function setexposure(fpga::XEM, exposure_time::Float64)
    volt_bit = 0
    for i in 0:15
        div = ceil(exposure_time/fpga.exposure_bit)
        if div>=2^i && div<2^(i+1)
            fpga.exposure_time = 2^i*fpga.exposure_bit
            println("The exposure time is ",fpga.exposure_time," us")
            volt_bit = bitstring(UInt16(i))
            break
        end
    end

    volt_bit = volt_bit[end-3:end]
    fpga.volt_bit = volt_bit
    volt_digit = zeros(1,4)
    for i in 1:4
        if volt_bit[i] == '1'
            volt_digit[i] = 2^(4-i)
        else
            volt_digit[i] = 0
        end
    end

    NIDAQcard.setvoltage(fpga.daq,fpga.task_trigger, volt_digit) 

    return volt_digit
end

function setexposure(fpga::XEM, volt_digit::Array{Float64})
    NIDAQcard.setvoltage(fpga.daq,fpga.task_trigger, volt_digit) 
    return nothing
end

"""
    enable(fpga::XEM, enable::Float64) -> nothing

Write `enable` to the enable task `fpga.task_enable` (see [`setupIO`](@ref)) through `NIDAQcard.setvoltage`;
`fpga.enable` is not updated. The unexported constants `TRIGGER_OFF` (0.0) and `TRIGGER_ON` (16.0) are the
values the struct's `enable` default uses. `NIDAQcard.setvoltage` accepts only 0 or 1 for a single-line
digital task and the port word for a port task, so `TRIGGER_ON` is accepted only when the task channel is a
port.
"""
function enable(fpga::XEM, enable::Float64)
    NIDAQcard.setvoltage(fpga.daq,fpga.task_enable, enable) 
    return nothing
end

function shutdown(fpga::XEM)
    okFrontPanel_Destruct(fpga.devicehandle)
    return nothing
end

"""
    setwirein(fpga::XEM, epaddr::UInt8, value::UInt32) -> nothing

Set FrontPanel wire-in endpoint `epaddr` to `value` and apply it to the FPGA (`SetWireInValue` with mask
`0xFFFF`, so only the low 16 bits of `value` are written, then `UpdateWireIns`). `[limitation]` A failing
FrontPanel call is reported with `println` and the function returns `nothing` as on success; nothing is
thrown.
"""
function setwirein(fpga::XEM, epaddr::UInt8, value::UInt32)
    err = okFrontPanel_SetWireInValue(fpga.devicehandle, epaddr, value, 0xFFFF)
    if err != ok_ErrorCode(0)
        println("Failed to set wire in value: "*string(err))
        return
    end
    err = okFrontPanel_UpdateWireIns(fpga.devicehandle)
    if err != ok_ErrorCode(0)
        println("Failed to update wire ins: "*string(err))
        return
    end
    return nothing
end

"""
    activetriggerin(fpga::XEM, epaddr::UInt8, bitmask::UInt32) -> nothing

Fire the trigger-in bits of `bitmask` on FrontPanel endpoint `epaddr` (`ActivateTriggerIn`). `[limitation]`
A failing call is reported with `println` and the function returns `nothing` as on success; nothing is thrown.
"""
function activetriggerin(fpga::XEM, epaddr::UInt8, bitmask::UInt32)
    err = okFrontPanel_ActivateTriggerIn(fpga.devicehandle, epaddr, bitmask)
    if err != ok_ErrorCode(0)
        println("Failed to activate trigger in: "*string(err))
        return
    end
    return nothing
end

"""
    getwireout(fpga::XEM, epaddr::UInt8) -> Union{UInt32, Nothing}

Refresh the FrontPanel wire-outs (`UpdateWireOuts`) and return the value of wire-out endpoint `epaddr` as a
`UInt32`. If the refresh fails the error is printed and `nothing` is returned.
"""
function getwireout(fpga::XEM, epaddr::UInt8)
    # Update wire outs first (required!)
    err = okFrontPanel_UpdateWireOuts(fpga.devicehandle)
    if err != ok_ErrorCode(0)
        println("Failed to update wire outs: " * string(err))
        return nothing
    end

    # Read value
    value = okFrontPanel_GetWireOutValue(fpga.devicehandle, epaddr)

    return UInt32(value)
end