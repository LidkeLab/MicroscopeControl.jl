
const TRIGGER_OFF = 0.0
const TRIGGER_ON = 16.0


mutable struct XEM 
    fpgalabel::String
    serialnumber::String
    devicehandle
    exposure_bit::Float64
    exposure_time::Float64
    enable::Float64
    task_trigger
    task_enable
    bitfile::String
    volt_bit::String
    daq::NIdaq
end

function XEM(;
    fpgalabel::String="",
    serialnumber::String="",
    devicehandle=0,
    exposure_bit::Float64=2.56, # unit: us
    exposure_time::Float64=30e3, # unit: us
    enable::Float64=TRIGGER_OFF,
    task_trigger=0,
    task_enable=0,
    bitfile::String="",
    volt_bit::String="0000",
    daq::NIdaq=NIdaq()
    )
    return XEM(fpgalabel,serialnumber,devicehandle,exposure_bit,exposure_time,enable,task_trigger,task_enable,bitfile,volt_bit,daq)
end