# These are the implimentations (methods) of the generic ScannerInterface functions

# Sets voltage of the galvanometer with a triggerscope
function ScannerInterface.set_voltage(scanner::Galvo, voltage::Float64)
    triggerscope = scanner.triggerscope
    # triggerscope.outputs[1] sets the output to "DAC" instead of "TTL"
    setoutputvalue(triggerscope, triggerscope.outputs[1], scanner.channel, voltage)
end

# Sets voltage of the galvanometer back to zero, which should be a neutral state
function ScannerInterface.reset(scanner::Galvo)
    setoutputvalue(triggerscope, triggerscope.outputs[1], scanner.channel, 0)
    @info "Galvanometer has been set to zero"
end

# Moves the galvanometer along a path of two angles
function ScannerInterface.scan_path(scanner::Galvo, voltage1::Float64, voltage2::Float64)
    # maybe use setrange()???????? I have no idea what that does
    setoutputvalue(triggerscope, triggerscope.outputs[1], scanner.channel, voltage1)
    setoutputvalue(triggerscope, riggerscope.outputs[1], voltage2)
end
