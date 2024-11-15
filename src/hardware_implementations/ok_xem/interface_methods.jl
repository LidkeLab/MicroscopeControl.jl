
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

function enable(fpga::XEM, enable::Float64)
    NIDAQcard.setvoltage(fpga.daq,fpga.task_enable, enable) 
    return nothing
end

function shutdown(fpga::XEM)
    okFrontPanel_Destruct(fpga.devicehandle)
    return nothing
end