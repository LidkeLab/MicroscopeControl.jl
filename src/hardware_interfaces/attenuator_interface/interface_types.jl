"""
`Attenuator` is an abstract type that defines the interface for an optical attenuator.
"""
abstract type Attenuator <: AbstractInstrument end

"""
    AttenuatorProperties

Generic properties for an optical attenuator.

# Fields
- `drive_voltage::Float64`: The current drive voltage of the attenuator.
- `transmission::Float64`: The current transmission (0 to 1), `NaN` if unknown (no calibration set).
- `min_voltage::Float64`: The minimum drive voltage of the attenuator.
- `max_voltage::Float64`: The maximum drive voltage of the attenuator.
- `cal_voltages::Vector{Float64}`: Calibration lookup table drive voltages (empty if not calibrated).
- `cal_transmissions::Vector{Float64}`: Calibration lookup table transmissions (0 to 1), same length as `cal_voltages`.
"""
mutable struct AttenuatorProperties
    drive_voltage::Float64
    transmission::Float64
    min_voltage::Float64
    max_voltage::Float64
    cal_voltages::Vector{Float64}
    cal_transmissions::Vector{Float64}
end
