# Created by Abbie Gatsch and Martin Zanazzi, Summer 2025
# This file provides a gui that has several tools to help characterize laser beams
# Supports two beam profiles:
#   - Donut: Laguerre-Gaussian beam with P = 0, L = 2 (extinction ratio metric)
#   - Gaussian: TEM00 Gaussian beam (FWHM and ellipticity metrics)
# It provides a live camera feed, a 2d intensity map, a 3d intensity map, and line profiles of the beam
# It also has options to show an approximate fit and an optimized fit using Optim.jl
# it also shows the difference image between the ideal and real data
# This version includes HDF5 data saving and PNG image export

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using Statistics, Optim, GLMakie, ImageFiltering, HDF5, Dates
include("./dev_helper_funcs.jl")

function beam_characterization(
    camera,
    framerate::Float64 = 5.0, # framerate seems to be limited to ~15.0
    exposure_time::Float64 = 0.01,
    save_dir::String = "Y:\\Projects\\NSF-MINFLUX\\projects\\Data\\Evaluation Experiments\\EOD Driver test\\beam characterizatiom",
)

    # initalize the camera and start the screen
    initialize(camera)
    camera.exposure_time = exposure_time
    live(camera)
    start = time()
    initial_frame = getlastframe(camera)'

    # create figure, axis, layout
    fig = Figure(size = (1000, 750), title = "Beam Characterization")
    ax2d = Axis(fig[1, 1], title = "2D Intensity Map", aspect = DataAspect())
    ax3d = Axis3(fig[1, 2], title = "3D Intensity Map", aspect = (1280, 1024, 400))
    ax3d.limits[] = (nothing, nothing, nothing, nothing, -50, nothing)

    info_box = GridLayout(fig[2, 2])
    toggle_box = GridLayout(info_box[1, 1])
    data_box = GridLayout(info_box[2, 1])
    line_profile_box = GridLayout(fig[2, 1])
    y_profile_ax = Axis(line_profile_box[2, 1], title = "Y Profile")
    y_profile_ax.limits[] = (0, 1080, 0, 100)
    x_profile_ax = Axis(line_profile_box[1, 1], title = "X Profile")
    x_profile_ax.limits[] = (0, 1280, 0, 100)

    colsize!(fig.layout, 1, Relative(0.5))
    colsize!(fig.layout, 2, Relative(0.5))
    rowsize!(fig.layout, 1, Relative(0.5))
    rowsize!(fig.layout, 2, Relative(0.5))

    # beam type selector
    beam_type = Observable(:donut)
    Label(toggle_box[0, 1], "Beam Profile:")
    beam_menu = Menu(toggle_box[0, 2:4], options = ["Donut", "Gaussian"])
    on(beam_menu.selection) do sel
        beam_type[] = sel == "Donut" ? :donut : :gaussian
    end

    Label(toggle_box[1, 1], "Approx Fit Curve")
    fit_toggle = Toggle(toggle_box[1, 2], active = true)
    Label(toggle_box[2, 1], "Real 3D data")
    real_3d_toggle = Toggle(toggle_box[2, 2], active = true)
    Label(toggle_box[1, 3], "Difference Image")
    diff_toggle = Toggle(toggle_box[1, 4], active = false)
    Label(toggle_box[2, 3], "Optimized Fit Curve")
    optimized_toggle = Toggle(toggle_box[2, 4], active = false)
    loading_label = Label(toggle_box[3, 1:4], "Loading...", visible = false)
    refresh_optim = Button(toggle_box[4, 1:2], label = "Refresh Optimizers") # poly fit for ext ratio and optimization
    save_button = Button(toggle_box[4, 3:4], label = "Save Data & Image")
    approx_r2_label = Label(data_box[1, 1], "Approximate Fit R^2: N/A")
    optim_r2_label = Label(data_box[2, 1], "Optimized Fit R^2*: N/A")
    metric_label = Label(data_box[3, 1], "Extinction Ratio*: N/A")
    Label(data_box[4, 1], "* = optimized values. Refresh to update.")

    #create frame observable
    frame_obs = Observable(initial_frame)

    # the dimensions of the frame
    nx, ny = size(initial_frame)
    x = collect(1:nx)
    y = collect(1:ny)

    # observables for mathematical ideal overlay
    C = Observable(1.0) # constant for height of beam
    ω = Observable(100.0) # constant for beam radius
    x_grid = repeat(x, 1, ny)  # shape (nx, ny)
    y_grid = repeat(y', nx, 1)  # shape (nx, ny)

    # initalize beam constants
    cx = Observable(1.0) # the x coord of the center
    cy = Observable(1.0) # the y coord of the center
    r_grid = Observable(zeros(size(frame_obs[]))) # r_grid is a polar representation of the cartesian grid
    ideal_z = Observable(zeros(size(frame_obs[]))) # the ideal intensity function
    optimized = Observable(zeros(size(frame_obs[]))) # the optimized intensity function
    r_squared = Observable(0.0) # the coefficient of determination for the optimized fit
    diff_img = Observable(zeros(size(frame_obs[]))) # the difference image
    y_prof = Observable(zeros(ny)) # y profile of the frame
    x_prof = Observable(zeros(nx)) # x profile of the frame
    x_prof_ideal = Observable(zeros(nx)) # x profile of the ideal frame
    y_prof_ideal = Observable(zeros(ny)) # y profile of the ideal frame
    x_prof_optim = Observable(zeros(nx)) # x profile of the optimized frame
    y_prof_optim = Observable(zeros(ny)) # y profile of the optimized frame
    ext_ratio = Observable(0.0) # extinction ratio

    # update labels and reset optimized data when beam type changes
    on(beam_type) do bt
        if bt == :gaussian
            metric_label.text = "FWHM & Ellipticity*: N/A"
        else
            metric_label.text = "Extinction Ratio*: N/A"
        end
        # reset optimized fit so stale data from the other beam type is not displayed
        optimized[] = zeros(size(frame_obs[]))
        r_squared[] = 0.0
        optim_r2_label.text = "Optimized Fit R^2*: N/A"
    end

    # update the observables that depend on optimizers
    on(refresh_optim.clicks) do n
        if !optimized_toggle.active[]
            @warn "toggle switch must be on to view optimized beam fit"
        end

        # run the characterization function when the refresh button is clicked
        if Bool(camera.is_running) == 1
            loading_label.visible[] = true
            yield()  # let the GUI update
            @async begin
                if beam_type[] == :donut
                    optimized[], r_squared[] = characterize_donut(frame_obs[])
                    optim_r2_label.text = "Optimized Fit R^2*: $(round(r_squared[], digits = 4))"
                    cx[], cy[], high_xs, high_ys = find_center_donut(frame_obs[])
                    ext_ratio[] = extinction_ratio(frame_obs[], cx[], cy[], high_xs, high_ys)
                    metric_label.text = "Extinction Ratio*: $(round(ext_ratio[], digits = 4))"
                else
                    optimized[], r_squared[] = characterize_gaussian(frame_obs[])
                    optim_r2_label.text = "Optimized Fit R^2*: $(round(r_squared[], digits = 4))"
                    fwhm_x, fwhm_y = compute_fwhm(frame_obs[], cx[], cy[])
                    ellip = max(fwhm_x, fwhm_y) / max(min(fwhm_x, fwhm_y), 1.0)
                    metric_label.text = "FWHM*: $(round(fwhm_x, digits=1))x$(round(fwhm_y, digits=1))px  Ellipticity: $(round(ellip, digits=3))"
                end
                loading_label.visible[] = false
            end
        end
    end

    # save current frame, characterization data to HDF5, and screenshot to PNG
    on(save_button.clicks) do n
        timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
        h5_path = joinpath(save_dir, "beam_characterization_$timestamp.h5")
        img_path = joinpath(save_dir, "beam_characterization_$timestamp.png")

        # snapshot all data as plain Arrays (collect ensures no lazy/Adjoint types)
        frame_data = collect(Float64, frame_obs[])
        ideal_data = collect(Float64, ideal_z[])
        optim_data = collect(Float64, optimized[])
        diff_data = collect(Float64, diff_img[])
        xprof_data = collect(Float64, x_prof[])
        yprof_data = collect(Float64, y_prof[])
        bt = string(beam_type[])
        cx_val = Float64(cx[])
        cy_val = Float64(cy[])
        C_val = Float64(C[])
        ω_val = Float64(ω[])
        approx_r2 = coeff_of_determination(ideal_data, frame_data)
        optim_r2 = Float64(r_squared[])
        exp_time = Float64(camera.exposure_time)
        min_pc = Float64(minimum(frame_data))
        max_pc = Float64(maximum(frame_data))

        @async begin
            # save HDF5 data
            try
                h5open(h5_path, "w") do h5file
                    write(h5file, "frame", frame_data)
                    write(h5file, "ideal_fit", ideal_data)
                    if any(optim_data .!= 0)
                        write(h5file, "optimized_fit", optim_data)
                    end
                    write(h5file, "difference", diff_data)
                    write(h5file, "x_profile", xprof_data)
                    write(h5file, "y_profile", yprof_data)
                    # save metadata as attributes
                    attrs(h5file)["beam_type"] = bt
                    attrs(h5file)["center_x"] = cx_val
                    attrs(h5file)["center_y"] = cy_val
                    attrs(h5file)["C"] = C_val
                    attrs(h5file)["omega"] = ω_val
                    attrs(h5file)["approx_r_squared"] = approx_r2
                    attrs(h5file)["optim_r_squared"] = optim_r2
                    attrs(h5file)["exposure_time"] = exp_time
                    attrs(h5file)["min_photon_count"] = min_pc
                    attrs(h5file)["max_photon_count"] = max_pc
                    attrs(h5file)["timestamp"] = timestamp
                end
                println("Saved HDF5 data to $h5_path")
            catch e
                @error "Failed to save HDF5 file"
                showerror(stdout, e, catch_backtrace())
            end
            # save PNG screenshot of the figure
            try
                save(img_path, fig)
                println("Saved screenshot to $img_path")
            catch e
                @error "Failed to save image"
                showerror(stdout, e, catch_backtrace())
            end
        end
    end

    # display figure and run window close manager
    display(fig)
    window_closer(fig, () -> shutdown(camera))

    # update observables when the beam changes
    r_grid = lift(cx, cy) do cx, cy
        sqrt.((x_grid .- cx).^2 .+ (y_grid .- cy).^2) # distance formula
    end
    ideal_z = lift(C, ω, r_grid, frame_obs, beam_type) do C, ω, r_grid, frame_obs, bt
        bg = set_baseline(frame_obs; frac = 0.05)
        if bt == :donut
            # laguerre gaussian beam formula with p = 0 and l = 2 and baseline added
            C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ bg
        else
            # gaussian beam formula (TEM00)
            C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .+ bg
        end
    end
    diff_img = lift(ideal_z, frame_obs) do ideal_z, frame_obs
        # difference image between ideal and real data
        ideal_z .- frame_obs
    end

    # min/max intensity label for saturation checking
    photon_count_label = Label(fig[1, 1, Top()], "Min Photon Count: 0  Max Photon Count: 0", fontsize = 14, halign = :left, padding = (5, 0, 0, 0))

    # draw on figure
    heatmap!(ax2d, frame_obs, colormap = :inferno) # live camera view
    scatter!(ax2d, cx, cy, color=:teal, markersize=10) # center dot
    surface!(ax3d, x, y, frame_obs; colormap = :viridis, visible = real_3d_toggle.active) # 3d real data
    surface!(ax3d, x, y, ideal_z; colormap = (:greys, 0.6), overdraw = false, visible = fit_toggle.active) # 3d ideal data
    surface!(ax3d, x, y, diff_img; colormap = (:bone, 0.6), overdraw = true, visible = diff_toggle.active) # 3d difference data
    surface!(ax3d, x, y, optimized; colormap = (:blues, 0.6), overdraw = false, visible = optimized_toggle.active) # 3d optimized data
    lines!(y_profile_ax, y_prof, color = :red) # y profile centered on beam
    lines!(x_profile_ax, x_prof, color = :blue) # x profile centered on beam
    lines!(y_profile_ax, y_prof_ideal, color = :grey, visible = fit_toggle.active) # ideal profile line
    lines!(x_profile_ax, x_prof_ideal, color = :grey, visible = fit_toggle.active) # ideal profile line
    lines!(x_profile_ax, x_prof_optim, color = :deepskyblue, visible = optimized_toggle.active) # optimized profile line
    lines!(y_profile_ax, y_prof_optim, color = :deepskyblue, visible = optimized_toggle.active) # optimized profile line

    # these tasks run every frame and would not update automatically otherwise.
    # they update the observables that the functions above rely on.
    @async begin
        while Bool(camera.is_running) == 1
            frame = getlastframe(camera)'
            # if the camera is on, update observables and titles
            if frame !== nothing
                frame_obs[] = frame
                duration = round(time() - start, digits = 2)
                ax2d.title = "Live Camera Feed - Time: $duration seconds"
                photon_count_label.text = "Min Photon Count: $(minimum(frame))  Max Photon Count: $(maximum(frame))"
                approx_r2_label.text = "Approximate Fit R^2: $(round(coeff_of_determination(ideal_z[], frame_obs[]), digits = 4))"

                if beam_type[] == :donut
                    cx[], cy[], high_xs, high_ys = find_center_donut(frame)
                    C[], ω[] = set_constants_donut(frame, cx[], cy[], high_xs, high_ys)
                else
                    cx[], cy[] = find_center_gaussian(frame)
                    C[], ω[] = set_constants_gaussian(frame, cx[], cy[])
                end

                y_prof[] = frame[:, round(Int, cy[])]
                x_prof[] = frame[round(Int, cx[]), :]
                y_prof_ideal[] = ideal_z[][:, round(Int, cy[])]
                x_prof_ideal[] = ideal_z[][round(Int, cx[]), :]
                y_prof_optim[] = optimized[][:, round(Int, cy[])]
                x_prof_optim[] = optimized[][round(Int, cx[]), :]
            end
            sleep(1/framerate)
        end
    end
    return fig, ax2d, ax3d, frame_obs
end

# ============================================================================
# Shared helper functions
# ============================================================================

# find the baseline or background brightness of the image
function set_baseline(frame; frac = 0.1) # frac is the fraction of darkest pixels to average
    thresh = quantile(vec(frame), frac)
    coords = findall(<=(thresh), frame)
    sum = 0
    for coord in coords
        sum += frame[coord[1], coord[2]]
    end
    avg_background = sum / length(coords)
    return avg_background
end

# R^2 calculation
function coeff_of_determination(ideal_z, data)
    r_sum = 0
    tot_sum = 0
    avg = mean(data)
    for i in eachindex(data)
        r_sum += (data[i] - ideal_z[i]) ^ 2
        tot_sum += (data[i] - avg) ^ 2
    end
    return 1 - (r_sum / tot_sum)
end

# inserts the ideal subimage onto a full frame so it can be displayed on the 3d intensity map
function insert_image(sub_img, cx, cy, bg, frame)
    int_cx = round(Int, cx)
    int_cy = round(Int, cy)
    sub_img_size = size(sub_img)
    ideal_frame = zeros(size(frame)) .+ bg # create a zero matrix to insert the sub image into

    for i in 1:sub_img_size[1]
        for j in 1:sub_img_size[2]
            ideal_frame[(int_cx - sub_img_size[1] ÷ 2) + i - 1, (int_cy - sub_img_size[2] ÷ 2) + j - 1] = sub_img[i, j]
        end
    end
    return ideal_frame
end

# ============================================================================
# Donut (Laguerre-Gaussian p=0, l=2) functions
# ============================================================================

# find the center of the donut by averaging the coordinates of the bright ring
# if this doesn't work well, adjust the fraction of brightest pixels to average
function find_center_donut(frame; frac=0.002) # frac is fraction of brightest pixels to average
    thresh = quantile(vec(frame), 1 - frac)  # gives the fraction of pixels that are above the threshold
    coords = findall(>=(thresh), frame) # gives a vector of the coordinates that corrospond to above threshold
    high_xs = []; high_ys = []
    for coord in coords # create individual vectors for x and y
        push!(high_xs, coord[1])
        push!(high_ys, coord[2])
    end
    center_x = mean(high_xs)
    center_y = mean(high_ys)
    return center_x, center_y, high_xs, high_ys
end

# Set constants C and ω for donut beam
function set_constants_donut(frame, cx, cy, high_xs, high_ys; frac = 0.001)
    # C is related to the highest intensity, ω is the beam width
    # To find the first constant C average the intensity of the brightest pixels
    thresh = quantile(vec(frame), 1 - frac)
    coords = findall(>=(thresh), frame)
    bright_sum = 0
    for coord in coords
        bright_sum += frame[coord[1], coord[2]]
    end
    avg_high_intensity = bright_sum / length(coords) * 7

    # Set omega equal to the average distance between the center point and the bright ring
    beam_radius = ring_radius(high_xs, high_ys, cx, cy) * 0.85 # constant that seems to work

    return avg_high_intensity, beam_radius
end

# Find radius of donut by averaging the distance from the center to the bright ring
function ring_radius(xs, ys, cx, cy)
    dist_sum = 0
    for i in eachindex(xs)
        dist_sum += sqrt((xs[i] - cx)^2 + (ys[i] - cy)^2)
    end
    return dist_sum / length(xs)
end

# Fits a 4th degree polynomial to the center of the donut and uses its minimum to calculate the extinction ratio
# The subframe size needs to be adjusted depending on the size of the donut on the screen.
function extinction_ratio(frame, cx, cy, high_xs, high_ys; subframe_size = 20)
    int_cx = round(Int, cx)
    int_cy = round(Int, cy)

    # create a subimage centered on the donut for the ideal overlay and extinction ratio calculation
    x_range = max(int_cx - subframe_size ÷ 2, 1) : min(int_cx + subframe_size ÷ 2, size(frame, 1))
    y_range = max(int_cy - subframe_size ÷ 2, 1) : min(int_cy + subframe_size ÷ 2, size(frame, 2))
    sub_image = frame[x_range, y_range]

    # creates a funciton to optimize that does not depend on sub_image
    func_to_min = inputs -> polysquare_err(inputs, sub_image)
    result = optimize(
        func_to_min,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 1.0],
        Optim.Options(
            show_trace = false,
            iterations = 100000
        ))

    println(result)
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O = Optim.minimizer(result)
    ideal_poly = polysquare_err([A, B, C, D, E, F, G, H, I, J, K, L, M, N, O], sub_image; return_ideal = true)

    # averages the intensity of the brightest fraction of pixels and calculates the extinction ratio
    # the lower the better
    bright_sum = 0
    for i in eachindex(high_xs)
        bright_sum += frame[high_xs[i], high_ys[i]]
    end
    bg = set_baseline(frame)
    avg_high = bright_sum / length(high_xs) - bg
    poly_min = abs(minimum(ideal_poly) - bg) # note the absolute value here?
    return poly_min / avg_high
end

# creates a 2d polynomial to fit to the donut center
# returns the sum of squared errors if return_ideal is false
# otherwise returns the ideal polynomial
function polysquare_err(inputs::Vector{Float64}, data; return_ideal::Bool = false)
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O = inputs
    nx, ny = size(data)
    x = collect(1:nx)
    y = collect(1:ny)
    x_grid = repeat(x, 1, ny)  # shape (nx, ny)
    y_grid = repeat(y', nx, 1)  # shape (nx, ny)
    poly = A .+ B .* x_grid .+ C .* y_grid .+ D .* x_grid.^2 .+ E .* y_grid.^2 .+
            F .* x_grid .* y_grid .+ G .* x_grid.^3 .+ H .* y_grid.^3 .+
            I .* x_grid.^2 .* y_grid .+ J .* x_grid .* y_grid.^2 .+
            K .* x_grid.^4 .+ L .* y_grid.^4 .+ M .* x_grid.^2 .* y_grid.^2 +
            N .* x_grid.^3 .* y_grid + O .* x_grid .* y_grid.^3
    if return_ideal
        return poly
    end
    return sum((data .- poly).^2)
end

# Donut beam cost function
function square_err_donut(inputs::Vector{Float64}, cx, cy, data, full_frame, return_ideal::Bool = false)
    C, ω, bg = inputs
    # make coordinate system
    nx, ny = size(data)
    x = collect(1:nx)
    y = collect(1:ny)
    x_grid = repeat(x, 1, ny)  # shape (nx, ny)
    y_grid = repeat(y', nx, 1)  # shape (nx, ny)

    # calculate the center of the sub image instead of the full frame
    sub_cx = (nx + 1) / 2
    sub_cy = (ny + 1) / 2

    # create an array of distances from the center calculated above
    r_grid = sqrt.((x_grid .- sub_cx).^2 .+ (y_grid .- sub_cy).^2)
    # make ideal function
    ideal = C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ bg

    if return_ideal
        return insert_image(ideal, cx, cy, bg, full_frame), coeff_of_determination(ideal, data)
    end
    return sum((data .- ideal).^2) # return the sum of squared errors
end

# Donut beam optimization
# takes about 8 seconds to run
function characterize_donut(data, sub_frame_size = 100)
    # make initial guesses for the parameters
    # this greatly reduces the time of the optimizer and makes for a better final outcome too

    # NOTE: it was very bad at finding the center of the donut, so we use find_center_donut
    # perhaps it was very bad because there were too many parameters to optimize, regardless
    # these guesses lead to better results and reduced runtime
    guess_cx, guess_cy, xs, ys = find_center_donut(data)
    int_cx = round(Int, guess_cx)
    int_cy = round(Int, guess_cy)
    guess_C, guess_ω = set_constants_donut(data, guess_cx, guess_cy, xs, ys)
    guess_bg = set_baseline(data; frac = 0.05)

    # cut out the donut from the frame for optimization
    x_range = max(int_cx - sub_frame_size ÷ 2, 1) : min(int_cx + sub_frame_size ÷ 2, size(data, 1))
    y_range = max(int_cy - sub_frame_size ÷ 2, 1) : min(int_cy + sub_frame_size ÷ 2, size(data, 2))
    sub_image = data[x_range, y_range]

    # make a function that depends on data, but does not take it as a parameter
    # so that the optimizer can use it without attempting to optimize the data itself
    func_to_min = inputs -> square_err_donut(inputs, guess_cx, guess_cy, sub_image, data)

    # optimize the function
    result = optimize(func_to_min, [guess_C, guess_ω, guess_bg])
    println(result)
    C, ω, bg = Optim.minimizer(result)
    ideal, r_squared = square_err_donut([C, ω, bg], guess_cx, guess_cy, sub_image, data, true)
    return ideal, r_squared
end

# ============================================================================
# Gaussian (TEM00) functions
# ============================================================================

# find center of Gaussian beam using the brightest pixel
function find_center_gaussian(frame)
    peak_idx = argmax(frame)
    return Float64(peak_idx[1]), Float64(peak_idx[2])
end

# Set constants C and ω for Gaussian beam
function set_constants_gaussian(frame, cx, cy)
    bg = set_baseline(frame; frac = 0.05)
    # C is the peak intensity above background
    C = maximum(frame) - bg

    # estimate ω from FWHM along x profile through center
    int_cx = clamp(round(Int, cx), 1, size(frame, 1))
    int_cy = clamp(round(Int, cy), 1, size(frame, 2))
    profile = frame[:, int_cy]
    half_max = (maximum(profile) + bg) / 2
    above = findall(>=(half_max), profile)
    if length(above) >= 2
        fwhm = above[end] - above[1]
        ω = fwhm / (2 * sqrt(log(2)))  # convert FWHM to 1/e² radius
    else
        ω = 50.0  # fallback
    end

    return C, ω
end

# Gaussian beam cost function
function square_err_gaussian(inputs::Vector{Float64}, cx, cy, data, full_frame, return_ideal::Bool = false)
    C, ω, bg = inputs
    nx, ny = size(data)
    x = collect(1:nx)
    y = collect(1:ny)
    x_grid = repeat(x, 1, ny)
    y_grid = repeat(y', nx, 1)

    sub_cx = (nx + 1) / 2
    sub_cy = (ny + 1) / 2

    r_grid = sqrt.((x_grid .- sub_cx).^2 .+ (y_grid .- sub_cy).^2)
    ideal = C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .+ bg

    if return_ideal
        return insert_image(ideal, cx, cy, bg, full_frame), coeff_of_determination(ideal, data)
    end
    return sum((data .- ideal).^2)
end

# Gaussian beam optimization
function characterize_gaussian(data, sub_frame_size = 100)
    guess_cx, guess_cy = find_center_gaussian(data)
    int_cx = round(Int, guess_cx)
    int_cy = round(Int, guess_cy)
    guess_C, guess_ω = set_constants_gaussian(data, guess_cx, guess_cy)
    guess_bg = set_baseline(data; frac = 0.05)

    x_range = max(int_cx - sub_frame_size ÷ 2, 1) : min(int_cx + sub_frame_size ÷ 2, size(data, 1))
    y_range = max(int_cy - sub_frame_size ÷ 2, 1) : min(int_cy + sub_frame_size ÷ 2, size(data, 2))
    sub_image = data[x_range, y_range]

    func_to_min = inputs -> square_err_gaussian(inputs, guess_cx, guess_cy, sub_image, data)

    result = optimize(func_to_min, [guess_C, guess_ω, guess_bg])
    println(result)
    C, ω, bg = Optim.minimizer(result)
    ideal, r_squared = square_err_gaussian([C, ω, bg], guess_cx, guess_cy, sub_image, data, true)
    return ideal, r_squared
end

# Compute FWHM in x and y for Gaussian beam quality metric
function compute_fwhm(frame, cx, cy)
    int_cx = clamp(round(Int, cx), 1, size(frame, 1))
    int_cy = clamp(round(Int, cy), 1, size(frame, 2))
    bg = set_baseline(frame; frac = 0.05)

    # X profile FWHM
    x_profile = frame[:, int_cy]
    x_half_max = (maximum(x_profile) + bg) / 2
    x_above = findall(>=(x_half_max), x_profile)
    fwhm_x = length(x_above) >= 2 ? Float64(x_above[end] - x_above[1]) : 0.0

    # Y profile FWHM
    y_profile = frame[int_cx, :]
    y_half_max = (maximum(y_profile) + bg) / 2
    y_above = findall(>=(y_half_max), y_profile)
    fwhm_y = length(y_above) >= 2 ? Float64(y_above[end] - y_above[1]) : 0.0

    return fwhm_x, fwhm_y
end

# To run:
# camera = ThorcamDCXCamera() # define camera first
# beam_characterization(camera)
# Or with custom save directory:
# beam_characterization(camera, save_dir="C:\\my_data\\beam_profiles")
