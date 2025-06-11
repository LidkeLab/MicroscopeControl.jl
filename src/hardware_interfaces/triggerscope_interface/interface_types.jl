"""
`NIdaq` an abstract type that defines the interface for a data acquisition card.
"""
abstract type TRIG end

#=
In order for this to be a useful interface, we need to define a few fields that are common to all DAQs.

- 'devicename': The name of the device.

- 'output_labels': The labels for the output channels.
- 'output_types': The formats that the device can output.
- 'output_channels': The number of output channels, per output type.
- 'output_ranges': The ranges that the device can output to each channel type.
- 'output_values': The values that the device is outputting to each channel.

- 'input_labels': The labels for the input channels.
- 'input_types': The formats that the device can input.
- 'input_channels': The number of input channels, per input type.
- 'input_ranges': The ranges that the device can recieve for each channel type.
- 'input_values': The values that the device is recieving from each channel.


These fields will be used to create the GUI for the DAQ.
=#

#It is useful to instead of having a large amount of fields, create two objects that contain the fields for the input and output channels. Each object will contain arrays of the fields for each channel.

mutable struct Output
    label::String           #The name of the type of output
    datatype::DataType      #The datatype of the output
    numchannels::Int        #The number of channels for the output type
    ranges::Array{Any}      #The range for each channel, should be an array of tuples this is the range for each channel
    values::Vector{Any}     #The values outputted to each channel
    israngevariable::Bool   #If the range is variable
end

mutable struct Input
    label::String           #The name of the type of input
    datatype::DataType      #The datatype of the input
    numchannels::Int        #The number of channels for the input type
    ranges::Array{Any}      #The range for each channel, should be an array of tuples, range for each channel
    values::Vector{Any}     #The values inputted from each channel
    israngevariable::Bool   #If the range is variable
end