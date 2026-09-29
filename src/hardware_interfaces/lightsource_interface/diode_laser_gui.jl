"""
    gui(laser::DiodeLaser)

Open the control panel for a regulated laser diode, chosen by its
[`RegulationMode`](@ref): [`current_panel`](@ref) for `ConstantCurrent`,
[`power_panel`](@ref) for `ConstantPhotocurrent`.

`[guarantee]` opening either panel issues no command and no read. The readout is
filled by its Read button, or by the Poll toggle, which starts off.
"""
gui(laser::DiodeLaser) = _panel(regulation_mode(laser), laser)

_panel(::ConstantCurrent, laser::DiodeLaser) = current_panel(laser)
_panel(::ConstantPhotocurrent, laser::DiodeLaser) = power_panel(laser)

"Human-readable amplifier range: `1e-3` -> `1 mA`."
function _format_tia(range_A::Float64)
    isnan(range_A) && return "unknown"
    range_A >= 1e-3 ? "$(_trim(range_A * 1e3)) mA" : "$(_trim(range_A * 1e6)) µA"
end
_trim(x) = isapprox(x, round(x); atol=1e-9) ? string(Int(round(x))) : string(round(x; digits=3))

_format_tec(t) = t === missing ? "unknown" : (t ? "stabilised" : "not stabilised")

"First line of an exception's message, for showing inside a panel."
_panel_message(e) = first(split(sprint(showerror, e), '\n'))

"""
    _readout_text(laser, s)

Format a [`loop_status`](@ref) snapshot for a panel.
"""
function _readout_text(laser::DiodeLaser, s)
    flags = String[]
    s.output_enabled || push!(flags, "output OFF")
    s.key || push!(flags, "KEY OFF")
    s.interlock || push!(flags, "INTERLOCK OPEN")
    s.saturated && push!(flags, "SATURATED (at current limit)")
    s.open_circuit && push!(flags, "OPEN CIRCUIT")
    s.tia_over && push!(flags, "TIA OVER")
    s.tia_under && push!(flags, "TIA UNDER")
    s.below_threshold === true && push!(flags, "BELOW THRESHOLD (not lasing)")
    lines = [
        "drive current: $(round(s.current_mA; digits=2)) mA",
        "photocurrent: $(round(s.photocurrent_A * 1e6; digits=2)) µA  (TIA $(_format_tia(s.tia_range_A)))",
    ]
    if regulation_mode(laser) isa ConstantPhotocurrent && isfinite(s.photocurrent_A)
        push!(lines, "indicated output power: $(round(s.photocurrent_A * laser.pd.wa_calibration * 1e3; digits=2)) mW")
    end
    push!(lines, isempty(flags) ? "status: ok" : "status: " * join(flags, ", "))
    return join(lines, "\n")
end

"""
    _attach_readout!(fig, row, laser)

The shared readout block: a status text, a Read button and a Poll toggle that
is off at construction. Polling reads [`loop_status`](@ref) twice a second and
stops when the toggle is turned off or the window closes.
"""
function _attach_readout!(fig, row, laser::DiodeLaser)
    readout = Label(fig[row, 1:3], "readout: not read yet (press Read, or turn on Poll)";
                    halign=:left, justification=:left, tellwidth=false)
    controls = GridLayout(fig[row+1, 1:3]; tellwidth=false, halign=:left)
    read_button = Button(controls[1, 1], label="Read")
    poll = Toggle(controls[1, 2], active=false)
    Label(controls[1, 3], "Poll (2 Hz)")

    function refresh()
        try
            readout.text = _readout_text(laser, loop_status(laser))
        catch e
            readout.text = "readout failed: " * _panel_message(e)
        end
        return nothing
    end
    on(_ -> refresh(), read_button.clicks)

    timer = Ref{Union{Nothing,Timer}}(nothing)
    function stop_polling()
        timer[] === nothing || close(timer[])
        timer[] = nothing
        return nothing
    end
    on(poll.active) do active
        stop_polling()
        active && (timer[] = Timer(_ -> refresh(), 0.0; interval=0.5))
    end
    on(fig.scene.events.window_open) do open
        open || stop_polling()
    end
    return readout
end

"""
    _attach_setpoint!(fig, laser, range, startvalue, command!, describe)

The slider and textbox both panels share. A slider change calls `command!(x)`
once. The textbox only moves the slider, so an entry issues one command, not
two, and lands on the slider's grid. The "commanded" line is refreshed from
`describe()` only after the command returned, so a refused request shows as
refused instead of as a value the device does not hold.

The textbox accepts only a number within `[first(range), last(range)]`, the
same bounds the driver enforces; anything else is not applied and the box's
border turns red until it is corrected. The bounds are printed beside it.
"""
function _attach_setpoint!(fig, laser::DiodeLaser, range, startvalue, command!, describe)
    lo, hi = first(range), last(range)
    slider = Slider(fig[2, 1], range=range, startvalue=startvalue, width=460, linewidth=24,
                    color_active=:gray, halign=:left)
    in_range(s) = (x = tryparse(Float64, s); x !== nothing && lo <= x <= hi)
    textbox = Textbox(fig[2, 2], placeholder="$(lo) - $(hi)", validator=in_range, width=110,
                      bordercolor_focused_invalid=:red)
    commanded = Label(fig[3, 1:3], describe(); halign=:left, tellwidth=false)
    message = Label(fig[4, 1:3], ""; halign=:left, color=:firebrick, tellwidth=false)

    on(textbox.stored_string) do s
        set_close_to!(slider, parse(Float64, s))
    end
    # on (not lift): a hardware command must fire on a change, never at construction.
    on(slider.value) do x
        try
            command!(x)
            message.text = ""
        catch e
            message.text = "refused: " * _panel_message(e)
        end
        commanded.text = describe()
    end
    return message
end

"""
    _attach_output_toggle!(fig, row, laser, message)

On/off toggle, initialised from `properties.is_on` so opening the panel does not
impose a state. The slider's lowest position is not "off"; this is.

The label follows the driver, not the click: after every command it shows
`properties.is_on`, whatever the command did, and if the toggle disagrees (a
failed `light_off` leaves the diode on) the toggle is put back, under a guard
that keeps the correction from firing `light_on`/`light_off` again. Returns
`(; toggle, status)`, the `Toggle` and the label's `Observable{String}`.
"""
function _attach_output_toggle!(fig, row, laser::DiodeLaser, message)
    label(is_on) = is_on ? "output on" : "output off"
    toggle = Toggle(fig[row, 1], active=laser.properties.is_on, halign=:left)
    status = Observable(label(laser.properties.is_on))
    Label(fig[row, 2], status)
    correcting = Ref(false)
    on(toggle.active) do x
        correcting[] && return
        try
            x ? light_on(laser) : light_off(laser)
        catch e
            message.text = "refused: " * _panel_message(e)
        end
        is_on = laser.properties.is_on
        status[] = label(is_on)
        if toggle.active[] != is_on
            correcting[] = true
            try
                toggle.active[] = is_on
            finally
                correcting[] = false
            end
        end
    end
    return (; toggle, status)
end

function _show_panel(fig, laser::DiodeLaser)
    GLMakie.activate!(title=laser.unique_id)
    display(GLMakie.Screen(), fig)
    return fig
end

"""
    current_panel(laser::DiodeLaser)

Control panel for a [`ConstantCurrent`](@ref) laser: a slider in **mA** over
`min_current .. effective_max_current(laser)`, calling [`setcurrent!`](@ref),
the declared threshold, an on/off toggle, and a [`loop_status`](@ref) readout.
The slider's lowest position is `min_current`, which still emits if the rig set
it above threshold; the toggle is the off control.
"""
function current_panel(laser::DiodeLaser)
    lo, hi = laser.min_current, effective_max_current(laser)
    fig = Figure(size=(760, 360))
    threshold = isnan(laser.threshold_current) ? "unknown" : "$(laser.threshold_current) mA"
    Label(fig[1, 1:3], "$(laser.unique_id): drive current [$(lo) mA - $(hi) mA], constant current.  " *
                       "Threshold $(threshold)"; halign=:left, tellwidth=false)
    start = isfinite(laser.drive_current) && lo <= laser.drive_current <= hi ? laser.drive_current : lo
    describe() = isnan(laser.drive_current) ? "commanded: nothing yet" :
                 "commanded: $(laser.drive_current) mA"
    message = _attach_setpoint!(fig, laser, lo:0.1:hi, start, x -> setcurrent!(laser, x), describe)
    _attach_output_toggle!(fig, 5, laser, message)
    _attach_readout!(fig, 6, laser)
    return _show_panel(fig, laser)
end

"""
    power_panel(laser::DiodeLaser)

Control panel for a [`ConstantPhotocurrent`](@ref) laser: a slider in **mW at
the laser output** over `properties.min_power .. max_power`, calling
[`setoutputpower!`](@ref); a basis line saying what that number is built from;
an on/off toggle; and a [`loop_status`](@ref) readout of what a power-mode user
must see -- the photocurrent with its range and over/under flags, the drive
current (a climbing current at a still setpoint is a blocked photodiode or an
ageing diode), and the `saturated` flag.
"""
function power_panel(laser::DiodeLaser)
    pd = laser.pd
    lo, hi = laser.properties.min_power, laser.properties.max_power
    fig = Figure(size=(760, 380))
    Label(fig[1, 1:3], "$(laser.unique_id): output power at the laser output [$(lo) mW - $(hi) mW], constant photocurrent.\n" *
                       "Basis: photodiode x $(pd.wa_calibration) W/A, TIA $(_format_tia(pd.tia_range)), " *
                       "TEC $(_format_tec(pd.tec_stabilised))"; halign=:left, tellwidth=false)
    start = isfinite(pd.output_power_requested) && lo <= pd.output_power_requested <= hi ?
            pd.output_power_requested : lo
    describe() = isnan(pd.output_power_requested) ? "commanded: nothing yet" :
                 "commanded: $(pd.output_power_requested) mW (loop holds $(round(pd.photocurrent_requested * 1e6; digits=3)) µA)"
    message = _attach_setpoint!(fig, laser, lo:0.1:hi, start, x -> setoutputpower!(laser, x), describe)
    _attach_output_toggle!(fig, 5, laser, message)
    _attach_readout!(fig, 6, laser)
    return _show_panel(fig, laser)
end
