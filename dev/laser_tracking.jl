# Created by Abbie Gatsch and Martin Zanazzi, Summer 2025
# This code tracks the mouse on a GLMakie figure and sends voltages to a Triggerscope4 to have laser follow the mouse.
# You can click the figure to enable and disable mouse tracking.
# This serves as a simple example of galvo tracking that will eventually be implemented in the MINFLUX microscope.
# The code also includes a live camera feed from a ThorcamDCX camera.
using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./galvo_calibration.jl")

function live_makie_display(camera::ThorcamDCXCamera)
    live(camera)  # Start capture
    start = time()
    
    # Get initial frame
    initial_frame = getlastframe(camera)'
    if initial_frame === nothing
        @error "Failed to get initial frame"
        return
    end
    
    # Create figure and axis
    fig = Figure(resolution = (1280, 1024))
    ax = Axis(fig[1, 1], title = "Live Camera Feed", aspect = DataAspect(), yreversed = true)
    
    # Create observable for real-time updates
    frame_obs = Observable(initial_frame)
    
    # Create heatmap
    heatmap!(ax, frame_obs, colormap = :cividis)
    
    # Display the figure
    display(fig)

    frame_count = 0
    
    # Update loop
    @async begin
        while camera.is_running == 1
            frame = getlastframe(camera)'
            
            if frame !== nothing
                frame_count += 1
                
                # Update the observable (this triggers plot update)
                frame_obs[] = frame

                duration = round(time() - start, digits = 2)
                # Update title
                ax.title = "Live Camera Feed - Frame: $frame_count, Time: $duration seconds"
            end

            sleep(1e-4)
        end
        println("Captured $frame_count frames in $duration seconds")
    end
    return fig, ax, frame_obs
end


function mouse_tracker(fig, ax, frame_obs, scope::Triggerscope4, covariance_matrix::Matrix{Float64})
    track_mouse = true
    cursor_text = Observable("Mouse: (0, 0)")
    text!(ax, cursor_text, position = (50, 950), fontsize = 16, color = :white)

    on(events(fig).mousebutton) do event
        # toggles the mouse tracking on left click
        if event.button == Mouse.left && event.action == Mouse.press
            track_mouse ? track_mouse = false : track_mouse = true
        end
    end

    on(events(fig).mouseposition) do mp
        plot_pos = mouseposition(ax.scene)
        x, y = round(Int, plot_pos[1]), round(Int, plot_pos[2])

        # Get current frame dimensions
        current_frame = frame_obs[]
        frame_width, frame_height = size(current_frame)
        
        center_x = x - frame_width ÷ 2
        center_y = y - frame_height ÷ 2
        voltages = position_to_voltage([center_x, center_y], covariance_matrix)

        if 1 <= x <= frame_width && 1 <= y <= frame_height
            cursor_text[] = "Mouse: ($x, $y) \n Tracking $(track_mouse ? "enabled" : "disabled" )"
            if track_mouse
                try
                    # Set X and Y position. The numbers 1000 and 701 are scaling factors to convert pixels to volts. 
                    # After changing the hardware you'll need to adjust this value.
                    setdac(scope, 1, voltages[1]) # Set X position
                    setdac(scope, 2, voltages[2]) # Set Y position
                catch e
                    setrange(scope4, 1, PLUSMINUS10)
                    sleep(0.2)
                    setrange(scope4, 2, PLUSMINUS10)
                end
            end
        end
    end
end

function window_close_handler(fig, camera::ThorcamDCXCamera, scope::Triggerscope4)
    on(events(fig).window_open) do is_open
        if !is_open
            println("Window closed - shutting down camera and scope...")
            try
                shutdown(camera)
                println("Camera shutdown complete")
            catch e
                println("Error shutting down camera: $e")
            end
            
            try
                shutdown(scope)
                println("Scope shutdown complete")
            catch e
                println("Error shutting down scope: $e")
            end
        end
    end
end

function laser_mouse_tracking(scope::Triggerscope4, camera::ThorcamDCXCamera, covariance_matrix::Matrix{Float64})
    try # Initialize the camera and scope
        initialize(scope)
        initialize(camera)
        sleep(2)  # Allow time for instruments to initialize
        clearall(scope)
        setrange(scope, 1, PLUSMINUS10)
        setrange(scope, 2, PLUSMINUS10)
        setdac(scope, 1, 0.0)
        setdac(scope, 2, 0.0)
        camera.exposure_time = 6e-5
        scope.compause = 1e-4
    catch e
        @error "Error initializing camera or scope: $e"
        shutdown(scope)
        shutdown(camera)
    end

    # Start live view
    fig, ax, frame_obs = live_makie_display(camera)
    mouse_tracker(fig, ax, frame_obs, scope, covariance_matrix)

    frame_width, frame_height = size(frame_obs[])
    center_x_pos = frame_width ÷ 2
    center_y_pos = frame_height ÷ 2

    # Horizontal and vertical line through center
    vlines!(ax, [center_x_pos], color = :black, linewidth = 1, alpha = 0.7)
    hlines!(ax, [center_y_pos], color = :black, linewidth = 1, alpha = 0.7)

    window_close_handler(fig, camera, scope)

end

# To run:
# Close each camera gui before running the next one.
# camera = ThorcamDCXCamera()
# scope4 = Triggerscope4(compause = 1e-4)
# galvo_calibration_gui(camera, scope4)
# covariance_matrix = calibrate_galvo(camera, scope4; step_size = 0.01)
# laser_mouse_tracking(scope4, camera, covariance_matrix)