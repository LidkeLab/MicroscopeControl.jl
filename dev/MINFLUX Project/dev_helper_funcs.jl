# Abbie Gatsch and Martin Zanazzi, Summer 2025
# These are some farily generic helper functions that can be used for various testing purposes. 
using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamCSC
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using MicroscopeControl.HardwareImplementations.MCLMicroPositioner
using GLMakie
using Statistics

"""
    find_beam_centroid(frame; bg_frac = 0.05, thresh_frac = 0.2)

Intensity-weighted centroid of the beam, returned as `(cx, cy)` where `cx` indexes the
first dimension of `frame` and `cy` the second.

Prefer this over `argmax`-style peak finding (`find_center_gaussian`) for anything that
measures beam *position*:

  * it is sub-pixel — `argmax` is quantized to whole pixels, so small galvo steps produce
    a staircase (or no motion at all) instead of a smooth position-vs-voltage line;
  * it is correct for donut beams — `argmax` lands somewhere on the ring, not at the
    center, and hops around the ring azimuthally as noise changes which pixel wins;
  * it is stable when the beam saturates — a flat-topped/clipped spot gives `argmax` a
    plateau of equal values, and it then returns the first one in column-major order,
    which biases the result toward low row indices and jitters frame to frame.

`bg_frac` sets the background level (that quantile of the frame is subtracted), and
`thresh_frac` discards everything below that fraction of the peak so the sensor-wide
noise floor doesn't drag the centroid toward the middle of the image. Note the centroid
*is* pulled by stray reflections or a second spot in the frame; raise `thresh_frac` if
that is a problem.
"""
function find_beam_centroid(frame; bg_frac = 0.05, thresh_frac = 0.2)
    f = Float64.(frame)
    w = max.(f .- quantile(vec(f), bg_frac), 0.0)
    w = ifelse.(w .>= thresh_frac * maximum(w), w, 0.0)

    total = sum(w)
    if total <= 0            # blank/dark frame — fall back to the peak pixel
        peak = argmax(f)
        return Float64(peak[1]), Float64(peak[2])
    end

    cx = sum(vec(sum(w, dims = 2)) .* (1:size(w, 1))) / total
    cy = sum(vec(sum(w, dims = 1)) .* (1:size(w, 2))) / total
    return cx, cy
end

function live_camera_display(camera; frame_rate::Float64 = 30.0, exposure_time::Real = 10000, gain::Int32 = Int32(1), roi::Union{CameraROI,Nothing} = nothing, window_size::Tuple{Int,Int} = (1400, 1050)) #Exposure time for ThorCam CSC is in microseconds (Int), for DCX it is in seconds (Float)
    # initalize camera
    initialize(camera)

    camera.exposure_time = exposure_time
    camera.frame_rate = frame_rate
    # Default to the full sensor (camera_format is populated by initialize); an explicit roi can still request a smaller region.
    camera.roi = roi === nothing ? CameraROI(0, 0, camera.camera_format.x_pixels, camera.camera_format.y_pixels) : roi
    hasfield(typeof(camera), :gain) && (camera.gain = gain) # DCX camera has no gain field


    live(camera)

    @info "Camera initialized with exposure time: $(camera.exposure_time), frame rate: $(camera.frame_rate) Hz, ROI: $(camera.roi.width)x$(camera.roi.height) pixels" * (hasfield(typeof(camera), :gain) ? ", gain: $(camera.gain / 10) dB" : "")
    println()

    initial_frame = getlastframe(camera)'

    start = time()

    # initalize figure and axis
    fig1 = Figure(size = window_size)
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