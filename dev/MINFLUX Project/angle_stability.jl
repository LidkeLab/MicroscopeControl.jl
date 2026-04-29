# angle_stability.jl
# Analyse beam-position stability over time.
# Folder structure mirrors angle_analysis.jl:
#   DATA_DIR/EOD34/  → ODE1 (HVA1)
#   DATA_DIR/EOD35/  → ODE2 (HVA2)
# sweep_step index × settle_time gives the time axis.

using HDF5, GLMakie, Statistics


const DATA_DIR        = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/stability_laser/MAR_27"
const PIXEL_SIZE_UM   = 5.2      # camera pixel size (µm)
const EOD_DISTANCE_MM = 350.0    # EOD → camera sensor distance (mm)

# ============================================================================
# Data loading
# ============================================================================

struct StabilityPoint
    step::Int
    time_s::Float64
    center_x::Float64
    center_y::Float64
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_stability_folder(folder)
    h5files = sort(filter(f -> endswith(f, ".h5") &&
                               !startswith(lowercase(f), "control"), readdir(folder)))
    println("    $(length(h5files)) sweep files")

    points = StabilityPoint[]
    for fname in h5files
        try
            h5open(joinpath(folder, fname), "r") do f
                step   = Int(read_attribute(f, "sweep_step"))
                settle = read_attr(f, "settle_time", 1.0)
                t      = (step - 1) * settle
                cx     = read_attr(f, "center_x")
                cy     = read_attr(f, "center_y")
                push!(points, StabilityPoint(step, t, cx, cy))
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()
    sort!(points, by = p -> p.step)
    return points
end

function load_all_stability(dir)
    groups  = Dict{String, Vector{StabilityPoint}}()
    subdirs = sort(filter(d -> isdir(joinpath(dir, d)), readdir(dir)))
    println("Found subfolders: $subdirs\n")

    for subdir in subdirs
        gkey = if occursin("34", subdir)
            "ODE1"
        elseif occursin("35", subdir)
            "ODE2"
        else
            @warn "Unmatched subfolder (skipping): $subdir"
            continue
        end
        println("  $subdir → $gkey:")
        groups[gkey] = load_stability_folder(joinpath(dir, subdir))
    end
    return groups
end

# ============================================================================
# Statistics helpers
# ============================================================================

function linear_drift(t, v)
    A      = hcat(t, ones(length(t)))
    coeffs = A \ v
    slope, intercept = coeffs[1], coeffs[2]
    resid  = v .- (slope .* t .+ intercept)
    ss_res = sum(resid .^ 2)
    ss_tot = sum((v .- mean(v)) .^ 2)
    r2     = ss_tot > 0 ? 1.0 - ss_res / ss_tot : 0.0
    return slope, intercept, r2
end

function print_stats(label, values, unit)
    μ   = mean(values)
    σ   = std(values)
    p2p = maximum(values) - minimum(values)
    println("  $label")
    println("    Mean        : $(round(μ,   digits=4)) $unit")
    println("    Std dev (σ) : $(round(σ,   digits=4)) $unit")
    println("    Peak-to-peak: $(round(p2p, digits=4)) $unit")
end

# ============================================================================
# Plotting — one set of figures per ODE
# ============================================================================

function plot_stability(points, gkey, dir)
    isempty(points) && return

    t  = [p.time_s   for p in points]
    cx = [p.center_x for p in points]
    cy = [p.center_y for p in points]

    Δcx = cx .- mean(cx)
    Δcy = cy .- mean(cy)
    Δr  = sqrt.(Δcx .^ 2 .+ Δcy .^ 2)

    px_to_um = PIXEL_SIZE_UM
    dist_m   = EOD_DISTANCE_MM * 1e-3

    Δcx_um = Δcx .* px_to_um
    Δcy_um = Δcy .* px_to_um
    Δr_um  = Δr  .* px_to_um

    Δcx_mrad = atan.(Δcx_um .* 1e-6 ./ dist_m) .* 1e3
    Δcy_mrad = atan.(Δcy_um .* 1e-6 ./ dist_m) .* 1e3
    Δr_mrad  = atan.(Δr_um  .* 1e-6 ./ dist_m) .* 1e3

    slope_cx, icx, _ = linear_drift(t, cx)
    slope_cy, icy, _ = linear_drift(t, cy)
    fit_cx = slope_cx .* t .+ icx
    fit_cy = slope_cy .* t .+ icy

    c = gkey == "ODE1" ? :steelblue : :tomato

    # ── Figure 1: raw position + drift fit ───────────────────────────────
    fig1 = Figure(size = (1000, 550))
    Label(fig1[0, 1:2], "$gkey — Beam Position vs Time (raw pixel coordinates)";
          fontsize = 16, font = :bold, tellwidth = false)

    ax_cx = Axis(fig1[1, 1], title = "Center X", xlabel = "Time (s)", ylabel = "Center X (px)")
    ax_cy = Axis(fig1[1, 2], title = "Center Y", xlabel = "Time (s)", ylabel = "Center Y (px)")

    scatterlines!(ax_cx, t, cx; color = c, markersize = 4, linewidth = 0.5)
    lines!(ax_cx, t, fit_cx; color = :red, linewidth = 1.5, linestyle = :dash,
           label = "drift $(round(slope_cx*60, digits=3)) px/min")
    axislegend(ax_cx; position = :lt)

    scatterlines!(ax_cy, t, cy; color = c, markersize = 4, linewidth = 0.5)
    lines!(ax_cy, t, fit_cy; color = :red, linewidth = 1.5, linestyle = :dash,
           label = "drift $(round(slope_cy*60, digits=3)) px/min")
    axislegend(ax_cy; position = :lt)

    display(fig1)
    out1 = joinpath(dir, "$(gkey)_stability_raw_position.png")
    save(out1, fig1);  println("Saved: $out1")

    # ── Figure 2: displacement from mean (µm) ────────────────────────────
    fig2 = Figure(size = (1000, 750))
    Label(fig2[0, 1:2], "$gkey — Beam Displacement from Mean Position";
          fontsize = 16, font = :bold, tellwidth = false)

    ax_dx = Axis(fig2[1, 1], title = "ΔX displacement", xlabel = "Time (s)", ylabel = "ΔX (µm)")
    ax_dy = Axis(fig2[1, 2], title = "ΔY displacement", xlabel = "Time (s)", ylabel = "ΔY (µm)")
    ax_dr = Axis(fig2[2, 1:2], title = "Total radial displacement √(ΔX² + ΔY²)",
                 xlabel = "Time (s)", ylabel = "Δr (µm)")

    scatterlines!(ax_dx, t, Δcx_um; color = c, markersize = 4, linewidth = 0.5)
    hlines!(ax_dx, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
    scatterlines!(ax_dy, t, Δcy_um; color = c, markersize = 4, linewidth = 0.5)
    hlines!(ax_dy, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
    scatterlines!(ax_dr, t, Δr_um;  color = :mediumpurple, markersize = 4, linewidth = 0.5)

    display(fig2)
    out2 = joinpath(dir, "$(gkey)_stability_displacement_um.png")
    save(out2, fig2);  println("Saved: $out2")

    # ── Figure 3: angular deviation (mrad) ───────────────────────────────
    fig3 = Figure(size = (1000, 750))
    Label(fig3[0, 1:2], "$gkey — Angular Deviation from Mean Angle";
          fontsize = 16, font = :bold, tellwidth = false)

    ax_ax = Axis(fig3[1, 1], title = "Angular deviation X", xlabel = "Time (s)", ylabel = "Δθ_x (mrad)")
    ax_ay = Axis(fig3[1, 2], title = "Angular deviation Y", xlabel = "Time (s)", ylabel = "Δθ_y (mrad)")
    ax_ar = Axis(fig3[2, 1:2], title = "Total angular deviation",
                 xlabel = "Time (s)", ylabel = "Δθ (mrad)")

    scatterlines!(ax_ax, t, Δcx_mrad; color = c, markersize = 4, linewidth = 0.5)
    hlines!(ax_ax, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
    scatterlines!(ax_ay, t, Δcy_mrad; color = c, markersize = 4, linewidth = 0.5)
    hlines!(ax_ay, [0.0]; color = :gray50, linestyle = :dash, linewidth = 1)
    scatterlines!(ax_ar, t, Δr_mrad;  color = :mediumpurple, markersize = 4, linewidth = 0.5)

    display(fig3)
    out3 = joinpath(dir, "$(gkey)_stability_angular_deviation_mrad.png")
    save(out3, fig3);  println("Saved: $out3")

    # ── Figure 4: 2-D XY scatter ─────────────────────────────────────────
    fig4 = Figure(size = (520, 500))
    Label(fig4[0, 1], "$gkey — Beam Position Scatter (XY)";
          fontsize = 16, font = :bold, tellwidth = false)
    ax_xy = Axis(fig4[1, 1], xlabel = "ΔX (µm)", ylabel = "ΔY (µm)", aspect = DataAspect())
    scatter!(ax_xy, Δcx_um, Δcy_um; color = 1:length(t),
             colormap = :plasma, markersize = 5)
    Colorbar(fig4[1, 2], limits = (t[1], t[end]), colormap = :plasma, label = "Time (s)")

    display(fig4)
    out4 = joinpath(dir, "$(gkey)_stability_xy_scatter.png")
    save(out4, fig4);  println("Saved: $out4")

    # ── Statistics summary ────────────────────────────────────────────────
    println()
    println("=" ^ 60)
    println("Beam Stability Summary — $gkey")
    println("  Pixel size     : $(PIXEL_SIZE_UM) µm")
    println("  EOD→camera     : $(EOD_DISTANCE_MM) mm")
    println("  Total duration : $(round(t[end], digits=1)) s  ($(length(t)) frames)")
    println("  Sample interval: $(round(t[2]-t[1], digits=3)) s")
    println()
    println("  ── Pixel coordinates ──")
    print_stats("Center X", cx, "px")
    print_stats("Center Y", cy, "px")
    println()
    println("  ── Physical displacement (µm) ──")
    print_stats("ΔX", Δcx_um, "µm")
    print_stats("ΔY", Δcy_um, "µm")
    print_stats("Δr", Δr_um,  "µm")
    println()
    println("  ── Angular deviation (mrad) ──")
    print_stats("Δθ_x", Δcx_mrad, "mrad")
    print_stats("Δθ_y", Δcy_mrad, "mrad")
    print_stats("Δθ",   Δr_mrad,  "mrad")
    println()
    println("  ── Linear drift ──")
    println("    Center X : $(round(slope_cx * 60, digits=4)) px/min  =  $(round(slope_cx * 60 * px_to_um, digits=4)) µm/min")
    println("    Center Y : $(round(slope_cy * 60, digits=4)) px/min  =  $(round(slope_cy * 60 * px_to_um, digits=4)) µm/min")
    println("=" ^ 60)
end

# ============================================================================
# Run
# ============================================================================

println("Loading stability data from: $DATA_DIR\n")
groups = load_all_stability(DATA_DIR)

for (gkey, points) in sort(collect(groups); by = first)
    println("\n$(gkey): $(length(points)) frames  " *
            "time span: 0 – $(round(points[end].time_s, digits=1)) s")
    plot_stability(points, gkey, DATA_DIR)
end

