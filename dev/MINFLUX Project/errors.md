println("=" ^ 60)
println("TEST 3: Multi-channel AITask reading (DAQ out + PS monitor)")
println("=" ^ 60)

mc_ao0 = AOTask("Dev2/ao0")
mc_ao1 = AOTask("Dev2/ao1")

# Read AI0, AI1, AI2, AI3 simultaneously
# AI0 = AO1 DAQ output loopback
# AI1 = AO0 DAQ output loopback
# AI2 = HVA1 monitor (AO0)
# AI3 = HVA2 monitor (AO1)
mc_ai = AITask("Dev2/ai0, Dev2/ai1, Dev2/ai2, Dev2/ai3")

start!(mc_ao0)
start!(mc_ao1)
start!(mc_ai)

test_voltage = 1.0
write_scalar(mc_ao0, test_voltage)
write_scalar(mc_ao1, test_voltage)
sleep(0.2)

println("Attempting multi-channel read (AI0, AI1, AI2, AI3)...")
data = read(mc_ai)
println("Raw data type: ", typeof(data))
println("Raw data: ", data)

    ao1_daq  = data[1]
    ao0_daq  = data[2]
    hva1_mon = data[3]
    hva2_mon = data[4]


println("\nAO0 (HVA1):")
println("  DAQ output  (AI1): ", round(ao0_daq,  digits=4), " V")
println("  HVA1 monitor(AI2): ", round(hva1_mon, digits=4), " V")
println("\nAO1 (HVA2):")
println("  DAQ output  (AI0): ", round(ao1_daq,  digits=4), " V")
println("  HVA2 monitor(AI3): ", round(hva2_mon, digits=4), " V")

write_scalar(mc_ao0, 0.0)
write_scalar(mc_ao1, 0.0)

stop!(mc_ao0)
stop!(mc_ao1)
stop!(mc_ai)
clear!(mc_ao0)
clear!(mc_ao1)
clear!(mc_ai)

println("\nTEST 3 complete.")
println("=" ^ 60)