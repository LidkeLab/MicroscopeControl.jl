using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.NIDAQcard





daq = NIdaq() # the type of daq is NIdaq




devs = showdevices(daq)
channelsAO = showchannels(daq,"AO",devs[1])

t = createtask(daq,"AO",channelsAO[1]) # the type of t is Task
setvoltage(daq,t, 0.0) # the maximum voltage is 5.0 V.

t1 = createtask(daq,"AO",channelsAO[2]) # the type of t is Task
setvoltage(daq,t1, -1.0) # the maximum voltage is 5.0 V.

channelsDO = showchannels(daq,"DO",devs[1])
t2 = createtask(daq,"DO",channelsDO[1]) # the type of t is Task

setvoltage(daq,t2, 1.0) 

deletetask(daq,t2)

voltages = collect(-0.01:0.005:0.01)
cyclenum = 10

for cycle in 1:cyclenum
    for v in voltages
        setvoltage(daq,t, v)
        sleep(0.1)
    end
end


deletetask(daq,t)


# ═══════════════════════════════════════════════════════════════════════════
# NI card as a beam-steering backend
# ═══════════════════════════════════════════════════════════════════════════
# Everything above is the raw NIdaq task API: you make a task, write to it, delete it.
# For a galvo or an EOD there is DAQmxBackend, which holds one analog-output task per
# axis open for the life of the device, so each move is a single write with no task
# setup cost, and the device enforces voltage limits and remembers where it is.

using MicroscopeControl.HardwareImplementations.Triggerscope   # for Range, if you mix backends

# ── Setup: two analog outputs as an X/Y pair ────────────────────────────────
backend = DAQmxBackend("Dev2/ao0", "Dev2/ao1"; vmin = -10.0, vmax = 10.0)

galvo = Galvo(backend; xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "galvo (NI)")

initialize(galvo)        # creates and starts both AO tasks, parks at 0 V

# ── Write ───────────────────────────────────────────────────────────────────
setvoltage(galvo, 0.2, -0.2)

# ── Read ────────────────────────────────────────────────────────────────────
getvoltage(galvo)        # (0.2, -0.2) -- last commanded, not a hardware readback

zeroaxes(galvo)
getvoltage(galvo)

# Out of range throws before anything reaches the card:
setvoltage(galvo, 5.0, 0.0)

shutdown(galvo)          # parks at 0 V, then stops and clears both tasks

# ── The same two channels driving an EOD through the HVA200s ────────────────
# eod = EOD(DAQmxBackend("Dev2/ao0", "Dev2/ao1");
#     amplifier_gain = 20.0, invert = true,
#     xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5), unique_id = "EOD (NI)")
# initialize(eod)
# setcrystalvoltage(eod, 100.0, 0.0)   # 100 V on the crystal -> -5 V out of the card
# getcrystalvoltage(eod)
# shutdown(eod)
#
# See also: dev/test_galvo.jl, dev/test_EOD.jl, dev/test_triggerscope.jl
