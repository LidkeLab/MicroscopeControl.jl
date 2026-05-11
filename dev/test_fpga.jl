using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.XEM_DAC



fpga = XEM_dac()
#fpga.xem.bitfile = raw"C:\Users\sheng\Documents\Vivado\dac_clk_fp_1\dac_clk_fp_1.runs\impl_1\dac_clk_fp.bit"
fpga.xem.bitfile = raw"C:\Users\sheng\Documents\Vivado\dac_slowclk\dac_slowclk.runs\impl_1\dac_clk_fp.bit"
initialize(fpga.xem)

va = -1.0 # voltage for channel A
vb = 0.2 # voltage for channel B
vc = 0.2 # voltage for channel C
vd = -0.2 # voltage for channel D

start(fpga)

setvoltageA(fpga, va)
setvoltageB(fpga, vb)

stop(fpga)


# generate sawtooth wave on channel A and B

voltages = collect(-0.005:0.002:0.005)
cyclenum = 20
start(fpga)
for cycle in 1:cyclenum
    for v in voltages
        #setvoltageA(fpga, v)
        setvoltageB(fpga, v)
        #setvoltage(daq,t, v)
        sleep(0.001)
    end
end
stop(fpga)


shutdown(fpga.xem)





