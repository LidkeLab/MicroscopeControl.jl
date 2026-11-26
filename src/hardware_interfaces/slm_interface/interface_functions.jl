
"""
    displayimage(slm::SLM)
    displayimage(slm::SLM, phase::Array{Float64,2})

Show a phase pattern on the SLM: the one already in `slm.phase`, or `phase`.

`[limitation]` Neither form works today, for any SLM. The one-argument form does nothing and returns `nothing`.
The two-argument form assigns to the abstract type (`SLM.phase`) instead of the argument, and throws. No driver
defines its own method (`MLSLM`'s file of interface methods is not included in the package). Drive an `MLSLM`
with its pattern generators, such as [`genblazed!`](@ref) and [`genzernike!`](@ref), and the Meadowlark functions
its docstring names.
"""
function displayimage(slm::SLM)


end

function displayimage(slm::SLM, phase::Array{Float64,2})
    SLM.phase = phase
    return displayimage(slm)
end

"""
    displayzernike(slm::SLM, zernike::Vector{Float64})

Show the phase described by Zernike coefficients `zernike`.

`[limitation]` Does not work: it calls `zernike_to_phase`, which is not defined in the package (the file that
would define it, `zernike.jl`, is not included and its function has no body), and throws an `UndefVarError`. On
an `MLSLM` use [`genzernike!`](@ref).
"""
function displayzernike(slm::SLM, zernike::Vector{Float64})
    phase = zernike_to_phase(zernike, slm)
    return displayimage(slm, phase)
end

"""
    displayblaze(slm::SLM, angle::Float64, period::Float64; blaze_start=0.0, blaze_end=-1.0)

Show a blazed grating at `angle` with `period`.

`[limitation]` Does not work: it calls `blaze_to_phase`, which is not defined anywhere, and throws an
`UndefVarError`. On an `MLSLM` use [`genblazed!`](@ref).
"""
function displayblaze(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)
    phase = blaze_to_phase(slm, angle, period; blaze_start=blaze_start, blaze_end=blaze_end)
    return displayimage(slm, phase)
end
