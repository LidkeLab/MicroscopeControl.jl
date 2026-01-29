"""
    # Arguments
    - `stage::Stage`: The stage for which the GUI is to be created. The stage must have a `dimensions` field that indicates the number of dimensions it operates in (1, 2, or 3).

    # Returns
    - The function returns the created GUI. The specific type of the GUI depends on the dimensions of the stage.

    # Errors
    - If the stage's dimensions are not 1, 2, or 3, an error is thrown.

    # Description
     - Function to create GUI for general stage format:
        - Target Position Textbox
        - X and Y Axis Control Arrows (right now implemented for 2D only, but should be extended to support 1 and 3 axis stages)
        - Query Position Button
        - Buttons to turn stage on and off
        - Stop Motion Button
        - Display for current position (can be text for now)
    
        - Servo Control Button (if servo is present)
        - Drift Correction Control Button (if drift correction is present)
"""
function gui(stage::Stage)
    #This funcion will create a GUI for the stage, calling the correct GUI function based on the stage dimensions
    if stage.dimensions == 1
        return gui1d(stage)
    elseif stage.dimensions == 2
        return gui2d(stage)
    elseif stage.dimensions == 3
        return gui3d(stage)
    else
        @error "Stage dimension not supported"
    end
end

function gui1d(stage::Stage)
    #First we will create a figure to hold the GUI elements
    stage_gui_fig = Figure(size=(600, 400))  #This is the Stage GUI Figure

    #Set up variables for motion that will be changed
    xstepsize = Observable(0.1)

    xposition = Observable(0.0)

    xtarget = Observable(0.0)

    #Creating observables for the labels of the target, current position, servo and drift correction status
    targetstring = @lift begin
        #Target string lifted from xtarget and ytarget
        xtargstring = string(round($xtarget, digits=4))
        return "( " * xtargstring * " )"
    end
    positionstring = @lift begin
        xposstring = string(round($xposition, digits=4))
        return "Current Position: ( " * xposstring * " )"
    end

    #Create the fields for entering the x position
    Label(stage_gui_fig[1, 1], "Target Position")
    targettb = Textbox(stage_gui_fig[1, 2], placeholder="Enter X", width=220)

    #Callback function to change the target position
    on(targettb.stored_string) do target_change
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        x = parse(Float64, target_change)

        if x < stage.range_x[1] || x > stage.range_x[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x = x
        xtarget[] = x

        move(stage, stage.targ_x)
    end

    Label(stage_gui_fig[1, 3], targetstring)

    #Using range, create arrow buttons for x with adjustable step size
    Label(stage_gui_fig[2, 1], "X Axis Control")
    stage_gui_fig[2, 2] = x_arrow_grid = GridLayout(1, 3)

    xbuttonlabels = ["<----", "Home", "---->"]

    x_arrow_buttons = x_arrow_grid[1, 1:3] = [Button(stage_gui_fig, label=xbuttonlabels[i], width=100) for i in 1:3]

    xsteptb = Textbox(stage_gui_fig[2, 3], placeholder="0.1", validator=Float64)

    #Callback functions to change the step size using the text boxes
    on(xsteptb.stored_string) do xstep_change
        xstepsize[] = parse(Float64, xstep_change)
    end

    #Define the callback functions for the arrow buttons
    on(x_arrow_buttons[1].clicks) do x_left_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x - xstepsize[] < stage.range_x[1]
            @error "Target position out of range"
            return
        end

        stage.targ_x -= xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x)
    end
    on(x_arrow_buttons[2].clicks) do return_home_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        home(stage)
        xtarget[], ytarget[] = stage.targ_x, stage.targ_y
    end


    on(x_arrow_buttons[3].clicks) do x_right_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x + xstepsize[] > stage.range_x[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x += xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x)
    end

    #Create a button to query current position, initialize, shutdown, or stop motion 
    stage_gui_fig[3:4, 1:3] = control_grid = GridLayout(2, 2)

    control_labels = ["Query Position", "Stop Motion", "Initialize", "Shutdown"]
    control_buttons = control_grid[1:2, 1:2] = [Button(stage_gui_fig, label=control_labels[i], width=150) for i in 1:4]


    on(control_buttons[1].clicks) do query_position_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        getposition(stage)
        xposition[] = stage.real_x
    end
    on(control_buttons[2].clicks) do stop_motion_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        stopmotion(stage)
    end
    on(control_buttons[3].clicks) do initialize_click
        initialize(stage)
        getposition(stage)
        xposition[] = stage.real_x
        xtarget[] = stage.targ_x

    end
    on(control_buttons[4].clicks) do shutdown_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        shutdown(stage)
    end

    Label(stage_gui_fig[4, 1:3], positionstring)

    #Now we check for servo and drift correction fields and build buttons if they are present

    hasservo = hasfield(typeof(stage), :servostatus)
    hasdrift = hasfield(typeof(stage), :driftcorrectionstatus)

    if hasservo
        servostatus = Observable(stage.servostatus)

        servostring = @lift begin
            if $servostatus
                return "Servo On"
            else
                return "Servo Off"
            end
        end


        #Create a button to toggle servo status
        Label(stage_gui_fig[5, 1], "Servo Control")
        stage_gui_fig[5, 2] = servo_control_button = Button(stage_gui_fig, label="Toggle Servo", width=200)
        Label(stage_gui_fig[5, 3], servostring)

        on(servo_control_button.clicks) do servo_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if servostatus[]
                servostatus[] = false
                servo(stage, false)
            else
                servostatus[] = true
                servo(stage, true)
            end
        end
    end

    if hasdrift
        driftcorrectionstatus = Observable(stage.driftcorrectionstatus)

        driftstring = @lift begin
            if $driftcorrectionstatus
                return "Drift Correction On"
            else
                return "Drift Correction Off"
            end
        end

        #Create a button to toggle drift correction status
        Label(stage_gui_fig[6, 1], "Drift Correction Control")
        stage_gui_fig[6, 2] = drift_control_button = Button(stage_gui_fig, label="Toggle Drift Correction", width=200)
        Label(stage_gui_fig[6, 3], driftstring)

        on(drift_control_button.clicks) do drift_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if driftcorrectionstatus[]
                driftcorrectionstatus[] = false
                driftcorrection(stage, false)
            else
                driftcorrectionstatus[] = true
                driftcorrection(stage, true)
            end
        end
    end

    GLMakie.activate!(title=stage.stagelabel)
    display(GLMakie.Screen(), stage_gui_fig)
end


function gui2d(stage::Stage)
    #First we will create a figure to hold the GUI elements
    stage_gui_fig = Figure(size=(1200, 600))  #This is the Stage GUI Figure

    #=
    This function should flow as follows

    1. Create the fields for entering the x and y position
    2. Create movement arrow buttons and a home button for the 2D stage
    3. Create a button to query current position now
    4. Create a button to initialize the stage
    5. Create a button to shutdown the stage

    =#

    #Set up variables for motion that will be changed
    xstepsize = Observable(0.1)
    ystepsize = Observable(0.1)

    xposition = Observable(0.0)
    yposition = Observable(0.0)

    xtarget = Observable(0.0)
    ytarget = Observable(0.0)

    #Creating observables for the labels of the target, current position, servo and drift correction status
    targetstring = @lift begin
        #Target string lifted from xtarget and ytarget
        xtargstring = string(round($xtarget, digits=4))
        ytargstring = string(round($ytarget, digits=4))
        return "( " * xtargstring * ", " * ytargstring * " )"
    end
    positionstring = @lift begin
        xposstring = string(round($xposition, digits=4))
        yposstring = string(round($yposition, digits=4))
        return "Current Position: ( " * xposstring * ", " * yposstring * " )"
    end

    #Now we will create the GUI elements for the 2D stage main movement control
    #Create the fields for entering the x and y position
    Label(stage_gui_fig[1, 1], "Target Position")
    targettb = Textbox(stage_gui_fig[1, 2:3], placeholder="Enter (X,Y)", width=200)

    #Callback function to change the target position
    on(targettb.stored_string) do target_change
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        x, y = split(target_change, ",")
        x = parse(Float64, x)
        y = parse(Float64, y)

        if x < stage.range_x[1] || x > stage.range_x[2] || y < stage.range_y[1] || y > stage.range_y[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x, stage.targ_y = x, y
        xtarget[], ytarget[] = x, y

        move(stage, stage.targ_x, stage.targ_y)
    end

    Label(stage_gui_fig[1, 4], targetstring)

    #Now we will create movement arrow buttons and a home button for the 2D stage
    #Using range, create arrow buttons for x and y with adjustable step size
    Label(stage_gui_fig[2, 1], "X Axis Control")
    Label(stage_gui_fig[2, 3], "Y Axis Control")

    xsteptb = Textbox(stage_gui_fig[2, 2], placeholder="0.1", validator=Float64)
    ysteptb = Textbox(stage_gui_fig[2, 4], placeholder="0.1", validator=Float64)

    #Callback functions to change the step size using the text boxes
    on(xsteptb.stored_string) do xstep_change
        xstepsize[] = parse(Float64, xstep_change)
    end

    on(ysteptb.stored_string) do ystep_change
        ystepsize[] = parse(Float64, ystep_change)
    end

    stage_gui_fig[3:5, 1:4] = arrow_grid = GridLayout(3, 3)

    xbuttonlabels = ["<", ">"]
    ybuttonlabels = ["^", "v"]
    homebuttonlabel = "Home"

    #Create the arrow buttons using [1,2] for up, [2,1] for left, [2,3] for right, [3,2] for down, and [2,2] for home
    x_left = Button(arrow_grid[2, 1], label=xbuttonlabels[1], width=100)
    x_right = Button(arrow_grid[2, 3], label=xbuttonlabels[2], width=100)
    y_up = Button(arrow_grid[1, 2], label=ybuttonlabels[1], width=100)
    y_down = Button(arrow_grid[3, 2], label=ybuttonlabels[2], width=100)
    homebutton = Button(arrow_grid[2, 2], label=homebuttonlabel, width=100)

    #Define the callback functions for the arrow buttons
    on(x_left.clicks) do x_left_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x - xstepsize[] < stage.range_x[1]
            @error "Target position out of range"
            return
        end

        stage.targ_x -= xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x, stage.targ_y)
    end
    on(x_right.clicks) do x_right_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x + xstepsize[] > stage.range_x[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x += xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x, stage.targ_y)
    end

    on(y_down.clicks) do y_down_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_y - ystepsize[] < stage.range_y[1]
            @error "Target position out of range"
            return
        end

        stage.targ_y -= ystepsize[]
        ytarget[] = stage.targ_y
        move(stage, stage.targ_x, stage.targ_y)
    end

    on(y_up.clicks) do y_right_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_y + ystepsize[] > stage.range_y[2]
            @error "Target position out of range"
            return
        end

        stage.targ_y += ystepsize[]
        ytarget[] = stage.targ_y
        move(stage, stage.targ_x, stage.targ_y)
    end

    on(homebutton.clicks) do return_home_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        home(stage)
        xtarget[], ytarget[] = stage.targ_x, stage.targ_y
    end

    #Create a button to query current position, initialize, shutdown, or stop motion 
    stage_gui_fig[6:7, 1:4] = control_grid = GridLayout(2, 2)

    control_labels = ["Query Position", "Stop Motion", "Initialize", "Shutdown"]
    control_buttons = control_grid[1:2, 1:2] = [Button(stage_gui_fig, label=control_labels[i], width=150) for i in 1:4]


    on(control_buttons[1].clicks) do query_position_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        getposition(stage)
        xposition[] = stage.real_x
        yposition[] = stage.real_y
    end
    on(control_buttons[2].clicks) do stop_motion_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        stopmotion(stage)
    end
    on(control_buttons[3].clicks) do initialize_click
        initialize(stage)
        getposition(stage)
        xposition[], yposition[] = stage.real_x, stage.real_y
        xtarget[], ytarget[] = stage.targ_x, stage.targ_y

    end
    on(control_buttons[4].clicks) do shutdown_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        shutdown(stage)
    end


    #Create a display to show current Position
    axis = Axis(stage_gui_fig[1:8, 5], xlabel="X", ylabel="Y", title="Stage Position", limits=(stage.range_x[1], stage.range_x[2], stage.range_y[1], stage.range_y[2]), aspect=DataAspect())
    Label(stage_gui_fig[8, 1:4], positionstring)

    scatter!(axis, xposition, yposition, markersize=20, color=:red)

    #Now we check for servo and drift correction fields and build buttons if they are present

    hasservo = hasfield(typeof(stage), :servostatus)
    hasdrift = hasfield(typeof(stage), :driftcorrectionstatus)

    if hasservo    #If field servostatus is present, create a button to toggle servo status
        servostatus = Observable(stage.servostatus[1] && stage.servostatus[2])

        servostring = @lift begin
            if $servostatus
                return "Servo On"
            else
                return "Servo Off"
            end
        end


        #Create a button to toggle servo status
        Label(stage_gui_fig[9, 1], "Servo Control")
        stage_gui_fig[9, 2:3] = servo_control_button = Button(stage_gui_fig, label="Toggle Servo", width=200)
        Label(stage_gui_fig[9, 4], servostring)

        on(servo_control_button.clicks) do servo_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if servostatus[]
                servostatus[] = false
                servo(stage, false, false)
            else
                servostatus[] = true
                servo(stage, true, true)
            end
        end
    end

    if hasdrift    #If field driftcorrectionstatus is present, create a button to toggle drift correction status
        driftcorrectionstatus = Observable(stage.driftcorrectionstatus[1] && stage.driftcorrectionstatus[2])

        driftstring = @lift begin
            if $driftcorrectionstatus
                return "Drift Correction On"
            else
                return "Drift Correction Off"
            end
        end

        #Create a button to toggle drift correction status
        Label(stage_gui_fig[10, 1], "Drift Correction Control")
        stage_gui_fig[10, 2:3] = drift_control_button = Button(stage_gui_fig, label="Toggle Drift Correction", width=200)
        Label(stage_gui_fig[10, 4], driftstring)

        on(drift_control_button.clicks) do drift_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if driftcorrectionstatus[]
                driftcorrectionstatus[] = false
                driftcorrection(stage, false, false)
            else
                driftcorrectionstatus[] = true
                driftcorrection(stage, true, true)
            end
        end
    end

    GLMakie.activate!(title=stage.stagelabel)
    display(GLMakie.Screen(), stage_gui_fig)
end


function gui3d(stage::Stage)

    #First we will create a figure to hold the GUI elements
    stage_gui_fig = Figure(size=(1200, 600))  #This is the Stage GUI Figure

    #Set up variables for motion that will be changed
    xstepsize = Observable(0.1)
    ystepsize = Observable(0.1)
    zstepsize = Observable(0.1)

    xposition = Observable(0.0)
    yposition = Observable(0.0)
    zposition = Observable(0.0)

    xtarget = Observable(0.0)
    ytarget = Observable(0.0)
    ztarget = Observable(0.0)

    #Creating observables for the labels of the target, current position, servo and drift correction status
    targetstring = @lift begin
        #Target string lifted from xtarget and ytarget
        xtargstring = string(round($xtarget, digits=4))
        ytargstring = string(round($ytarget, digits=4))
        ztargstring = string(round($ztarget, digits=4))
        return "( " * xtargstring * ", " * ytargstring * ", " * ztargstring * " )"
    end
    positionstring = @lift begin
        xposstring = string(round($xposition, digits=4))
        yposstring = string(round($yposition, digits=4))
        zposstring = string(round($zposition, digits=4))
        return "Current Position: ( " * xposstring * ", " * yposstring * ", " * zposstring * " )"
    end

    #Now we will create the GUI elements for the 2D stage main movement control
    #Create the fields for entering the x and y position
    Label(stage_gui_fig[1, 1], "Target Position")
    targettb = Textbox(stage_gui_fig[1, 2:3], placeholder="Enter (X,Y,Z)", width=200)

    #Callback function to change the target position
    on(targettb.stored_string) do target_change
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        x, y, z = split(target_change, ",")
        x = parse(Float64, x)
        y = parse(Float64, y)
        z = parse(Float64, z)

        if x < stage.range_x[1] || x > stage.range_x[2] || y < stage.range_y[1] || y > stage.range_y[2] || z < stage.range_z[1] || z > stage.range_z[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x, stage.targ_y, stage.targ_z = x, y, z
        xtarget[], ytarget[], ztarget[] = x, y, z

        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    Label(stage_gui_fig[1, 4], targetstring)

    #Now we will create movement arrow buttons and a home button for the 2D stage
    #Using range, create arrow buttons for x and y with adjustable step size
    Label(stage_gui_fig[2, 1], "X Axis Control")
    Label(stage_gui_fig[2, 3], "Y Axis Control")
    Label(stage_gui_fig[2, 5], "Z Axis Control")

    xsteptb = Textbox(stage_gui_fig[2, 2], placeholder="0.1", validator=Float64)
    ysteptb = Textbox(stage_gui_fig[2, 4], placeholder="0.1", validator=Float64)
    zsteptb = Textbox(stage_gui_fig[2, 6], placeholder="0.1", validator=Float64)

    #Callback functions to change the step size using the text boxes
    on(xsteptb.stored_string) do xstep_change
        xstepsize[] = parse(Float64, xstep_change)
    end

    on(ysteptb.stored_string) do ystep_change
        ystepsize[] = parse(Float64, ystep_change)
    end

    on(zsteptb.stored_string) do zstep_change
        zstepsize[] = parse(Float64, zstep_change)
    end

    stage_gui_fig[3:5, 1:4] = arrow_grid = GridLayout(3, 3)

    xbuttonlabels = ["<", ">"]
    ybuttonlabels = ["^", "v"]
    homebuttonlabel = "Home"

    #Create the arrow buttons using [1,2] for up, [2,1] for left, [2,3] for right, [3,2] for down, and [2,2] for home
    x_left = Button(arrow_grid[2, 1], label=xbuttonlabels[1], width=100)
    x_right = Button(arrow_grid[2, 3], label=xbuttonlabels[2], width=100)
    y_up = Button(arrow_grid[1, 2], label=ybuttonlabels[1], width=100)
    y_down = Button(arrow_grid[3, 2], label=ybuttonlabels[2], width=100)
    homebutton = Button(arrow_grid[2, 2], label=homebuttonlabel, width=100)

    #Define the callback functions for the arrow buttons
    on(x_left.clicks) do x_left_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x - xstepsize[] < stage.range_x[1]
            @error "Target position out of range"
            return
        end

        stage.targ_x -= xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end
    on(x_right.clicks) do x_right_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_x + xstepsize[] > stage.range_x[2]
            @error "Target position out of range"
            return
        end

        stage.targ_x += xstepsize[]
        xtarget[] = stage.targ_x
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    on(y_down.clicks) do y_down_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_y - ystepsize[] < stage.range_y[1]
            @error "Target position out of range"
            return
        end

        stage.targ_y -= ystepsize[]
        ytarget[] = stage.targ_y
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    on(y_up.clicks) do y_right_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_y + ystepsize[] > stage.range_y[2]
            @error "Target position out of range"
            return
        end

        stage.targ_y += ystepsize[]
        ytarget[] = stage.targ_y
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    on(homebutton.clicks) do return_home_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        home(stage)
        xtarget[], ytarget[], ztarget[] = stage.targ_x, stage.targ_y, stage.targ_z
    end

    Label(stage_gui_fig[6, 1:4], "XY Axes Control")

    #Create an up and down button for the Z control
    stage_gui_fig[3:5, 5:6] = z_arrow_grid = GridLayout(2, 1)

    zbuttonlabels = ["^", "v"]

    z_up = Button(z_arrow_grid[1, 1], label=zbuttonlabels[1], width=50, height=80)
    z_down = Button(z_arrow_grid[2, 1], label=zbuttonlabels[2], width=50, height=80)

    #Define the callback functions for the arrow buttons
    on(z_down.clicks) do z_down_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_z - zstepsize[] < stage.range_z[1]
            @error "Target position out of range"
            return
        end

        stage.targ_z -= zstepsize[]
        ztarget[] = stage.targ_z
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    on(z_up.clicks) do z_up_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        if stage.targ_z + zstepsize[] > stage.range_z[2]
            @error "Target position out of range"
            return
        end

        stage.targ_z += zstepsize[]
        ztarget[] = stage.targ_z
        move(stage, stage.targ_x, stage.targ_y, stage.targ_z)
    end

    Label(stage_gui_fig[6, 5:6], "Z Axis Control")

    #Create a button to query current position, initialize, shutdown, or stop motion 
    stage_gui_fig[7:8, 1:4] = control_grid = GridLayout(2, 2)

    control_labels = ["Query Position", "Stop Motion", "Initialize", "Shutdown"]
    control_buttons = control_grid[1:2, 1:2] = [Button(stage_gui_fig, label=control_labels[i], width=150) for i in 1:4]


    on(control_buttons[1].clicks) do query_position_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        getposition(stage)
        xposition[] = stage.real_x
        yposition[] = stage.real_y
        zposition[] = stage.real_z
    end
    on(control_buttons[2].clicks) do stop_motion_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        stopmotion(stage)
    end
    on(control_buttons[3].clicks) do initialize_click
        initialize(stage)
        getposition(stage)
        xposition[], yposition[], zposition[] = stage.real_x, stage.real_y, stage.real_z
        xtarget[], ytarget[], ztarget[] = stage.targ_x, stage.targ_y, stage.targ_z

    end
    on(control_buttons[4].clicks) do shutdown_click
        if stage.connectionstatus == false
            @error "Stage not connected"
            return
        end

        shutdown(stage)
    end


    # Create a display to show current Position
    axis = Axis3(stage_gui_fig[1:8, 7], xlabel="X", ylabel="Y", zlabel="Z", title="Stage Position", limits=(stage.range_x[1], stage.range_x[2], stage.range_y[1], stage.range_y[2], stage.range_z[1], stage.range_z[2]))
    Label(stage_gui_fig[9, 1:4], positionstring)

    scatter!(axis, xposition, yposition, zposition, markersize=20, color=:red)

    #Now we check for servo and drift correction fields and build buttons if they are present

    hasservo = hasfield(typeof(stage), :servostatus)
    hasdrift = hasfield(typeof(stage), :driftcorrectionstatus)

    if hasservo
        servostatus = Observable(stage.servostatus[1] && stage.servostatus[2] && stage.servostatus[3])

        servostring = @lift begin
            if $servostatus
                return "Servo On"
            else
                return "Servo Off"
            end
        end


        #Create a button to toggle servo status
        Label(stage_gui_fig[10, 1], "Servo Control")
        stage_gui_fig[10, 2:3] = servo_control_button = Button(stage_gui_fig, label="Toggle Servo", width=200)
        Label(stage_gui_fig[10, 4], servostring)

        on(servo_control_button.clicks) do servo_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if servostatus[]
                servostatus[] = false
                servo(stage, false, false, false)
            else
                servostatus[] = true
                servo(stage, true, true, true)
            end
        end
    end

    if hasdrift
        driftcorrectionstatus = Observable(stage.driftcorrectionstatus[1] && stage.driftcorrectionstatus[2] && stage.driftcorrectionstatus[3])

        driftstring = @lift begin
            if $driftcorrectionstatus
                return "Drift Correction On"
            else
                return "Drift Correction Off"
            end
        end

        #Create a button to toggle drift correction status
        Label(stage_gui_fig[11, 1], "Drift Correction Control")
        stage_gui_fig[11, 2:3] = drift_control_button = Button(stage_gui_fig, label="Toggle Drift Correction", width=200)
        Label(stage_gui_fig[11, 4], driftstring)

        on(drift_control_button.clicks) do drift_control_click
            if stage.connectionstatus == false
                @error "Stage not connected"
                return
            end

            if driftcorrectionstatus[]
                driftcorrectionstatus[] = false
                driftcorrection(stage, false, false, false)
            else
                driftcorrectionstatus[] = true
                driftcorrection(stage, true, true, true)
            end
        end
    end

    GLMakie.activate!(title=stage.stagelabel)
    display(GLMakie.Screen(), stage_gui_fig)
end