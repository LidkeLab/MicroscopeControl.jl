"""
    Galvanometer

A scanner type, controlled with a triggerscope inhereted from Scanner.

# Fields
- `unique_id::String`: A unique identifier for the device.
- `properties::ScannerProperties`: A ScannerProperties struct with basic scanner information.
- `triggerscope::Triggerscope4`: The Triggerscope that will control the galvo.
- `channel::Int`: The output port of the Triggerscope that goes to the galvanometer
"""
mutable struct Galvo <: Scanner
    unique_id::String
    properties::ScannerProperties
    triggerscope::Triggerscope4
    channel::Int
end

# constructor, needs argument `scopeChannel::Int`
function Galvo(scopeChannel::Int;
    unique_id::String="Galvanometer",
    properties::ScannerProperties=ScannerProperties(0, -5, 5)
    )
    # interacting with and setting up triggerscope connection
    if !isdefined(Main, triggerscope)
        triggerscope = Triggerscope4()
        init_triggerscope(triggerscope4)
    end
    channel = scopeChannel
    Galvo(unique_id, properties, triggerscope, channel)
end