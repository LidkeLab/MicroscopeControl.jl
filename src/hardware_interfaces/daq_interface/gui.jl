"""
    gui(daq::NIdaq)

Create a GUI for the NIdaq.

# Arguments
- `daq::NIdaq`: A NIdaq type.
"""
function gui(daq::DAQ)
    println(typeof(daq))

    # Create the figure for the control window
    control_fig = Figure(resolution = (900,400))

    # create a dropdown menu for the devices
    devs = showdevices(daq)
    menudev = Menu(control_fig, options = devs, width = 100)
    # create a dropdown menu for the channels
    wd = 150
    channelsAO = showchannels(daq,"AO",devs[1])
    menuAO = Menu(control_fig, options = channelsAO,width=wd)
    channelsAI = showchannels(daq,"AI",devs[1])
    menuAI = Menu(control_fig, options = channelsAI,width=wd)
    channelsDO = showchannels(daq,"DO",devs[1])
    menuDO = Menu(control_fig, options = channelsDO,width=wd)
    channelsDI = showchannels(daq,"DI",devs[1])
    menuDI = Menu(control_fig, options = channelsDI,width=wd)

    control_fig[1,1] = hgrid!(
        Label(control_fig,"Device", width = 100),
        Label(control_fig,"Analog Output", width = wd),
        Label(control_fig,"Analog Input", width = wd),
        Label(control_fig,"Digital Output", width = wd),
        Label(control_fig,"Digital Input", width = wd)
    )
    control_fig[2,1] = hgrid!(menudev,menuAO,menuAI,menuDO,menuDI)

    on(menudev.selection) do s
        menuAO.options = showchannels(daq,"AO",s)
        menuAI.options = showchannels(daq,"AI",s)
        menuDO.options = showchannels(daq,"DO",s)
        menuDI.options = showchannels(daq,"DI",s)
    end

    # create a textbox for set voltage
    tboxAO = Textbox(control_fig, placeholder = string(0),validator = Float64, width = wd)
    tboxAI = Textbox(control_fig, placeholder = string(0),validator = Float64, width = wd)
    tboxDO = Textbox(control_fig, placeholder = string(0),validator = Float64, width = wd)
    tboxDI = Textbox(control_fig, placeholder = string(0),validator = Float64, width = wd)
    buttonAI = Button(control_fig, label="Read", width = wd)
    buttonDI = Button(control_fig, label="Read", width = wd)
    control_fig[3,1] = hgrid!(Label(control_fig,"set/read voltage", width = 100),
        tboxAO,tboxAI,tboxDO,tboxDI)
    
    control_fig[4,1] = hgrid!(Label(control_fig,"", width = 100),Label(control_fig,"", width = wd),buttonAI,Label(control_fig,"", width = wd),buttonDI)
    on(tboxAO.stored_string) do s
        val = parse(Float64, s)
        t = createtask(daq,"AO",menuAO.selection[])
        setvoltage(daq,t,val)
        deletetask(daq,t)
    end

    on(tboxDO.stored_string) do s
        val = parse(Float64, s)
        t = createtask(daq,"DO",menuDO.selection[])
        setvoltage(daq,t,val)
        deletetask(daq,t)
    end

    on(buttonAI.clicks) do s
        t = createtask(daq,"AI",menuAI.selection[])
        val = readvoltage(daq,t)
        tboxAI.displayed_string = string(val[1])
        deletetask(daq,t)
    end

    on(buttonDI.clicks) do s
        t = createtask(daq,"DI",menuDI.selection[])
        val = readvoltage(daq,t)
        tboxDI.displayed_string = string(val[1])
        deletetask(daq,t)
    end

    GLMakie.activate!(title=daq.unique_id)
    display(GLMakie.Screen(), control_fig)
end