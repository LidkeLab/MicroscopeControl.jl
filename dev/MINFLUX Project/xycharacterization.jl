# xycharacterization.jl
# Analyze XY beam characterization sweep data (relay system).
#
# Folder structure (flat):
#   DATA_DIR/control_<timestamp>.h5          — 0 V reference frame
#   DATA_DIR/relay_step<NNN>_<V>V_<ts>.h5   — sweep steps, both HVAs together
#
# HVA1 → Y deflection (center_y)
# HVA2 → X deflection (center_x)
# Real HVA output = −monitor × 20  (HVA200 gain = 20×)
#
# Figures saved to DATA_DIR (CairoMakie — static PNG):
#   1. xy_position_vs_voltage.png   — cx / cy vs HVA output + mrad/kV
#   2. xy_xcorr_vs_control.png      — NCC and displacement vs control
#   3. xy_fwhm_vs_voltage.png       — beam FWHM X and Y vs voltage

using HDF5, CairoMakie, Statistics, FFTW

const DATA_DIR         = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/relay_system/APR22"
const PIXEL_SIZE_UM    = 5.2        # camera pixel pitch (µm)
const EOD_DISTANCE_MM  = 190.0      # EOD → camera sensor (mm)
const SPEC_MRAD_PER_KV = 3.0        # manufacturer deflection spec (mrad/kV HVA output)

# ============================================================================
# Data structs & loading
# ============================================================================

struct SweepFrame
    step::Int
    sweep_voltage::Float64      # setpoint sent to HVA (V)
    hva1_out::Float64           # real HVA1 output  = −monitor × 20 (V)
    hva2_out::Float64           # real HVA2 output  = −monitor × 20 (V)
    center_x::Float64
    center_y::Float64
    fwhm_x::Float64
    fwhm_y::Float64
    frame::Matrix{Float64}
end

struct ControlFrame
    center_x::Float64
    center_y::Float64
    frame::Matrix{Float64}
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function background_level(frame; frac = 0.05)
    thresh = quantile(vec(frame), frac)
    return mean(filter(<=(thresh), vec(frame)))
end

function fit_fwhm(frame)
    idx = argmax(frame)
    cx, cy = idx[1], idx[2]
    bg = background_level(frame)
    xprof = max.(frame[:, cy] .- bg, 0.0)
    yprof = max.(frame[cx, :] .- bg, 0.0)
    xa = findall(>=(maximum(xprof) / 2), xprof)
    ya = findall(>=(maximum(yprof) / 2), yprof)
    fwhm_x = length(xa) >= 2 ? Float64(xa[end] - xa[1]) : 0.0
    fwhm_y = length(ya) >= 2 ? Float64(ya[end] - ya[1]) : 0.0
    return fwhm_x, fwhm_y
end

function load_control(dir)
    cf = filter(f -> startswith(f, "control") && endswith(f, ".h5"), readdir(dir))
    isempty(cf) && error("No control file found in $dir")
    h5open(joinpath(dir, first(cf)), "r") do f
        fr = Float64.(read(f["frame"]))
        ControlFrame(read_attr(f, "center_x"), read_attr(f, "center_y"), fr)
    end
end

function load_sweep_frames(dir)
    files = sort(filter(f -> startswith(f, "relay_step") && endswith(f, ".h5"),
                        readdir(dir)))
    println("  $(length(files)) relay sweep files")
    frames = SweepFrame[]
    for fname in files
        try
            h5open(joinpath(dir, fname), "r") do f
                fr = Float64.(read(f["frame"]))
                fx, fy = fit_fwhm(fr)
                push!(frames, SweepFrame(
                    Int(read_attr(f, "sweep_step", 0.0)),
                    read_attr(f, "sweep_voltage"),
                    -read_attr(f, "hva1_monitor") * 20,
                    -read_attr(f, "hva2_monitor") * 20,
                    read_attr(f, "center_x"),
                    read_attr(f, "center_y"),
                    fx, fy, fr,
                ))
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()
    sort!(frames, by = f -> f.step)
    return frames
end

# ============================================================================
# Cross-correlation helpers
# ============================================================================

function xcorr2d(ref, frame)
    r = ref   .- mean(ref)
    f = frame .- mean(frame)
    cc    = real(ifft(fft(r) .* conj(fft(f))))
    denom = sqrt(sum(r .^ 2) * sum(f .^ 2))
    return denom > 0 ? fftshift(cc) ./ denom : fftshift(cc)
end

function xcorr_peak(cc)
    nx, ny = size(cc)
    cx0, cy0 = nx ÷ 2 + 1, ny ÷ 2 + 1
    peak_val = maximum(cc)
    pidx     = argmax(cc)
    dx       = Float64(pidx[1] - cx0)
    dy       = Float64(pidx[2] - cy0)
    ax = findall(>=(peak_val / 2), cc[:, pidx[2]])
    ay = findall(>=(peak_val / 2), cc[pidx[1], :])
    fwhm_cc = ((length(ax) >= 2 ? Float64(ax[end] - ax[1]) : 0.0) +
               (length(ay) >= 2 ? Float64(ay[end] - ay[1]) : 0.0)) / 2
    return peak_val, fwhm_cc, dx, dy
end

# ============================================================================
# Calibration — OLS regression per deflection axis
# ============================================================================

struct CalResult
    mrad_per_kV::Float64
    pct_spec::Float64
    slope_px_per_V::Float64     # primary axis slope (px / V HVA output)
    cross_slope_px_per_V::Float64  # cross-axis coupling
    ΔV_out::Float64             # full HVA output voltage range (V)
    Δpos_px::Float64            # total position change over ΔV
    θ_total_mrad::Float64
end

function compute_calibration(frames, hva_num)::Union{CalResult, Nothing}
    length(frames) < 2 && return nothing
    mon_v   = hva_num == 1 ? [f.hva1_out for f in frames] :
                              [f.hva2_out for f in frames]
    primary = hva_num == 1 ? [f.center_y for f in frames] :
                              [f.center_x for f in frames]
    cross   = hva_num == 1 ? [f.center_x for f in frames] :
                              [f.center_y for f in frames]

    ΔV_out = maximum(mon_v) - minimum(mon_v)
    ΔV_out == 0 && return nothing

    V̄     = mean(mon_v)
    var_V = sum((v - V̄)^2 for v in mon_v)
    var_V == 0 && return nothing

    p̄ = mean(primary);  c̄ = mean(cross)
    slope_p = sum((mon_v[i] - V̄) * (primary[i] - p̄) for i in eachindex(mon_v)) / var_V
    slope_c = sum((mon_v[i] - V̄) * (cross[i]   - c̄) for i in eachindex(mon_v)) / var_V

    # θ = displacement / distance  (small angle)
    mrad_per_V   = (abs(slope_p) * PIXEL_SIZE_UM * 1e-6 / (EOD_DISTANCE_MM * 1e-3)) * 1e3
    mrad_per_kV  = mrad_per_V * 1000.0
    pct_spec     = abs(mrad_per_kV) / SPEC_MRAD_PER_KV * 100.0
    Δpos_px      = abs(slope_p) * ΔV_out
    θ_total_mrad = (Δpos_px * PIXEL_SIZE_UM * 1e-6 / (EOD_DISTANCE_MM * 1e-3)) * 1e3

    return CalResult(mrad_per_kV, pct_spec, slope_p, slope_c, ΔV_out, Δpos_px, θ_total_mrad)
end

# ============================================================================
# Figure 1 — Position vs HVA output voltage
# ============================================================================

function plot_position_vs_voltage(frames, ctrl)
    fig = Figure(size = (1200, 800))
    Label(fig[0, 1:2],
          "Beam Position vs HVA Output Voltage\n" *
          "pixel = $(PIXEL_SIZE_UM) µm   EOD→cam = $(EOD_DISTANCE_MM) mm   " *
          "spec = $(SPEC_MRAD_PER_KV) mrad/kV";
          fontsize = 14, font = :bold, tellwidth = false)

    v1 = [f.hva1_out for f in frames]
    v2 = [f.hva2_out for f in frames]
    cx = [f.center_x for f in frames]
    cy = [f.center_y for f in frames]

    # ── HVA1 → Y panel ───────────────────────────────────────────────────────
    ax1 = Axis(fig[1, 1],
               title  = "HVA1 → Y deflection",
               xlabel = "HVA1 Output (V)",
               ylabel = "Beam Position (px)")
    scatterlines!(ax1, v1, cy; color = :steelblue,       markersize = 5, label = "Center Y  (primary)")
    scatterlines!(ax1, v1, cx; color = (:steelblue, 0.4), markersize = 4,
                  linestyle = :dash, label = "Center X  (cross-talk)")
    if ctrl !== nothing
        hlines!(ax1, [ctrl.center_y]; color = (:gray40, 0.7), linestyle = :dot, linewidth = 1.5)
    end
    cal1 = compute_calibration(frames, 1)
    if cal1 !== nothing
        txt1 = "$(round(cal1.mrad_per_kV, digits=2)) mrad/kV  ($(round(cal1.pct_spec, digits=1))% spec)"
        text!(ax1, txt1; position = (minimum(v1), maximum(cy)),
              align = (:left, :top), fontsize = 12, color = :steelblue, font = :bold)
    end
    axislegend(ax1; position = :rb, framevisible = true, labelsize = 11)

    # ── HVA2 → X panel ───────────────────────────────────────────────────────
    ax2 = Axis(fig[1, 2],
               title  = "HVA2 → X deflection",
               xlabel = "HVA2 Output (V)",
               ylabel = "Beam Position (px)")
    scatterlines!(ax2, v2, cx; color = :tomato,       markersize = 5, label = "Center X  (primary)")
    scatterlines!(ax2, v2, cy; color = (:tomato, 0.4), markersize = 4,
                  linestyle = :dash, label = "Center Y  (cross-talk)")
    if ctrl !== nothing
        hlines!(ax2, [ctrl.center_x]; color = (:gray40, 0.7), linestyle = :dot, linewidth = 1.5)
    end
    cal2 = compute_calibration(frames, 2)
    if cal2 !== nothing
        txt2 = "$(round(cal2.mrad_per_kV, digits=2)) mrad/kV  ($(round(cal2.pct_spec, digits=1))% spec)"
        text!(ax2, txt2; position = (minimum(v2), maximum(cx)),
              align = (:left, :top), fontsize = 12, color = :tomato, font = :bold)
    end
    axislegend(ax2; position = :rb, framevisible = true, labelsize = 11)

    out = joinpath(DATA_DIR, "xy_position_vs_voltage.png")
    save(out, fig);  println("Saved: $out")
    return fig
end

# ============================================================================
# Figure 2 — Cross-correlation vs control
# ============================================================================

function plot_xcorr(frames, ctrl)
    ctrl === nothing && (@warn "No control frame — skipping xcorr plot"; return nothing)
    println("  Computing cross-correlations…")

    v     = [f.hva1_out for f in frames]   # same as v2 since both swept together
    nccs  = Float64[];  fwhms = Float64[]
    dxs   = Float64[];  dys   = Float64[]

    for fr in frames
        cc = xcorr2d(ctrl.frame, fr.frame)
        ncc, fwhm_cc, dx, dy = xcorr_peak(cc)
        push!(nccs, ncc);  push!(fwhms, fwhm_cc)
        push!(dxs,  dx);   push!(dys,   dy)
        print(".")
    end
    println()

    disp_x = dxs .* PIXEL_SIZE_UM    # µm
    disp_y = dys .* PIXEL_SIZE_UM

    fig = Figure(size = (1200, 900))
    Label(fig[0, 1:2],
          "Cross-Correlation vs Control (0 V reference)";
          fontsize = 14, font = :bold, tellwidth = false)

    ax_ncc = Axis(fig[1, 1], title = "Peak NCC — beam similarity to control",
                  xlabel = "HVA Output (V)", ylabel = "Peak NCC (0–1)")
    ax_fw  = Axis(fig[1, 2], title = "Xcorr FWHM — beam sharpness",
                  xlabel = "HVA Output (V)", ylabel = "Xcorr FWHM (px)")
    ax_dx  = Axis(fig[2, 1], title = "Beam Displacement ΔX vs control",
                  xlabel = "HVA Output (V)", ylabel = "ΔX (µm)")
    ax_dy  = Axis(fig[2, 2], title = "Beam Displacement ΔY vs control",
                  xlabel = "HVA Output (V)", ylabel = "ΔY (µm)")

    scatterlines!(ax_ncc, v, nccs;  color = :steelblue, markersize = 5)
    scatterlines!(ax_fw,  v, fwhms; color = :seagreen,  markersize = 5)
    scatterlines!(ax_dx,  v, disp_x; color = :tomato,   markersize = 5)
    scatterlines!(ax_dy,  v, disp_y; color = :steelblue, markersize = 5)

    hlines!(ax_ncc, [1.0]; color = (:gray40, 0.6), linestyle = :dash, linewidth = 1.5)
    hlines!(ax_dx,  [0.0]; color = (:gray40, 0.6), linestyle = :dash, linewidth = 1.5)
    hlines!(ax_dy,  [0.0]; color = (:gray40, 0.6), linestyle = :dash, linewidth = 1.5)

    # Annotate max displacement range
    text!(ax_dx, "range: $(round(maximum(disp_x) - minimum(disp_x), digits=1)) µm";
          position = (minimum(v), maximum(disp_x)),
          align = (:left, :top), fontsize = 11, color = :tomato)
    text!(ax_dy, "range: $(round(maximum(disp_y) - minimum(disp_y), digits=1)) µm";
          position = (minimum(v), maximum(disp_y)),
          align = (:left, :top), fontsize = 11, color = :steelblue)

    out = joinpath(DATA_DIR, "xy_xcorr_vs_control.png")
    save(out, fig);  println("Saved: $out")
    return fig
end

# ============================================================================
# Figure 3 — Beam FWHM vs voltage
# ============================================================================

function plot_fwhm(frames)
    v  = [f.hva1_out for f in frames]
    fx = [f.fwhm_x   for f in frames]
    fy = [f.fwhm_y   for f in frames]

    fig = Figure(size = (900, 500))
    Label(fig[0, 1], "Beam FWHM vs HVA Output Voltage";
          fontsize = 14, font = :bold, tellwidth = false)

    ax = Axis(fig[1, 1],
              title  = "Beam size across the full sweep",
              xlabel = "HVA Output (V)",
              ylabel = "FWHM (px)")

    scatterlines!(ax, v, fx; color = :steelblue, markersize = 6, label = "FWHM X")
    scatterlines!(ax, v, fy; color = :tomato,    markersize = 6, label = "FWHM Y")
    axislegend(ax; position = :rt, framevisible = true)

    # Annotate control reference (central step)
    mid = length(frames) ÷ 2
    ctrl_v = v[mid]
    text!(ax, "center: $(round(fx[mid], digits=1)) px  ×  $(round(fy[mid], digits=1)) px";
          position = (ctrl_v, maximum(vcat(fx, fy))),
          align = (:center, :top), fontsize = 11, color = :gray40)

    out = joinpath(DATA_DIR, "xy_fwhm_vs_voltage.png")
    save(out, fig);  println("Saved: $out")
    return fig
end

# ============================================================================
# Calibration summary table
# ============================================================================

function print_calibration(frames)
    println("\n", "=" ^ 80)
    println("XY Characterization — Calibration Summary")
    println("  Pixel = $(PIXEL_SIZE_UM) µm   EOD→cam = $(EOD_DISTANCE_MM) mm   Spec = $(SPEC_MRAD_PER_KV) mrad/kV")
    println("-" ^ 80)
    println(rpad("Channel", 9), rpad("Axis", 10), rpad("ΔV_out (V)", 12),
            rpad("Δpos (px)", 11), rpad("θ total (mrad)", 16),
            rpad("mrad/kV", 12), rpad("% spec", 9),
            rpad("slope_primary (px/V)", 22), "slope_cross (px/V)")
    println("-" ^ 80)
    for (hva_num, axis) in ((1, "Y (cy)"), (2, "X (cx)"))
        cal = compute_calibration(frames, hva_num)
        cal === nothing && continue
        println(rpad("HVA$hva_num", 9), rpad(axis, 10),
                rpad(round(cal.ΔV_out,              digits=1), 12),
                rpad(round(cal.Δpos_px,             digits=1), 11),
                rpad(round(cal.θ_total_mrad,        digits=3), 16),
                rpad(round(cal.mrad_per_kV,         digits=3), 12),
                rpad("$(round(cal.pct_spec, digits=1))%", 9),
                rpad(round(cal.slope_px_per_V,      digits=4), 22),
                round(cal.cross_slope_px_per_V,     digits=4))
    end
    println("=" ^ 80)
end

# ============================================================================
# Run
# ============================================================================

println("Loading data from:\n  $DATA_DIR\n")

ctrl   = load_control(DATA_DIR)
println("Control loaded: cx=$(round(ctrl.center_x, digits=1))  cy=$(round(ctrl.center_y, digits=1))\n")

frames = load_sweep_frames(DATA_DIR)
println("  Sweep steps loaded: $(length(frames))")
println("  Voltage range: $(round(minimum(f.sweep_voltage for f in frames), digits=2)) V " *
        "→ $(round(maximum(f.sweep_voltage for f in frames), digits=2)) V")

print_calibration(frames)

println("\nGenerating figures…")
plot_position_vs_voltage(frames, ctrl)
plot_xcorr(frames, ctrl)
plot_fwhm(frames)

println("\nDone.")
