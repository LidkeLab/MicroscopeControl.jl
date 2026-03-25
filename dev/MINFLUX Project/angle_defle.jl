# angle_defle.jl
# For each EOD folder in mar_25, load all sweep HDF5 files and plot
# voltage (DAQ output + monitor) vs beam position sqrt(cx²+cy²).
# EOD34 → HVA1 only.  EOD35 → HVA2 only.

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/angle/mar_25"

# ============================================================================
# Data struct & loading
# ============================================================================

struct SweepPoint
    sweep_step::Int
    sweep_voltage::Float64
    hva1_daq::Float64
    hva1_monitor::Float64
    hva2_daq::Float64
    hva2_monitor::Float64
    center_x::Float64
    center_y::Float64
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_eod_folder(folder_path)
    h5files = sort(filter(f -> endswith(f, ".h5"), readdir(folder_path)))
    println("  Found $(length(h5files)) files in $(basename(folder_path))")

    points = SweepPoint[]
    for fname in h5files
        try
            h5open(joinpath(folder_path, fname), "r") do f
                p = SweepPoint(
                    Int(read_attribute(f, "sweep_step")),
                    read_attr(f, "sweep_voltage"),
                    read_attr(f, "hva1_daq_output"),
                    -read_attr(f, "hva1_monitor") * 20,   # negate + ×20 → real HVA output (V)
                    read_attr(f, "hva2_daq_output"),
                    -read_attr(f, "hva2_monitor") * 20,   # negate + ×20 → real HVA output (V)
                    read_attr(f, "center_x"),
                    read_attr(f, "center_y"),
                )
                push!(points, p)
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()
    sort!(points, by = p -> p.sweep_step)
    return points
end

# ============================================================================
# Plotting
# ============================================================================

function plot_eod(points, eod_name)
    isempty(points) && return

    # beam position = Euclidean distance from image origin
    pos = [sqrt(p.center_x^2 + p.center_y^2) for p in points]

    # select HVA channel based on EOD folder name
    hva_num  = occursin("34", eod_name) ? 1 : 2
    hva_name = "HVA$hva_num"
    daq_v    = hva_num == 1 ? [p.hva1_daq     for p in points] :
                               [p.hva2_daq     for p in points]
    mon_v    = hva_num == 1 ? [p.hva1_monitor for p in points] :
                               [p.hva2_monitor for p in points]
    c        = hva_num == 1 ? :steelblue : :tomato

    cx = [p.center_x for p in points]
    cy = [p.center_y for p in points]

    fig = Figure(size = (950, 800))
    Label(fig[0, 1:2], "$eod_name — $hva_name Voltage vs Beam Position";
          fontsize = 16, font = :bold, tellwidth = false)

    # ── row 1: vs total position ──────────────────────────────────────────
    ax1 = Axis(fig[1, 1], title = "$hva_name DAQ Output vs Position",
               xlabel = "$hva_name DAQ Output (V)",
               ylabel = "Position √(cx² + cy²) (px)")
    ax2 = Axis(fig[1, 2], title = "$hva_name Monitor vs Position",
               xlabel = "$hva_name Real Output (V)",
               ylabel = "Position √(cx² + cy²) (px)")

    scatterlines!(ax1, daq_v, pos; color = c, marker = :circle, markersize = 6)
    scatterlines!(ax2, mon_v, pos; color = c, marker = :circle, markersize = 6)

    # ── row 2: center x and center y vs monitor ───────────────────────────
    ax3 = Axis(fig[2, 1], title = "$hva_name Monitor vs Center X",
               xlabel = "$hva_name Real Output (V)", ylabel = "Center X (px)")
    ax4 = Axis(fig[2, 2], title = "$hva_name Monitor vs Center Y",
               xlabel = "$hva_name Real Output (V)", ylabel = "Center Y (px)")

    scatterlines!(ax3, mon_v, cx; color = c, marker = :circle, markersize = 6)
    scatterlines!(ax4, mon_v, cy; color = c, marker = :circle, markersize = 6)

    display(fig)
    outpath = joinpath(DATA_DIR, "$(eod_name)_$(hva_name).png")
    save(outpath, fig)
    println("Saved: $outpath")
end

# ============================================================================
# Angle calibration
# ============================================================================
# Physical constants — adjust to match your setup
const PIXEL_SIZE_UM = 3.45      # camera pixel size in micrometres (µm)
const EOD_DISTANCE_MM = 265.0   # distance from EOD to camera sensor in mm

function compute_angle_calibration(points, eod_name)
    isempty(points) && return

    hva_num  = occursin("34", eod_name) ? 1 : 2
    hva_name = "HVA$hva_num"
    mon_v    = hva_num == 1 ? [-p.hva1_monitor for p in points] :
                               [-p.hva2_monitor for p in points]  # already ×20; negate inverted reading
    cx       = [p.center_x for p in points]
    cy       = [p.center_y for p in points]

    # ── linear fit: center = slope * voltage + intercept ──────────────────
    function linfit(v, c)
        A = hcat(v, ones(length(v)))
        coeffs = A \ c
        slope, intercept = coeffs[1], coeffs[2]
        resid  = c .- (slope .* v .+ intercept)
        ss_res = sum(resid .^ 2)
        ss_tot = sum((c .- mean(c)) .^ 2)
        r2     = 1.0 - ss_res / ss_tot
        return slope, intercept, r2
    end

    pos = sqrt.(cx .^ 2 .+ cy .^ 2)   # total distance from image origin

    slope_cx,  _, r2_cx  = linfit(mon_v, cx)
    slope_cy,  _, r2_cy  = linfit(mon_v, cy)
    slope_pos, _, r2_pos = linfit(mon_v, pos)

    # ── unit conversion ────────────────────────────────────────────────────
    # small-angle approx: θ (rad) = displacement (m) / distance (m)
    px_to_m = PIXEL_SIZE_UM * 1e-6
    dist_m  = EOD_DISTANCE_MM * 1e-3

    function to_calibration(slope_px_per_V)
        rad_per_V  = slope_px_per_V * px_to_m / dist_m
        mrad_per_V = rad_per_V * 1e3
        deg_per_V  = rad_per_V * 180.0 / π
        V_per_mrad = abs(rad_per_V) > 0 ? 1.0 / mrad_per_V : NaN
        V_per_deg  = abs(rad_per_V) > 0 ? 1.0 / deg_per_V  : NaN
        return mrad_per_V, deg_per_V, V_per_mrad, V_per_deg
    end

    println("=" ^ 60)
    println("Angle Calibration — $eod_name ($hva_name)  [monitor ×20 = real output]")
    println("  Pixel size : $(PIXEL_SIZE_UM) µm")
    println("  EOD→camera : $(EOD_DISTANCE_MM) mm")
    println()

    for (label, slope, r2) in [
            ("Monitor×20 → Center X",        slope_cx,  r2_cx),
            ("Monitor×20 → Center Y",        slope_cy,  r2_cy),
            ("Monitor×20 → Distance √(X²+Y²)", slope_pos, r2_pos),
        ]
        mrad_V, deg_V, V_mrad, V_deg = to_calibration(slope)
        println("  $label")
        println("    Slope      : $(round(slope,   digits=4)) px/V   (R² = $(round(r2, digits=4)))")
        println("    Deflection : $(round(mrad_V,  digits=4)) mrad/V  |  $(round(deg_V, digits=4)) deg/V")
        println("    Sensitivity: $(round(V_mrad,  digits=4)) V/mrad  |  $(round(V_deg, digits=4)) V/deg")
        println()
    end
    println("=" ^ 60)
end

# ============================================================================
# Run
# ============================================================================

println("Scanning: $DATA_DIR\n")

eod_dirs = sort(filter(d -> isdir(joinpath(DATA_DIR, d)), readdir(DATA_DIR)))
println("Found EOD folders: $(eod_dirs)\n")

for eod_name in eod_dirs
    folder = joinpath(DATA_DIR, eod_name)
    println("Loading $eod_name…")
    points = load_eod_folder(folder)
    println("  Loaded $(length(points)) sweep points")
    if !isempty(points)
        println("  sweep_voltage range: $(round(minimum(p.sweep_voltage for p in points), digits=3)) – $(round(maximum(p.sweep_voltage for p in points), digits=3)) V")
        println("  center_x range: $(round(minimum(p.center_x for p in points), digits=1)) – $(round(maximum(p.center_x for p in points), digits=1)) px")
        println("  center_y range: $(round(minimum(p.center_y for p in points), digits=1)) – $(round(maximum(p.center_y for p in points), digits=1)) px")
    end
    println()
    plot_eod(points, eod_name)
    compute_angle_calibration(points, eod_name)
end
