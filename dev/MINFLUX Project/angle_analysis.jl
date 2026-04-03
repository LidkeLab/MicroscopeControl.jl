# Angle analysis
# ODE1: hva1_daq_output and hva1_monitor vs center_x / center_y
# ODE2: hva2_daq_output and hva2_monitor vs center_x / center_y
# Control file shown as a reference point on every plot.

using HDF5, GLMakie, Statistics, FFTW

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/angle/apr_1"

# ============================================================================
# Data loading
# ============================================================================

struct AngleMeasurement
    hva1_daq::Float64
    hva1_monitor::Float64
    hva2_daq::Float64
    hva2_monitor::Float64
    center_x::Float64
    center_y::Float64
    fwhm_x::Float64
    fwhm_y::Float64
    ellipticity::Float64
    frame::Matrix{Float64}
end

# ── FWHM helpers (profile-based) ─────────────────────────────────────────────
function _background(frame; frac = 0.05)
    thresh = quantile(vec(frame), frac)
    return mean(filter(<=(thresh), vec(frame)))
end

function _fit_fwhm(frame)
    idx = argmax(frame)
    cx, cy = idx[1], idx[2]
    bg = _background(frame)
    xprof = max.(frame[:, cy] .- bg, 0.0)
    x_above = findall(>=(maximum(xprof) / 2), xprof)
    fwhm_x = length(x_above) >= 2 ? Float64(x_above[end] - x_above[1]) : 0.0
    yprof = max.(frame[cx, :] .- bg, 0.0)
    y_above = findall(>=(maximum(yprof) / 2), yprof)
    fwhm_y = length(y_above) >= 2 ? Float64(y_above[end] - y_above[1]) : 0.0
    ellip  = max(fwhm_x, fwhm_y) / max(min(fwhm_x, fwhm_y), 1.0)
    return fwhm_x, fwhm_y, ellip
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_angle_data(dir)
    groups = Dict{String, Vector{AngleMeasurement}}()

    # folder structure: EOD34/ → ODE1 (HVA1), EOD35/ → ODE2 (HVA2)
    subdirs = sort(filter(d -> isdir(joinpath(dir, d)), readdir(dir)))
    println("  Found subfolders: $subdirs")

    for subdir in subdirs
        group = if occursin("34", subdir)
            "ODE1"
        elseif occursin("35", subdir)
            "ODE2"
        else
            @warn "Unmatched subfolder (skipping): $subdir"
            continue
        end

        folder  = joinpath(dir, subdir)
        allfiles = sort(filter(f -> endswith(f, ".h5"), readdir(folder)))
        ctrl_files  = filter(f -> startswith(lowercase(f), "control"), allfiles)
        sweep_files = filter(f -> !startswith(lowercase(f), "control"), allfiles)
        println("  $subdir → $group: $(length(sweep_files)) sweep + $(length(ctrl_files)) control")

        ctrl_group = "$(group)_Control"

        for (fnames, dest) in ((sweep_files, group), (ctrl_files, ctrl_group))
            for fname in fnames
                try
                    h5open(joinpath(folder, fname), "r") do f
                        frame = read(f["frame"])

                        cx = read_attr(f, "center_x", NaN)
                        cy = read_attr(f, "center_y", NaN)
                        if isnan(cx) || isnan(cy)
                            idx = argmax(frame)
                            cx, cy = Float64(idx[1]), Float64(idx[2])
                        end

                        frame_f = Float64.(frame)
                        fwhm_x, fwhm_y, ellip = _fit_fwhm(frame_f)
                        m = AngleMeasurement(
                            read_attr(f, "hva1_daq_output"),
                            read_attr(f, "hva1_monitor"),
                            read_attr(f, "hva2_daq_output"),
                            read_attr(f, "hva2_monitor"),
                            cx, cy, fwhm_x, fwhm_y, ellip, frame_f
                        )
                        push!(get!(groups, dest, AngleMeasurement[]), m)
                    end
                    print(".")
                catch e
                    @warn "Skipping $fname: $e"
                end
            end
        end
        println()
    end

    for (gkey, v) in groups
        sort!(v, by = gkey == "ODE2" ? (m -> m.hva2_daq) : (m -> m.hva1_daq))
    end
    return groups
end

# ============================================================================
# Plot helpers
# ============================================================================

function add_control_point!(ax, ctrl_meas, volt_fn)
    isempty(ctrl_meas) && return
    cv = mean(volt_fn(m) for m in ctrl_meas)
    # delta is always 0 at control (reference subtracted)
    scatter!(ax, [cv], [0.0];
             color = :gray30, marker = :diamond, markersize = 16,
             label = "Control")
end

# ============================================================================
# Main plot — one figure per ODE group
# ============================================================================

function plot_angle(groups, dir)
    ctrl = get(groups, "Control", AngleMeasurement[])

    # reference center from control (delta = value - ref)
    ref_x = isempty(ctrl) ? 0.0 : mean(m.center_x for m in ctrl)
    ref_y = isempty(ctrl) ? 0.0 : mean(m.center_y for m in ctrl)

    configs = [
        ("ODE1", m -> m.hva1_daq, m -> m.hva1_monitor, "HVA1"),
        ("ODE2", m -> m.hva2_daq, m -> m.hva2_monitor, "HVA2"),
    ]

    for (gkey, daq_fn, mon_fn, prefix) in configs
        meas = get(groups, gkey, AngleMeasurement[])
        isempty(meas) && (@warn "No data for $gkey"; continue)

        daq_v  =  daq_fn.(meas)
        mon_v  = -mon_fn.(meas)   # monitor is inverted — negate to correct
        cx_abs = [m.center_x for m in meas]
        cy_abs = [m.center_y for m in meas]
        cx_del = cx_abs .- ref_x
        cy_del = cy_abs .- ref_y

        # shared legend elements
        legend_elems = [
            [MarkerElement(color = :steelblue, marker = :circle, markersize = 10),
             LineElement(color = :steelblue)],
            [MarkerElement(color = :tomato, marker = :circle, markersize = 10),
             LineElement(color = :tomato)],
        ]
        legend_labels = ["DAQ Output", "Monitor"]
        if !isempty(ctrl)
            push!(legend_elems,  [MarkerElement(color = :gray30, marker = :diamond, markersize = 16)])
            push!(legend_labels, "Control")
        end

        # ── Figure 1: absolute center ──────────────────────────────────────
        fig_abs = Figure(size = (900, 750))
        Label(fig_abs[0, 1:2], "$gkey — Absolute Beam Center vs $prefix Voltage";
              fontsize = 16, font = :bold, tellwidth = false)

        ax1 = Axis(fig_abs[1, 1], title = "$prefix DAQ vs Center X",
                   xlabel = "$prefix DAQ Output (V)", ylabel = "Center X (px)")
        ax2 = Axis(fig_abs[1, 2], title = "$prefix DAQ vs Center Y",
                   xlabel = "$prefix DAQ Output (V)", ylabel = "Center Y (px)")
        ax3 = Axis(fig_abs[2, 1], title = "$prefix Monitor vs Center X",
                   xlabel = "$prefix Monitor (V)", ylabel = "Center X (px)")
        ax4 = Axis(fig_abs[2, 2], title = "$prefix Monitor vs Center Y",
                   xlabel = "$prefix Monitor (V)", ylabel = "Center Y (px)")

        scatterlines!(ax1, daq_v, cx_abs; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax2, daq_v, cy_abs; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax3, mon_v, cx_abs; color = :tomato,    marker = :circle, markersize = 10)
        scatterlines!(ax4, mon_v, cy_abs; color = :tomato,    marker = :circle, markersize = 10)

        # control absolute point
        if !isempty(ctrl)
            cx_ctrl = mean(m.center_x for m in ctrl)
            cy_ctrl = mean(m.center_y for m in ctrl)
            ctrl_daq_v = mean( daq_fn(m) for m in ctrl)
            ctrl_mon_v = mean(-mon_fn(m) for m in ctrl)
            scatter!(ax1, [ctrl_daq_v], [cx_ctrl]; color = :gray30, marker = :diamond, markersize = 16)
            scatter!(ax2, [ctrl_daq_v], [cy_ctrl]; color = :gray30, marker = :diamond, markersize = 16)
            scatter!(ax3, [ctrl_mon_v], [cx_ctrl]; color = :gray30, marker = :diamond, markersize = 16)
            scatter!(ax4, [ctrl_mon_v], [cy_ctrl]; color = :gray30, marker = :diamond, markersize = 16)
        end

        Legend(fig_abs[3, 1:2], legend_elems, legend_labels, "$prefix Channel";
               orientation = :horizontal, framevisible = true)
        display(fig_abs)
        outpath_abs = joinpath(dir, "$(gkey)_angle_absolute.png")
        save(outpath_abs, fig_abs)
        println("Saved: $outpath_abs")

        # ── Figure 2: delta center (relative to control) ───────────────────
        fig_del = Figure(size = (900, 750))
        Label(fig_del[0, 1:2], "$gkey — ΔBeam Center vs $prefix Voltage (ref = control)";
              fontsize = 16, font = :bold, tellwidth = false)

        ax5 = Axis(fig_del[1, 1], title = "$prefix DAQ vs ΔCenter X",
                   xlabel = "$prefix DAQ Output (V)", ylabel = "ΔCenter X (px)")
        ax6 = Axis(fig_del[1, 2], title = "$prefix DAQ vs ΔCenter Y",
                   xlabel = "$prefix DAQ Output (V)", ylabel = "ΔCenter Y (px)")
        ax7 = Axis(fig_del[2, 1], title = "$prefix Monitor vs ΔCenter X",
                   xlabel = "$prefix Monitor (V)", ylabel = "ΔCenter X (px)")
        ax8 = Axis(fig_del[2, 2], title = "$prefix Monitor vs ΔCenter Y",
                   xlabel = "$prefix Monitor (V)", ylabel = "ΔCenter Y (px)")

        scatterlines!(ax5, daq_v, cx_del; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax6, daq_v, cy_del; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax7, mon_v, cx_del; color = :tomato,    marker = :circle, markersize = 10)
        scatterlines!(ax8, mon_v, cy_del; color = :tomato,    marker = :circle, markersize = 10)

        add_control_point!(ax5, ctrl, daq_fn)
        add_control_point!(ax6, ctrl, daq_fn)
        add_control_point!(ax7, ctrl, m -> -mon_fn(m))
        add_control_point!(ax8, ctrl, m -> -mon_fn(m))

        Legend(fig_del[3, 1:2], legend_elems, legend_labels, "$prefix Channel";
               orientation = :horizontal, framevisible = true)
        display(fig_del)
        outpath_del = joinpath(dir, "$(gkey)_angle_delta.png")
        save(outpath_del, fig_del)
        println("Saved: $outpath_del")
    end
end

# ============================================================================
# Beam quality vs center displacement
# ============================================================================

function plot_beam_quality(groups, dir)
    ctrl = get(groups, "Control", AngleMeasurement[])

    # control reference quality (mean)
    ctrl_fx = isempty(ctrl) ? NaN : mean(m.fwhm_x      for m in ctrl)
    ctrl_fy = isempty(ctrl) ? NaN : mean(m.fwhm_y      for m in ctrl)
    ctrl_el = isempty(ctrl) ? NaN : mean(m.ellipticity  for m in ctrl)

    palette = Dict("ODE1" => :steelblue, "ODE2" => :tomato)

    for gkey in ("ODE1", "ODE2")
        meas = get(groups, gkey, AngleMeasurement[])
        isempty(meas) && continue

        c      = get(palette, gkey, :black)
        prefix = gkey == "ODE1" ? "HVA1" : "HVA2"
        daq_fn = gkey == "ODE1" ? (m -> m.hva1_daq)     : (m -> m.hva2_daq)
        mon_fn = gkey == "ODE1" ? (m -> -m.hva1_monitor) : (m -> -m.hva2_monitor)

        cx_raw  = [m.center_x for m in meas]
        cy_raw  = [m.center_y for m in meas]
        fxs     = [m.fwhm_x   for m in meas]
        fys     = [m.fwhm_y   for m in meas]
        els     = [m.ellipticity for m in meas]
        daq_v   = daq_fn.(meas)
        mon_v   = mon_fn.(meas)

        ctrl_daq_v = isempty(ctrl) ? NaN : mean(daq_fn(m) for m in ctrl)
        ctrl_mon_v = isempty(ctrl) ? NaN : mean(mon_fn(m) for m in ctrl)
        ctrl_cx    = isempty(ctrl) ? NaN : mean(m.center_x for m in ctrl)
        ctrl_cy    = isempty(ctrl) ? NaN : mean(m.center_y for m in ctrl)

        # ── Figure 1: beam quality vs center position ──────────────────────
        fig1 = Figure(size = (1100, 700))
        Label(fig1[0, 1:3], "$gkey — Beam Quality vs Center Position";
              fontsize = 16, font = :bold, tellwidth = false)

        ax_x1 = Axis(fig1[1, 1], title = "FWHM X vs Center X",
                     xlabel = "Center X (px)", ylabel = "FWHM X (px)")
        ax_x2 = Axis(fig1[1, 2], title = "FWHM Y vs Center X",
                     xlabel = "Center X (px)", ylabel = "FWHM Y (px)")
        ax_x3 = Axis(fig1[1, 3], title = "Ellipticity vs Center X",
                     xlabel = "Center X (px)", ylabel = "Ellipticity")
        ax_y1 = Axis(fig1[2, 1], title = "FWHM X vs Center Y",
                     xlabel = "Center Y (px)", ylabel = "FWHM X (px)")
        ax_y2 = Axis(fig1[2, 2], title = "FWHM Y vs Center Y",
                     xlabel = "Center Y (px)", ylabel = "FWHM Y (px)")
        ax_y3 = Axis(fig1[2, 3], title = "Ellipticity vs Center Y",
                     xlabel = "Center Y (px)", ylabel = "Ellipticity")

        scatterlines!(ax_x1, cx_raw, fxs; color = c, marker = :circle, markersize = 10)
        scatterlines!(ax_x2, cx_raw, fys; color = c, marker = :circle, markersize = 10)
        scatterlines!(ax_x3, cx_raw, els; color = c, marker = :circle, markersize = 10)
        scatterlines!(ax_y1, cy_raw, fxs; color = c, marker = :circle, markersize = 10)
        scatterlines!(ax_y2, cy_raw, fys; color = c, marker = :circle, markersize = 10)
        scatterlines!(ax_y3, cy_raw, els; color = c, marker = :circle, markersize = 10)

        if !isnan(ctrl_fx)
            for ax in (ax_x1, ax_y1); hlines!(ax, [ctrl_fx]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            for ax in (ax_x2, ax_y2); hlines!(ax, [ctrl_fy]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            for ax in (ax_x3, ax_y3); hlines!(ax, [ctrl_el]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            if !isnan(ctrl_cx)
                for (ax, yv) in ((ax_x1, ctrl_fx), (ax_x2, ctrl_fy), (ax_x3, ctrl_el))
                    scatter!(ax, [ctrl_cx], [yv]; color = :gray30, marker = :diamond, markersize = 14)
                end
            end
            if !isnan(ctrl_cy)
                for (ax, yv) in ((ax_y1, ctrl_fx), (ax_y2, ctrl_fy), (ax_y3, ctrl_el))
                    scatter!(ax, [ctrl_cy], [yv]; color = :gray30, marker = :diamond, markersize = 14)
                end
            end
        end

        display(fig1)
        out1 = joinpath(dir, "$(gkey)_beam_quality.png")
        save(out1, fig1)
        println("Saved: $out1")

        # ── Figure 2: beam quality vs applied voltage ──────────────────────
        fig2 = Figure(size = (1100, 700))
        Label(fig2[0, 1:3], "$gkey — Beam Quality vs $prefix Voltage";
              fontsize = 16, font = :bold, tellwidth = false)

        ax_d1 = Axis(fig2[1, 1], title = "FWHM X vs $prefix DAQ",
                     xlabel = "$prefix DAQ Output (V)", ylabel = "FWHM X (px)")
        ax_d2 = Axis(fig2[1, 2], title = "FWHM Y vs $prefix DAQ",
                     xlabel = "$prefix DAQ Output (V)", ylabel = "FWHM Y (px)")
        ax_d3 = Axis(fig2[1, 3], title = "Ellipticity vs $prefix DAQ",
                     xlabel = "$prefix DAQ Output (V)", ylabel = "Ellipticity")
        ax_m1 = Axis(fig2[2, 1], title = "FWHM X vs $prefix Monitor",
                     xlabel = "$prefix Monitor (V)", ylabel = "FWHM X (px)")
        ax_m2 = Axis(fig2[2, 2], title = "FWHM Y vs $prefix Monitor",
                     xlabel = "$prefix Monitor (V)", ylabel = "FWHM Y (px)")
        ax_m3 = Axis(fig2[2, 3], title = "Ellipticity vs $prefix Monitor",
                     xlabel = "$prefix Monitor (V)", ylabel = "Ellipticity")

        scatterlines!(ax_d1, daq_v, fxs; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax_d2, daq_v, fys; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax_d3, daq_v, els; color = :steelblue, marker = :circle, markersize = 10)
        scatterlines!(ax_m1, mon_v, fxs; color = :tomato,    marker = :circle, markersize = 10)
        scatterlines!(ax_m2, mon_v, fys; color = :tomato,    marker = :circle, markersize = 10)
        scatterlines!(ax_m3, mon_v, els; color = :tomato,    marker = :circle, markersize = 10)

        if !isnan(ctrl_fx)
            for ax in (ax_d1, ax_m1); hlines!(ax, [ctrl_fx]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            for ax in (ax_d2, ax_m2); hlines!(ax, [ctrl_fy]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            for ax in (ax_d3, ax_m3); hlines!(ax, [ctrl_el]; color = (:gray30, 0.8), linestyle = :dash, linewidth = 2); end
            if !isnan(ctrl_daq_v)
                for (ax, yv) in ((ax_d1, ctrl_fx), (ax_d2, ctrl_fy), (ax_d3, ctrl_el))
                    scatter!(ax, [ctrl_daq_v], [yv]; color = :gray30, marker = :diamond, markersize = 14)
                end
            end
            if !isnan(ctrl_mon_v)
                for (ax, yv) in ((ax_m1, ctrl_fx), (ax_m2, ctrl_fy), (ax_m3, ctrl_el))
                    scatter!(ax, [ctrl_mon_v], [yv]; color = :gray30, marker = :diamond, markersize = 14)
                end
            end
        end

        display(fig2)
        out2 = joinpath(dir, "$(gkey)_beam_quality_voltage.png")
        save(out2, fig2)
        println("Saved: $out2")
    end
end

# ============================================================================
# Displacement distance vs voltage
# ============================================================================

function plot_distance_vs_voltage(groups, dir)
    ctrl = get(groups, "Control", AngleMeasurement[])
    ref_x = isempty(ctrl) ? 0.0 : mean(m.center_x for m in ctrl)
    ref_y = isempty(ctrl) ? 0.0 : mean(m.center_y for m in ctrl)

    palette = Dict("ODE1" => (:steelblue, :circle), "ODE2" => (:tomato, :rect))

    for gkey in ("ODE1", "ODE2")
        meas = get(groups, gkey, AngleMeasurement[])
        isempty(meas) && continue

        c, mk  = palette[gkey]
        prefix = gkey == "ODE1" ? "HVA1" : "HVA2"
        daq_fn = gkey == "ODE1" ? (m -> m.hva1_daq)      : (m -> m.hva2_daq)
        mon_fn = gkey == "ODE1" ? (m -> -m.hva1_monitor)  : (m -> -m.hva2_monitor)

        dist   = [sqrt((m.center_x - ref_x)^2 + (m.center_y - ref_y)^2) for m in meas]
        daq_v  = daq_fn.(meas)
        mon_v  = mon_fn.(meas)

        ctrl_daq_v = isempty(ctrl) ? NaN : mean(daq_fn(m) for m in ctrl)
        ctrl_mon_v = isempty(ctrl) ? NaN : mean(mon_fn(m) for m in ctrl)

        fig = Figure(size = (900, 450))
        Label(fig[0, 1:2], "$gkey — Beam Displacement Distance vs $prefix Voltage";
              fontsize = 16, font = :bold, tellwidth = false)

        ax_d = Axis(fig[1, 1], title = "Distance vs $prefix DAQ Output",
                    xlabel = "$prefix DAQ Output (V)",
                    ylabel = "Distance √(ΔX² + ΔY²) (px)")
        ax_m = Axis(fig[1, 2], title = "Distance vs $prefix Monitor",
                    xlabel = "$prefix Monitor (V)",
                    ylabel = "Distance √(ΔX² + ΔY²) (px)")

        scatterlines!(ax_d, daq_v, dist; color = c, marker = mk, markersize = 10)
        scatterlines!(ax_m, mon_v, dist; color = c, marker = mk, markersize = 10)

        if !isnan(ctrl_daq_v)
            scatter!(ax_d, [ctrl_daq_v], [0.0]; color = :gray30, marker = :diamond, markersize = 14)
        end
        if !isnan(ctrl_mon_v)
            scatter!(ax_m, [ctrl_mon_v], [0.0]; color = :gray30, marker = :diamond, markersize = 14)
        end

        display(fig)
        outpath = joinpath(dir, "$(gkey)_distance_vs_voltage.png")
        save(outpath, fig)
        println("Saved: $outpath")
    end
end

# ============================================================================
# Cross-correlation beam quality vs angle deflection
# ============================================================================

function _xcorr2d(ref, frame)
    r  = ref   .- mean(ref)
    f  = frame .- mean(frame)
    cc = real(ifft(fft(r) .* conj(fft(f))))
    denom = sqrt(sum(r .^ 2) * sum(f .^ 2))
    return denom > 0 ? fftshift(cc) ./ denom : fftshift(cc)
end

function _xcorr_metrics(ref, frame)
    cc = _xcorr2d(ref, frame)
    nx, ny = size(cc)
    cx0, cy0 = nx ÷ 2 + 1, ny ÷ 2 + 1

    peak_val = maximum(cc)
    pidx     = argmax(cc)
    dx       = Float64(pidx[1] - cx0)
    dy       = Float64(pidx[2] - cy0)

    half  = peak_val / 2
    ax_   = findall(>=(half), cc[:, pidx[2]])
    ay_   = findall(>=(half), cc[pidx[1], :])
    fwhm_x = length(ax_) >= 2 ? Float64(ax_[end] - ax_[1]) : 0.0
    fwhm_y = length(ay_) >= 2 ? Float64(ay_[end] - ay_[1]) : 0.0
    fwhm_cc = (fwhm_x + fwhm_y) / 2

    return peak_val, fwhm_cc, dx, dy
end

function plot_xcorr_angle(groups, dir)
    palette = Dict("ODE1" => (:steelblue, :circle), "ODE2" => (:tomato, :rect))

    for gkey in ("ODE1", "ODE2")
        meas = get(groups, gkey, AngleMeasurement[])
        isempty(meas) && continue

        ctrl = get(groups, "$(gkey)_Control", AngleMeasurement[])
        if isempty(ctrl)
            @warn "No control for $gkey — skipping xcorr plot"
            continue
        end
        ref = mean(m.frame for m in ctrl)

        c, mk  = palette[gkey]
        prefix = gkey == "ODE1" ? "HVA1" : "HVA2"
        daq_fn = gkey == "ODE1" ? (m -> m.hva1_daq)      : (m -> m.hva2_daq)
        mon_fn = gkey == "ODE1" ? (m -> -m.hva1_monitor) : (m -> -m.hva2_monitor)

        daq_v = daq_fn.(meas)
        mon_v = mon_fn.(meas)

        peak_nccs = Float64[]
        fwhm_ccs  = Float64[]
        for m in meas
            p, fw, _, _ = _xcorr_metrics(ref, m.frame)
            push!(peak_nccs, p)
            push!(fwhm_ccs,  fw)
        end

        ctrl_daq_v  = mean(daq_fn(m) for m in ctrl)
        ctrl_mon_v  = mean(mon_fn(m) for m in ctrl)
        ctrl_p, ctrl_fw, _, _ = _xcorr_metrics(ref, mean(m.frame for m in ctrl))

        fig = Figure(size = (1000, 750))
        Label(fig[0, 1:2], "$gkey — Beam Quality (Cross-Correlation) vs $prefix Voltage";
              fontsize = 16, font = :bold, tellwidth = false)

        ax_nd = Axis(fig[1, 1], title = "Peak NCC vs $prefix DAQ",
                     xlabel = "$prefix DAQ Output (V)", ylabel = "Peak NCC (0–1)")
        ax_nm = Axis(fig[1, 2], title = "Peak NCC vs $prefix Monitor",
                     xlabel = "$prefix Monitor (V)",   ylabel = "Peak NCC (0–1)")
        ax_fd = Axis(fig[2, 1], title = "Xcorr FWHM vs $prefix DAQ",
                     xlabel = "$prefix DAQ Output (V)", ylabel = "Xcorr FWHM (px)")
        ax_fm = Axis(fig[2, 2], title = "Xcorr FWHM vs $prefix Monitor",
                     xlabel = "$prefix Monitor (V)",   ylabel = "Xcorr FWHM (px)")

        scatterlines!(ax_nd, daq_v, peak_nccs; color = c, marker = mk, markersize = 10)
        scatterlines!(ax_nm, mon_v, peak_nccs; color = c, marker = mk, markersize = 10)
        scatterlines!(ax_fd, daq_v, fwhm_ccs;  color = c, marker = mk, markersize = 10)
        scatterlines!(ax_fm, mon_v, fwhm_ccs;  color = c, marker = mk, markersize = 10)

        # control reference
        hlines!(ax_nd, [ctrl_p];  color = (:gray30, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_nm, [ctrl_p];  color = (:gray30, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_fd, [ctrl_fw]; color = (:gray30, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_fm, [ctrl_fw]; color = (:gray30, 0.7), linestyle = :dash, linewidth = 2)
        scatter!(ax_nd, [ctrl_daq_v], [ctrl_p];  color = :gray30, marker = :diamond, markersize = 14)
        scatter!(ax_nm, [ctrl_mon_v], [ctrl_p];  color = :gray30, marker = :diamond, markersize = 14)
        scatter!(ax_fd, [ctrl_daq_v], [ctrl_fw]; color = :gray30, marker = :diamond, markersize = 14)
        scatter!(ax_fm, [ctrl_mon_v], [ctrl_fw]; color = :gray30, marker = :diamond, markersize = 14)

        display(fig)
        outpath = joinpath(dir, "$(gkey)_xcorr_quality.png")
        save(outpath, fig)
        println("Saved: $outpath")
    end
end

# ============================================================================
# Video — one per ODE group, sorted by DAQ voltage
# ============================================================================

function make_angle_videos(groups, dir; framerate = 2)
    for gkey in ("ODE1", "ODE2")
        meas = get(groups, gkey, AngleMeasurement[])
        isempty(meas) && continue

        prefix = gkey == "ODE1" ? "HVA1" : "HVA2"
        daq_fn = gkey == "ODE1" ? (m -> m.hva1_daq) : (m -> m.hva2_daq)
        sorted = sort(meas, by = daq_fn)

        outpath = joinpath(dir, "$(gkey)_video.mp4")
        nx, ny  = size(sorted[1].frame)
        clim    = (0.0, maximum(maximum(m.frame) for m in sorted))

        fig = Figure(size = (nx, ny), backgroundcolor = :black, figure_padding = 0)
        ax  = Axis(fig[1, 1], aspect = DataAspect(), backgroundcolor = :black)
        hidedecorations!(ax); hidespines!(ax)
        rowgap!(fig.layout, 0); colgap!(fig.layout, 0)

        frame_obs = Observable(sorted[1].frame)
        heatmap!(ax, frame_obs; colormap = :inferno, colorrange = clim)

        label_obs = Observable("$prefix DAQ: $(round(daq_fn(sorted[1]), digits=3)) V")
        text!(ax, label_obs;
              position = (0.98, 0.98), space = :relative,
              align = (:right, :top), color = :white, fontsize = 16, font = :bold)

        println("Recording $outpath  ($(length(sorted)) frames @ $(framerate) fps)")
        record(fig, outpath, sorted; framerate = framerate) do m
            frame_obs[] = m.frame
            label_obs[] = "$prefix DAQ: $(round(daq_fn(m), digits=3)) V"
        end
        println("  Saved: $outpath")

        # ── centered video: xcorr-align each frame to the control ─────────
        ctrl = get(groups, "$(gkey)_Control", AngleMeasurement[])
        if isempty(ctrl)
            @warn "No control for $gkey — skipping centered video"
            continue
        end
        ref = mean(m.frame for m in ctrl)

        outpath_c = joinpath(dir, "$(gkey)_video_centered.mp4")
        fig_c = Figure(size = (nx, ny), backgroundcolor = :black, figure_padding = 0)
        ax_c  = Axis(fig_c[1, 1], aspect = DataAspect(), backgroundcolor = :black)
        hidedecorations!(ax_c); hidespines!(ax_c)
        rowgap!(fig_c.layout, 0); colgap!(fig_c.layout, 0)

        frame_c_obs = Observable(sorted[1].frame)
        heatmap!(ax_c, frame_c_obs; colormap = :inferno, colorrange = clim)

        label_c_obs = Observable("$prefix DAQ: $(round(daq_fn(sorted[1]), digits=3)) V  [centered]")
        text!(ax_c, label_c_obs;
              position = (0.98, 0.98), space = :relative,
              align = (:right, :top), color = :white, fontsize = 16, font = :bold)

        println("Recording $outpath_c  (centered, $(length(sorted)) frames @ $(framerate) fps)")
        record(fig_c, outpath_c, sorted; framerate = framerate) do m
            # xcorr gives displacement of this frame relative to ref
            _, _, dx, dy = _xcorr_metrics(ref, m.frame)
            # circshift cancels the displacement → beam stays at control position
            frame_c_obs[] = circshift(m.frame, (-round(Int, dx), -round(Int, dy)))
            label_c_obs[] = "$prefix DAQ: $(round(daq_fn(m), digits=3)) V  [centered]"
        end
        println("  Saved: $outpath_c")
    end
end

# ============================================================================
# Run
# ============================================================================

println("Loading HDF5 files from:\n  $DATA_DIR\n")
groups = load_angle_data(DATA_DIR)

println("\nLoaded:")
for (g, v) in sort(collect(groups); by = first)
    println("  $g: $(length(v)) files")
    if !isempty(v)
        println("    HVA1 daq: $(round(minimum(m.hva1_daq for m in v), digits=3)) – $(round(maximum(m.hva1_daq for m in v), digits=3)) V")
        println("    HVA2 daq: $(round(minimum(m.hva2_daq for m in v), digits=3)) – $(round(maximum(m.hva2_daq for m in v), digits=3)) V")
        println("    center_x: $(round(minimum(m.center_x for m in v), digits=1)) – $(round(maximum(m.center_x for m in v), digits=1)) px")
        println("    center_y: $(round(minimum(m.center_y for m in v), digits=1)) – $(round(maximum(m.center_y for m in v), digits=1)) px")
    end
end

plot_angle(groups, DATA_DIR)
plot_beam_quality(groups, DATA_DIR)
plot_xcorr_angle(groups, DATA_DIR)
make_angle_videos(groups, DATA_DIR)
