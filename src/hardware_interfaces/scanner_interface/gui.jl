function addNewCommand!(fig, cmdSig::CommandSignal, boxnum)
    grid = GridLayout(fig[boxnum, 1])
    one_to_sixteen = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
    one_to_fifty = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", 
        "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
        "21", "22", "23", "24", "25", "26", "27", "28", "29", "30",
        "31", "32", "33", "34", "35", "36", "37", "38", "39", "40",
        "41", "42", "43", "44", "45", "46", "47", "48", "49", "50",
    ]

    # Define elements to go into box
    programLine = Menu(
        grid[1,1],
        options = one_to_fifty,
        default = "1"
    )
    typeMenu = Menu(
        grid[1,2], 
        options = zip(["DAC", "TTL"], [DAC, TTL]),
        default="DAC"
    )
    channelMenu = Menu(grid[1,3], options=one_to_sixteen, default="1")

    trueFalse = Menu(
        grid[1,4], 
        options=zip(["ON", "OFF"], [true, false]), 
        default="OFF",
        width=50
    )
    trueFalse.blockscene.visible[] = false

    volts = Textbox(
        grid[1,4], 
        placeholder = string(0), 
        validator = Float64, 
    )
    volts.blockscene.visible[] = true # Volts is visible as default is DAC

    # events!
    on(typeMenu.selection) do mode
        cmdSig.commandType = mode
        if mode == DAC
            volts.blockscene.visible[] = true
            trueFalse.blockscene.visible[] = false
        else
            trueFalse.blockscene.visible[] = true
            volts.blockscene.visible[] = false
        end
    end
    on(channelMenu.selection) do mode
        cmdSig.channel = parse(Int, mode)
    end
    on(volts.stored_string) do s
        cmdSig.value = parse(Float64, s)
    end
    on(trueFalse.selection) do mode
        cmdSig.value = mode
    end
    on(programLine.selection) do line
        cmdSig.progLine = line
    end
    return grid
end

function gui()
    @info "Creating GUI for a " typeof(scanner) " Scanner!"
    
    control_fig = Figure(size=(500,400))
    wd = 150
    wd2 = 75
    volts1 = 0
    volts2 = 0
    volts3 = 0

    # set single angle voltage
    setAngleLabel = Label(control_fig, "Set to an angle with Voltage")
    tboxVolts = Textbox(control_fig, placeholder = string(0), validator = Float64, width = wd)
    setVoltsButton = Button(control_fig, label = "Set Voltage!")

    on(tboxVolts.stored_string) do s
        volts1 = parse(Float64, s)
    end

    on(setVoltsButton.clicks) do s
        println("Voltage was set to $volts1")
        set_voltage(scanner, volts1)
    end

    # set scan path range
    scanPathLabel = Label(control_fig, "Scan a path")
    tboxRange1 = Textbox(control_fig, placeholder = string(0), validator = Float64, width = wd2)
    tboxRange2 = Textbox(control_fig, placeholder = string(0), validator = Float64, width = wd2)
    scanButton = Button(control_fig, label = "Scan Path!")

    on(tboxRange1.stored_string) do s
        volts2 = parse(Float64, s)
    end

    on(tboxRange2.stored_string) do s
        volts3 = parse(Float64, s)
    end

    on(scanButton.clicks) do s
        println("Scanning!")
        scan_path(scanner, volts2, volts3, stepSize)
    end

    # reset back to zero volts
    resetLabel = Label(control_fig, "Reset the scanner")
    resetButton = Button(control_fig, label = "Reset!")
    on(resetButton.clicks) do s
        println("The scanner was reset!")
        volts1 = 0; volts2 = 0; volts3 = 0
        tboxVolts.displayed_string = "0"
        tboxRange1.displayed_string = "0"
        tboxRange2.displayed_string = "0"
        reset(scanner)
    end

    # program a sequence onto the scanner
    cmdBoxes = [addNewCommand!(control_fig, CommandSignal("DAC", 1, 0.0), 7)]
    boxnum = 8

    newCmdButton = Button(control_fig, label="+")
    on(newCmdButton.clicks) do s
        push!(cmdBoxes, addNewCommand!(control_fig, CommandSignal("DAC", 1, 0.0), boxnum))
        boxnum += 1
    end

    progButton = Button(control_fig, label="PROGRAM!")
    on(progButton.clicks) do s
        prog_cmd_seq(scanner, sigArr, loops, false)
    end

    # place on board
    control_fig[1,1] = hgrid!(setAngleLabel)
    control_fig[2,1] = hgrid!(tboxVolts, setVoltsButton)
    control_fig[3,1] = hgrid!(scanPathLabel)
    control_fig[4,1] = hgrid!(tboxRange1, tboxRange2, scanButton)
    control_fig[5,1] = hgrid!(resetLabel, resetButton)
    control_fig[6,1] = hgrid!(progButton, newCmdButton)
    

    GLMakie.activate!(title="scanner gui")
    display(GLMakie.Screen(), control_fig)
end