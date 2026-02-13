# Camera test script for Gaussian beam profiling
# Based on the live camera approach from beam_characterization.jl

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./dev_helper_funcs.jl")

function camera_test(
    camera;
    framerate::Float64 = 5.0,
    exposure_time::Float64 = 0.01,
)
    # initialize the camera and start live capture
    initialize(camera)
    camera.exposure_time = exposure_time
    live(camera)
    start = time()
    initial_frame = getlastframe(camera)'

    # create figure and layout
    fig = Figure(size = (1000, 750), title = "Camera Test")
    ax2d = Axis(fig[1, 1], title = "2D Intensity Map", aspect = DataAspect())
    ax3d = Axis3(fig[1, 2], title = "3D Intensity Map", aspect = (1280, 1024, 400))

    line_profile_box = GridLayout(fig[2, 1])
    x_profile_ax = Axis(line_profile_box[1, 1], title = "X Profile")
    y_profile_ax = Axis(line_profile_box[2, 1], title = "Y Profile")

    colsize!(fig.layout, 1, Relative(0.5))
    colsize!(fig.layout, 2, Relative(0.5))
    rowsize!(fig.layout, 1, Relative(0.5))
    rowsize!(fig.layout, 2, Relative(0.5))

    # create frame observable
    frame_obs = Observable(initial_frame)
    nx, ny = size(initial_frame)
    x = collect(1:nx)
    y = collect(1:ny)

    # center position observables
    cx = Observable(nx ÷ 2)
    cy = Observable(ny ÷ 2)
    x_prof = Observable(zeros(nx))
    y_prof = Observable(zeros(ny))

    # draw on figure
    heatmap!(ax2d, frame_obs, colormap = :inferno)
    scatter!(ax2d, cx, cy, color = :teal, markersize = 10)
    surface!(ax3d, x, y, frame_obs; colormap = :viridis)
    lines!(x_profile_ax, x_prof, color = :blue)
    lines!(y_profile_ax, y_prof, color = :red)

    # display and setup window close handler
    display(fig)
    window_closer(fig, () -> shutdown(camera))

    # async update loop
    @async begin
        while Bool(camera.is_running) == 1
            frame = getlastframe(camera)'
            if frame !== nothing
                frame_obs[] = frame
                duration = round(time() - start, digits = 2)
                ax2d.title = "Live Camera Feed - Time: $duration seconds"

                # find brightest pixel as center estimate
                peak_idx = argmax(frame)
                cx[] = peak_idx[1]
                cy[] = peak_idx[2]

                # update line profiles through the peak
                x_prof[] = frame[:, cy[]]
                y_prof[] = frame[cx[], :]
            end
            sleep(1 / framerate)
        end
    end
    return fig, ax2d, ax3d, frame_obs
end

# To run:
# camera = ThorcamDCXCamera()
# camera_test(camera)
