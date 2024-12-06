abstract type AbstractInstrument end

function export_state(instrument::AbstractInstrument)
    @error "Export state not implemented for this instrument"
end

function initialize(instrument::AbstractInstrument)
    @error "Initialize not implemented for this instrument"
end

function shutdown(instrument::AbstractInstrument)
    @error "Shutdown not implemented for this instrument"
end
