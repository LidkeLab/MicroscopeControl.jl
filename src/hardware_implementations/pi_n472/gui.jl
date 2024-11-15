function gui(stage::N472)
    gui_fig = Figure(resolution=(600, 400))  #This is the Stage GUI Figure

    # create buttons to control individual axis
    gui_fig[2,1] = buttongrid1 = GridLayout(3,3,halign=:left)
    ax1_text = Label(buttongrid1[1,1],"Axis 1",width = 50)
    ax1_up = Button(buttongrid1[1,2],label="^",width = 50)
    ax1_down = Button(buttongrid1[1,3],label="v",width = 50)
    ax2_text = Label(buttongrid1[2,1],"Axis 2",width = 50)
    ax2_up = Button(buttongrid1[2,2],label="^",width = 50)
    ax2_down = Button(buttongrid1[2,3],label="v",width = 50)
    ax3_text = Label(buttongrid1[3,1],"Axis 3",width = 50)
    ax3_up = Button(buttongrid1[3,2],label="^",width = 50)
    ax3_down = Button(buttongrid1[3,3],label="v",width = 50)
    colsize!(gui_fig.layout,1,Relative(1.5/3))

    # create buttons to control all axis
    all_up = Button(gui_fig,label="^",width = 150, height = 50)
    all_down = Button(gui_fig,label="v",width = 150,height = 50)
    gui_fig[2,2] = vgrid!(Label(gui_fig,"All axes",width = 60),
                            all_up,
                            all_down,halign=:left)

    

    # display current position
    pos = Observable([0.0,0.0,0.0])
    pos[] = round.(stage.pos.*1e3,digits=3)
    curpos_string = @lift begin
        return "Current Position (μm): $(string($pos))"
    end
    curpos_label = Label(gui_fig[1,1],curpos_string,width = 400,halign=:left)
    
    # define step size
    stepsize_tbox = Textbox(gui_fig,placeholder="1.0",width = 100,height = 35,validator=Float64)
    gui_fig[3,1] = hgrid!(Label(gui_fig,"Step size (μm):",width = 100),
                            stepsize_tbox,halign=:left)
    


    # define the callback functions
    on(ax1_up.clicks) do s
        stage.pos[1] += parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(ax1_down.clicks) do s
        stage.pos[1] -= parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(ax2_up.clicks) do s
        stage.pos[2] += parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(ax2_down.clicks) do s
        stage.pos[2] -= parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(ax3_up.clicks) do s
        stage.pos[3] += parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(ax3_down.clicks) do s
        stage.pos[3] -= parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(all_up.clicks) do s
        stage.pos .+= parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end

    on(all_down.clicks) do s
        stage.pos .-= parse(Float64,stepsize_tbox.stored_string[])/1e3
        move(stage,stage.pos)
        pos[] = round.(stage.pos.*1e3,digits=3)
    end
    
    GLMakie.activate!(title=stage.stagelabel)
    display(GLMakie.Screen(), gui_fig)
end