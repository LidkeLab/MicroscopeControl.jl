using Revise
using GLMakie, ImageFiltering
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using Statistics
function live_view_3d(
    camera::ThorcamDCXCamera, 
    framerate::Float64 = 15.0, 
    exposure_time::Float64 = 0.01,
)
    initialize(camera)
    camera.exposure_time = exposure_time
    live(camera)
    start = time()
    initial_frame = getlastframe(camera)
    fig = Figure(resolution = (1200, 500))
    ax2d = Axis(fig[1, 1], title = "Live Camera Feed")
    ax3d = Axis3(fig[1, 2], title = "3D Intensity Map")
    
    frame_obs = Observable(initial_frame)
    heatmap!(ax2d, frame_obs, colormap = :inferno)

    nx, ny = size(initial_frame)
    x = 1:nx
    y = 1:ny

    # for mathematical ideal overlay
    C = Observable(1.0)
    ω = Observable(1.0)
    rs = 1:10
    theatas = 0:360
    ideal_x = rs .* cosd.(theatas')
    ideal_y = rs .* sind.(theatas')
    ideal_z = C*exp((-2(rs^2))/ω)*((r/ω)^4)

    surface!(ax3d, x, y, frame_obs; colormap = :viridis)
    surface!(ax3d, ideal_x, ideal_y, ideal_z; colormap = (:greyC10, 0.2), overdraw = false)

    display(fig)
    window_closer(fig, () -> shutdown(camera))
    cx = Observable(0.0)
    cy = Observable(0.0)
    @async begin
        while camera.is_running == 1
            frame = getlastframe(camera)
            
            if frame !== nothing
                frame_obs[] = frame
                duration = round(time() - start, digits = 2)
                ax2d.title = "Live Camera Feed - Time: $duration seconds"
                cx[], cy[] = bright_median(frame)
                scatter!(ax2d, cx, cy, color=:teal, markersize=10)
            end
            sleep(1/framerate)
        end
    end
    return fig, ax2d, ax3d, frame_obs
end

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

function bright_median(frame; frac=0.05)
    thresh = quantile(vec(frame), 1 - frac)  # threshold for top fraction of pixels
    inds = findall(>=(thresh), frame)
    xs = []; ys = []
    for index in inds
        push!(xs, index[1])
        push!(ys, index[2])
    end
    center_x = median(xs)
    center_y = median(ys)
    return center_x, center_y
end

function set_constants(frame; frac = 0.05)
    # C is related to the highest intensity, ω is the beam width
    # To find the first constant C average the intensity of the brightest pixels
    thresh = quantile(vec(frame), 1 - frac)
    inds = findall(>=(thresh), frame)
    sum = 0
    for index in inds
        sum += frame[index[1]][index[2]]
    end
    average_high_intensity = sum/length(inds)
end

camera = ThorcamDCXCamera()
live_view_3d(camera)
shutdown(camera)