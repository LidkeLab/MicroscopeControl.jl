"""
`NIdaq` is a subtype of `DAQ` that defines National instruments DAQs.
"""
mutable struct NIdaq <: DAQ
    unique_id::String
end

function NIdaq(;
    unique_id::String="NIdaq")
    NIdaq(unique_id)
end
