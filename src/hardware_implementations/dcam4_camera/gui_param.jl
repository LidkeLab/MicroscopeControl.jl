
function gui_param(camera::DCAM4Camera)
    prop_fig = GLMakie.Figure(size=(900, 1800), title="Camera Properties")
    wd = 200
    wd1 = 300
    wd2 = 130
    hd = 30
    err, idprop = dcamprop_getnextid(camera.camera_handle, Int32(0), DCAMPROP_OPTION_SUPPORT)
    prop_control = Any[]
    prop_control_labels = Any[]
    prop_control_idprop = Any[]
    range_labels = Any[]
    units_labels = Any[]
    while (idprop != 0)
        prop = Prop_Info()
        try
            prop = dcam_get_propinfo(camera.camera_handle, idprop)
        catch
            output *= " : Unknown ID"
        end

        if prop.writable == 1
            if prop.type == "Mode"
                #DCAM4.dcam_get_prop_options!(cam.camera_handle, prop, idprop)
                push!(prop_control, Menu(prop_fig, options=prop.options, width=wd, height=hd))
                err, val = dcamprop_getvalue(camera.camera_handle, idprop)
                prop_control[end].i_selected[] = Int64(val)
                push!(prop_control_labels, Label(prop_fig, prop.name, width=wd1, height=hd))
                push!(prop_control_idprop, idprop)
            end
            if (prop.type == "Long") || (prop.type == "Real")
                err, val = dcamprop_getvalue(camera.camera_handle, idprop)
                push!(prop_control, Textbox(prop_fig, placeholder=string(val), width=wd, height=hd))
                push!(prop_control_labels, Label(prop_fig, prop.name, width=wd1, height=hd))
                push!(prop_control_idprop, idprop)
            end
            push!(range_labels, Label(prop_fig, string(round.(prop.range; digits=2)), width=wd2, height=hd))
            if prop.unit == "None"
                push!(units_labels, Label(prop_fig, "", width=wd2, height=hd))
            else
                push!(units_labels, Label(prop_fig, prop.unit, width=wd2, height=hd))
            end

        end

        err, idprop = dcamprop_getnextid(camera.camera_handle, idprop, DCAMPROP_OPTION_SUPPORT)
        if DCAM4.is_failed(err)
            display(err)
            println(idprop)
        end

    end

    for j in eachindex(prop_control)
        if typeof(prop_control[j]) == Menu
            on(prop_control[j].selection) do s
                ind = Float64(prop_control[j].i_selected[])
                err, val = setvalue(camera, prop_control_idprop[j], ind)
            end
        end
        if typeof(prop_control[j]) == Textbox
            on(prop_control[j].stored_string) do s
                val = parse(Float64, s)
                err, val = setvalue(camera, prop_control_idprop[j], val)
            end
        end
    end


    prop_fig[1, 2] = vgrid!(prop_control...)
    prop_fig[1, 1] = vgrid!(prop_control_labels...)
    prop_fig[1, 3] = vgrid!(range_labels...)
    prop_fig[1, 4] = vgrid!(units_labels...)

    # Display the control figure in a new window
    GLMakie.activate!(title="camera properties")
    display(GLMakie.Screen(), prop_fig)
end