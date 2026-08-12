
"""
    `LCC1620` A Thorlabs LCC1620/M liquid crystal attenuator inherited from `Attenuator`,
driven through a Triggerscope V4 DAC output channel.

Multiple attenuators can share one `Triggerscope4` — construct the scope once
and pass it to each `LCC1620` with a different `dac_channel`. The scope's
serial-port lifecycle is owned by the caller: `initialize(att)` opens the port
only if it is not already open, and `shutdown(att)` drives the channel to
`min_voltage` but leaves the port open (another attenuator may still use it).

# Fields
- `unique_id::String`: A unique identifier for the attenuator.
- `properties::AttenuatorProperties`: The properties of the attenuator.
- `scope::Triggerscope4`: The Triggerscope driving the attenuator.
- `dac_channel::Int`: The Triggerscope DAC channel wired to the LCC1620 EXT INPUT (1-16).
"""
mutable struct LCC1620 <: Attenuator
    unique_id::String
    properties::AttenuatorProperties
    scope::Triggerscope4
    dac_channel::Int
end

function LCC1620(;
    unique_id::String="LCC1620",
    scope::Triggerscope4=Triggerscope4(),
    dac_channel::Int=1,
    min_voltage::Float64=0.0,
    max_voltage::Float64=5.0
    )
    if !(1 <= dac_channel <= scope.dacoutputs)
        @error "dac_channel must be between 1 and $(scope.dacoutputs)"
    end
    properties = AttenuatorProperties(0.0, NaN, min_voltage, max_voltage, Float64[], Float64[])
    LCC1620(unique_id, properties, scope, dac_channel)
end
