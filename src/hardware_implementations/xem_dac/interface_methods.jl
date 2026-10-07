const EP_WIREIN_A = 0x01
const EP_WIREIN_B = 0x02
const EP_WIREIN_C = 0x03
const EP_WIREIN_D = 0x04

const EP_WIREIN_START = 0x05
const BIT_START = 0x00000001
const BIT_STOP = 0x00000000


# Voltage-to-code helper (adjust for DAC8814 mode)
""" 
    volts_to_code(v::Float64; vmin::Float64=-10.0, vmax::Float64=10.0)
Convert a voltage value to hex code for the DAC8814.
# Arguments
- `v::Float64`: The voltage value to convert (in volts).
- `vmin::Float64`: The minimum voltage the DAC can output (default: -10.0 V).
- `vmax::Float64`: The maximum voltage the DAC can output (default: 10.0 V).
# Returns
- `UInt32`: The corresponding hex code.
"""
function volts_to_code(v::Float64; vmin::Float64=-10.0, vmax::Float64=10.0)
    if v < vmin || v > vmax
        error("Voltage $v V out of range for Vmin=$vmin V and Vmax=$vmax V")
    end
    return UInt32(round(65535 - ((v - vmin) / (vmax - vmin)) * 65535))
end

# send voltages to FPGA
"""
    setvoltageAll(fpga::XEM_dac, va::Float64, vb::Float64, vc::Float64, vd::Float64)
Set the output voltages for all four channels of the DAC.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware implementation.
- `va::Float64`: The desired output voltage for channel A (in volts).
- `vb::Float64`: The desired output voltage for channel B (in volts).
- `vc::Float64`: The desired output voltage for channel C (in volts).
- `vd::Float64`: The desired output voltage for channel D (in volts).

"""
function setvoltageAll(fpga::XEM_dac, va::Float64, vb::Float64, vc::Float64, vd::Float64)
    a = volts_to_code(va)
    b = volts_to_code(vb)
    c = volts_to_code(vc)
    d = volts_to_code(vd)

    setwirein(fpga.xem, EP_WIREIN_A, a)
    setwirein(fpga.xem, EP_WIREIN_B, b)
    setwirein(fpga.xem, EP_WIREIN_C, c)
    setwirein(fpga.xem, EP_WIREIN_D, d)

    return nothing
end


"""
    setvoltageA(fpga::XEM_dac, va::Float64)
Set the output voltage for channel A of the DAC.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware implementation.
- `va::Float64`: The desired output voltage for channel A (in volts).

"""
function setvoltageA(fpga::XEM_dac, va::Float64)
    a = volts_to_code(va)

    setwirein(fpga.xem, EP_WIREIN_A, a)

    return nothing
end

# set voltage for channel B
"""
    setvoltageB(fpga::XEM_dac, vb::Float64)
Set the output voltage for channel B of the DAC.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware implementation.
- `vb::Float64`: The desired output voltage for channel B (in volts).

"""
function setvoltageB(fpga::XEM_dac, vb::Float64)
    b = volts_to_code(vb)

    setwirein(fpga.xem, EP_WIREIN_B, b)

    return nothing
end

# set voltage for channel C
"""
    setvoltageC(fpga::XEM_dac, vc::Float64)
Set the output voltage for channel C of the DAC.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware implementation.
- `vc::Float64`: The desired output voltage for channel C (in volts).

"""
function setvoltageC(fpga::XEM_dac, vc::Float64)
    c = volts_to_code(vc)

    setwirein(fpga.xem, EP_WIREIN_C, c)

    return nothing
end

# set voltage for channel D
"""
    setvoltageD(fpga::XEM_dac, vd::Float64)
Set the output voltage for channel D of the DAC.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware
- `vd::Float64`: The desired output voltage for channel D (in volts).

"""
function setvoltageD(fpga::XEM_dac, vd::Float64)
    d = volts_to_code(vd)

    setwirein(fpga.xem, EP_WIREIN_D, d)

    return nothing
end

# start DAC output
"""
    start(fpga::XEM_dac)
Start the DAC output on the FPGA.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware implementation.

"""
function start(fpga::XEM_dac)
    setwirein(fpga.xem, EP_WIREIN_START, BIT_START)
    return nothing
end

"""
    stop(fpga::XEM_dac)
Stop the DAC output on the FPGA.
# Arguments
- `fpga::XEM_dac`: An instance of the XEM_dac hardware
"""
function stop(fpga::XEM_dac)
    setwirein(fpga.xem, EP_WIREIN_START, BIT_STOP)
    return nothing
end

