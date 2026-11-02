"""
    export_state(slm::MLSLM)

Export cached configuration, the phase image, and offset/sequence children without accessing the SDK.
The SDK fields are cached construction values, not evidence of a connected board.
"""
function export_state(slm::MLSLM)
    attributes = Dict{String,Any}("width" => slm.width, "height" => slm.height,
        "pixelsize" => slm.pixelsize, "wavelength" => slm.wavelength,
        "pupil_x_center" => slm.pupil.x_center, "pupil_y_center" => slm.pupil.y_center,
        "pupil_x_radius" => slm.pupil.x_radius, "pupil_y_radius" => slm.pupil.y_radius)
    for name in (:bit_depth, :n_boards_found, :constructed_ok, :is_nematic_type,
                 :ram_write_enable, :use_gpu, :max_transient_frames)
        attributes[string(name)] = getfield(slm, name)
    end
    children = Dict{String,Any}(
        "offset" => (Dict{String,Any}(), slm.offset, Dict{String,Any}()),
        "sequence" => (Dict{String,Any}("num_frames" => slm.sequence.num_frames), slm.sequence.phase,
            Dict{String,Any}("offset" => (Dict{String,Any}(), slm.sequence.offset, Dict{String,Any}()))))
    return attributes, slm.phase, children
end
