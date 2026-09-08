
"""
    setdrivevoltage(attenuator::Attenuator, voltage::Float64)

Set the raw drive voltage of the attenuator.

# Arguments
- `attenuator::Attenuator`: An Attenuator type.
- `voltage::Float64`: The drive voltage to set, unit: volt.
"""
function setdrivevoltage(attenuator::Attenuator, voltage::Float64)
    # set the drive voltage of the attenuator
    @error "setdrivevoltage not implemented"
end

"""
    getdrivevoltage(attenuator::Attenuator)

Get the current drive voltage of the attenuator.

# Arguments
- `attenuator::Attenuator`: An Attenuator type.

# Returns
- `voltage::Float64`: The current drive voltage, unit: volt.
"""
function getdrivevoltage(attenuator::Attenuator)
    # get the drive voltage of the attenuator
    @error "getdrivevoltage not implemented"
end

"""
    settransmission(attenuator::Attenuator, transmission::Float64)

Set the transmission of the attenuator (0 to 1) using the stored
voltage-to-transmission calibration (see `set_calibration!`).

# Arguments
- `attenuator::Attenuator`: An Attenuator type.
- `transmission::Float64`: The transmission to set, between 0 and 1.
"""
function settransmission(attenuator::Attenuator, transmission::Float64)
    # set the transmission of the attenuator
    @error "settransmission not implemented"
end

"""
    gettransmission(attenuator::Attenuator)

Get the current transmission of the attenuator (0 to 1), `NaN` if no
calibration has been set.

# Arguments
- `attenuator::Attenuator`: An Attenuator type.

# Returns
- `transmission::Float64`: The current transmission, between 0 and 1.
"""
function gettransmission(attenuator::Attenuator)
    # get the transmission of the attenuator
    @error "gettransmission not implemented"
end

"""
    set_calibration!(attenuator::Attenuator, voltages::Vector{Float64}, transmissions::Vector{Float64})

Store a voltage-to-transmission calibration lookup table, measured externally
(e.g. with a photodiode in a characterization script). The table is used by
`settransmission` and `gettransmission` via linear interpolation.

# Arguments
- `attenuator::Attenuator`: An Attenuator type.
- `voltages::Vector{Float64}`: Drive voltages, unit: volt.
- `transmissions::Vector{Float64}`: Measured transmissions (0 to 1), same length as `voltages`.
"""
function set_calibration!(attenuator::Attenuator, voltages::Vector{Float64}, transmissions::Vector{Float64})
    # store the calibration lookup table
    @error "set_calibration! not implemented"
end
