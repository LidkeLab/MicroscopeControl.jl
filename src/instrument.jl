"""
    AbstractInstrument is an abstract type that all instruments should inherit from.
"""
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

"""
    initialize(instrument::AbstractInstrument)

Initialize the instrument.

# Arguments
- `instrument::AbstractInstrument`: The instrument to initialize.
"""
function initialize(instrument::AbstractInstrument)
    @error "Initialize not implemented for this instrument"
end

"""
    shutdown(instrument::AbstractInstrument)

Shuts down the instrument.

# Arguments
- `instrument::AbstractInstrument`: The instrument to shut down.
"""
function shutdown(instrument::AbstractInstrument)
    @error "Shutdown not implemented for this instrument"
end

# =============================================================================
# AbstractSystem - Composite of instruments
# =============================================================================

"""
    AbstractSystemState

Abstract type for system state. Concrete implementations should contain
the configuration parameters for a specific system.
"""
abstract type AbstractSystemState end

"""
    AbstractSystem

Abstract type for a microscope system (composite of instruments).
Systems compose multiple instruments and manage their collective state.
"""
abstract type AbstractSystem end

"""
    get_state(sys::AbstractSystem)

Get the current state of the system.

# Arguments
- `sys::AbstractSystem`: The system to get state from.

# Returns
- An `AbstractSystemState` representing the current configuration.
"""
function get_state(sys::AbstractSystem)
    @error "get_state not implemented for $(typeof(sys))"
end

"""
    set_state(sys::AbstractSystem, state::AbstractSystemState)

Set the state of the system, updating all relevant instruments.

# Arguments
- `sys::AbstractSystem`: The system to configure.
- `state::AbstractSystemState`: The desired state.
"""
function set_state(sys::AbstractSystem, state::AbstractSystemState)
    @error "set_state not implemented for $(typeof(sys))"
end

"""
    initialize(sys::AbstractSystem)

Initialize all instruments in the system.

# Arguments
- `sys::AbstractSystem`: The system to initialize.
"""
function initialize(sys::AbstractSystem)
    @error "initialize not implemented for $(typeof(sys))"
end

"""
    shutdown(sys::AbstractSystem)

Shutdown all instruments in the system.

# Arguments
- `sys::AbstractSystem`: The system to shut down.
"""
function shutdown(sys::AbstractSystem)
    @error "shutdown not implemented for $(typeof(sys))"
end

"""
    export_state(sys::AbstractSystem)

Export the state of the system as a tuple of attributes, data, and children.

# Arguments
- `sys::AbstractSystem`: The system to export state from.

# Returns
- A tuple of (attributes::Dict, data, children::Dict).
"""
function export_state(sys::AbstractSystem)
    @error "export_state not implemented for $(typeof(sys))"
end