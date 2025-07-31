# Abbie Gatsch and Martin Zanazzi, Summer 2025
# These are some farily generic helper functions that can be used for various testing purposes. 
using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamCSC
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using MicroscopeControl.HardwareImplementations.MCLMicroPositioner
using GLMakie

function live_camera_display(camera; frame_rate::Float64 = 30.0, exposure_time::Int64 = 10000, gain::Int32 = Int32(1), roi::CameraROI = CameraROI(0, 0, 1440, 1080)) #Exposure time for ThorCam CSC is in microseconds (Int), for DCX it is in seconds (Float)
    # initalize camera
    initialize(camera)    

    camera.exposure_time = exposure_time
    camera.frame_rate = frame_rate
    camera.roi = roi
    camera.gain = gain


    live(camera)

    @info "Camera initialized with exposure time: $(getexposuretime(camera)[1]) μs, frame rate: $(getframerate(camera)[1]) Hz, ROI: $(getroisize(camera)) pixels, gain: $(getgain(camera)[1] / 10) dB "
    println()

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

function make_objective_gui!(positioner, fig::Figure)
    try
        initialize(positioner)
    catch
        @error "Failed to initialize the positioner. Please check the connection."
        return
    end

    obj_box = GridLayout(fig[1, 2], tellwidth=true, tellheight=false)

    targ_pos = Observable(0.0)
    real_pos = Observable(0.0)
    is_moving = Observable{Bool}(false)

    Label(obj_box[1, 1], "Objective controls!", font=:bold, fontsize=20)

    current_pos_str = lift(real_pos) do real_pos
        "Current Position: $real_pos"
    end
    current_pos_label = Label(obj_box[2, 1], current_pos_str)

    targ_pos_str = lift(targ_pos) do targ_pos
        "Target Position: $targ_pos"
    end
    targ_pos_label = Label(obj_box[3, 1], targ_pos_str)

    set_targ_label = Label(obj_box[4, 1], "Amount to move (mm)")
    targ_tb = Textbox(obj_box[4, 2], placeholder = string(0), validator = Float64)

    on(targ_tb.stored_string) do target_change
        if !positioner.connectionstatus
            @error "Stage is not connected!"
            return
        end

        x = parse(Float64, target_change)
        val = targ_pos[]
        targ_pos[] = val + x

        @async begin 
            move(positioner, x)
        end
    end
    
    # Reset positioner
    reset_button = Button(obj_box[5, 1], label="reset")
    on(reset_button.clicks) do mb
        if !positioner.connectionstatus
            @error "Stage is not connected!"
            return
        end
        targ_pos[] = 0.0
        home(positioner)
    end

    # Stop motion
    stop_button = Button(obj_box[5, 2], label="STOP MOTION")
    on(stop_button.clicks) do mb
        if !positioner.connectionstatus
            @error "Stage is not connected!"
            return
        end
        stopmotion(positioner)
    end

    on(events(fig).tick) do tick
        if positioner.connectionstatus
            # Update the real position observable
            real_pos[] = round(MCLMicroPositioner.getposition(positioner), digits=3)
            is_moving[] = positioner.ismoving
        else
            @error "Positioner is not connected!"
        end
    end

    # makes everything fit nicely in the grid
    obj_box[4, 1] = hgrid!(set_targ_label, targ_tb)
    obj_box[5, 1] = hgrid!(reset_button, stop_button)

    return obj_box
end

function zero_galvos(scope::Triggerscope4)
    clearall(scope)
    setrange(scope, 1, PLUSMINUS10)
    setrange(scope, 2, PLUSMINUS10)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
end

# camera = ThorCamCSCCamera()
# setgain(camera, Int32(480))
# live_camera_display(camera)