    
include("constants_okFP.jl")
include("functions_okFP.jl")

const okFP = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64\\okFrontPanel.dll"

devicehandle = okFrontPanel_Construct()
num = okFrontPanel_GetDeviceCount(devicehandle)
if num == 0
    println("No fpga board found.")
    return
end

# find device model and serial number
fpgalabel = string(okFrontPanel_GetDeviceListModel(devicehandle, 0))
println("FPGA board found: " * fpgalabel)

buffersize = 128
serialstring = zeros(UInt8, buffersize)
okFrontPanel_GetDeviceListSerial(devicehandle, 0, serialstring)
serialstring = filter(x -> x != 0x00, serialstring)

# open the device
err = okFrontPanel_OpenBySerial(devicehandle, serialstring)
if err != ok_ErrorCode(0)
    println("Failed to open FPGA board: " * string(err))
    return
end
serialnumber = String(serialstring)
println("FPGA board serial number: " * serialnumber)

# configure the FPGA
bitfile = raw"C:\Users\sheng\Documents\Vivado\dac_clk_fp_1\dac_clk_fp_1.runs\impl_1\dac_clk_fp.bit"
err = okFrontPanel_ConfigureFPGA(devicehandle, bitfile)
if err != ok_ErrorCode(0)
    println("Failed to configure FPGA: " * string(err))
    return
end



const EP_WIREIN_A = 0x01
const EP_WIREIN_B = 0x02
const EP_WIREIN_C = 0x03
const EP_WIREIN_D = 0x04

const EP_WIREIN_START = 0x05
const BIT_START = 0x01
const BIT_STOP = 0x00

const EP_TRIGGEROUT_CYCLEEND = 0x60
const TRIG_BIT_CYCLEEND = 0x01

# Voltage-to-code helper (adjust for DAC8814 mode)
function volts_to_code(v::Float64; vmin::Float64=-10.0, vmax::Float64=10.0)
    if v < vmin || v > vmax
        error("Voltage $v V out of range for Vmin=$vmin V and Vmax=$vmax V")
    end
    return UInt32(round(65535 - ((v - vmin) / (vmax - vmin)) * 65535))
end

# Main routine


# Example voltages
a = volts_to_code(-0.205)
b = volts_to_code(0.205)
c = volts_to_code(0.405)
d = volts_to_code(-0.405)

# Write voltages

err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_A, a, 0xFFFF)
err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_B, b, 0xFFFF)
err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_C, c, 0xFFFF)
err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_D, d, 0xFFFF)
err = okFrontPanel_UpdateWireIns(devicehandle)

# start
err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_START, BIT_START, 0xFFFF)
err = okFrontPanel_UpdateWireIns(devicehandle)
# stop
err = okFrontPanel_SetWireInValue(devicehandle, EP_WIREIN_START, BIT_STOP, 0xFFFF)
err = okFrontPanel_UpdateWireIns(devicehandle)

#err = okFrontPanel_ActivateTriggerIn(devicehandle, EP_TRIGGERIN_START, TRIG_BIT_START)

#err = okFrontPanel_UpdateTriggerOuts(devicehandle)

#iscycleend = okFrontPanel_IsTriggered(devicehandle, EP_TRIGGEROUT_CYCLEEND, TRIG_BIT_CYCLEEND)

err = okFrontPanel_Destruct(devicehandle)
