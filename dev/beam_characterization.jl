using Revise
using GLMakie, ImageFiltering
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using Statistics

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
    fig = Figure(size = (1200, 500))
    ax2d = Axis(fig[1, 1], title = "Live Camera Feed")
    ax3d = Axis3(fig[1, 2], title = "3D Intensity Map", aspect = (1280, 1024, 750))
    ax3d.limits[] = (nothing, nothing, nothing, nothing, -50, nothing)
    toggle_box = GridLayout(fig[2, 1:2])

    # create toggle
    Label(toggle_box[1, 1], "Fit Curve")
    fit_toggle = Toggle(toggle_box[1, 2], active = true)
    
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
    cx = Observable(0.0) # the x coord of the center
    cy = Observable(0.0) # the y coord of the center 
    ideal_z = Observable(zeros(size(frame_obs[]))) # the ideal intensity function
    r_grid = Observable(zeros(size(frame_obs[]))) # r_grid is a polar representation of the cartesian grid

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

    # draw on figure
    heatmap!(ax2d, frame_obs, colormap = :inferno) # live camera view
    scatter!(ax2d, cx, cy, color=:teal, markersize=10) # center dot
    surface!(ax3d, y, x, frame_obs; colormap = :viridis) # 3d real data
    surface!(ax3d, y, x, ideal_z; colormap = (:greys, 0.6), overdraw = false, visible = fit_toggle.active) # 3d ideal data
    
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
                ax3d.title = "Coefficient of Determination: $(round(coeff_of_determination(ideal_z[], frame_obs[]), digits = 4))"
                cx[], cy[], xs, ys = bright_median(frame)
                C[], ω[] = set_constants(frame, cx[], cy[], xs, ys; frac = 0.05)
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
function bright_median(frame; frac=0.05) # frac is fraction of brightest pixels to average
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
    dist_sum = 0
    for i in eachindex(xs)
        dist_sum += sqrt((xs[i] - cx)^2 + (ys[i] - cy)^2)
    end
    beam_radius = dist_sum / length(xs) * 0.85 # constant that seems to work

    return avg_high_intensity, beam_radius
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


camera = ThorcamDCXCamera() # define camera first
beam_characterization(camera)

