#=

TRIGGERSCOPE 4 HARDWARE SPECIFICATIONS
MCU @ 600 Mhz
1024K MCU RAM
16GB SD Card
RTC included
TTL 1-4 are 500mA sources
TTL 5-12 are 200mA sources

DAC Outputs are 16 bits
RANGES:
1: 0-5V
2: 0-10V
3: +/-5V
4: +/-10V
5: +/-2.5V

DAC Update Rate can be overclocked

OPTIONS FOR CONTROL ARE DIRECT CONTROL OR SEQUENCE CONTROL
=#

module Triggerscope
    using ...MicroscopeControl
    using ...MicroscopeControl.HardwareInterfaces.TrigInterface
    
    using LibSerialPort

    import ...MicroscopeControl: export_state, initialize, shutdown

    export Triggerscope4

    export setdac, setttl, acknowledgetest, focus, setrange, getstatus, runtest, reset, savesettings
    export arm, clearall, progfocus, progttl, progdac, cleartable, progdelay, progwave, timecycles, trigmode
    export TriggerMode, RISING, FALLING, CHANGE
    export openport, closeport
    export gui

    include("types.jl")
    include("interface_methods.jl")
    include("direct_control.jl")
    include("sequence_control.jl")
    include("helper_functions.jl")
end