using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.OK_XEM




fpga = XEM()
fpga.bitfile = raw"C:\Users\sheng\Documents\Vivado\test_div\test_div.runs\impl_1\normalize_fp.bit"
initialize(fpga)


#----------------------------------------
# Endpoint Constants
#----------------------------------------
const EP_WIREIN_CTRL = 0x00
const EP_WIREIN_X0   = 0x01
const EP_WIREIN_X1   = 0x02
const EP_WIREIN_X2   = 0x03

const EP_WIREOUT_Y0  = 0x20
const EP_WIREOUT_Y1  = 0x21
const EP_WIREOUT_ST  = 0x22

#----------------------------------------
# Control Constants
#----------------------------------------
const CTRL_VALID_ON  = UInt32(0x00000001)
const CTRL_VALID_OFF = UInt32(0x00000000)

#----------------------------------------
# Helper: convert 32-bit → signed 16-bit
#----------------------------------------
function to_int16(x::UInt32)
    val = x & 0xFFFF              # keep only lower 16 bits
    return reinterpret(Int16, UInt16(val))
end

function q14_to_float(x::UInt32)
    val = to_int16(x)             # signed 16-bit
    return Float64(val) / 16384   # 2^14 = 16384
end
#----------------------------------------
# One transaction
#----------------------------------------
function send_and_read(fpga::XEM, x0::Int16, x1::Int16, x2::Int16)
    #x0 = Int16(100)
    #x1 = Int16(200)
    #x2 = Int16(20)

    setwirein(fpga, EP_WIREIN_X0, UInt32(reinterpret(UInt16, x0)))
    setwirein(fpga, EP_WIREIN_X1, UInt32(reinterpret(UInt16, x1)))
    setwirein(fpga, EP_WIREIN_X2, UInt32(reinterpret(UInt16, x2)))

    # Pulse valid_in using constants
    setwirein(fpga, EP_WIREIN_CTRL, CTRL_VALID_ON)
    sleep(0.001)
    setwirein(fpga, EP_WIREIN_CTRL, CTRL_VALID_OFF)
    sleep(0.0005)

    status = getwireout(fpga, EP_WIREOUT_ST)


    y0_raw = getwireout(fpga, EP_WIREOUT_Y0)
    y1_raw = getwireout(fpga, EP_WIREOUT_Y1)

    y0_q14 = to_int16(y0_raw)
    y1_q14 = to_int16(y1_raw)

    y0_real = q14_to_float(y0_raw)
    y1_real = q14_to_float(y1_raw)

    println("INPUT  : x0=$x0 x1=$x1 x2=$x2")
    println("OUTPUT : y0_raw=0x", string(y0_raw, base=16), " y1_raw=0x", string(y1_raw, base=16))
    println("OUTPUT : y0_q14=$y0_q14 y1_q14=$y1_q14 ")
    println("OUTPUT : y0_real=$(round(y0_real, sigdigits=4)) y1_real=$(round(y1_real, sigdigits=4)) (ready=$status)")
    println("--------------------------------------")



end

#----------------------------------------
# Main test
#----------------------------------------


println("Starting normalize_fp test...\n")

send_and_read(fpga, Int16(20),  Int16(50),  Int16(20))
send_and_read(fpga, Int16(40),  Int16(20),  Int16(70))
send_and_read(fpga, Int16(10),     Int16(10),     Int16(10))

println("Test completed.")

shutdown(fpga)