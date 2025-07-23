function create_menu(figure, row, column, options, default)
    menu = Menu(figure[row, column], options=options, default=default, width=350, height=30)
    on(menu.selection) do mode
        camera.capture_mode = mode
    end
    return menu
end

function create_label_textbox(figure, row, placeholder, callback)
    label = Label(figure[row, 1], placeholder)
    textbox = Textbox(figure[row, 2], placeholder=placeholder)
    on(textbox.stored_string) do text
        callback(text)
    end
    return (label, textbox)
end


function create_button(figure, row, column, label, action, camera)
    button = Button(figure[row, column], label=label)
    on(button.clicks) do _
        action(camera)
    end
    return button
end


function create_display(camera, display_function)
    # Setup display
    im_height = camera.roi.height
    im_width = camera.roi.width
    println("Creating display with dimensions: $im_width x $im_height")
    img = Observable(rand(Gray{N0f8}, im_width, im_height))

    imgplot = image(img,
        axis=(aspect=DataAspect(),),
        figure=(figure_padding=0, resolution=(im_width, im_height)), interpolate=false)
    # Create an Observable for the text
    text_data = Observable("Initial Text")
    neon_green = RGB(0.2, 1, 0.2)

    # Add the Observable text to the plot
    text!(imgplot.axis, text_data, position=(im_width / 10, im_height * 9 / 10), color=neon_green, fontsize=50)

    hidedecorations!(imgplot.axis)

    # Display the plot and store the Scene
    scene = display(GLMakie.Screen(), imgplot)

    # Add a listener to the `window_open` Observable
    # on(events(scene).window_open) do is_open
    #     if !is_open
    #         println("The window has been closed!")
    #         # Add your callback logic here
    #     end
    # end

    # Start live imaging or sequence based on display_function
    #@sync begin
        #display_function(camera)
        fps = 60
        display_function(camera)

        @async begin
            while camera.is_running == 1

                framedata = getlastframe(camera)
                max_val = maximum(framedata)
                min_val = minimum(framedata)
                img[] = Gray{N0f8}.(framedata .* (1 / max_val))
                text_data[] = "[$min_val $max_val]"
                sleep(1 / fps)
            end
        end
    #end
end

"""
    gui(camera::Camera)
"""
function gui(camera::Camera)
    println(typeof(camera))

    # Create the figure for the control window
    control_fig = Figure()

    # Dropdown menus for enums
    modes = ["capture", "trigger"]
    for (index, mode) in enumerate(modes)
        options = [(string(m), m) for m in instances(typeof(getfield(camera, Symbol(mode * "_mode"))))]
        create_menu(control_fig, 2, index, options, string(getfield(camera, Symbol(mode * "_mode"))))
    end

    # label, textbox, and callback for each property
    properties = [
        ("Exposure time", string(camera.exposure_time), (text -> camera.exposure_time = parse(Float64, text))),
        ("ROI", string([camera.roi.x_start, camera.roi.y_start, camera.roi.width, camera.roi.height]), (text -> begin
            camera.roi.x_start, camera.roi.y_start, camera.roi.width, camera.roi.height = parse.(Int, split(text, ","))
        end)),
        ("Number of images", string(camera.sequence_length), (text -> camera.sequence_length = parse(Int, text)))
    ]

    for (index, (label, placeholder, callback)) in enumerate(properties)
        create_label_textbox(control_fig, index + 2, placeholder, callback)
    end


    # Buttons and actions
    labels = ["Start Live", "Start Capture", "Start Sequence", "Abort"]
    actions = [start_live, start_capture, start_sequence, abort]
    for (index, (label, action)) in enumerate(zip(labels, actions))
        create_button(control_fig, index + 5, 1, label, action, camera)
    end

    # Display the unique_id string in the window
    if typeof(camera.unique_id) == String
        camera_name = camera.unique_id
    else
        camera_name = "Camera"
    end

    id_label = Label(control_fig[1, 1], "Unique ID: " * camera_name)
    # Display the control figure in a new window
    GLMakie.activate!(title=camera_name)
    display(GLMakie.Screen(), control_fig)
end

function start_live(camera::Camera)
    create_display(camera, live)
end

function start_capture(camera::Camera)
    # Start a capture

    println(typeof(camera))
    framedata = capture(camera)

    # Create an Observable for the text
    max_val = maximum(framedata)
    min_val = minimum(framedata)
    img = Gray{N0f8}.(framedata .* (1 / max_val))

    imgplot = image(rotr90(img),
        axis=(aspect=DataAspect(),),
        figure=(figure_padding=0, resolution=size(img)))

    # Add [min max] text to image
    text_data = "[$min_val $max_val]"
    im_height = camera.roi.height
    im_width = camera.roi.width

    neon_green = RGB(0.2, 1, 0.2)
    text!(imgplot.axis, text_data, position=(im_width / 10, im_height * 9 / 10), color=neon_green, fontsize=50)

    hidedecorations!(imgplot.axis)
    display(GLMakie.Screen(), imgplot)
end

function start_sequence(camera::Camera)
    create_display(camera, sequence)

    # Need something here to wait until sequence is done
    #Threads.@spawn begin
      
      #println("Sequence done")
    # println("get data")
    # data = getdata(camera)
    # #end

    # print(Int.(data[1:10,1:10,10]))


    return nothing
end
