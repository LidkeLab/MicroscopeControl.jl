
function displayimage(slm::SLM)


end

function displayimage(slm::SLM, phase::Array{Float64,2})
    SLM.phase = phase
    return displayimage(slm)
end

function displayzernike(slm::SLM, zernike::Vector{Float64})
    phase = zernike_to_phase(zernike, slm)
    return displayimage(slm, phase)
end

function displayblaze(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)
    phase = blaze_to_phase(slm, angle, period; blaze_start=blaze_start, blaze_end=blaze_end)
    return displayimage(slm, phase)
end


function blaze_to_phase(slm::SLM, angle::Float64, period::Float64; blaze_start::Float64=0.0, blaze_end::Float64=-1.0)
    
    return phase
end








