# voltage_supply_beam_char.jl
# Based on beam_char_save.jl — adds HVA200 high-voltage amplifier control to the GUI.
#
# ── Package installation (run once in Julia REPL) ────────────────────────────
# using Pkg
# Pkg.activate("path/to/MicroscopeControl.jl/dev/implementation")
# Pkg.add(url="https://github.com/LidkeLab/DAQMX.jl", rev="under_dev_v1")
# Pkg.instantiate()
# ─────────────────────────────────────────────────────────────────────────────
#
# HVA200 hardware (via NIDAQ Dev2):
#   Gain: 20x  →  1 V DAQ input = 20 V HVA output
#   Monitor output ≈ DAQ input  (1/20 of actual output)
#   HVA1: AO0 (write)  →  AI1 (DAQ loopback)  →  AI0 (monitor read)
#   HVA2: AO1 (write)  →  AI3 (DAQ loopback)  →  AI2 (monitor read)
#
# New GUI controls (rows 7–9 of toggle_box):
#   Row 7: HVA channel selector (HVA1 / HVA2)
#   Row 8: Set voltage textbox (in HVA output scale, e.g. "20.0" = 20 V)
#   Row 9: Apply Voltage button  |  Monitor readback label
#
# New HDF5 attributes saved:
#   hva_channel         – "HVA1" or "HVA2"
#   hva_voltage_actual  – last applied HVA output voltage (V, real scale ×20)
#
# Keyboard shortcuts:
#   Ctrl+S  Save  |  Ctrl+M  Mode  |  Ctrl+R  Refresh
#   Ctrl+N  Filename  |  Ctrl+P  Position  |  Ctrl+V  Apply Voltage

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using Statistics, Optim, GLMakie, ImageFiltering, HDF5, Dates, DAQmx
include("./dev_helper_funcs.jl")

function beam_characterization(
    camera,
    framerate::Float64 = 5.0,
    exposure_time::Float64 = 0.01,
    save_dir::String = "Y:\\Projects\\NSF-MINFLUX\\projects\\Data\\Evaluation Experiments\\EOD Driver test\\beam characterizatiom",
)

    # ── Camera ───────────────────────────────────────────────────────────────
    initialize(camera)
    camera.exposure_time = exposure_time
    live(camera)
    start = time()
    initial_frame = getlastframe(camera)'

    # ── HVA200 DAQ tasks (session-level, following test_powersupply.jl TEST 3) ──
    # Tasks started once at startup and held running for the entire session.
    # Port map: AO0→HVA1  AO1→HVA2
    #   data[1]=AI0=HVA1 mon  data[2]=AI1=AO0 loop
    #   data[3]=AI2=HVA2 mon  data[4]=AI3=AO1 loop
    local dao0, dao1, dai
    daq_ok = false
    try
        dao0 = AOTask("Dev2/ao0")
        dao1 = AOTask("Dev2/ao1")
        dai  = AITask("Dev2/ai0, Dev2/ai1, Dev2/ai2, Dev2/ai3")
        start!(dao0); start!(dao1); start!(dai)
        write_scalar(dao0, 0.0); write_scalar(dao1, 0.0)
        daq_ok = true
    catch e
        @warn "DAQ init failed — HVA200 controls disabled" exception=e
    end

    # ── Figure / layout ──────────────────────────────────────────────────────
    fig = Figure(size = (1300, 900), title = "Beam Characterization")

    # Tab bar (row 1, spans both columns)
    tab_bar  = GridLayout(fig[1, 1:2])
    tab1_btn = Button(tab_bar[1, 1], label = "Beam Char",       tellwidth = false)
    tab2_btn = Button(tab_bar[1, 2], label = "Voltage Sweep",   tellwidth = false)
    tab3_btn = Button(tab_bar[1, 3], label = "Angle Stability", tellwidth = false)
    rowsize!(fig.layout, 1, Fixed(40))
    colsize!(fig.layout, 1, Relative(0.55))
    colsize!(fig.layout, 2, Relative(0.45))

    # Left panel — live view always shown; profiles shown on Tab 1 only
    left_panel   = GridLayout(fig[2, 1])
    ax2d = Axis(left_panel[1, 1], title = "2D Intensity Map", aspect = DataAspect())

    profile_box  = GridLayout(left_panel[2, 1])
    y_profile_ax = Axis(profile_box[2, 1], title = "Y Profile",
                        xticklabelsize = 9, yticklabelsize = 9, titlesize = 10)
    y_profile_ax.limits[] = (0, 1080, 0, 100)
    x_profile_ax = Axis(profile_box[1, 1], title = "X Profile",
                        xticklabelsize = 9, yticklabelsize = 9, titlesize = 10)
    x_profile_ax.limits[] = (0, 1280, 0, 100)
    rowsize!(profile_box, 1, Fixed(80))
    rowsize!(profile_box, 2, Fixed(80))

    # Right panel — tab-specific content stacked vertically; only one shown at a time
    right_panel = GridLayout(fig[2, 2])

    # ── Tab 1: 3D view + beam char controls ──────────────────────────────────
    tab1_right = GridLayout(right_panel[1, 1])
    ax3d = Axis3(tab1_right[1, 1], title = "3D Intensity Map", aspect = (1280, 1024, 400))
    ax3d.limits[] = (nothing, nothing, nothing, nothing, -50, nothing)
    rowsize!(tab1_right, 1, Relative(0.45))

    tab1_ctrl = GridLayout(tab1_right[2, 1])

    beam_type = Observable(:donut)
    Label(tab1_ctrl[0, 1], "Beam Profile:")
    beam_menu = Menu(tab1_ctrl[0, 2:4], options = ["Donut", "Gaussian"])
    on(beam_menu.selection) do sel
        beam_type[] = sel == "Donut" ? :donut : :gaussian
    end

    Label(tab1_ctrl[1, 1], "Approx Fit Curve")
    fit_toggle       = Toggle(tab1_ctrl[1, 2], active = true)
    Label(tab1_ctrl[1, 3], "Difference Image")
    diff_toggle      = Toggle(tab1_ctrl[1, 4], active = false)
    Label(tab1_ctrl[2, 1], "Real 3D data")
    real_3d_toggle   = Toggle(tab1_ctrl[2, 2], active = true)
    Label(tab1_ctrl[2, 3], "Optimized Fit Curve")
    optimized_toggle = Toggle(tab1_ctrl[2, 4], active = false)
    loading_label    = Label(tab1_ctrl[3, 1:4], "Loading...", visible = false)

    refresh_optim = Button(tab1_ctrl[4, 1:2], label = "Refresh Optimizers")
    save_button   = Button(tab1_ctrl[4, 3:4], label = "Save Data & Image")

    Label(tab1_ctrl[5, 1], "Filename:")
    filename_textbox = Textbox(tab1_ctrl[5, 2:4],
        placeholder = "beam_characterization", stored_string = "beam_characterization")
    Label(tab1_ctrl[6, 1], "Position:")
    position_textbox = Textbox(tab1_ctrl[6, 2:4], placeholder = "0.0", stored_string = "0.0")

    Label(tab1_ctrl[7, 1], "HVA1 (V):")
    hva1_textbox = Textbox(tab1_ctrl[7, 2:4], placeholder = "0.0", stored_string = "0.0")
    Label(tab1_ctrl[8, 1], "HVA2 (V):")
    hva2_textbox = Textbox(tab1_ctrl[8, 2:4], placeholder = "0.0", stored_string = "0.0")
    apply_voltage_button = Button(tab1_ctrl[9, 1:4], label = "Apply Voltage")
    hva1_monitor_label   = Label(tab1_ctrl[10, 1:2], "Mon HVA1: -- V")
    hva2_monitor_label   = Label(tab1_ctrl[10, 3:4], "Mon HVA2: -- V")
    hva1_loop_label      = Label(tab1_ctrl[11, 1:2], "Loop HVA1: -- V")
    hva2_loop_label      = Label(tab1_ctrl[11, 3:4], "Loop HVA2: -- V")

    approx_r2_label = Label(tab1_ctrl[12, 1:4], "Approximate Fit R^2: N/A")
    optim_r2_label  = Label(tab1_ctrl[13, 1:4], "Optimized Fit R^2*: N/A")
    metric_label    = Label(tab1_ctrl[14, 1:4], "Extinction Ratio*: N/A")
    Label(tab1_ctrl[15, 1:4], "* optimized values. Ctrl+S=Save  Ctrl+V=Apply  Ctrl+R=Refresh",
          fontsize = 11)

    # ── Tab 2: voltage sweep controls ────────────────────────────────────────
    tab2_right = GridLayout(right_panel[2, 1])
    Label(tab2_right[0, 1:4], "── Voltage Sweep ──"; fontsize = 13, font = :bold, tellwidth = false)

    Label(tab2_right[1, 1], "Channel:")
    sweep_chan_menu = Menu(tab2_right[1, 2], options = ["HVA1", "HVA2", "Both"], default = "HVA1")
    Label(tab2_right[1, 3], "File prefix:")
    sweep_name_textbox = Textbox(tab2_right[1, 4], placeholder = "sweep", stored_string = "sweep")

    Label(tab2_right[2, 1], "V start:")
    sweep_vstart_textbox = Textbox(tab2_right[2, 2], placeholder = "0.0", stored_string = "0.0")
    Label(tab2_right[2, 3], "V stop:")
    sweep_vstop_textbox  = Textbox(tab2_right[2, 4], placeholder = "1.0", stored_string = "1.0")

    Label(tab2_right[3, 1], "Steps:")
    sweep_steps_textbox  = Textbox(tab2_right[3, 2], placeholder = "10",  stored_string = "10")
    Label(tab2_right[3, 3], "Settle (s):")
    sweep_settle_textbox = Textbox(tab2_right[3, 4], placeholder = "1.0", stored_string = "1.0")

    sweep_start_button = Button(tab2_right[4, 1:3], label = "Start Sweep")
    sweep_status_label = Label(tab2_right[4, 4], "Idle")

    # ── Tab 3: angle stability controls ──────────────────────────────────────
    tab3_right = GridLayout(right_panel[3, 1])
    Label(tab3_right[0, 1:4], "── Angle Stability ──"; fontsize = 13, font = :bold, tellwidth = false)

    Label(tab3_right[1, 1], "Channel:")
    stab_chan_menu    = Menu(tab3_right[1, 2], options = ["HVA1", "HVA2", "Both"], default = "HVA1")
    Label(tab3_right[1, 3], "File prefix:")
    stab_name_textbox = Textbox(tab3_right[1, 4], placeholder = "stability", stored_string = "stability")

    Label(tab3_right[2, 1], "V start:")
    stab_vstart_textbox = Textbox(tab3_right[2, 2], placeholder = "0.0",  stored_string = "0.0")
    Label(tab3_right[2, 3], "V stop:")
    stab_vstop_textbox  = Textbox(tab3_right[2, 4], placeholder = "1.0",  stored_string = "1.0")

    Label(tab3_right[3, 1], "Steps:")
    stab_steps_textbox  = Textbox(tab3_right[3, 2], placeholder = "5",    stored_string = "5")
    Label(tab3_right[3, 3], "Settle (s):")
    stab_settle_textbox = Textbox(tab3_right[3, 4], placeholder = "1.0",  stored_string = "1.0")

    Label(tab3_right[4, 1], "Dwell (s):")
    stab_dwell_textbox  = Textbox(tab3_right[4, 2], placeholder = "10.0", stored_string = "10.0")
    Label(tab3_right[4, 3], "Frames/pos:")
    stab_frames_textbox = Textbox(tab3_right[4, 4], placeholder = "50",   stored_string = "50")

    stab_start_button = Button(tab3_right[5, 1:3], label = "Start Stability")
    stab_status_label = Label(tab3_right[5, 4], "Idle")

    # Initially show Tab 1; hide Tab 2 and Tab 3
    rowsize!(right_panel, 2, Fixed(0))
    rowsize!(right_panel, 3, Fixed(0))

    stab_running  = Observable(false)
    sweep_running = Observable(false)

    # ── Tab switching ─────────────────────────────────────────────────────────
    on(tab1_btn.clicks) do _
        rowsize!(right_panel, 1, Auto())
        rowsize!(right_panel, 2, Fixed(0))
        rowsize!(right_panel, 3, Fixed(0))
        rowsize!(left_panel, 2, Auto())    # show profiles
    end
    on(tab2_btn.clicks) do _
        rowsize!(right_panel, 1, Fixed(0))
        rowsize!(right_panel, 2, Auto())
        rowsize!(right_panel, 3, Fixed(0))
        rowsize!(left_panel, 2, Fixed(0))  # hide profiles
    end
    on(tab3_btn.clicks) do _
        rowsize!(right_panel, 1, Fixed(0))
        rowsize!(right_panel, 2, Fixed(0))
        rowsize!(right_panel, 3, Auto())
        rowsize!(left_panel, 2, Fixed(0))  # hide profiles
    end

    # Observables tracking the last applied/read HVA values
    current_hva1_setpoint = Observable(0.0)
    current_hva2_setpoint = Observable(0.0)
    current_hva1_monitor  = Observable(0.0)
    current_hva2_monitor  = Observable(0.0)
    current_ao0_read      = Observable(0.0)
    current_ao1_read      = Observable(0.0)

    # ── Observables ──────────────────────────────────────────────────────────
    frame_obs      = Observable(initial_frame)
    nx, ny         = size(initial_frame)
    x = collect(1:nx);  y = collect(1:ny)
    x_grid = repeat(x,   1, ny)
    y_grid = repeat(y', nx, 1)

    C          = Observable(1.0)
    ω          = Observable(100.0)
    cx         = Observable(1.0)
    cy         = Observable(1.0)
    r_grid     = Observable(zeros(size(frame_obs[])))
    ideal_z    = Observable(zeros(size(frame_obs[])))
    optimized  = Observable(zeros(size(frame_obs[])))
    r_squared  = Observable(0.0)
    diff_img   = Observable(zeros(size(frame_obs[])))
    y_prof           = Observable(zeros(ny))
    x_prof           = Observable(zeros(nx))
    x_prof_ideal     = Observable(zeros(nx))
    y_prof_ideal     = Observable(zeros(ny))
    x_prof_optim     = Observable(zeros(nx))
    y_prof_optim     = Observable(zeros(ny))
    ext_ratio  = Observable(0.0)

    # ── Beam type change handler ──────────────────────────────────────────────
    on(beam_type) do bt
        if bt == :gaussian
            metric_label.text = "FWHM & Ellipticity*: N/A"
        else
            metric_label.text = "Extinction Ratio*: N/A"
        end
        optimized[]  = zeros(size(frame_obs[]))
        r_squared[]  = 0.0
        optim_r2_label.text = "Optimized Fit R^2*: N/A"
    end

    # ── Refresh optimizers ────────────────────────────────────────────────────
    on(refresh_optim.clicks) do _
        if !optimized_toggle.active[]
            @warn "toggle switch must be on to view optimized beam fit"
        end
        if Bool(camera.is_running) == 1
            loading_label.visible[] = true
            yield()
            @async begin
                if beam_type[] == :donut
                    optimized[], r_squared[] = characterize_donut(frame_obs[])
                    optim_r2_label.text = "Optimized Fit R^2*: $(round(r_squared[], digits = 4))"
                    cx[], cy[], high_xs, high_ys = find_center_donut(frame_obs[])
                    ext_ratio[] = extinction_ratio(frame_obs[], cx[], cy[], high_xs, high_ys)
                    metric_label.text = "Extinction Ratio*: $(round(ext_ratio[], digits = 4))"
                else
                    optimized[], r_squared[] = characterize_gaussian(frame_obs[])
                    optim_r2_label.text = "Optimized Fit R^2*: $(round(r_squared[], digits = 4))"
                    fwhm_x, fwhm_y = compute_fwhm(frame_obs[], cx[], cy[])
                    ellip = max(fwhm_x, fwhm_y) / max(min(fwhm_x, fwhm_y), 1.0)
                    metric_label.text = "FWHM*: $(round(fwhm_x, digits=1))x$(round(fwhm_y, digits=1))px  Ellipticity: $(round(ellip, digits=3))"
                end
                loading_label.visible[] = false
            end
        end
    end

    # ── Apply Voltage handler ─────────────────────────────────────────────────
    # Tasks are already running (session-level); just write new values and read back.
    on(apply_voltage_button.clicks) do _
        !daq_ok && return
        v1_daq = tryparse(Float64, hva1_textbox.displayed_string[])   # displayed_string updates as user types
        v2_daq = tryparse(Float64, hva2_textbox.displayed_string[])
        v1_daq = isnothing(v1_daq) ? 0.0 : v1_daq   # raw DAQ voltage (V), sent directly
        v2_daq = isnothing(v2_daq) ? 0.0 : v2_daq
        @async begin
            try
                write_scalar(dao0, v1_daq)
                write_scalar(dao1, v2_daq)
                current_hva1_setpoint[] = v1_daq
                current_hva2_setpoint[] = v2_daq
                sleep(0.2)   # wait for HVA to settle
                data = read(dai)
                hva1_mon = data[1]   # AI0 → HVA1 monitor (= DAQ out / 20 ≈ v1_daq)
                ao0_loop = data[2]   # AI1 → AO0 loopback (= actual DAQ output)
                hva2_mon = data[3]   # AI2 → HVA2 monitor (= DAQ out / 20 ≈ v2_daq)
                ao1_loop = data[4]   # AI3 → AO1 loopback (= actual DAQ output)
                current_hva1_monitor[] = hva1_mon
                current_hva2_monitor[] = hva2_mon
                current_ao0_read[]     = ao0_loop
                current_ao1_read[]     = ao1_loop
                hva1_monitor_label.text = "Mon HVA1: $(round(hva1_mon, digits=3)) V"
                hva2_monitor_label.text = "Mon HVA2: $(round(hva2_mon, digits=3)) V"
                hva1_loop_label.text    = "Loop HVA1: $(round(ao0_loop, digits=3)) V"
                hva2_loop_label.text    = "Loop HVA2: $(round(ao1_loop, digits=3)) V"
            catch e
                @error "HVA200 voltage apply failed"
                showerror(stdout, e, catch_backtrace())
                hva1_monitor_label.text = "Mon HVA1: ERROR"
                hva2_monitor_label.text = "Mon HVA2: ERROR"
            end
        end
    end

    # ── Sweep handler ─────────────────────────────────────────────────────────
    on(sweep_start_button.clicks) do _
        # toggle: if already running, stop
        if sweep_running[]
            sweep_running[] = false
            sweep_start_button.label = "Start Sweep"
            sweep_status_label.text  = "Stopped."
            return
        end

        !daq_ok && (sweep_status_label.text = "DAQ not available."; return)

        vstart = tryparse(Float64, sweep_vstart_textbox.displayed_string[])
        vstop  = tryparse(Float64, sweep_vstop_textbox.displayed_string[])
        nsteps = tryparse(Int,     sweep_steps_textbox.displayed_string[])
        settle = tryparse(Float64, sweep_settle_textbox.displayed_string[])
        if any(isnothing, (vstart, vstop, nsteps, settle))
            sweep_status_label.text = "Invalid params."
            return
        end
        nsteps = max(nsteps, 2)
        settle = max(settle, 0.0)

        voltages    = range(vstart, vstop; length = nsteps)
        sweep_chan  = sweep_chan_menu.selection[]
        sweep_pfx   = sweep_name_textbox.stored_string[]
        isempty(sweep_pfx) && (sweep_pfx = "sweep")

        sweep_running[]           = true
        sweep_start_button.label  = "Stop Sweep"
        sweep_status_label.text   = "Running…"

        @async begin
            for (i, v) in enumerate(voltages)
                !sweep_running[] && break

                sweep_status_label.text = "Step $i/$(length(voltages)): $(round(v, digits=4)) V"

                # ── apply voltage ──────────────────────────────────────────
                try
                    v1 = (sweep_chan == "HVA1" || sweep_chan == "Both") ? v : Float64(current_hva1_setpoint[])
                    v2 = (sweep_chan == "HVA2" || sweep_chan == "Both") ? v : Float64(current_hva2_setpoint[])
                    write_scalar(dao0, v1)
                    write_scalar(dao1, v2)
                    current_hva1_setpoint[] = v1
                    current_hva2_setpoint[] = v2

                    sleep(settle)   # wait for HVA and beam to settle

                    data = read(dai)
                    hva1_mon = data[1];  ao0_loop = data[2]
                    hva2_mon = data[3];  ao1_loop = data[4]
                    current_hva1_monitor[] = hva1_mon
                    current_hva2_monitor[] = hva2_mon
                    current_ao0_read[]     = ao0_loop
                    current_ao1_read[]     = ao1_loop
                    hva1_monitor_label.text = "Mon HVA1: $(round(hva1_mon, digits=3)) V"
                    hva2_monitor_label.text = "Mon HVA2: $(round(hva2_mon, digits=3)) V"
                    hva1_loop_label.text    = "Loop HVA1: $(round(ao0_loop, digits=3)) V"
                    hva2_loop_label.text    = "Loop HVA2: $(round(ao1_loop, digits=3)) V"
                catch e
                    @error "Sweep step $i: voltage apply failed"
                    showerror(stdout, e, catch_backtrace())
                    continue
                end

                # ── auto-save this step ────────────────────────────────────
                timestamp  = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
                step_label = "$(sweep_pfx)_step$(lpad(i, 3, '0'))_$(round(v, digits=4))V"
                h5_path    = joinpath(save_dir, "$(step_label)_$(timestamp).h5")
                frame_data = collect(Float64, frame_obs[])
                cx_val     = Float64(cx[]);  cy_val = Float64(cy[])

                try
                    h5open(h5_path, "w") do h5file
                        write(h5file, "frame", frame_data)
                        attrs(h5file)["beam_type"]       = string(beam_type[])
                        attrs(h5file)["center_x"]        = cx_val
                        attrs(h5file)["center_y"]        = cy_val
                        attrs(h5file)["timestamp"]       = timestamp
                        attrs(h5file)["sweep_step"]      = i
                        attrs(h5file)["sweep_voltage"]   = Float64(v)
                        attrs(h5file)["sweep_channel"]   = sweep_chan
                        attrs(h5file)["settle_time"]     = settle
                        attrs(h5file)["hva1_setpoint"]   = Float64(current_hva1_setpoint[])
                        attrs(h5file)["hva2_setpoint"]   = Float64(current_hva2_setpoint[])
                        attrs(h5file)["hva1_monitor"]    = Float64(current_hva1_monitor[])
                        attrs(h5file)["hva2_monitor"]    = Float64(current_hva2_monitor[])
                        attrs(h5file)["hva1_daq_output"] = Float64(current_ao0_read[])
                        attrs(h5file)["hva2_daq_output"] = Float64(current_ao1_read[])
                    end
                    println("Sweep step $i saved: $h5_path")
                catch e
                    @error "Sweep step $i: save failed"
                    showerror(stdout, e, catch_backtrace())
                end
            end

            if sweep_running[]
                sweep_status_label.text = "Done ($(length(voltages)) steps)."
            end
            sweep_running[]           = false
            sweep_start_button.label  = "Start Sweep"
        end
    end

    # ── Angle Stability handler ───────────────────────────────────────────────
    on(stab_start_button.clicks) do _
        if stab_running[]
            stab_running[] = false
            stab_start_button.label = "Start Stability"
            stab_status_label.text  = "Stopped."
            return
        end

        !daq_ok && (stab_status_label.text = "DAQ not available."; return)

        vstart   = tryparse(Float64, stab_vstart_textbox.displayed_string[])
        vstop    = tryparse(Float64, stab_vstop_textbox.displayed_string[])
        nsteps   = tryparse(Int,     stab_steps_textbox.displayed_string[])
        settle   = tryparse(Float64, stab_settle_textbox.displayed_string[])
        dwell    = tryparse(Float64, stab_dwell_textbox.displayed_string[])
        nframes  = tryparse(Int,     stab_frames_textbox.displayed_string[])
        if any(isnothing, (vstart, vstop, nsteps, settle, dwell, nframes))
            stab_status_label.text = "Invalid params."
            return
        end
        nsteps  = max(nsteps,  2);  nframes = max(nframes, 1)
        settle  = max(settle,  0.0); dwell   = max(dwell,  0.0)

        voltages   = range(vstart, vstop; length = nsteps)
        stab_chan  = stab_chan_menu.selection[]
        stab_pfx   = stab_name_textbox.stored_string[]
        isempty(stab_pfx) && (stab_pfx = "stability")
        frame_interval = nframes > 1 ? dwell / (nframes - 1) : dwell

        stab_running[]          = true
        stab_start_button.label = "Stop Stability"
        stab_status_label.text  = "Running…"

        @async begin
            for (i, v) in enumerate(voltages)
                !stab_running[] && break

                # ── apply voltage for this angle step ──────────────────────
                try
                    v1 = (stab_chan == "HVA1" || stab_chan == "Both") ? v : Float64(current_hva1_setpoint[])
                    v2 = (stab_chan == "HVA2" || stab_chan == "Both") ? v : Float64(current_hva2_setpoint[])
                    write_scalar(dao0, v1)
                    write_scalar(dao1, v2)
                    current_hva1_setpoint[] = v1
                    current_hva2_setpoint[] = v2
                    sleep(settle)
                    data = read(dai)
                    hva1_mon = data[1];  ao0_loop = data[2]
                    hva2_mon = data[3];  ao1_loop = data[4]
                    current_hva1_monitor[] = hva1_mon
                    current_hva2_monitor[] = hva2_mon
                    current_ao0_read[]     = ao0_loop
                    current_ao1_read[]     = ao1_loop
                    hva1_monitor_label.text = "Mon HVA1: $(round(hva1_mon, digits=3)) V"
                    hva2_monitor_label.text = "Mon HVA2: $(round(hva2_mon, digits=3)) V"
                    hva1_loop_label.text    = "Loop HVA1: $(round(ao0_loop, digits=3)) V"
                    hva2_loop_label.text    = "Loop HVA2: $(round(ao1_loop, digits=3)) V"
                catch e
                    @error "Stability step $i: voltage apply failed"
                    showerror(stdout, e, catch_backtrace())
                    continue
                end

                # ── record nframes at this angle ───────────────────────────
                for j in 1:nframes
                    !stab_running[] && break

                    stab_status_label.text = "Angle $i/$(length(voltages)) · Frame $j/$nframes  $(round(v, digits=4)) V"

                    timestamp  = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
                    fname      = "$(stab_pfx)_step$(lpad(i,3,'0'))_frame$(lpad(j,4,'0'))_$(round(v,digits=4))V_$(timestamp).h5"
                    h5_path    = joinpath(save_dir, fname)
                    frame_data = collect(Float64, frame_obs[])
                    cx_val     = Float64(cx[]);  cy_val = Float64(cy[])

                    try
                        h5open(h5_path, "w") do h5file
                            write(h5file, "frame", frame_data)
                            attrs(h5file)["beam_type"]           = string(beam_type[])
                            attrs(h5file)["center_x"]            = cx_val
                            attrs(h5file)["center_y"]            = cy_val
                            attrs(h5file)["timestamp"]           = timestamp
                            attrs(h5file)["sweep_step"]          = i
                            attrs(h5file)["sweep_voltage"]       = Float64(v)
                            attrs(h5file)["stability_frame"]     = j
                            attrs(h5file)["frames_per_position"] = nframes
                            attrs(h5file)["dwell_time"]          = dwell
                            attrs(h5file)["settle_time"]         = settle
                            attrs(h5file)["sweep_channel"]       = stab_chan
                            attrs(h5file)["hva1_setpoint"]       = Float64(current_hva1_setpoint[])
                            attrs(h5file)["hva2_setpoint"]       = Float64(current_hva2_setpoint[])
                            attrs(h5file)["hva1_monitor"]        = Float64(current_hva1_monitor[])
                            attrs(h5file)["hva2_monitor"]        = Float64(current_hva2_monitor[])
                            attrs(h5file)["hva1_daq_output"]     = Float64(current_ao0_read[])
                            attrs(h5file)["hva2_daq_output"]     = Float64(current_ao1_read[])
                        end
                        println("Stability $i/$j saved: $h5_path")
                    catch e
                        @error "Stability step $i frame $j: save failed"
                        showerror(stdout, e, catch_backtrace())
                    end

                    j < nframes && sleep(frame_interval)
                end
            end

            if stab_running[]
                stab_status_label.text = "Done ($(length(voltages)) angles)."
            end
            stab_running[]          = false
            stab_start_button.label = "Start Stability"
        end
    end

    # ── Save handler ──────────────────────────────────────────────────────────
    on(save_button.clicks) do _
        timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
        base_name = filename_textbox.stored_string[]
        if isempty(base_name)
            base_name = "beam_characterization"
        end
        h5_path  = joinpath(save_dir, "$(base_name)_$timestamp.h5")
        img_path = joinpath(save_dir, "$(base_name)_$timestamp.png")

        # snapshot all data as plain Arrays
        frame_data  = collect(Float64, frame_obs[])
        ideal_data  = collect(Float64, ideal_z[])
        optim_data  = collect(Float64, optimized[])
        diff_data   = collect(Float64, diff_img[])
        xprof_data  = collect(Float64, x_prof[])
        yprof_data  = collect(Float64, y_prof[])
        bt          = string(beam_type[])
        cx_val      = Float64(cx[])
        cy_val      = Float64(cy[])
        C_val       = Float64(C[])
        ω_val       = Float64(ω[])
        approx_r2   = coeff_of_determination(ideal_data, frame_data)
        optim_r2    = Float64(r_squared[])
        exp_time    = Float64(camera.exposure_time)
        min_pc      = Float64(minimum(frame_data))
        max_pc      = Float64(maximum(frame_data))
        position_val = tryparse(Float64, position_textbox.stored_string[])
        position_val = isnothing(position_val) ? 0.0 : position_val

        # HVA200 values at save time
        hva1_setpoint_val = Float64(current_hva1_setpoint[])  # voltage applied to DAQ (V)
        hva2_setpoint_val = Float64(current_hva2_setpoint[])
        hva1_monitor_val  = Float64(current_hva1_monitor[])   # AI0: HVA1 monitor reading (V)
        hva2_monitor_val  = Float64(current_hva2_monitor[])   # AI2: HVA2 monitor reading (V)
        hva1_daq_val      = Float64(current_ao0_read[])       # AI1: AO0 loopback (V)
        hva2_daq_val      = Float64(current_ao1_read[])       # AI3: AO1 loopback (V)

        # beam quality metrics
        ext_ratio_val  = 0.0
        fwhm_x_val     = 0.0
        fwhm_y_val     = 0.0
        ellipticity_val = 0.0
        if beam_type[] == :donut
            try
                _, _, high_xs, high_ys = find_center_donut(frame_data)
                ext_ratio_val = extinction_ratio(frame_data, cx_val, cy_val, high_xs, high_ys)
            catch; end
        else
            fwhm_x_val, fwhm_y_val = compute_fwhm(frame_data, cx_val, cy_val)
            ellipticity_val = max(fwhm_x_val, fwhm_y_val) / max(min(fwhm_x_val, fwhm_y_val), 1.0)
        end

        @async begin
            try
                h5open(h5_path, "w") do h5file
                    write(h5file, "frame",        frame_data)
                    write(h5file, "ideal_fit",    ideal_data)
                    if any(optim_data .!= 0)
                        write(h5file, "optimized_fit", optim_data)
                    end
                    write(h5file, "difference",   diff_data)
                    write(h5file, "x_profile",    xprof_data)
                    write(h5file, "y_profile",    yprof_data)
                    # metadata
                    attrs(h5file)["beam_type"]         = bt
                    attrs(h5file)["center_x"]          = cx_val
                    attrs(h5file)["center_y"]          = cy_val
                    attrs(h5file)["C"]                 = C_val
                    attrs(h5file)["omega"]             = ω_val
                    attrs(h5file)["approx_r_squared"]  = approx_r2
                    attrs(h5file)["optim_r_squared"]   = optim_r2
                    attrs(h5file)["exposure_time"]     = exp_time
                    attrs(h5file)["min_photon_count"]  = min_pc
                    attrs(h5file)["max_photon_count"]  = max_pc
                    attrs(h5file)["timestamp"]         = timestamp
                    attrs(h5file)["position"]          = position_val
                    # HVA200 voltages
                    attrs(h5file)["hva1_setpoint"]   = hva1_setpoint_val  # applied DAQ V (user input)
                    attrs(h5file)["hva2_setpoint"]   = hva2_setpoint_val
                    attrs(h5file)["hva1_monitor"]    = hva1_monitor_val   # AI0 monitor reading (V)
                    attrs(h5file)["hva2_monitor"]    = hva2_monitor_val   # AI2 monitor reading (V)
                    attrs(h5file)["hva1_daq_output"] = hva1_daq_val       # AI1 loopback (V)
                    attrs(h5file)["hva2_daq_output"] = hva2_daq_val       # AI3 loopback (V)
                    # beam quality
                    if beam_type[] == :donut
                        attrs(h5file)["extinction_ratio"] = ext_ratio_val
                    else
                        attrs(h5file)["fwhm_x"]       = fwhm_x_val
                        attrs(h5file)["fwhm_y"]       = fwhm_y_val
                        attrs(h5file)["ellipticity"]  = ellipticity_val
                    end
                end
                println("Saved HDF5 data to $h5_path")
            catch e
                @error "Failed to save HDF5 file"
                showerror(stdout, e, catch_backtrace())
            end
            try
                save(img_path, fig)
                println("Saved screenshot to $img_path")
            catch e
                @error "Failed to save image"
                showerror(stdout, e, catch_backtrace())
            end
        end
    end

    # ── Display and cleanup ───────────────────────────────────────────────────
    display(fig)
    window_closer(fig, () -> begin
        shutdown(camera)
        if daq_ok
            try
                write_scalar(dao0, 0.0); write_scalar(dao1, 0.0)
                stop!(dao0); stop!(dao1); stop!(dai)
                clear!(dao0); clear!(dao1); clear!(dai)
            catch; end
        end
    end)

    # ── Keyboard shortcuts ────────────────────────────────────────────────────
    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.s
                notify(save_button.clicks)
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.m
                if beam_type[] == :donut
                    beam_menu.selection[] = "Gaussian"
                    beam_type[] = :gaussian
                else
                    beam_menu.selection[] = "Donut"
                    beam_type[] = :donut
                end
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.r
                notify(refresh_optim.clicks)
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.n
                filename_textbox.focused[] = true
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.p
                position_textbox.focused[] = true
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.v
                notify(apply_voltage_button.clicks)
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.one
                hva1_textbox.focused[] = true
            end
            if ispressed(fig, Keyboard.left_control) && event.key == Keyboard.two
                hva2_textbox.focused[] = true
            end
        end
        return Consume(false)
    end

    # ── Reactive observables ──────────────────────────────────────────────────
    r_grid = lift(cx, cy) do cx, cy
        sqrt.((x_grid .- cx).^2 .+ (y_grid .- cy).^2)
    end
    ideal_z = lift(C, ω, r_grid, frame_obs, beam_type) do C, ω, r_grid, frame_obs, bt
        bg = set_baseline(frame_obs; frac = 0.05)
        if bt == :donut
            C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ bg
        else
            C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .+ bg
        end
    end
    diff_img = lift(ideal_z, frame_obs) do ideal_z, frame_obs
        ideal_z .- frame_obs
    end

    # ── Plots ─────────────────────────────────────────────────────────────────
    photon_count_label = Label(left_panel[1, 1, Top()],
        "Min Photon Count: 0  Max Photon Count: 0", fontsize = 14, halign = :left, padding = (5, 0, 0, 0))

    heatmap!(ax2d, frame_obs, colormap = :inferno)
    scatter!(ax2d, cx, cy, color = :teal, markersize = 10)
    surface!(ax3d, x, y, frame_obs;   colormap = :viridis,          visible = real_3d_toggle.active)
    surface!(ax3d, x, y, ideal_z;     colormap = (:greys, 0.6),     overdraw = false, visible = fit_toggle.active)
    surface!(ax3d, x, y, diff_img;    colormap = (:bone, 0.6),      overdraw = true,  visible = diff_toggle.active)
    surface!(ax3d, x, y, optimized;   colormap = (:blues, 0.6),     overdraw = false, visible = optimized_toggle.active)
    lines!(y_profile_ax, y_prof,       color = :red)
    lines!(x_profile_ax, x_prof,       color = :blue)
    lines!(y_profile_ax, y_prof_ideal, color = :grey,        visible = fit_toggle.active)
    lines!(x_profile_ax, x_prof_ideal, color = :grey,        visible = fit_toggle.active)
    lines!(x_profile_ax, x_prof_optim, color = :deepskyblue, visible = optimized_toggle.active)
    lines!(y_profile_ax, y_prof_optim, color = :deepskyblue, visible = optimized_toggle.active)

    # ── Camera loop ───────────────────────────────────────────────────────────
    @async begin
        while Bool(camera.is_running) == 1
            frame = getlastframe(camera)'
            if frame !== nothing
                frame_obs[] = frame
                duration = round(time() - start, digits = 2)
                ax2d.title = "Live Camera Feed - Time: $duration seconds"
                photon_count_label.text = "Min Photon Count: $(minimum(frame))  Max Photon Count: $(maximum(frame))"
                approx_r2_label.text = "Approximate Fit R^2: $(round(coeff_of_determination(ideal_z[], frame_obs[]), digits = 4))"

                if beam_type[] == :donut
                    cx[], cy[], high_xs, high_ys = find_center_donut(frame)
                    C[], ω[] = set_constants_donut(frame, cx[], cy[], high_xs, high_ys)
                else
                    cx[], cy[] = find_center_gaussian(frame)
                    C[], ω[] = set_constants_gaussian(frame, cx[], cy[])
                end

                y_prof[]       = frame[:, round(Int, cy[])]
                x_prof[]       = frame[round(Int, cx[]), :]
                y_prof_ideal[] = ideal_z[][:, round(Int, cy[])]
                x_prof_ideal[] = ideal_z[][round(Int, cx[]), :]
                y_prof_optim[] = optimized[][:, round(Int, cy[])]
                x_prof_optim[] = optimized[][round(Int, cx[]), :]
            end
            sleep(1/framerate)
        end
    end

    return fig, ax2d, ax3d, frame_obs
end

# ============================================================================
# Shared helper functions  (identical to beam_char_save.jl)
# ============================================================================

function set_baseline(frame; frac = 0.1)
    thresh = quantile(vec(frame), frac)
    coords = findall(<=(thresh), frame)
    sum = 0
    for coord in coords
        sum += frame[coord[1], coord[2]]
    end
    return sum / length(coords)
end

function coeff_of_determination(ideal_z, data)
    r_sum = 0;  tot_sum = 0
    avg = mean(data)
    for i in eachindex(data)
        r_sum   += (data[i] - ideal_z[i]) ^ 2
        tot_sum += (data[i] - avg) ^ 2
    end
    return 1 - (r_sum / tot_sum)
end

function insert_image(sub_img, cx, cy, bg, frame)
    int_cx = round(Int, cx);  int_cy = round(Int, cy)
    sub_img_size = size(sub_img)
    ideal_frame = zeros(size(frame)) .+ bg
    for i in 1:sub_img_size[1], j in 1:sub_img_size[2]
        ideal_frame[(int_cx - sub_img_size[1] ÷ 2) + i - 1,
                    (int_cy - sub_img_size[2] ÷ 2) + j - 1] = sub_img[i, j]
    end
    return ideal_frame
end

# ── Donut functions ──────────────────────────────────────────────────────────

function find_center_donut(frame; frac=0.002)
    thresh = quantile(vec(frame), 1 - frac)
    coords = findall(>=(thresh), frame)
    high_xs = [];  high_ys = []
    for coord in coords
        push!(high_xs, coord[1]);  push!(high_ys, coord[2])
    end
    return mean(high_xs), mean(high_ys), high_xs, high_ys
end

function set_constants_donut(frame, cx, cy, high_xs, high_ys; frac = 0.001)
    thresh = quantile(vec(frame), 1 - frac)
    coords = findall(>=(thresh), frame)
    bright_sum = 0
    for coord in coords
        bright_sum += frame[coord[1], coord[2]]
    end
    avg_high_intensity = bright_sum / length(coords) * 7
    beam_radius = ring_radius(high_xs, high_ys, cx, cy) * 0.85
    return avg_high_intensity, beam_radius
end

function ring_radius(xs, ys, cx, cy)
    dist_sum = 0
    for i in eachindex(xs)
        dist_sum += sqrt((xs[i] - cx)^2 + (ys[i] - cy)^2)
    end
    return dist_sum / length(xs)
end

function extinction_ratio(frame, cx, cy, high_xs, high_ys; subframe_size = 20)
    int_cx = round(Int, cx);  int_cy = round(Int, cy)
    x_range = max(int_cx - subframe_size ÷ 2, 1) : min(int_cx + subframe_size ÷ 2, size(frame, 1))
    y_range = max(int_cy - subframe_size ÷ 2, 1) : min(int_cy + subframe_size ÷ 2, size(frame, 2))
    sub_image = frame[x_range, y_range]
    func_to_min = inputs -> polysquare_err(inputs, sub_image)
    result = optimize(func_to_min,
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 1.0],
        Optim.Options(show_trace = false, iterations = 100000))
    println(result)
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O = Optim.minimizer(result)
    ideal_poly = polysquare_err([A, B, C, D, E, F, G, H, I, J, K, L, M, N, O], sub_image; return_ideal = true)
    bright_sum = 0
    for i in eachindex(high_xs)
        bright_sum += frame[high_xs[i], high_ys[i]]
    end
    bg = set_baseline(frame)
    avg_high  = bright_sum / length(high_xs) - bg
    poly_min  = abs(minimum(ideal_poly) - bg)
    return poly_min / avg_high
end

function polysquare_err(inputs::Vector{Float64}, data; return_ideal::Bool = false)
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O = inputs
    nx, ny = size(data)
    x = collect(1:nx);  y = collect(1:ny)
    x_grid = repeat(x, 1, ny);  y_grid = repeat(y', nx, 1)
    poly = A .+ B .* x_grid .+ C .* y_grid .+ D .* x_grid.^2 .+ E .* y_grid.^2 .+
           F .* x_grid .* y_grid .+ G .* x_grid.^3 .+ H .* y_grid.^3 .+
           I .* x_grid.^2 .* y_grid .+ J .* x_grid .* y_grid.^2 .+
           K .* x_grid.^4 .+ L .* y_grid.^4 .+ M .* x_grid.^2 .* y_grid.^2 +
           N .* x_grid.^3 .* y_grid + O .* x_grid .* y_grid.^3
    return_ideal ? poly : sum((data .- poly).^2)
end

function square_err_donut(inputs::Vector{Float64}, cx, cy, data, full_frame, return_ideal::Bool = false)
    C, ω, bg = inputs
    nx, ny = size(data)
    x = collect(1:nx);  y = collect(1:ny)
    x_grid = repeat(x, 1, ny);  y_grid = repeat(y', nx, 1)
    sub_cx = (nx + 1) / 2;  sub_cy = (ny + 1) / 2
    r_grid = sqrt.((x_grid .- sub_cx).^2 .+ (y_grid .- sub_cy).^2)
    ideal  = C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .* (r_grid ./ ω).^4 .+ bg
    return_ideal ? (insert_image(ideal, cx, cy, bg, full_frame), coeff_of_determination(ideal, data)) :
                   sum((data .- ideal).^2)
end

function characterize_donut(data, sub_frame_size = 100)
    guess_cx, guess_cy, xs, ys = find_center_donut(data)
    int_cx = round(Int, guess_cx);  int_cy = round(Int, guess_cy)
    guess_C, guess_ω = set_constants_donut(data, guess_cx, guess_cy, xs, ys)
    guess_bg = set_baseline(data; frac = 0.05)
    x_range = max(int_cx - sub_frame_size ÷ 2, 1) : min(int_cx + sub_frame_size ÷ 2, size(data, 1))
    y_range = max(int_cy - sub_frame_size ÷ 2, 1) : min(int_cy + sub_frame_size ÷ 2, size(data, 2))
    sub_image  = data[x_range, y_range]
    func_to_min = inputs -> square_err_donut(inputs, guess_cx, guess_cy, sub_image, data)
    result = optimize(func_to_min, [guess_C, guess_ω, guess_bg])
    println(result)
    C, ω, bg = Optim.minimizer(result)
    return square_err_donut([C, ω, bg], guess_cx, guess_cy, sub_image, data, true)
end

# ── Gaussian functions ───────────────────────────────────────────────────────

function find_center_gaussian(frame)
    peak_idx = argmax(frame)
    return Float64(peak_idx[1]), Float64(peak_idx[2])
end

function set_constants_gaussian(frame, _cx, cy)
    bg  = set_baseline(frame; frac = 0.05)
    C   = maximum(frame) - bg
    int_cy  = clamp(round(Int, cy), 1, size(frame, 2))
    profile = frame[:, int_cy]
    half_max = (maximum(profile) + bg) / 2
    above    = findall(>=(half_max), profile)
    ω = length(above) >= 2 ? (above[end] - above[1]) / (2 * sqrt(log(2))) : 50.0
    return C, ω
end

function square_err_gaussian(inputs::Vector{Float64}, cx, cy, data, full_frame, return_ideal::Bool = false)
    C, ω, bg = inputs
    nx, ny = size(data)
    x = collect(1:nx);  y = collect(1:ny)
    x_grid = repeat(x, 1, ny);  y_grid = repeat(y', nx, 1)
    sub_cx = (nx + 1) / 2;  sub_cy = (ny + 1) / 2
    r_grid = sqrt.((x_grid .- sub_cx).^2 .+ (y_grid .- sub_cy).^2)
    ideal  = C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .+ bg
    return_ideal ? (insert_image(ideal, cx, cy, bg, full_frame), coeff_of_determination(ideal, data)) :
                   sum((data .- ideal).^2)
end

function characterize_gaussian(data, sub_frame_size = 100)
    guess_cx, guess_cy = find_center_gaussian(data)
    int_cx = round(Int, guess_cx);  int_cy = round(Int, guess_cy)
    guess_C, guess_ω = set_constants_gaussian(data, guess_cx, guess_cy)
    guess_bg = set_baseline(data; frac = 0.05)
    x_range = max(int_cx - sub_frame_size ÷ 2, 1) : min(int_cx + sub_frame_size ÷ 2, size(data, 1))
    y_range = max(int_cy - sub_frame_size ÷ 2, 1) : min(int_cy + sub_frame_size ÷ 2, size(data, 2))
    sub_image   = data[x_range, y_range]
    func_to_min = inputs -> square_err_gaussian(inputs, guess_cx, guess_cy, sub_image, data)
    result = optimize(func_to_min, [guess_C, guess_ω, guess_bg])
    println(result)
    C, ω, bg = Optim.minimizer(result)
    return square_err_gaussian([C, ω, bg], guess_cx, guess_cy, sub_image, data, true)
end

function compute_fwhm(frame, cx, cy)
    int_cx = clamp(round(Int, cx), 1, size(frame, 1))
    int_cy = clamp(round(Int, cy), 1, size(frame, 2))
    bg = set_baseline(frame; frac = 0.05)

    x_profile  = frame[:, int_cy]
    x_half_max = (maximum(x_profile) + bg) / 2
    x_above    = findall(>=(x_half_max), x_profile)
    fwhm_x     = length(x_above) >= 2 ? Float64(x_above[end] - x_above[1]) : 0.0

    y_profile  = frame[int_cx, :]
    y_half_max = (maximum(y_profile) + bg) / 2
    y_above    = findall(>=(y_half_max), y_profile)
    fwhm_y     = length(y_above) >= 2 ? Float64(y_above[end] - y_above[1]) : 0.0

    return fwhm_x, fwhm_y
end

# To run:
# camera = ThorcamDCXCamera()
# beam_characterization(camera)
#
# If tasks are left reserved after a crash, clear them manually in the REPL:
# using DAQmx
# ao0 = AOTask("Dev2/ao0"); ao1 = AOTask("Dev2/ao1")
# ai  = AITask("Dev2/ai0, Dev2/ai1, Dev2/ai2, Dev2/ai3")
# stop!(ao0); stop!(ao1); stop!(ai)
# clear!(ao0); clear!(ao1); clear!(ai)
