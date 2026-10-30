"""
    gui(dev::BeamSteerer)

Control panel for a beam steerer: one slider per axis over the device's voltage limits,
a Zero button, and a readout of the commanded voltages and the angle they give.

Opening the panel writes nothing to the hardware: each slider acts through `on`, which
does not run when it is wired. A command the device refuses (out of range, or before
`initialize`) is shown in the readout instead of being thrown.
"""
function gui(dev::BeamSteerer)
    fig = Figure(size = (700, 230))
    Label(fig[1, 1:3], dev.unique_id; fontsize = 18, halign = :left)

    v0 = getvoltage(dev)
    sliders = map(enumerate((("X", dev.xlimits), ("Y", dev.ylimits)))) do (i, (axis, lims))
        Label(fig[i+1, 1], "$axis (V)"; halign = :left)
        start = clamp(isfinite(v0[i]) ? v0[i] : 0.0, lims[1], lims[2])
        slider = Slider(fig[i+1, 2]; range = range(lims[1], lims[2]; length = 1001),
            startvalue = start, width = 450)
        Label(fig[i+1, 3], lift(v -> string(round(v; digits = 4)), slider.value))
        slider
    end

    zero_button = Button(fig[4, 1]; label = "Zero")
    readout = Label(fig[4, 2:3], panel_readout(dev); halign = :left)

    function command(f)
        try
            f()
            readout.text[] = panel_readout(dev)
        catch e
            readout.text[] = sprint(showerror, e)
        end
    end

    # Moving the sliders back after Zero must not write their (grid-rounded) values.
    syncing = Ref(false)
    for slider in sliders
        on(slider.value) do _
            syncing[] && return
            command(() -> setvoltage(dev, sliders[1].value[], sliders[2].value[]))
        end
    end
    on(zero_button.clicks) do _
        command(() -> zeroaxes(dev))
        syncing[] = true
        try
            foreach(s -> set_close_to!(s, 0.0), sliders)
        finally
            syncing[] = false
        end
    end

    GLMakie.activate!(title = dev.unique_id)
    display(GLMakie.Screen(), fig)
    return fig
end

"""
    panel_readout(dev::BeamSteerer)

The status line of the `gui` panel. A device with more to say (an `EOD`'s crystal
volts) adds a method.
"""
function panel_readout(dev::BeamSteerer)
    vx, vy = getvoltage(dev)
    ax, ay = getangle(dev)
    r(v) = round(v; digits = 4)
    state = dev.isopen ? "" : "not initialized; "
    return "$(state)$(r(vx)), $(r(vy)) V; $(r(ax)), $(r(ay)) mrad"
end
