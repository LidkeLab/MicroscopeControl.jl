#Triggermodes 1 and 2 only supported by Triggerscope3B
@enum TriggerMode begin
    RISING = 2
    FALLING = 3
    CHANGE = 4
end

@enum Range begin
    ZEROTOFIVE = 1
    ZEROTOTEN = 2
    PLUSMINUS5 = 3
    PLUSMINUS10 = 4
    PLUSMINUS2_5 = 5
end

mutable struct Triggerscope4 <: DAQ #This is a "Data Aquistion Device
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

function Triggerscope4(;
    devicename::String = "Triggerscope4",
    portname::String = "COM3",
    baudrate::Int = 115200,
    rwtimeout::Float64 = 10.0,
    compause::Float64 = .1,

    dacresolution::Int = 16,
    dacoutputs::Int = 16,
    dacvalues::Vector{Int} = zeros(Int, 16),
    dacranges::Vector{Range} = fill(ZEROTOFIVE, 16),

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
