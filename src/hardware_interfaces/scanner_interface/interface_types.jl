"""
`Scanner` is an abstract type that defines the interface for a camera.
"""
abstract type Scanner <: AbstractInstrument end

"""
    ScannerProperties

Generic properties for a scanner.

# Fields
- `voltage::Float64`: The current voltage of the light source.
- `min_volts::Float64`: The minimum voltage of the light source.
- `max_volts::Float64`: The maximum voltage of the light source.
"""

mutable struct ScannerProperties
    voltage::Float64
    min_volts::Float64
    max_volts::Float64
end