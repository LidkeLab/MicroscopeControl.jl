function create_menu(figure, row, column, options, default, camera::Camera)
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


"""
    run_live_loop(show_frame, camera; fps = 60, stop = Threads.Atomic{Bool}(false)) -> (reader, display_task, stop)

Read frames from `camera` while `camera.is_running == 1` and pass each to `show_frame`. The blocking
`getlastframe` runs on its own thread (`Threads.@spawn`), so a frame wait of up to the camera's timeout does not stall
the thread that renders; a task on the calling thread (`@async`) alone calls `show_frame`, which updates the
Observables (GLMakie Observables are not thread-safe). The two hand frames over through a one-slot channel, so the
reader runs at most one frame ahead of the display. A `nothing` frame (a timeout, a failed read, or a stopped
capture) is skipped and does not end the loop. A frame that `show_frame` throws on is logged and skipped. With one
Julia thread the reader shares it with the display task and the wait blocks both, as before. Setting `stop[]` ends
the reader (at its next frame or timeout); the display task ends when the reader has.
"""
function run_live_loop(show_frame, camera; fps = 60, stop = Threads.Atomic{Bool}(false))
    frames = Channel{Any}(1)
    reader = Threads.@spawn begin
        try
            while camera.is_running == 1 && !stop[]
                framedata = getlastframe(camera)  # Returns (H, W), or nothing
                framedata === nothing || put!(frames, framedata)
                sleep(1 / fps)
            end
        catch e
            e isa InvalidStateException || @error "Camera display: the frame reader stopped on an error" exception = (e, catch_backtrace())
        finally
            close(frames)
        end
    end
    display_task = @async for framedata in frames
        try
            show_frame(framedata)
        catch e
            @error "Camera display: could not show a frame" exception = (e, catch_backtrace())
        end
    end
    return reader, display_task, stop
end

function create_display(camera, display_function; on_close=nothing)
    # Setup display
    # Camera data is (H, W) where data[row, col] = data[y, x]
    # Makie image() maps first dim → x, second dim → y
    # So we need permutedims to get (W, H) and yreversed for top-left origin
    im_height = camera.roi.height
    im_width = camera.roi.width
    println("Creating display with dimensions: $im_width x $im_height")

    # Create observable with (W, H) layout for Makie
    img = Observable(rand(Gray{N0f8}, im_width, im_height))

    imgplot = image(img,
        axis=(aspect=DataAspect(), yreversed=true),
        figure=(figure_padding=0, size=(im_width, im_height)), interpolate=false)
    # Create an Observable for the text
    text_data = Observable("Initial Text")
    neon_green = RGB(0.2, 1, 0.2)

    # Add the Observable text to the plot (position in data coords, adjusted for yreversed)
    text!(imgplot.axis, text_data, position=(im_width / 10, im_height / 10), color=neon_green, fontsize=50)

    hidedecorations!(imgplot.axis)

    # Display the plot and store the Scene
    scene = display(GLMakie.Screen(), imgplot)

    # Stop the frame reader, abort the camera when the display window is closed, and call on_close callback
    stop = Threads.Atomic{Bool}(false)
    on(events(imgplot).window_open) do open
        if !open
            stop[] = true  # the reader ends at its next frame; abort does not wait for it, and is safe during its wait
            abort(camera)
            if on_close !== nothing
                on_close()
            end
        end
    end

    # Start live imaging or sequence based on display_function
    fps = 60
    display_function(camera)

    _, display_task, _ = run_live_loop(camera, fps = fps, stop = stop) do framedata
        max_val = maximum(framedata)
        min_val = minimum(framedata)
        # Permute from (H, W) to (W, H) for Makie display; an all-zero frame scales by 1, not by Inf
        img[] = Gray{N0f8}.(permutedims(framedata) .* (1 / max(max_val, one(max_val))))
        text_data[] = "[$min_val $max_val]"
    end
    return display_task
end

"""
    gui(camera::Camera)
"""
function gui(camera::Camera)
    println(typeof(camera))

    # Create the figure for the control window
    control_fig = Figure(size=(800, 600), title="Camera Control: " * camera.unique_id)

    # Dropdown menus for enums
    modes = ["capture", "trigger"]
    for (index, mode) in enumerate(modes)
        options = [(string(m), m) for m in instances(typeof(getfield(camera, Symbol(mode * "_mode"))))]
        create_menu(control_fig, 2, index, options,
            string(getfield(camera, Symbol(mode * "_mode"))), camera)
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
    id_label = Label(control_fig[1, 1], "Unique ID: " * camera.unique_id)

    # Display the control figure in a new window
    GLMakie.activate!(title=camera.unique_id)
    display(GLMakie.Screen(), control_fig)
end

function start_live(camera::Camera; on_close=nothing)
    create_display(camera, live; on_close=on_close)
end

function start_capture(camera::Camera)
    # Start a capture
    println(typeof(camera))
    framedata = capture(camera)  # Returns (H, W)

    max_val = maximum(framedata)
    min_val = minimum(framedata)
    # Permute from (H, W) to (W, H) for Makie display
    img = Gray{N0f8}.(permutedims(framedata) .* (1 / max_val))

    im_height = camera.roi.height
    im_width = camera.roi.width

    imgplot = image(img,
        axis=(aspect=DataAspect(), yreversed=true),
        figure=(figure_padding=0, size=(im_width, im_height)))

    # Add [min max] text to image (position adjusted for yreversed)
    text_data = "[$min_val $max_val]"
    neon_green = RGB(0.2, 1, 0.2)
    text!(imgplot.axis, text_data, position=(im_width / 10, im_height / 10), color=neon_green, fontsize=50)

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
