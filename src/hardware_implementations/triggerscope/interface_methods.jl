#These are the hardware specific functions that are used to interact with the Triggerscope4 DAQ device via the GUI
#Since the Triggerscope4 has a unique number of outputs and inputs specific to the device, ie. a general implementation is not necessary, we will implement the functions here to respond with "fixed values" 


#Start and Stop the Device
function TrigInterface.initialize(scope::Triggerscope4)
    @info "Connecting to serial port '$(scope.portname)'..."
    
    # Create connection using openport function
    openport(scope)
    
    # Julia assumes connection was successful after opening
    @info "Triggerscope connected successfully"
    
    # Acknowledgement test to verify connection
    try
        response = acknowledgetest(scope)
        @info "Triggerscope version: $response"
    catch e
        @warn "Could not get version information: $e"
    end
end

function TrigInterface.shutdown(scope::Triggerscope4)
    @info "Shutting down Triggerscope4"
    closeport(scope)
end

#Functions to set and read values from the DAQ device
function TrigInterface.setoutputvalue(scope::Triggerscope4, output::Output, channel::Int, value::Any)
    if typeof(value) != output.datatype
        @error "Value is not of the correct datatype"
    end

    if output.label == "DAC"
        scope.dacvalues[channel] = volttooutput(scope, channel, value)
        scope.outputs[1].values[channel] = value

        setdac(scope, channel, value)
    elseif output.label == "TTL"
        scope.ttlvalues[channel] = value
        scope.outputs[2].values[channel] = value

        setttl(scope, channel, value)  
    end

    @info "Setting " * output.label * " channel " * string(channel) * " to " * string(value)

end

function TrigInterface.setoutputrange(scope::Triggerscope4, output::Output, channel::Int, range::Any)
    if typeof(range) != typeof(output.ranges[1])
        @error "Range is not of the correct datatype"
    end

    @info "Setting " * output.label * " channel " * string(channel) * " to " * string(range)

    if output.label == "DAC"
        scope.dacranges[channel] = Range(range)
        scope.outputs[1].ranges[channel] = Range(range)

        setrange(scope, channel, Range(range))
    end
end

function TrigInterface.getoutputvalue(scope::Triggerscope4, output::Output, channel::Int)
    @info "Getting " * output.label * " channel " * string(channel) * " value"
    return output.values[channel]
end

function TrigInterface.getinputvalue(scope::Triggerscope4, input::Input, channel::Int)
    @error "THIS IS NOT CORRECTLY IMPLEMENTED FOR THE TRIGGERSCOPE4 DEVICE AS THE INPUTS ARE USED FOR TRIGGERING"
    return input.values[channel]
end
