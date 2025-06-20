"""
`Scanner` is an abstract type that defines the interface for a camera.
"""
abstract type Scanner <: AbstractInstrument end

"""
    ScannerProperties

Generic properties for a scanner.

# Fields
- `voltage::Float64`: The current voltage of the scanner.
- `min_volts::Float64`: The minimum voltage of the scanner.
- `max_volts::Float64`: The maximum voltage of the scanner.
"""

mutable struct ScannerProperties
    voltage::Float64
    min_volts::Float64
    max_volts::Float64
end

mutable struct CommandSignal
    commandType::Any
    channel::Int
    value::Union{Float64,Bool}
    programLine::Int
end