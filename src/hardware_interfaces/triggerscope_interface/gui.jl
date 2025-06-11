"""
This function builds a GUI for any implemented DAQ device based on the prior existing GUI for the NIDAQ device.
GLMakie is used

There will be an equal number of dropdown menus to the number of datatypes that the DAQ device can read and write.
ex: If the DAQ device has DAC and TTL outputs, there will be two dropdown menus for output and two for input.

The dropdown menus will have a number of fields equal to the number of channels that the DAQ device has for each datatype.
ex: If the DAQ device has 4 DAC outputs, there will be 4 fields for the DAC output dropdown menu.

For each selected output channel, there will be a field to input the value to be written to the channel.
There will be a textbox to display the value outputted to the selected channel, this will update when the value is updated.

For each selected input channel, there will be a textbox to display the value read from the channel.
There will be a button to update this reading. 

The GUI will have a button to start the DAQ device and a button to stop the DAQ device.
ex: For the Triggerscope this will initiate serial communication and close serial communication.
"""
function gui(trig::TRIG)
    @info "Creating GUI for " trig.devicename

    #Create the GUI window
    trig_gui_fig = Figure()

    #Create the layout for the GUI
    
    #Leftmost buttons will be for starting and stopping the device
    trig_gui_fig[1,1] = startbutton = Button(trig_gui_fig, label="Start Device")
    trig_gui_fig[2,1] = stopbutton = Button(trig_gui_fig, label="Stop Device")
    
    on(startbutton.clicks) do event
        initialize(trig)
    end

    on(stopbutton.clicks) do event
        shutdown(trig)
    end

    #Discovery the number of outputs and inputs, in order to create the necessary output and input fields
    numoutputs = size(trig.outputs)[1]
    numinputs = size(trig.inputs)[1]

    #First create a lable for each output type, a dropdown under the label, a field for the value to be written to the channel, and a field to display the value outputted to the channel
    for i in 1:numoutputs
        menuselections = Vector{Int}(undef, trig.outputs[i].numchannels)
        for j in 1:trig.outputs[i].numchannels
            menuselections[j] = j
        end

        outputlabel = Label(trig_gui_fig[1 , 1+ i],trig.outputs[i].label * " Output")
        outputdropdown = Menu(trig_gui_fig[2, 1 + i], options=menuselections, default = 1)
        outputvalue = Textbox(trig_gui_fig[3, 1+i], placeholder="Value")
        outputdisplay = Label(trig_gui_fig[4, 1+i], "Output Value")

        on(outputdropdown.selection) do event
            outputchannel = Int(outputdropdown.selection[])
            outputdisplay.text = string(getoutputvalue(trig, trig.outputs[i], outputchannel))
        end

        on(outputvalue.stored_string) do event
            outputchannel = Int(outputdropdown.selection[])
            value = parse(trig.outputs[i].datatype, outputvalue.stored_string[])
            setoutputvalue(trig, trig.outputs[i], outputchannel, value)
            outputdisplay.text = string(getoutputvalue(trig, trig.outputs[i], outputchannel))

        end

        if trig.outputs[i].israngevariable == true #build a range dropdown with range options\
            rangeenter = Textbox(trig_gui_fig[5, 1+i], placeholder="Range")
            rangedisplay = Label(trig_gui_fig[6, 1+i], "Output Range")

            on(rangeenter.stored_string) do event
                outputchannel = Int(outputdropdown.selection[])     #assumed enumerated range type (only integer input is valid)
                range = parse(Int, rangeenter.stored_string[])
                setoutputrange(trig, trig.outputs[i], outputchannel, range)
                rangedisplay.text = string(trig.outputs[i].ranges[outputchannel])
            end
        end

    end

    #Next create a lable for each input type, a dropdown under the label, a button to update the reading, and a field to display the value read from the channel
    for i in 1:numinputs
        menuselections = Vector{Int}(undef, trig.inputs[i].numchannels)
        for j in 1:trig.inputs[i].numchannels
            menuselections[j] = j
        end


        inputlabel = Label(trig_gui_fig[1, 1 + i + numoutputs], trig.inputs[i].label * " Input")
        inputdropdown = Menu(trig_gui_fig[2, 1 + i + numoutputs], options=menuselections, default = 1)
        inputupdate = Button(trig_gui_fig[3, 1 + i + numoutputs], label="Update")
        inputdisplay = Label(trig_gui_fig[4, 1 + i + numoutputs], "Input Value")

        on(inputdropdown.selection) do event
            inputchannel = Int(inputdropdown.selection[])
            inputdisplay.text = string(getinputvalue(trig, trig.inputs[i], inputchannel))
        end

        on(inputupdate.clicks) do event
            inputchannel = Int(inputdropdown.selection[])
            inputdisplay.text = string(getinputvalue(trig, trig.inputs[i], inputchannel))
        end

    end

    display(GLMakie.Screen(), trig_gui_fig)
end
