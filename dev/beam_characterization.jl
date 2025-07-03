using Revise
using GLMakie, ImageFiltering
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using Statistics, Optim

function beam_characterization(
    camera::ThorcamDCXCamera, 
    framerate::Float64 = 5.0, # framerate seems to be limited to ~15.0
    exposure_time::Float64 = 0.01,
)

    # initalize the camera and start the screen
    initialize(camera)
    camera.exposure_time = exposure_time
    live(camera)
    start = time()
    initial_frame = getlastframe(camera)

    # create figure, axis, layout
    fig = Figure(size = (1000, 750), title = "Beam Characterization")
    ax2d = Axis(fig[1, 1], title = "2D Intensity Map", aspect = DataAspect())
    ax3d = Axis3(fig[1, 2], title = "3D Intensity Map", aspect = (1280, 1024, 750))
    ax3d.limits[] = (nothing, nothing, nothing, nothing, -50, nothing)

    info_box = GridLayout(fig[2, 2])
    toggle_box = GridLayout(info_box[1, 1])
    data_box = GridLayout(info_box[2, 1])
    line_profile_box = GridLayout(fig[2, 1])
    y_profile_ax = Axis(line_profile_box[1, 1], title = "Y Profile")
    y_profile_ax.limits[] = (0, 1080, 0, 100)
    x_profile_ax = Axis(line_profile_box[2, 1], title = "X Profile")
    x_profile_ax.limits[] = (0, 1280, 0, 100)

    colsize!(fig.layout, 1, Relative(0.5))
    colsize!(fig.layout, 2, Relative(0.5))
    rowsize!(fig.layout, 1, Relative(0.5))
    rowsize!(fig.layout, 2, Relative(0.5))

    Label(toggle_box[1, 1], "Approx Fit Curve")
    fit_toggle = Toggle(toggle_box[1, 2], active = true)
    Label(toggle_box[2, 1], "Real 3D data")
    real_3d_toggle = Toggle(toggle_box[2, 2], active = true)
    Label(toggle_box[1, 3], "Difference Image")
    diff_toggle = Toggle(toggle_box[1, 4], active = false)
    Label(toggle_box[2, 3], "Optimized Fit Curve")
    optimized_toggle = Toggle(toggle_box[2, 4], active = false)
    refresh_optim = Button(toggle_box[3, 1:4], label = "Refresh Optimization")

    approx_r2_label = Label(data_box[1, 1], "Approximate Fit R^2: ")
    optim_r2_label = Label(data_box[2, 1], "Optimized Fit R^2: ")
    x_ext_label = Label(data_box[3, 1], "X Extinction Ratio: ")
    y_ext_label = Label(data_box[4, 1], "Y Extinction Ratio: ")

    #create frame observable
    frame_obs = Observable(initial_frame)

    # the dimensions of the frame
    ny, nx = size(initial_frame)
    x = collect(1:nx)
    y = collect(1:ny)

    # observables for mathematical ideal overlay
    C = Observable(1.0) # constant for height of donut
    ω = Observable(100.0) # constant for beam radius
    x_grid = repeat(x', ny, 1)  # shape (ny, nx)
    y_grid = repeat(y, 1, nx)  # shape (ny, nx)

    # initalize donut constants
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
    x_ext = Observable(0.0) # x extinction ratio
    y_ext = Observable(0.0) # y extinction ratio

    on(refresh_optim.clicks) do n
        if !optimized_toggle.active[]
            @warn "toggle switch must be on to view optimized beam fit"
        end

        # run the characterization function when the refresh button is clicked
        if camera.is_running == 1
            optimized[], r_squared[] = characterize(frame_obs[])
        end
    end

    # display figure and run window close manager
    display(fig)
    window_closer(fig, () -> shutdown(camera))

    # update observables when the beam changes
    r_grid = lift(cx, cy) do cx, cy
        sqrt.((x_grid .- cy).^2 .+ (y_grid .- cx).^2) # distance formula
    end
    ideal_z = lift(C, ω, r_grid, frame_obs) do C, ω, r_grid, frame_obs
        # leguerre gaussian beam formula with p = 0 and l = 2 and baseline added
        C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ set_baseline(frame_obs; frac = 0.05)
    end
    diff_img = lift(ideal_z, frame_obs) do ideal_z, frame_obs
        # difference image between ideal and real data
        ideal_z .- frame_obs
    end

    # draw on figure
    heatmap!(ax2d, frame_obs, colormap = :inferno) # live camera view
    scatter!(ax2d, cx, cy, color=:teal, markersize=10) # center dot
    surface!(ax3d, y, x, frame_obs; colormap = :viridis, visible = real_3d_toggle.active) # 3d real data
    surface!(ax3d, y, x, ideal_z; colormap = (:greys, 0.6), overdraw = false, visible = fit_toggle.active) # 3d ideal data
    surface!(ax3d, y, x, diff_img; colormap = (:bone, 0.6), overdraw = true, visible = diff_toggle.active) # 3d difference data
    surface!(ax3d, y, x, optimized; colormap = (:blues, 0.6), overdraw = false, visible = optimized_toggle.active) # 3d optimized data
    lines!(y_profile_ax, y_prof, color = :red)
    lines!(x_profile_ax, x_prof, color = :blue)
    lines!(y_profile_ax, y_prof_ideal, color = :grey, visible = fit_toggle.active)
    lines!(x_profile_ax, x_prof_ideal, color = :grey, visible = fit_toggle.active)

    # these tasks run every frame and would not update automatically otherwise.
    # they update the observables that the functions above rely on.
    @async begin
        while camera.is_running == 1
            frame = getlastframe(camera)
            # if the camera is on, update observables and titles
            if frame !== nothing
                frame_obs[] = frame
                duration = round(time() - start, digits = 2)
                ax2d.title = "Live Camera Feed - Time: $duration seconds"

                approx_r2_label.text = "Approximate Fit R^2: $(round(coeff_of_determination(ideal_z[], frame_obs[]), digits = 4))"
                optim_r2_label.text = "Optimized Fit R^2: $(optimized_toggle.active[] ? r_squared[] : "N/A")"
                cx[], cy[], xs, ys = find_center(frame)
                C[], ω[] = set_constants(frame, cx[], cy[], xs, ys; frac = 0.05)
                y_prof[] = frame[:, round(Int, cy[])]
                x_prof[] = frame[round(Int, cx[]), :]
                y_prof_ideal[] = ideal_z[][:, round(Int, cy[])]
                x_prof_ideal[] = ideal_z[][round(Int, cx[]), :]
                x_ext[], y_ext[] = extinction_ratio(frame, cx[], cy[], xs, ys)
                y_ext_label.text = "Y Extinction Ratio: $(round(y_ext[], digits = 4))"
                x_ext_label.text = "X Extinction Ratio: $(round(x_ext[], digits = 4))"
            end
            sleep(1/framerate)
        end
    end
    return fig, ax2d, ax3d, frame_obs
end

# pass clean up functions, such as shutdown(camera)
function window_closer(fig, cleanups...)
    on(events(fig).window_open) do is_open
        if !is_open
            println("Window closed - running cleanup...")
            for cleanup in cleanups
                try
                    cleanup()
                catch e
                    println("Error during cleanup: $e")
                end
            end
            println("Cleanup complete!")
        end
    end
end

# find the center of the donut by averaging the coordinates of the bright ring
function find_center(frame; frac=0.05) # frac is fraction of brightest pixels to average
    thresh = quantile(vec(frame), 1 - frac)  # gives the fraction of pixels that are above the threshold
    coords = findall(>=(thresh), frame) # gives a vector of the coordinates that corrospond to above threshold
    xs = []; ys = []
    for coord in coords # create individual vectors for x and y
        push!(xs, coord[1])
        push!(ys, coord[2])
    end
    center_x = median(xs)
    center_y = median(ys)
    return center_x, center_y, xs, ys
end

# Set constants C and ω
function set_constants(frame, cx, cy, xs, ys; frac = 0.05)
    # C is related to the highest intensity, ω is the beam width
    # To find the first constant C average the intensity of the brightest pixels
    thresh = quantile(vec(frame), 1 - frac)
    coords = findall(>=(thresh), frame)
    bright_sum = 0
    for coord in coords
        bright_sum += frame[coord[1], coord[2]]
    end
    avg_high_intensity = bright_sum / length(coords) * 11

    # Set omega equal to the average distance between the center point and the bright ring
    dist_sum = ring_radius(xs, ys, cx, cy)
    beam_radius = dist_sum / length(xs) * 0.85 # constant that seems to work

    return avg_high_intensity, beam_radius
end

function ring_radius(xs, ys, cx, cy)
    dist_sum = 0
    for i in eachindex(xs)
        dist_sum += sqrt((xs[i] - cx)^2 + (ys[i] - cy)^2)
    end
    return dist_sum
end

function extinction_ratio(frame, cx, cy, xs, ys; frac = 0.05)
    thresh = quantile(vec(frame), 1 - frac)
    int_cx = round(Int, cx)
    int_cy = round(Int, cy)
    x_prof = frame[int_cx, :]
    y_prof = frame[:, int_cy]

    r = round(Int, ring_radius(xs, ys, cx, cy))
    x_bg_sum = 0
    x_center_sum = 0
    y_bg_sum = 0
    y_center_sum = 0
    tot_hole_x = 0
    tot_hole_y = 0

    for i in eachindex(x_prof)
        if abs(i - int_cx) > r && x_prof[i] < thresh
            x_bg_sum += x_prof[i]
        elseif x_prof[i] < thresh
            x_center_sum += x_prof[i]
            tot_hole_x += 1
        end
    end
    for j in eachindex(y_prof)
        if abs(j - int_cy) > r && y_prof[j] < thresh
            y_bg_sum += y_prof[j]
        elseif y_prof[j] < thresh
            y_center_sum += y_prof[j]
            tot_hole_y += 1
        end
    end

    x_bg_avg = x_bg_sum / (length(x_prof) - 2 * r)
    y_bg_avg = y_bg_sum / (length(y_prof) - 2 * r)
    x_center_avg = x_center_sum / tot_hole_x
    y_center_avg = y_center_sum / tot_hole_y

    x_ext = x_center_avg / x_bg_avg
    y_ext = y_center_avg / y_bg_avg

    return x_ext, y_ext
end

# find the baseline or backgroun brightness of the image
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

function square_err(inputs::Vector{Float64}, cx, cy, data, return_ideal::Bool = false)
    C, ω, bg = inputs
    # make coordinate system
    ny, nx = size(data)
    x = collect(1:nx)
    y = collect(1:ny)
    x_grid = repeat(x', ny, 1)  # shape (ny, nx)
    y_grid = repeat(y, 1, nx) 
    r_grid = sqrt.((x_grid .- cy).^2 .+ (y_grid .- cx).^2)
    # make ideal function
    ideal = C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ bg

    if return_ideal
        return ideal, coeff_of_determination(ideal, data)
    end
    return sum(data .- ideal).^2
end

# a more precise characterization Function
# takes about 8 seconds to run
function characterize(data)
    # make initial guesses for the parameters
    # this greatly reduces the time of the optimizer and makes for a better final outcome too

    # NOTE: it was very bad at finding the center of the donut, so we use find_center
    # perhaps it was very bad because there were too many parameters to optimize, regardless
    # these guesses lead to better results and reduced runtime
    guess_cx, guess_cy, xs, ys = find_center(data)
    guess_C, guess_ω = set_constants(data, guess_cx, guess_cy, xs, ys)
    guess_bg = set_baseline(data; frac = 0.05)

    # make a function that depends on data, but does not take it as a parameter
    # so that the optimizer can use it without attempting to optimize the data itself
    func_to_min = inputs -> square_err(inputs, guess_cx, guess_cy, data)

    # optimize the function
    result = optimize(func_to_min, [guess_C, guess_ω, guess_bg])
    println(result)
    C, ω, bg = Optim.minimizer(result)
    ideal, r_squared = square_err([C, ω, bg], guess_cx, guess_cy, data, true)
    return ideal, r_squared
end

camera = ThorcamDCXCamera() # define camera first

beam_characterization(camera)

shutdown(camera)

