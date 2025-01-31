abstract type AbstractInstrument end

"""
    export_state(instrument::AbstractInstrument)

Export the state of the instrument as a tuple of attributes, data, and children.

# Arguments
- `instrument::AbstractInstrument`: The instrument to export the state of.

# Returns
- A tuple of dictionaries containing the attributes, data, and children of the instrument.
"""
function export_state(instrument::AbstractInstrument)
    @error "Export state not implemented for this instrument"
end

function initialize(instrument::AbstractInstrument)
    @error "Initialize not implemented for this instrument"
end

function shutdown(instrument::AbstractInstrument)
    @error "Shutdown not implemented for this instrument"
end