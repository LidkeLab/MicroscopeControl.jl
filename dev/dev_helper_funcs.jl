# Abbie Gatsch and Martin Zanazzi, Summer 2025
# These are some farily generic helper functions that can be used for various testing purposes. 
using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamCSC
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie

function live_camera_display(camera; frame_rate::Float64 = 30.0, exposure_time = 10000) #Exposure time for ThorCam CSC is in microseconds (Int), for DCX it is in seconds (Float)
    # initalize camera
    initialize(camera)    
    camera.exposure_time = exposure_time
    live(camera)
    initial_frame = getlastframe(camera)'
    start = time()

    # initalize figure and axis
    fig1 = Figure(size = (1000, 750))
    ax = Axis(fig1[1, 1], title = "Live Camera Feed"; aspect = DataAspect(), yreversed = true)

    # Create observables for the frame, duration, and center coordinates
    frame_obs = Observable(initial_frame)
    duration = Observable(0.0)

    # Create heatmap for camera view and scatter for center point
    heatmap!(ax, frame_obs, colormap = :inferno)

    # Create separate window and call window_closer to shutdown scope and camera on close
    display(GLMakie.Screen(), fig1)
    window_closer(fig1, () -> shutdown(camera))

    # Async loop to update observables with live camera feed
    @async begin 
        while Bool(camera.is_running) == 1
            frame = getlastframe(camera)'
            if frame !== nothing
                frame_obs[] = frame
                duration[] = round(time() - start, digits = 2)
                ax.title = "Live Camera Feed - Time: $(duration[]) seconds"
            end
            sleep(1 / frame_rate)
        end
    end
    return fig1, ax, frame_obs
end

# pass clean up functions, such as shutdown(camera)
function window_closer(fig, cleanups...)
    on(events(fig).window_open) do is_open
        if !is_open
            @info "Window closed - running cleanup..."
            for cleanup in cleanups
                try
                    cleanup()
                catch e
                    @error "Error during cleanup: $e"
                end
            end
            @info "Cleanup complete!"
        end
    end
end

# camera = ThorCamCSCCamera()
# setgain(camera, Int32(480))
# live_camera_display(camera)
# shutdown(camera)