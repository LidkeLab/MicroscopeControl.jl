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

