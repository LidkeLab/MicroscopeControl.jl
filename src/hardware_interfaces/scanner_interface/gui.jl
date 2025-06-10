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
        scan_path(scanner, volts2, volts3)
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