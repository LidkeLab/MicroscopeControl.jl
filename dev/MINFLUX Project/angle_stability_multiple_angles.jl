# angle_stability_multiple_angles.jl
# Analyse beam-position stability at each voltage step (angle) separately.
#
# Folder structure:
#   DATA_DIR/EOD34/<stability files>  → ODE1 (HVA1)
#   DATA_DIR/EOD35/<stability files>  → ODE2 (HVA2)
#
# Each HDF5 file contains one frame; files are grouped by sweep_step.
# For each step the voltage is fixed — we measure how much the beam drifts
# (deviation from the step mean) across all frames at that angle.
#
# Plots per ODE:
#   Fig 1 — Mean position ± std vs voltage  (center X, Y, radial)
#   Fig 2 — Box plots of displacement from step mean vs voltage
#   Fig 3 — Angular deviation box plots (mrad) vs voltage

using HDF5, GLMakie, Statistics

const DATA_DIR        = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/angle_stability/apr_4"
const PIXEL_SIZE_UM   = 5.2      # camera pixel pitch (µm)
const EOD_DISTANCE_MM = 350.0    # EOD → camera sensor (mm)

# ============================================================================
# Data struct & loading
# ============================================================================

struct StabFrame
    step::Int
    sweep_voltage::Float64
    frame_num::Int
    center_x::Float64
    center_y::Float64
    hva1_monitor::Float64   # real HVA1 output: monitor × (-20)
    hva2_monitor::Float64
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_stab_folder(folder)
    h5files = sort(filter(f -> endswith(f, ".h5"), readdir(folder)))
    println("  $(length(h5files)) files in $(basename(folder))")
    frames = StabFrame[]
    for fname in h5files
        try
            h5open(joinpath(folder, fname), "r") do f
                push!(frames, StabFrame(
                    Int(read_attr(f, "sweep_step", 0.0)),
                    read_attr(f, "sweep_voltage"),
                    Int(read_attr(f, "stability_frame", 0.0)),
                    read_attr(f, "center_x"),
                    read_attr(f, "center_y"),
                    -read_attr(f, "hva1_monitor") * 20,
                    -read_attr(f, "hva2_monitor") * 20,
                ))
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()
    sort!(frames, by = f -> (f.step, f.frame_num))
    return frames
end

# ============================================================================
# Per-step statistics
# ============================================================================

struct StepStats
    step::Int
    voltage::Float64           # nominal voltage at this step
    n::Int                     # number of frames
    mean_cx::Float64
    mean_cy::Float64
    std_cx::Float64
    std_cy::Float64
    std_r::Float64             # std of radial displacement
    p2p_cx::Float64
    p2p_cy::Float64
    p2p_r::Float64
    # raw deviations from step mean (for box plots)
    Δcx::Vector{Float64}
    Δcy::Vector{Float64}
    Δr::Vector{Float64}        # px
    Δr_um::Vector{Float64}
    Δr_mrad::Vector{Float64}
    frame_nums::Vector{Int}    # frame index within step (for time series)
end

function compute_step_stats(frames::Vector{StabFrame}, hva_num::Int)
    steps = sort(unique(f.step for f in frames))
    stats = StepStats[]
    for s in steps
        grp = filter(f -> f.step == s, frames)
        isempty(grp) && continue
        voltage = mean(f.sweep_voltage for f in grp)
        cx = [f.center_x for f in grp]
        cy = [f.center_y for f in grp]
        mcx = mean(cx);  mcy = mean(cy)
        Δcx = cx .- mcx
        Δcy = cy .- mcy
        Δr  = sqrt.(Δcx .^ 2 .+ Δcy .^ 2)
        Δr_um   = Δr .* PIXEL_SIZE_UM
        Δr_mrad = atan.(Δr_um .* 1e-6 ./ (EOD_DISTANCE_MM * 1e-3)) .* 1e3
        frame_nums = [f.frame_num for f in grp]
        push!(stats, StepStats(
            s, voltage, length(grp),
            mcx, mcy,
            std(cx), std(cy), std(Δr),
            maximum(cx) - minimum(cx),
            maximum(cy) - minimum(cy),
            maximum(Δr) - minimum(Δr),
            Δcx, Δcy, Δr, Δr_um, Δr_mrad, frame_nums,
        ))
    end
    return stats
end

# ============================================================================
# Printing
# ============================================================================

function print_step_table(stats, ode_name)
    println("\n", "=" ^ 76)
    println("Stability Summary — $ode_name")
    println(rpad("Step", 6), rpad("V (V)", 9),
            rpad("n", 5),
            rpad("std cx (px)", 13), rpad("std cy (px)", 13),
            rpad("std Δr (px)", 13), rpad("p2p Δr (px)", 13))
    println("-" ^ 76)
    for s in stats
        println(rpad(s.step, 6), rpad(round(s.voltage, digits=2), 9),
                rpad(s.n, 5),
                rpad(round(s.std_cx, digits=3), 13),
                rpad(round(s.std_cy, digits=3), 13),
                rpad(round(s.std_r,  digits=3), 13),
                rpad(round(s.p2p_r,  digits=3), 13))
    end
    println("=" ^ 76)
end

# ============================================================================
# Plotting
# ============================================================================

function plot_stab_multiple(stats, ode_name)
    isempty(stats) && return
    c = ode_name == "ODE1" ? :steelblue : :tomato

    voltages  = [s.voltage for s in stats]
    vlabels   = ["$(round(v, digits=1)) V" for v in voltages]
    xs        = 1:length(stats)   # integer x positions for box plots

    # ── Figure 1: mean position ± std vs voltage ──────────────────────────────
    fig1 = Figure(size = (1100, 750))
    Label(fig1[0, 1:3], "$ode_name — Mean Position ± Std at Each Voltage Step";
          fontsize = 15, font = :bold, tellwidth = false)

    ax_cx = Axis(fig1[1, 1], title = "Center X",
                 xlabel = "Voltage (V)", ylabel = "Mean Center X (px)")
    ax_cy = Axis(fig1[1, 2], title = "Center Y",
                 xlabel = "Voltage (V)", ylabel = "Mean Center Y (px)")
    ax_r  = Axis(fig1[1, 3], title = "Radial Std",
                 xlabel = "Voltage (V)", ylabel = "Std Δr (px)")

    errorbars!(ax_cx, voltages, [s.mean_cx for s in stats],
               [s.std_cx for s in stats]; color = c, linewidth = 2, whiskerwidth = 8)
    scatterlines!(ax_cx, voltages, [s.mean_cx for s in stats];
                  color = c, markersize = 8)

    errorbars!(ax_cy, voltages, [s.mean_cy for s in stats],
               [s.std_cy for s in stats]; color = c, linewidth = 2, whiskerwidth = 8)
    scatterlines!(ax_cy, voltages, [s.mean_cy for s in stats];
                  color = c, markersize = 8)

    scatterlines!(ax_r, voltages, [s.std_r for s in stats];
                  color = c, markersize = 8)

    display(fig1)
    out1 = joinpath(DATA_DIR, "$(ode_name)_mean_position_vs_voltage.png")
    save(out1, fig1);  println("Saved: $out1")

    # ── Figure 2: box plots — displacement in px and µm ───────────────────────
    fig2 = Figure(size = (1100, 800))
    Label(fig2[0, 1:2], "$ode_name — Position Deviation per Voltage Step (box plots)";
          fontsize = 15, font = :bold, tellwidth = false)

    ax_bx = Axis(fig2[1, 1], title = "ΔX from step mean",
                 xlabel = "Voltage Step", ylabel = "ΔX (px)")
    ax_by = Axis(fig2[1, 2], title = "ΔY from step mean",
                 xlabel = "Voltage Step", ylabel = "ΔY (px)")
    ax_br = Axis(fig2[2, 1:2], title = "Radial displacement Δr from step mean",
                 xlabel = "Voltage Step", ylabel = "Δr (µm)")

    # Build flat arrays for boxplot! (group index + value per observation)
    grp_idx = vcat([fill(i, s.n) for (i, s) in enumerate(stats)]...)
    all_Δcx  = vcat([s.Δcx   for s in stats]...)
    all_Δcy  = vcat([s.Δcy   for s in stats]...)
    all_Δr_um = vcat([s.Δr_um for s in stats]...)

    boxplot!(ax_bx, grp_idx, all_Δcx;  color = (c, 0.7), strokewidth = 1)
    boxplot!(ax_by, grp_idx, all_Δcy;  color = (c, 0.7), strokewidth = 1)
    boxplot!(ax_br, grp_idx, all_Δr_um; color = (:mediumpurple, 0.7), strokewidth = 1)

    for ax in (ax_bx, ax_by, ax_br)
        ax.xticks = (xs, vlabels)
        ax.xticklabelrotation[] = π / 5
        hlines!(ax, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
    end

    display(fig2)
    out2 = joinpath(DATA_DIR, "$(ode_name)_boxplot_displacement.png")
    save(out2, fig2);  println("Saved: $out2")

    # ── Figure 3: angular deviation box plots (mrad) ──────────────────────────
    fig3 = Figure(size = (900, 550))
    Label(fig3[0, 1], "$ode_name — Angular Deviation per Voltage Step (mrad)";
          fontsize = 15, font = :bold, tellwidth = false)

    ax_mrad = Axis(fig3[1, 1], title = "Δθ radial (mrad)",
                   xlabel = "Voltage Step", ylabel = "Δθ (mrad)")

    all_mrad = vcat([s.Δr_mrad for s in stats]...)
    boxplot!(ax_mrad, grp_idx, all_mrad; color = (:seagreen, 0.7), strokewidth = 1)
    ax_mrad.xticks = (xs, vlabels)
    ax_mrad.xticklabelrotation[] = π / 5

    # Annotate each box with its std value
    for (i, s) in enumerate(stats)
        σ_mrad = std(s.Δr_mrad)
        text!(ax_mrad, "σ=$(round(σ_mrad, digits=3))";
              position = (Float64(i), maximum(s.Δr_mrad)),
              align = (:center, :bottom), fontsize = 9, color = :gray30)
    end

    display(fig3)
    out3 = joinpath(DATA_DIR, "$(ode_name)_boxplot_angular_mrad.png")
    save(out3, fig3);  println("Saved: $out3")

    # ── Figure 4: time series within each step ────────────────────────────────
    ncols4 = min(3, length(stats))
    nrows4 = ceil(Int, length(stats) / ncols4)
    fig4 = Figure(size = (380 * ncols4, 280 * nrows4 + 60))
    Label(fig4[0, 1:ncols4], "$ode_name — Position Time Series per Voltage Step";
          fontsize = 15, font = :bold, tellwidth = false)

    for (idx, s) in enumerate(stats)
        row = (idx - 1) ÷ ncols4 + 1
        col = (idx - 1) % ncols4 + 1
        ax = Axis(fig4[row, col],
                  title    = "$(round(s.voltage, digits=1)) V (n=$(s.n))",
                  xlabel   = "Frame #",
                  ylabel   = "Δ (px)")
        lines!(ax, s.frame_nums, s.Δcx; color = :steelblue, linewidth = 1, label = "ΔX")
        lines!(ax, s.frame_nums, s.Δcy; color = :tomato,     linewidth = 1, label = "ΔY")
        hlines!(ax, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
        idx == 1 && axislegend(ax; position = :rt, labelsize = 9)
    end

    display(fig4)
    out4 = joinpath(DATA_DIR, "$(ode_name)_timeseries_per_step.png")
    save(out4, fig4);  println("Saved: $out4")

    # ── Figure 5: stability metrics (std & p2p) vs voltage ────────────────────
    fig5 = Figure(size = (800, 420))
    Label(fig5[0, 1:2], "$ode_name — Stability Metrics vs Applied Voltage";
          fontsize = 15, font = :bold, tellwidth = false)

    ax5a = Axis(fig5[1, 1], title = "Std of Radial Displacement",
                xlabel = "Voltage (V)", ylabel = "std Δr (px)")
    ax5b = Axis(fig5[1, 2], title = "Peak-to-Peak Radial Displacement",
                xlabel = "Voltage (V)", ylabel = "p2p Δr (px)")

    scatterlines!(ax5a, voltages, [s.std_r  for s in stats]; color = c, markersize = 8)
    scatterlines!(ax5b, voltages, [s.p2p_r  for s in stats]; color = c, markersize = 8)

    display(fig5)
    out5 = joinpath(DATA_DIR, "$(ode_name)_stability_vs_voltage.png")
    save(out5, fig5);  println("Saved: $out5")

    # ── Figure 6: 2D scatter ΔX vs ΔY per step ───────────────────────────────
    ncols6 = min(3, length(stats))
    nrows6 = ceil(Int, length(stats) / ncols6)
    fig6 = Figure(size = (320 * ncols6, 310 * nrows6 + 60))
    Label(fig6[0, 1:ncols6], "$ode_name — 2D Position Scatter (ΔX vs ΔY) per Voltage Step";
          fontsize = 15, font = :bold, tellwidth = false)

    for (idx, s) in enumerate(stats)
        row = (idx - 1) ÷ ncols6 + 1
        col = (idx - 1) % ncols6 + 1
        ax = Axis(fig6[row, col],
                  title  = "$(round(s.voltage, digits=1)) V",
                  xlabel = "ΔX (px)", ylabel = "ΔY (px)",
                  aspect = DataAspect())
        scatter!(ax, s.Δcx, s.Δcy;
                 color = 1:s.n, colormap = :plasma, markersize = 5)
    end

    display(fig6)
    out6 = joinpath(DATA_DIR, "$(ode_name)_2d_scatter_per_step.png")
    save(out6, fig6);  println("Saved: $out6")

    # ── Figure 7: frame-to-frame displacement ─────────────────────────────────
    fig7 = Figure(size = (1000, 420))
    Label(fig7[0, 1:2], "$ode_name — Frame-to-Frame Displacement per Voltage Step";
          fontsize = 15, font = :bold, tellwidth = false)

    ax7a = Axis(fig7[1, 1], title = "Frame-to-Frame |Δr| box plot",
                xlabel = "Voltage Step", ylabel = "|r(t+1) − r(t)| (px)")
    ax7b = Axis(fig7[1, 2], title = "Mean Frame-to-Frame |Δr| vs Voltage",
                xlabel = "Voltage (V)", ylabel = "Mean |Δr step| (px)")

    ftf_grp  = Int[]
    ftf_vals = Float64[]
    mean_ftf = Float64[]
    for (i, s) in enumerate(stats)
        Δr_step = sqrt.(diff(s.Δcx) .^ 2 .+ diff(s.Δcy) .^ 2)
        append!(ftf_grp,  fill(i, length(Δr_step)))
        append!(ftf_vals, Δr_step)
        push!(mean_ftf, mean(Δr_step))
    end

    boxplot!(ax7a, ftf_grp, ftf_vals; color = (c, 0.7), strokewidth = 1)
    ax7a.xticks = (xs, vlabels)
    ax7a.xticklabelrotation[] = π / 5
    hlines!(ax7a, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)

    scatterlines!(ax7b, voltages, mean_ftf; color = c, markersize = 8)

    display(fig7)
    out7 = joinpath(DATA_DIR, "$(ode_name)_frameto_frame_displacement.png")
    save(out7, fig7);  println("Saved: $out7")
end

# ============================================================================
# Run
# ============================================================================

println("Loading data from: $DATA_DIR\n")

eod_dirs = sort(filter(d -> isdir(joinpath(DATA_DIR, d)), readdir(DATA_DIR)))

for eod in eod_dirs
    hva_num = occursin("34", eod) ? 1 :
              occursin("35", eod) ? 2 : continue
    ode_name = "ODE$hva_num"

    println("$eod → $ode_name")
    frames = load_stab_folder(joinpath(DATA_DIR, eod))
    println("  Total frames: $(length(frames))")

    if isempty(frames)
        @warn "No data loaded for $eod"
        continue
    end

    stats = compute_step_stats(frames, hva_num)
    println("  Voltage steps found: $(length(stats))")

    print_step_table(stats, ode_name)
    plot_stab_multiple(stats, ode_name)
    println()
end
