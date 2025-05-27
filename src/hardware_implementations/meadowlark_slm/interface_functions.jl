#=
These functions generate images using the write single image function in the Meadowlark SDK
=#

function SLMInterface.displayimage(slm::SLM)
    writesingleimage(slm)
end

function SLMInterface.displayimage(slm::SLM, phase::Array{Float64,2})
    SLM.phase = phase
    return displayimage(slm)
end

function SLMInteface.displayzernike(slm::SLM, zernike::Vector{Float64})
    phase = zernike_to_phase(zernike, slm)
    return displayimage(slm, phase)
end

function SLMInterface.displayblaze(slm::SLM, is_vert::Bool = false , period::Int = 8; blaze_start::Int=1, blaze_end::Int=1024)
    genblazed!(slm, is_vert, period, blaze_start=blaze_start, blaze_end=blaze_end)
    return displayimage(slm)
end