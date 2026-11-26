
const TRIGGER_OFF = 0.0
const TRIGGER_ON = 16.0


"""
    XEM(; fpgalabel="", serialnumber="", devicehandle=0, exposure_bit=2.56, exposure_time=30e3,
        enable=0.0, task_trigger=0, task_enable=0, bitfile="", volt_bit="0000", daq=NIdaq()) -> XEM

Opal Kelly XEM FPGA board, driven through the FrontPanel DLL (`okFrontPanel.dll`), with the camera trigger
and enable lines carried by a National Instruments digital-output task (`daq`). The keyword constructor
only fills the struct; it opens nothing. `initialize` creates the FrontPanel handle, opens the
first board listed (index 0), configures it with the bitfile at `bitfile`, and sets `fpgalabel` (model)
and `serialnumber`. `shutdown` destroys the handle.
`[limitation]` The DLL path is `C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64\\okFrontPanel.dll`,
so the driver works only on Windows with FrontPanel installed. `initialize` reports a missing board or a
failed open or configure with `println` and returns without throwing, so a returned call does not mean the
board is configured. It also passes the serial string to the DLL as a byte vector with the zero bytes
removed, so the string handed over has no terminating NUL.

Fields: `exposure_bit` (us per exposure step, default 2.56), `exposure_time` (us, the last rounded exposure
`setexposure` was asked for, stored before its DAQ write, default 30000), `enable` (default `0.0`; not updated by
[`enable`](@ref)), `volt_bit` (the four exposure code bits of the last `setexposure(fpga, exposure_time)` request that could be encoded,
as a string, even if its DAQ write then failed; a request outside the encodable range throws before changing it,
and the form that takes the digits directly updates neither field), `task_trigger` and `task_enable` (NI tasks created by
[`setupIO`](@ref)), `devicehandle`, `bitfile` and `daq`.
"""
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

### export_state for later