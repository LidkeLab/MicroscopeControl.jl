"""
    initialize(attenuator::LCC1620)

Open the Triggerscope serial port (if not already open — the scope may be
shared with another attenuator), set the DAC channel range to 0-5 V, and
drive to `min_voltage`.
"""
function initialize(attenuator::LCC1620)
    isopen(attenuator.scope.sp) || initialize(attenuator.scope)
    setrange(attenuator.scope, attenuator.dac_channel, ZEROTOFIVE)
    setdrivevoltage(attenuator, attenuator.properties.min_voltage)
    return nothing
end

function AttenuatorInterface.setdrivevoltage(attenuator::LCC1620, voltage::Float64)
    if !isopen(attenuator.scope.sp)
        @warn "Triggerscope port is not open for LCC1620, call initialize first"
        return
    end
    if voltage < attenuator.properties.min_voltage || voltage > attenuator.properties.max_voltage
        @error "The voltage should be between $(attenuator.properties.min_voltage) and $(attenuator.properties.max_voltage)"
        return
    end
    setdac(attenuator.scope, attenuator.dac_channel, voltage)
    attenuator.properties.drive_voltage = voltage
    attenuator.properties.transmission = voltage_to_transmission(attenuator, voltage)
    return nothing
end

function AttenuatorInterface.getdrivevoltage(attenuator::LCC1620)
    return attenuator.properties.drive_voltage
end

function AttenuatorInterface.settransmission(attenuator::LCC1620, transmission::Float64)
    if isempty(attenuator.properties.cal_voltages)
        @error "No calibration set for LCC1620, call set_calibration! first"
        return
    end
    if transmission < 0.0 || transmission > 1.0
        @error "The transmission should be between 0 and 1"
        return
    end
    voltage = interp1(attenuator.properties.cal_transmissions,
        attenuator.properties.cal_voltages, transmission)
    setdrivevoltage(attenuator, voltage)
    return nothing
end

function AttenuatorInterface.gettransmission(attenuator::LCC1620)
    return attenuator.properties.transmission
end

function AttenuatorInterface.set_calibration!(attenuator::LCC1620,
    voltages::Vector{Float64}, transmissions::Vector{Float64})
    if length(voltages) != length(transmissions)
        @error "voltages and transmissions must have the same length"
        return
    end
    if length(voltages) < 2
        @error "The calibration table needs at least 2 points"
        return
    end
    if !issorted(voltages)
        @error "voltages must be sorted in increasing order"
        return
    end
    if !(issorted(transmissions) || issorted(transmissions; rev=true))
        @error "transmissions must be monotonic so settransmission can invert the table"
        return
    end
    attenuator.properties.cal_voltages = copy(voltages)
    attenuator.properties.cal_transmissions = copy(transmissions)
    attenuator.properties.transmission =
        voltage_to_transmission(attenuator, attenuator.properties.drive_voltage)
    return nothing
end

"""
    voltage_to_transmission(attenuator::LCC1620, voltage::Float64)

Look up the transmission for a given drive voltage from the calibration table.
Returns `NaN` if no calibration is set.
"""
function voltage_to_transmission(attenuator::LCC1620, voltage::Float64)
    if isempty(attenuator.properties.cal_voltages)
        return NaN
    end
    return interp1(attenuator.properties.cal_voltages,
        attenuator.properties.cal_transmissions, voltage)
end

"""
    interp1(x::Vector{Float64}, y::Vector{Float64}, xq::Float64)

Linear interpolation of `y` over monotonic `x` at query point `xq`,
clamped to the table endpoints. `x` may be increasing or decreasing.
"""
function interp1(x::Vector{Float64}, y::Vector{Float64}, xq::Float64)
    if x[end] < x[1]
        x = reverse(x)
        y = reverse(y)
    end
    if xq <= x[1]
        return y[1]
    elseif xq >= x[end]
        return y[end]
    end
    i = searchsortedlast(x, xq)
    frac = (xq - x[i]) / (x[i+1] - x[i])
    return y[i] + frac * (y[i+1] - y[i])
end

"""
    shutdown(attenuator::LCC1620)

Drive the DAC channel to `min_voltage` (0 V = full transmission on the
LCC1620). The Triggerscope serial port is left open — it may be shared with
another attenuator; shut the scope down separately when done with all
channels.
"""
function shutdown(attenuator::LCC1620)
    if !isopen(attenuator.scope.sp)
        return nothing
    end
    setdac(attenuator.scope, attenuator.dac_channel, attenuator.properties.min_voltage)
    attenuator.properties.drive_voltage = attenuator.properties.min_voltage
    attenuator.properties.transmission =
        voltage_to_transmission(attenuator, attenuator.properties.min_voltage)
    return nothing
end

"""
    export_state(attenuator::LCC1620)
"""
function export_state(attenuator::LCC1620)
    attributes = Dict{String, Any}(
        "unique_id" => attenuator.unique_id,
        # Attenuator properties
        "drive_voltage" => attenuator.properties.drive_voltage,
        "transmission" => attenuator.properties.transmission,
        "min_voltage" => attenuator.properties.min_voltage,
        "max_voltage" => attenuator.properties.max_voltage,
        # Calibration lookup table
        "cal_voltages" => copy(attenuator.properties.cal_voltages),
        "cal_transmissions" => copy(attenuator.properties.cal_transmissions),
        # Triggerscope channel
        "dac_channel" => attenuator.dac_channel,
        "scope_devicename" => attenuator.scope.devicename,
        "scope_portname" => attenuator.scope.portname
    )

    data = nothing

    children = Dict{String, Any}()

    return attributes, data, children
end
