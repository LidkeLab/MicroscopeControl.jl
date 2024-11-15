
"""
    `CrystaLaser` A LaserDaqControl type inherited from `LightSource`.

# Fields
- `unique_id::String`: A unique identifier for the light source.
- `properties::LightSourceProperties`: The properties of the light source.
- `laser_color::String`: The color of the laser.
- `daq::NIdaq`: The NIDAQ card.
- `t::Task`: The task of the NIDAQ card.
- 'min_voltage'::Float64: The minimum voltage of the laser.
- 'max_voltage'::Float64: The maximum voltage of the laser.
- 'channelsAO'::Array{String}: The channels of the NIDAQ card.
"""
mutable struct CrystaLaser <: LightSource
    unique_id::String
    properties::LightSourceProperties
    laser_color::String
    daq::NIdaq
    min_voltage::Float64
    max_voltage::Float64
    channelsAO::Array{String}
    channelsDO::Array{String}
end

function determine_t_based_on_color(laser_color::String)
    
    return daq, channelsAO, channelsDO
end


function CrystaLaser(;
    unique_id::String="CrystaLaser",
    properties::LightSourceProperties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
    laser_color::String="561"
    )
    
    J = 1 # 561
    if !isdefined(Main, :channelsAO)
        daq = NIdaq()
        devs = NIDAQcard.showdevices(daq)
        channelsAO = NIDAQcard.showchannels(daq,"AO",devs[1])
    end
    if !isdefined(Main, :channelsDO)
        channelsDO = NIDAQcard.showchannels(daq,"DO",devs[1])
    end
    min_voltage=0.7
    max_voltage=2.7785
    CrystaLaser(unique_id, properties, laser_color, daq , min_voltage, max_voltage, channelsAO, channelsDO)
end