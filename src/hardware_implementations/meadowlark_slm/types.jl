"""
    Sequence(; phase=zeros(Float64, 1024, 1024, 10), offset=zeros(Float64, 1024, 1024, 10)) -> Sequence

A stack of phase patterns for a Meadowlark SLM, held in the `sequence` field of [`MLSLM`](@ref). `phase` and
`offset` are three-dimensional `Float64` arrays with frames along the third dimension; `num_frames` is
`size(phase, 3)`. If it exceeds 754, the Meadowlark limit named in the source, an error is logged but the
object is still returned. `offset` is not checked against `phase`.
`[limitation]` Nothing in this package writes a sequence to the board (`writesequence` and
`selectsequenceimage` log "Not implemented").
"""
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

"""
    MLSLM(; width=1024, height=1024, pixelsize=1, wavelength=1, phase, offset, pupil=Pupil(0, 0, 1, 1),
          sequence=Sequence(), bit_depth=Cuint(12), ...) -> MLSLM

Meadowlark Optics spatial light modulator driven through the Blink OverDrive Plus SDK. The keyword
constructor only fills the struct: it does not load the SDK DLL or contact a board. `MLSLM` has no
`initialize`, `shutdown` or `gui` method. The functions that drive it are unexported: `initializesdk`
opens the SDK, `loadlut` loads a fixed LUT file, `writesingleimage(slm)` writes `slm.phase` to board 1 and
`closesdk` closes the SDK. [`genblazed!`](@ref) and [`genzernike!`](@ref) fill `slm.phase` in memory.
`[limitation]` The SLM interface's `displayimage`, `displayzernike` and `displayblaze` do not drive an
`MLSLM`: the module defines no methods of its own for them (its `interface_functions.jl` is not loaded), so a
call reaches the generic interface methods, which send nothing to the board or fail.
`[limitation]` The SDK functions above name
`C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\Blink_C_wrapper.dll`, so the device path works
only on Windows with that SDK installed.

Keywords and fields: `width` and `height` (pixels), `pixelsize` and `wavelength` (stored and exported by
`export_state` only; the code gives no unit), `phase` and `offset` (`Float64` arrays of size
`(width, height)`, default zeros; `phase` holds fractions of a wave in 0 to 1, which `writesingleimage`
scales to 0 to 255), `pupil` (a `Pupil`), `sequence` (a [`Sequence`](@ref)). The SDK fields `bit_depth`,
`n_boards_found`, `constructed_ok`, `is_nematic_type`, `ram_write_enable`, `use_gpu` and
`max_transient_frames` (all `Cuint`, defaults 12, 0, 1, 1, 1, 1, 10) are cached values only; `initializesdk`
takes its own keywords and does not read them.
"""
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

