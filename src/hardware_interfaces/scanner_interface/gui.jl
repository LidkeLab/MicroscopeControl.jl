function addNewCommand!(fig, cmdSig::CommandSignal)
    box = Box(fig, linestyle = :dot)
    one_to_sixteen = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
    # need to zip menu with enum for command types
    typeMenu = Menu(box[1,1], options = ["DAC", "TTL"], default="DAC")
    channelMenu = Menu(box[1,2], options =one_to_sixteen, default="1")
    # need to zip menu with true false
    trueFalse = Menu(box[1,3], options=["ON", "OFF"], default="OFF")
    trueFalse.blockscene.visible[] = false
    # Volts is visible as default is DAC
    volts = Textbox(box[1,3], placeholder = string(0), validator = Float64, width = wd)
    volts.blockscene.visible[] = true
    
    on(typeMenu.selection) do mode
        cmdSig.commandType = mode
        if mode == "DAC"
            volts.blockscene.visible[] = true
        else
            trueFalse.blockscene.visible[] = true
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
    return box
end

function gui()
    @info "Creating GUI for a " typeof(scanner) " Scanner!"
    
    control_fig = Figure(size=(300,400))
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

    # # program a sequence onto the scanner
    # cmdBoxes = [addNewCommand!(fig, CommandSignal("DAC", 1, 0.0))]

    # newCmdButton = Button(control_fig, label="+")
    # on(newCmdButton.clicks) do s
    #     push!(cmdBoxes, addNewCommand!(control_fig, CommandSignal("DAC", 1, 0.0)))
    # end

    # progButton = Button(control_fig, label="PROGRAM!")
    # on(progButton.clicks) do s
    #     prog_cmd_seq(scanner, sigArr, loops, false)
    # end

    # place on board
    control_fig[1,1] = hgrid!(setAngleLabel)
    control_fig[2,1] = hgrid!(tboxVolts, setVoltsButton)
    control_fig[3,1] = hgrid!(scanPathLabel)
    control_fig[4,1] = hgrid!(tboxRange1, tboxRange2, scanButton)
    control_fig[5,1] = hgrid!(resetLabel)
    control_fig[6,1] = hgrid!(resetButton)

    GLMakie.activate!(title="scanner gui")
    display(GLMakie.Screen(), control_fig)
end