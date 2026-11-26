"""
    TRIG

Abstract type for a trigger and output controller: a box with groups of output channels (analog DAC, digital TTL)
and input channels, each group described by an [`Output`](@ref) or [`Input`](@ref) for the shared control panel
(`gui`). Unlike the other device classes it is not a subtype of `AbstractInstrument`, though its driver,
`Triggerscope4`, defines `initialize` and `shutdown`. A driver implements `setoutputvalue`, `setoutputrange`,
`getoutputvalue`, `getinputvalue` and `Base.reset`. The first four are not exported (call them as
`TrigInterface.setoutputvalue` and so on); `reset` extends `Base.reset` and is callable unqualified.
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

"""
    Output(label, datatype, numchannels, ranges, values, israngevariable)

One group of output channels on a [`TRIG`](@ref) device, as the control panel shows it: `label` (for example
`"DAC"` or `"TTL"`), the channel value type `datatype` (`Float64` volts, `Bool`), `numchannels`, the per-channel
`ranges`, the last-commanded `values`, and whether the range can be changed (`israngevariable`).
"""
mutable struct Output
    label::String           #The name of the type of output
    datatype::DataType      #The datatype of the output
    numchannels::Int        #The number of channels for the output type
    ranges::Array{Any}      #The range for each channel, should be an array of tuples this is the range for each channel
    values::Vector{Any}     #The values outputted to each channel
    israngevariable::Bool   #If the range is variable
end

"""
    Input(label, datatype, numchannels, ranges, values, israngevariable)

One group of input channels on a [`TRIG`](@ref) device, with the same fields as [`Output`](@ref); `values` holds
the last readings.
"""
mutable struct Input
    label::String           #The name of the type of input
    datatype::DataType      #The datatype of the input
    numchannels::Int        #The number of channels for the input type
    ranges::Array{Any}      #The range for each channel, should be an array of tuples, range for each channel
    values::Vector{Any}     #The values inputted from each channel
    israngevariable::Bool   #If the range is variable
end