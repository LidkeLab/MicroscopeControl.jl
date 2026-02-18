# Standalone save utilities for beam characterization data
# Saves HDF5 data files and PNG screenshot images of the GUI figure

using HDF5, Dates, GLMakie

"""
    save_beam_data(filename, frame_obs, ideal_z, optimized, diff_img, x_prof, y_prof,
                   beam_type, cx, cy, C, ω, r_squared, camera)

Save beam characterization data and metadata to an HDF5 file.
"""
function save_beam_data(filename::String, frame_obs, ideal_z, optimized, diff_img,
                        x_prof, y_prof, beam_type, cx, cy, C, ω, r_squared, camera)
    h5open(filename, "w") do h5file
        # save raw frame
        write(h5file, "frame", frame_obs[])
        # save ideal fit
        write(h5file, "ideal_fit", ideal_z[])
        # save optimized fit if available
        if any(optimized[] .!= 0)
            write(h5file, "optimized_fit", optimized[])
        end
        # save difference image
        write(h5file, "difference", diff_img[])
        # save line profiles
        write(h5file, "x_profile", x_prof[])
        write(h5file, "y_profile", y_prof[])
        # save metadata as attributes
        attrs(h5file)["beam_type"] = string(beam_type[])
        attrs(h5file)["center_x"] = cx[]
        attrs(h5file)["center_y"] = cy[]
        attrs(h5file)["C"] = C[]
        attrs(h5file)["omega"] = ω[]
        attrs(h5file)["optim_r_squared"] = r_squared[]
        attrs(h5file)["exposure_time"] = camera.exposure_time
        attrs(h5file)["min_photon_count"] = minimum(frame_obs[])
        attrs(h5file)["max_photon_count"] = maximum(frame_obs[])
        attrs(h5file)["timestamp"] = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    end
end

"""
    save_beam_image(filename, fig)

Save a PNG screenshot of the beam characterization GUI figure.
"""
function save_beam_image(filename::String, fig::Figure)
    save(filename, fig)
end

"""
    save_beam_characterization(save_dir, fig, frame_obs, ideal_z, optimized, diff_img,
                               x_prof, y_prof, beam_type, cx, cy, C, ω, r_squared, camera)

Save both HDF5 data and PNG image to the specified directory.
Returns the paths of the saved files.
"""
function save_beam_characterization(save_dir::String, fig, frame_obs, ideal_z, optimized,
                                     diff_img, x_prof, y_prof, beam_type, cx, cy, C, ω,
                                     r_squared, camera)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    h5_path = joinpath(save_dir, "beam_characterization_$timestamp.h5")
    img_path = joinpath(save_dir, "beam_characterization_$timestamp.png")

    try
        save_beam_data(h5_path, frame_obs, ideal_z, optimized, diff_img,
                       x_prof, y_prof, beam_type, cx, cy, C, ω, r_squared, camera)
        println("Saved HDF5 data to $h5_path")
    catch e
        @error "Failed to save HDF5 file" exception = e
    end

    try
        save_beam_image(img_path, fig)
        println("Saved screenshot to $img_path")
    catch e
        @error "Failed to save image" exception = e
    end

    return h5_path, img_path
end
