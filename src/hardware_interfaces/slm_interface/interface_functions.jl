
"""
    displayimage(slm::SLM)

Display the current phase map on the SLM. ???

# Arguments
- `slm::SLM`: The SLM to display the phase map on.
"""
function displayimage(slm::SLM)


end

"""
    displayimage(slm::SLM, phase::Array{Float64,2})

Display the given phase map on the SLM. ???

# Arguments
- `slm::SLM`: The SLM to display the phase map on.
- `phase::Array{Float64,2}`: The phase map to display.
"""
function displayimage(slm::SLM, phase::Array{Float64,2})
    SLM.phase = phase
    return displayimage(slm)
end

"""
    displayzernike(slm::SLM, zernike::Vector{Float64})

Display the Zernike polynomial on the SLM. ???

# Arguments
- `slm::SLM`: The SLM to display the Zernike polynomial on.
- `zernike::Vector{Float64}`: The Zernike polynomial coefficients.
"""
function displayzernike(slm::SLM, zernike::Vector{Float64})
    phase = zernike_to_phase(zernike, slm)
    return displayimage(slm, phase)
end

"""
    displayblaze(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)

Display the blaze function on the SLM. ???

# Arguments
- `slm::SLM`: The SLM to display the blaze function on.
- `angle::Float64`: The angle of the blaze function.
- `period::Float64`: The period of the blaze function.
- `blaze_start::Float64=0.0`: The starting point of the blaze function.
- `blaze_end::Float64=-1.0`: The ending point of the blaze function.
"""
function displayblaze(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)
    phase = blaze_to_phase(slm, angle, period; blaze_start=blaze_start, blaze_end=blaze_end)
    return displayimage(slm, phase)
end

"""
    zernike_to_phase(zernike::Vector{Float64}, slm::SLM)

Converts a Zernike polynomial to a phase map for an SLM. ???

# Arguments
- `zernike::Vector{Float64}`: The Zernike polynomial coefficients.
- `slm::SLM`: The SLM to generate the phase map for.
"""
function blaze_to_phase(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)
    
    return phase
end