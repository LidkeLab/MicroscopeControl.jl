# Layout:
#   • A "Reference" button per channel (MCS2 must be referenced before moving)
#   • A "Stop All" emergency button
#   • A live status indicator per channel (calibrated / referenced / moving)
#   • The position display shows µm 

function gui(stage::MCS2Stage)
    n = stage.n_channels

    # Build the figure
    fig = Figure(size = (620, 180 + n * 60))

    # Row 1: position display + STOP ALL
    pos_um = Observable(round.(stage.pos_pm ./ 1e6, digits = 3))

    pos_string = @lift begin
        vals = join(["$(v) µm" for v in $pos_um], "   ")
        "Position:  $vals"
    end

    Label(fig[1, 1], pos_string,
          halign = :left, width = 440, tellwidth = false)

    stop_btn = Button(fig[1, 2], label = "■ STOP ALL",
                      width = 120, height = 35,
                      buttoncolor = :firebrick,
                      labelcolor  = :white)

    on(stop_btn.clicks) do _
        stopmotion!(stage)
        sleep(0.05)
        query_positions!(stage)
        pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
    end

    # Separator
    Label(fig[2, 1:2], "─"^80, halign = :left)

    # Rows 3 … 3+n-1: one row per channel
    # Each row: label | Ref button | status label | ↑ | ↓
    for (i, ch) in enumerate(stage.channel_ids)
        row = 2 + i   # row index in the Figure grid

        Label(fig[row, 1],
              "Ch $ch",
              width = 50, halign = :left)

        if !stage.connected[i]
            # Unconnected channel: show greyed-out "N/C" row 
            # The row still exists (so the layout/column widths stay
            # consistent and the channel slot is visually present), but
            # the Ref/↑/↓ buttons are disabled — clicking them does
            # nothing, because move_abs!/find_reference! already no-op
            # for disconnected channels (see helper_smaract.jl). Graying
            # them out here just makes that visually obvious.
            Button(fig[row, 2], label = "Ref", width = 50, height = 30,
                   buttoncolor = :gray85, labelcolor = :gray50)
            Label(fig[row, 3], "N/C", width = 130, halign = :left, color = :gray50)
            Button(fig[row, 4], label = "↑", width = 40, height = 30,
                   buttoncolor = :gray85, labelcolor = :gray50)
            Button(fig[row, 5], label = "↓", width = 40, height = 30,
                   buttoncolor = :gray85, labelcolor = :gray50)
            continue   # skip wiring up callbacks for this channel
        end

        ref_btn = Button(fig[row, 2], label = "Ref",
                         width = 50, height = 30)

        # Status observable: reflects calibrated + referenced flags
        status_obs = Observable(_channel_status_string(stage, i))
        status_lbl = Label(fig[row, 3], status_obs,
                           width = 130, halign = :left,
                           color  = @lift(_channel_status_color($status_obs)))

        on(ref_btn.clicks) do _
            try
                find_reference!(stage, i)
                query_channel_states!(stage)
                status_obs[] = _channel_status_string(stage, i)
                query_positions!(stage)
                pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
            catch e
                @error "Referencing failed: $e"
            end
        end

        btn_up = Button(fig[row, 4], label = "↑", width = 40, height = 30)
        btn_dn = Button(fig[row, 5], label = "↓", width = 40, height = 30)

        on(btn_up.clicks) do _
            step = _parse_stepsize(stepsize_box)
            target_pm = stage.pos_pm[i] + round(Int64, step * 1e6)
            try
                move_abs!(stage, i, target_pm)
                pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
                status_obs[] = _channel_status_string(stage, i)
            catch e
                @error "Move failed: $e"
            end
        end

        on(btn_dn.clicks) do _
            step = _parse_stepsize(stepsize_box)
            target_pm = stage.pos_pm[i] - round(Int64, step * 1e6)
            try
                move_abs!(stage, i, target_pm)
                pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
                status_obs[] = _channel_status_string(stage, i)
            catch e
                @error "Move failed: $e"
            end
        end
    end

    # All-axes row
    all_row = 3 + n
    Label(fig[all_row, 1:3], "All axes", halign = :left)

    all_up = Button(fig[all_row, 4], label = "↑", width = 40, height = 30)
    all_dn = Button(fig[all_row, 5], label = "↓", width = 40, height = 30)

    on(all_up.clicks) do _
        step = _parse_stepsize(stepsize_box)
        targets = stage.pos_pm .+ round(Int64, step * 1e6)
        try
            move!(stage, targets)
            pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
        catch e
            @error "Move-all failed: $e"
        end
    end

    on(all_dn.clicks) do _
        step = _parse_stepsize(stepsize_box)
        targets = stage.pos_pm .- round(Int64, step * 1e6)
        try
            move!(stage, targets)
            pos_um[] = round.(stage.pos_pm ./ 1e6, digits = 3)
        catch e
            @error "Move-all failed: $e"
        end
    end

    # Separator
    Label(fig[all_row + 1, 1:5], "─"^80, halign = :left)

    # Settings row: step size + velocity 
    settings_row = all_row + 2

    Label(fig[settings_row, 1], "Step (µm):", halign = :right, width = 80)
    stepsize_box = Textbox(fig[settings_row, 2],
                           placeholder = "1.0",
                           width = 80, height = 30,
                           validator = Float64)

    Label(fig[settings_row, 3], "Vel (mm/s):", halign = :right, width = 90)
    velocity_box = Textbox(fig[settings_row, 4:5],
                           placeholder = string(stage.velocity_pm_s[1] / 1e9),
                           width = 80, height = 30,
                           validator = Float64)

    on(velocity_box.stored_string) do s
        vel_mms = tryparse(Float64, s)
        vel_mms === nothing && return
        vel_pm = round(Int64, vel_mms * 1e9)
        try
            set_velocity!(stage, vel_pm)
        catch e
            @error "Set velocity failed: $e"
        end
    end

    # ── Show window ────────────────────────────────────────────────────────
    GLMakie.activate!(title = stage.stagelabel)
    display(GLMakie.Screen(), fig)
end

# Internal helpers used by gui()
"""Return a short status string for one channel."""
function _channel_status_string(stage::MCS2Stage, i::Int) :: String
    cal = stage.is_calibrated[i] ? "cal" : "uncal"
    ref = stage.is_referenced[i] ? "ref"  : "unref"
    return "$cal / $ref"
end

"""Return a color for the status label."""
function _channel_status_color(s::String)
    if contains(s, "unref") || contains(s, "uncal")
        return :orangered
    else
        return :forestgreen
    end
end

"""Parse the step-size text box, defaulting to 1.0 µm on failure."""
function _parse_stepsize(box::Textbox) :: Float64
    val = tryparse(Float64, box.stored_string[])
    return val === nothing ? 1.0 : val
end
