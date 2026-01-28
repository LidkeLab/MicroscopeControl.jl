using GLMakie

function gui(positioner::Zpositioner)
    try
        initialize(positioner)
    catch
        @error "Failed to initialize the positioner. Please check the connection."
        return
    end

    fig = Figure(resolution=(600, 400))
    
    # Set position observables
    targ_pos = Observable(0.0)
    real_pos = Observable(0.0)
    is_moving = Observable{Bool}(false)

    # update obervable strings
    current_pos_str = lift(real_pos) do real_pos
        "Current Position: $real_pos"
    end
    current_pos_label = Label(fig, current_pos_str)

    targ_pos_str = lift(targ_pos) do targ_pos
        "Current Target Position: $targ_pos"
    end
    targ_pos_label = Label(fig, targ_pos_str)

    # is_moving_str = lift(is_moving) do is_moving
    #     is_moving ? "Positioner IS MOVING" : "Positioner at rest"
    # end
    # is_moving_label = Label(fig, is_moving_str)

    # Move the positioner
    set_targ_label = Label(fig, "Amount to move positioner (mm)")
    targ_tb = Textbox(fig, placeholder = string(0), validator = Float64)

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

    # get position

    # Reset positioner
    reset_button = Button(fig, label="reset")
    on(reset_button.clicks) do mb
        if !positioner.connectionstatus
            @error "Stage is not connected!"
            return
        end
        targ_pos[] = 0.0
        reset(positioner)
    end

    # Stop motion
    stop_button = Button(fig, label="STOP MOTION")
    on(stop_button.clicks) do mb
        if !positioner.connectionstatus
            @error "Stage is not connected!"
            return
        end
        stop_motion(positioner)
    end

    # Place Everything on screen
    fig[1,1] = hgrid!(current_pos_label, targ_pos_label)
    fig[2,1] = hgrid!(set_targ_label, targ_tb)
    fig[3,1] = hgrid!(reset_button, stop_button)

    # closing the window, shutting down the positioner
    on(events(fig).window_open) do is_open
        if !is_open
            try
                shutdown(positioner)
            catch e
                @error "Error shutting down positioner: $e"
            end
        end
    end

    on(events(fig).tick) do tick
        if positioner.connectionstatus
            # Update the real position observable
            real_pos[] = round(get_position(positioner), digits=3)
            # is_moving[] = positioner.ismoving
        else
            @error "Positioner is not connected!"
        end
    end

    # Show!
    GLMakie.activate!(title="Objective Positioner GUI")
    display(GLMakie.Screen(), fig)
end