# polarization_angle.jl
# Load voltage-sweep HDF5 files for multiple polarization conditions and plot
# voltage vs beam position for HVA1 and HVA2.  Computes mrad/kV calibration
# for each polarization and annotates the values directly on the figures.
#
# Expected folder structure:
#   DATA_DIR/
#     <polarization_label>/
#       EOD34/   ← HVA1 sweep files
#       EOD35/   ← HVA2 sweep files

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/polarization/apr4"

const PIXEL_SIZE_UM   = 5.2      # camera pixel pitch (µm)
const EOD_DISTANCE_MM = 350.0    # EOD → camera sensor (mm)
const SPEC_MRAD_PER_KV = 3.0     # manufacturer spec

# ============================================================================
# Data struct & loading
# ============================================================================

struct SweepPoint
    sweep_step::Int
    sweep_voltage::Float64
    hva1_daq::Float64
    hva1_monitor::Float64   # real HVA1 output (V): negate × 20
    hva2_daq::Float64
    hva2_monitor::Float64   # real HVA2 output (V): negate × 20
    center_x::Float64
    center_y::Float64
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_eod_folder(folder_path)
    h5files = sort(filter(f -> endswith(f, ".h5"), readdir(folder_path)))
    println("    $(length(h5files)) files in $(basename(folder_path))")
    points = SweepPoint[]
    for fname in h5files
        try
            h5open(joinpath(folder_path, fname), "r") do f
                push!(points, SweepPoint(
                    Int(read_attribute(f, "sweep_step")),
                    read_attr(f, "sweep_voltage"),
                    read_attr(f, "hva1_daq_output"),
                    -read_attr(f, "hva1_monitor") * 20,
                    read_attr(f, "hva2_daq_output"),
                    -read_attr(f, "hva2_monitor") * 20,
                    read_attr(f, "center_x"),
                    read_attr(f, "center_y"),
                ))
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
# Calibration
# ============================================================================

struct CalResult
    mrad_per_V::Float64
    mrad_per_kV::Float64
    pct_spec::Float64
    ΔV::Float64
    Δpos_px::Float64
    θ_mrad::Float64
end

function compute_calibration(points, hva_num)::Union{CalResult, Nothing}
    isempty(points) && return nothing
    mon_v = hva_num == 1 ? [p.hva1_monitor for p in points] :
                            [p.hva2_monitor for p in points]
    cx    = [p.center_x for p in points]
    cy    = [p.center_y for p in points]

    imin = argmin(mon_v);  imax = argmax(mon_v)
    ΔV      = mon_v[imax] - mon_v[imin]
    ΔV == 0 && return nothing

    Δpos_px = sqrt((cx[imax] - cx[imin])^2 + (cy[imax] - cy[imin])^2)
    Δpos_m  = Δpos_px * PIXEL_SIZE_UM * 1e-6
    θ_rad   = atan(Δpos_m / (EOD_DISTANCE_MM * 1e-3))
    θ_mrad  = θ_rad * 1e3
    mrad_per_V  = θ_mrad / ΔV
    mrad_per_kV = mrad_per_V * 1000.0
    pct_spec    = abs(mrad_per_V) / (SPEC_MRAD_PER_KV / 1000.0) * 100.0
    return CalResult(mrad_per_V, mrad_per_kV, pct_spec, ΔV, Δpos_px, θ_mrad)
end

# ============================================================================
# Plotting — one figure per HVA channel
# ============================================================================

const COLORS = [:steelblue, :tomato, :seagreen, :darkorange, :mediumpurple,
                :crimson, :teal, :goldenrod]

function plot_polarization_hva(all_data, hva_num)
    hva_name = "HVA$hva_num"
    pol_names = sort(collect(keys(all_data)))
    isempty(pol_names) && return

    fig = Figure(size = (1200, 950))
    Label(fig[0, 1:3],
          "$hva_name — Voltage vs Beam Position by Polarization  " *
          "(pixel size $(PIXEL_SIZE_UM) µm, EOD→cam $(EOD_DISTANCE_MM) mm)";
          fontsize = 15, font = :bold, tellwidth = false)

    # ── row 1: position + cx ─────────────────────────────────────────────────
    ax_pos = Axis(fig[1, 1],
                  title  = "Monitor vs √(cx²+cy²)",
                  xlabel = "$hva_name Real Output (V)",
                  ylabel = "Position (px)")
    ax_cx  = Axis(fig[1, 2],
                  title  = "Monitor vs Center X",
                  xlabel = "$hva_name Real Output (V)",
                  ylabel = "Center X (px)")

    # ── row 2: cy + calibration bar ──────────────────────────────────────────
    ax_cy  = Axis(fig[2, 1],
                  title  = "Monitor vs Center Y",
                  xlabel = "$hva_name Real Output (V)",
                  ylabel = "Center Y (px)")
    ax_bar = Axis(fig[2, 2],
                  title  = "mrad / kV by Polarization  (spec = $(SPEC_MRAD_PER_KV) mrad/kV)",
                  xlabel = "Polarization",
                  ylabel = "mrad / kV")
    ax_bar.xticklabelrotation[] = π / 5

    legend_elems  = []
    legend_labels = String[]
    bar_vals      = Float64[]

    for (k, pol) in enumerate(pol_names)
        points = all_data[pol]
        isempty(points) && continue
        c = COLORS[mod1(k, length(COLORS))]

        mon_v = hva_num == 1 ? [p.hva1_monitor for p in points] :
                                [p.hva2_monitor for p in points]
        cx_v  = [p.center_x for p in points]
        cy_v  = [p.center_y for p in points]
        pos_v = sqrt.(cx_v .^ 2 .+ cy_v .^ 2)

        scatterlines!(ax_pos, mon_v, pos_v; color = c, markersize = 6)
        scatterlines!(ax_cx,  mon_v, cx_v;  color = c, markersize = 6)
        scatterlines!(ax_cy,  mon_v, cy_v;  color = c, markersize = 6)

        cal = compute_calibration(points, hva_num)
        mkv = cal === nothing ? NaN : cal.mrad_per_kV
        push!(bar_vals, isnan(mkv) ? 0.0 : mkv)

        # Annotate position plot with mrad/kV value
        if cal !== nothing
            imax = argmax(mon_v)
            text!(ax_pos,
                  "$(round(cal.mrad_per_kV, digits = 2)) mrad/kV";
                  position  = (mon_v[imax], pos_v[imax]),
                  color     = c,
                  fontsize  = 10,
                  align     = (:left, :bottom))
        end

        push!(legend_elems,  [MarkerElement(color = c, marker = :circle, markersize = 9),
                               LineElement(color = c, linewidth = 2)])
        push!(legend_labels, pol)
    end

    # ── calibration bar chart ─────────────────────────────────────────────────
    if !isempty(pol_names)
        xs = 1:length(pol_names)
        barplot!(ax_bar, xs, bar_vals;
                 color = [COLORS[mod1(k, length(COLORS))] for k in xs])
        ax_bar.xticks = (xs, pol_names)
        hlines!(ax_bar, [SPEC_MRAD_PER_KV];
                color = :gray40, linestyle = :dash, linewidth = 2)
        ymax = maximum(abs.(bar_vals); init = 0.0)
        for (i, v) in zip(xs, bar_vals)
            text!(ax_bar, "$(round(v, digits = 2))";
                  position = (Float64(i), v + 0.03 * ymax),
                  align    = (:center, :bottom),
                  fontsize = 11)
        end
        # spec label
        text!(ax_bar, "spec $(SPEC_MRAD_PER_KV) mrad/kV";
              position = (Float64(last(xs)) + 0.1, SPEC_MRAD_PER_KV),
              color    = :gray40, fontsize = 10, align = (:left, :center))
    end

    # ── legend ────────────────────────────────────────────────────────────────
    !isempty(legend_elems) &&
        Legend(fig[1:2, 3], legend_elems, legend_labels, "Polarization";
               framevisible = true)

    display(fig)
    outpath = joinpath(DATA_DIR, "$(hva_name)_polarization_angle.png")
    save(outpath, fig)
    println("Saved: $outpath")
    return fig
end

# ============================================================================
# Run
# ============================================================================

println("Scanning: $DATA_DIR\n")

# Structure: DATA_DIR/EOD34/<pol>/*.h5   (HVA1)
#            DATA_DIR/EOD35/<pol>/*.h5   (HVA2)
all_hva1 = Dict{String, Vector{SweepPoint}}()
all_hva2 = Dict{String, Vector{SweepPoint}}()

for eod_dir in sort(filter(d -> isdir(joinpath(DATA_DIR, d)), readdir(DATA_DIR)))
    eod_path = joinpath(DATA_DIR, eod_dir)
    hva_num  = occursin("34", eod_dir) ? 1 :
               occursin("35", eod_dir) ? 2 : continue
    dict     = hva_num == 1 ? all_hva1 : all_hva2
    println("$eod_dir → HVA$hva_num")

    for pol in sort(filter(d -> isdir(joinpath(eod_path, d)), readdir(eod_path)))
        print("  $pol: ")
        pts = load_eod_folder(joinpath(eod_path, pol))
        dict[pol] = pts
        println("  $(length(pts)) points")
    end
    println()
end

# ── Calibration table ─────────────────────────────────────────────────────────
println("=" ^ 72)
println(rpad("Polarization", 20), rpad("Channel", 8),
        rpad("ΔV (V)", 10), rpad("Δpos (px)", 12),
        rpad("θ (mrad)", 12), rpad("mrad/kV", 12), "% spec")
println("-" ^ 72)
for pol in sort(union(collect(keys(all_hva1)), collect(keys(all_hva2))))
    for (hva_num, dict) in ((1, all_hva1), (2, all_hva2))
        haskey(dict, pol) || continue
        cal = compute_calibration(dict[pol], hva_num)
        cal === nothing && continue
        println(rpad(pol, 20), rpad("HVA$hva_num", 8),
                rpad(round(cal.ΔV,        digits=3), 10),
                rpad(round(cal.Δpos_px,   digits=1), 12),
                rpad(round(cal.θ_mrad,    digits=4), 12),
                rpad(round(cal.mrad_per_kV, digits=3), 12),
                "$(round(cal.pct_spec, digits=1))%")
    end
end
println("=" ^ 72)

plot_polarization_hva(all_hva1, 1)
plot_polarization_hva(all_hva2, 2)
