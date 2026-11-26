#Triggermodes 1 and 2 only supported by Triggerscope3B
"""
    TriggerMode

Trigger mode for Triggerscope sequences (the type of the `trigmode` field), set with [`trigmode`](@ref). The integer value
is what `trigmode` sends to the device: `RISING` = 2, `FALLING` = 3, `CHANGE` = 4.
A comment in the source says trigger modes 1 and 2 are supported only by the Triggerscope 3B; that would include
`RISING` (2), the constructor's default. This has not been checked against the device.
"""
@enum TriggerMode begin
    RISING = 2
    FALLING = 3
    CHANGE = 4
end

"""
    Range

Output voltage range of one Triggerscope4 DAC channel, for [`setrange`](@ref) and the `dacranges`
field of [`Triggerscope4`](@ref). The integer value is the range code sent to the device, and the range
decides how a voltage becomes a 16-bit DAC code (0 to 65535 spans the whole range):
`ZEROTOFIVE` = 1 (0 to 5 V), `ZEROTOTEN` = 2 (0 to 10 V), `PLUSMINUS5` = 3 (-5 to 5 V),
`PLUSMINUS10` = 4 (-10 to 10 V), `PLUSMINUS2_5` = 5 (-2.5 to 2.5 V).
"""
@enum Range begin
    ZEROTOFIVE = 1
    ZEROTOTEN = 2
    PLUSMINUS5 = 3
    PLUSMINUS10 = 4
    PLUSMINUS2_5 = 5
end

"""
    CommandType

Kind of one entry in a [`SignalArray`](@ref): `DAC` (value is a voltage, `Float64`) or `TTL` (value is
`Bool`). `DAC` and `TTL` are not exported.
"""
@enum CommandType begin
    DAC = 1
    TTL = 2
end

"""
    Triggerscope4(; devicename, portname, baudrate, rwtimeout, compause, ...) -> Triggerscope4

Advanced Research Consulting Triggerscope 4: a USB serial DAC (16-bit analog outputs) and TTL controller.
The keyword constructor builds the object and an unopened `LibSerialPort.SerialPort` for `portname`;
it does not talk to the device. `[limitation]` Creating that `SerialPort` needs `portname` to be a port the
operating system lists: on a machine without the default `"COM3"`, `Triggerscope4()` throws a `LibSerialPort`
error (`SP_ERR_ARG`), so pass a real `portname`. `initialize` opens the port (see [`openport`](@ref)) and
sends the acknowledgement test, `shutdown` closes it.

Every command function (`setdac`, `setttl`, `arm`, ...) writes one ASCII command line to the port, sleeps
`compause`, reads one response line, and returns that line as a `String`, except where its docstring gives a
`[limitation]` (`progttl` throws after sending its command). If the write or the read throws,
the port is closed and reopened and an error is raised. The response text is never parsed or checked.

Fields a caller reads or sets: `portname`, `baudrate`, `rwtimeout` (s, read and write timeout),
`compause` (s, pause after each write and each read), `dacranges` (the range assumed per DAC channel
when converting volts), `dacvalues` and `ttlvalues`, `trigmode`. `dacvalues` and `ttlvalues` are a cache, not a
readback: the panel's `setoutputvalue` updates them before it writes, `progdac` updates `dacvalues`, and `setdac`
and `setttl` do not touch them; a DAC code computed from an out-of-range voltage can fall outside 0 to 65535. The
`outputs` and `inputs` fields feed the generic DAQ GUI.
"""
mutable struct Triggerscope4 <: TRIG #This is a "Data Aquistion Device
    #basic setup parameters
    devicename::String               #devicename for the scope, defaults to "Triggerscope4"
    portname::String            #name of the serial port
    baudrate::Int               #baudrate for serial communication
    rwtimeout::Float64              #timeout for read and write operations
    compause::Float64             #timeout for communication operations

    #LibSerialPort object
    sp::SerialPort

    #DAC parameters
    dacresolution::Int          #output "resolution" of the DAC ports, this is 16 bits
    dacoutputs::Int             #number of DAC outputs
    dacvalues::Vector{Int}      #Values of 0-65535 range read from and written to DAC output ports
    dacranges::Vector{Range}       #ranges for the DAC outputs, defaults to ZEROTOFIVE for all

    #TTL parameters
    #OUTPUT, Transistor Transistor Logic outputs either high or low, represented by 1 or 0
    ttloutputs::Int             #number of TTL outputs
    ttlvalues::Vector{Bool}     #values of TTL outputs
    ttloutputranges::Vector{Tuple{Bool,Bool}} #ranges for the TTL outputs, defaults to (0,1) for all

    ttlinputs::Int              #number of TTL inputs
    ttlreadings::Vector{Bool}   #values of TTL inputs
    ttlinputranges::Vector{Tuple{Bool,Bool}} #ranges for the TTL inputs, defaults to (0,1) for all
    trigmode::TriggerMode       #trigger mode for sequences


    #GUI Interface Fields
    outputs::Vector{Output}
    inputs::Vector{Input}
end

#constructor for the Triggerscope4 object

"""
    Triggerscope4(; devicename="Triggerscope4", portname="COM3", baudrate=115200, rwtimeout=10.0,
                  compause=0.1, dacoutputs=16, ttloutputs=16, ttlinputs=4, dacranges=fill(PLUSMINUS10, 16),
                  trigmode=RISING, ...) -> Triggerscope4

Keyword constructor of [`Triggerscope4`](@ref); every argument has a default, so `Triggerscope4(portname="COM5")`
is a complete call. The remaining keywords (`dacresolution=16`, `dacvalues`, `ttlvalues`, `ttloutputranges`,
`ttlreadings`, `ttlinputranges`) set the matching fields; vector keywords must be vectors of the
declared element type (`Vector{Int}`, `Vector{Range}`, `Vector{Bool}`, `Vector{Tuple{Bool,Bool}}`).
`portname` is a serial port name (`"COM3"` is a Windows name) and must exist on the machine, or the call
throws (see [`Triggerscope4`](@ref)). The constructor does not open the port and does
not send `dacranges` to the device: the device keeps whatever ranges it has until [`setrange`](@ref) is called,
so set the ranges to match `dacranges` before relying on voltage conversion.
"""
function Triggerscope4(;
    devicename::String = "Triggerscope4",
    portname::String = "COM3",
    baudrate::Int = 115200,
    rwtimeout::Float64 = 10.0,
    compause::Float64 = .1,

    dacresolution::Int = 16,
    dacoutputs::Int = 16,
    dacvalues::Vector{Int} = zeros(Int, 16),
    dacranges::Vector{Range} = fill(PLUSMINUS10, 16),

    ttloutputs::Int = 16,
    ttlvalues::Vector{Bool} = zeros(Bool, 16),
    ttloutputranges::Vector{Tuple{Bool,Bool}} = fill((false, true), 16),

    ttlinputs::Int = 4,
    ttlreadings::Vector{Bool} = zeros(Bool, 4),
    ttlinputranges::Vector{Tuple{Bool,Bool}} = fill((false, true), 4),
    trigmode::TriggerMode = RISING
    ) 
    
    #Create a SerialPort object, unopened
    sp = LibSerialPort.SerialPort(portname)

    #Create the necessary GUI fields
    outputs = Vector{Output}(undef, 2) #DAC and TTL outputs
    
    outputs[1] = Output("DAC", Float64, dacoutputs, dacranges, dacvalues, true)
    outputs[2] = Output("TTL", Bool, ttloutputs, [false, true], ttlvalues, false)

    inputs = Vector{Input}(undef, 1) #TTL inputs
    inputs[1] = Input("TTL", Bool, ttlinputs, [false, true], ttlreadings, false)

    return Triggerscope4(devicename, portname, baudrate, rwtimeout, compause, sp, dacresolution, dacoutputs, dacvalues, dacranges, ttloutputs, ttlvalues, ttloutputranges, ttlinputs, ttlreadings, ttlinputranges, trigmode, outputs, inputs)
end

mutable struct CommandSignal
    commandType::CommandType
    channel::Int
    value::Union{Float64,Bool}
end

"""
    SignalArray(trigMode::TriggerMode, commands::Vector{CommandSignal})

A list of DAC and TTL commands plus a trigger mode, the input of [`progarray`](@ref). Each element of
`commands` is a `CommandSignal(commandType::CommandType, channel::Int, value::Union{Float64,Bool})` (not
exported). `[limitation]` [`progarray`](@ref) as written does not complete, so a `SignalArray` cannot
presently be programmed onto the device through it. `progdac` and the other program functions can be called
directly, except `progttl`, which throws after sending its command (see its docstring).
"""
mutable struct SignalArray
    trigMode::TriggerMode
    commands::Vector{CommandSignal}
end

"""
Trigger mode "rising"; `trigmode` sends code 2. See [`TriggerMode`](@ref).
"""
RISING

"""
Trigger mode "falling"; `trigmode` sends code 3. See [`TriggerMode`](@ref).
"""
FALLING

"""
Trigger mode "change"; `trigmode` sends code 4. See [`TriggerMode`](@ref).
"""
CHANGE

"""
DAC range 0 to 5 V, range code 1. See [`Range`](@ref).
"""
ZEROTOFIVE

"""
DAC range 0 to 10 V, range code 2. See [`Range`](@ref).
"""
ZEROTOTEN

"""
DAC range -5 to 5 V, range code 3. See [`Range`](@ref).
"""
PLUSMINUS5

"""
DAC range -10 to 10 V, range code 4. See [`Range`](@ref).
"""
PLUSMINUS10

"""
DAC range -2.5 to 2.5 V, range code 5. See [`Range`](@ref).
"""
PLUSMINUS2_5
