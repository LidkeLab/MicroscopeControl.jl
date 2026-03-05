"""
    gui(light::LightSource)

Create a GUI for the light source.

# Arguments
- `light::LightSource`: A LightSource type.
"""
function gui(light::LightSource)
    println(typeof(light))

    # Create the figure for the control window
    control_fig = Figure(size = (700,300), title = light.unique_id)

    # Buttons and actions    
    # create a slider for the power
    slider = Slider(control_fig[1,1],color_active = :gray,halign = :right,
    range = light.properties.min_power:0.1:light.properties.max_power, 
    startvalue = 0.5,width = 500,linewidth = 30)

    # create a textbox for the power
    textbox = Textbox(control_fig[1,2], placeholder = string(light.properties.power),validator = Float64)
   
    # call back for changing textbox and slider value
    on(textbox.stored_string) do s
        val = parse(Float64, s)
        set_close_to!(slider, val)
        setpower(light, val)
    end

    lift(slider.value) do x        
        textbox.displayed_string = string(x)
        setpower(light, x)
    end    

    # toggle light source on/off
    toggle = Toggle(control_fig[2,1], active = false, halign = :right) 
    Label(control_fig[2,2], lift(x -> x ? "On" : "Off", toggle.active))
    lift(toggle.active) do x
        if x
            light_on(light)
        else
            light_off(light)
        end
    end 
    GLMakie.activate!(title=light.unique_id)
    display(GLMakie.Screen(), control_fig)
        
end