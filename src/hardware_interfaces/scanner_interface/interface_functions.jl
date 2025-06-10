# These are the general functions for a generic scanner

"""
    set_voltage(scanner::Scanner, voltage::Float64)

sets the voltage of the scanner

# Arguments
- `scanner::Scanner`: The scanner object
- `voltage1::Float64`: The voltage to start at

# Returns
- nothing
"""
function set_voltage(scanner::Scanner, voltage::Float64)
    #set voltage of scanner
    @error "set_voltage() not implimented"
end

"""
    reset(scanner::Scanner)

reset the scanner to its neutral postition

# Arguments
- `scanner::Scanner`: The scanner object

# Returns
- nothing
"""
function reset(scanner::Scanner)
    #set voltage of scanner
    @error "reset() not implimented"
end

"""
    scan_path(scanner::Scanner, voltage1::Float64, voltage2::Float64)

Scan through set of voltages

# Arguments
- `scanner::Scanner`: The scanner object
- `voltage1::Float64`: The starting voltage
- `voltage2::Float64`: The ending voltage

# Returns
- nothing
"""
function scan_path(scanner::Scanner, voltage1::Float64, voltage2::Float64)
    # scan through set of voltages
    @error "scan_path() not implimented"
end