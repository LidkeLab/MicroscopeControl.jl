# These are the implimentations (methods) of the generic ScannerInterface functions
function initialize(scanner::Galvo)
    @info initializing galvo
    setdac(scanner.triggerscope, scanner.channel, 0.0)
end

# Sets voltage of the galvanometer with a triggerscope
function ScannerInterface.set_voltage(scanner::Galvo, voltage::Float64)
    triggerscope = scanner.triggerscope
    setdac(triggerscope, scanner.channel, voltage)
end

# Sets voltage of the galvanometer back to zero, which should be a neutral state
function ScannerInterface.reset(scanner::Galvo)
    setdac(scanner.triggerscope, scanner.channel, 0.0)
    @info "Galvanometer has been set to zero"
end

# Moves the galvanometer along a path of two angles
function ScannerInterface.scan_path(scanner::Galvo, voltage1::Float64, voltage2::Float64, stepSize::Float64)
    for i = voltage1:stepSize:voltage2
        setdac(scanner.triggerscope, scanner.channel, i)
    end
end

function ScannerInterface.prog_cmd_seq(scanner::Galvo, sigArr::SignalArray, NLoops::Int, arm::Bool)
    progarray(scanner.triggerscope, sigArr, NLoops, arm)
end
