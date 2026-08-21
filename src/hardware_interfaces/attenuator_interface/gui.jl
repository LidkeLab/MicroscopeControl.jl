"""
    gui(attenuator::Attenuator)

Create a GUI for the attenuator.

# Arguments
- `attenuator::Attenuator`: An Attenuator type.
"""
function gui(attenuator::Attenuator)
    println(typeof(attenuator))

    # Create the figure for the control window
    control_fig = Figure(size = (700, 200), title = attenuator.unique_id)

    # create a slider for the drive voltage
    Label(control_fig[1, 1], "Drive voltage (V)", halign = :left)
    slider = Slider(control_fig[1, 2], color_active = :gray, halign = :right,
        range = attenuator.properties.min_voltage:0.01:attenuator.properties.max_voltage,
        startvalue = attenuator.properties.drive_voltage, width = 400, linewidth = 30)

    # create a textbox for the drive voltage
    textbox = Textbox(control_fig[1, 3],
        placeholder = string(attenuator.properties.drive_voltage), validator = Float64)

    # call back for changing textbox and slider value
    on(textbox.stored_string) do s
        set_close_to!(slider, parse(Float64, s))
    end

    on(slider.value) do x
        textbox.displayed_string = string(x)
        setdrivevoltage(attenuator, Float64(x))
    end

    GLMakie.activate!(title = attenuator.unique_id)
    display(GLMakie.Screen(), control_fig)

end
