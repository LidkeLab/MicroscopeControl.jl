mutable struct Sequence
    phase::Array{Float64,3}
    offset::Array{Float64,3}
    num_frames::Int
end

function Sequence(; 
    phase = zeros(Float64, 1024, 1024, 10),
    offset = zeros(Float64, 1024, 1024, 10))

    num_frames = size(phase, 3)

    if num_frames > 754
        @error "Number of frames in sequence exceeds maximum allowed by Meadowlark SLM"
    end

    return Sequence(phase, offset, num_frames)
end

mutable struct MLSLM <: SLM
    # Single Image Generation Fields
    width::Int
    height::Int
    pixelsize::Float64
    wavelength::Float64
    phase::Array{Float64,2}
    offset::Array{Float64,2}
    pupil::Pupil

    #Sequence Pattern
    sequence::Sequence

    #SDK Fields
    bit_depth::Cuint # = 12
    n_boards_found::Cuint # = Ref{Cuint}(0)
    constructed_ok::Cuint # = Ref{Cuint}(1)
    is_nematic_type::Cuint # = 1
    ram_write_enable::Cuint # = 1
    use_gpu::Cuint # = 1
    max_transient_frames::Cuint # = 10
end

function MLSLM(; width = 1024,
    height = 1024,
    pixelsize = 1,
    wavelength = 1,
    phase = zeros(Float64, width, height),
    offset = zeros(Float64, width, height),
    pupil = Pupil(0, 0, 1, 1),

    sequence = Sequence(),

    bit_depth = Cuint(12),
    n_boards_found = Cuint(0),
    constructed_ok = Cuint(1),
    is_nematic_type = Cuint(1),
    ram_write_enable = Cuint(1),
    use_gpu = Cuint(1),
    max_transient_frames = Cuint(10) )


    return MLSLM(width, height, pixelsize, wavelength, phase, offset, pupil, sequence,bit_depth, n_boards_found, constructed_ok, is_nematic_type, ram_write_enable, use_gpu, max_transient_frames)
end

