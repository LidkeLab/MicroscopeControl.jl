# angle_defle.jl
# For each EOD folder in mar_25, load all sweep HDF5 files and plot
# HVA1 and HVA2 voltage (DAQ output + monitor) vs center_x / center_y.
# Produces 4 PNGs per EOD folder (one per HVA × one per axis).

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
                    -read_attr(f, "hva1_monitor"),   # negate inverted monitor
                    read_attr(f, "hva2_daq_output"),
                    -read_attr(f, "hva2_monitor"),   # negate inverted monitor
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

function plot_eod(points, eod_name, dir)
    isempty(points) && return

    cx = [p.center_x   for p in points]
    cy = [p.center_y   for p in points]

    configs = [
        ("HVA1", [p.hva1_daq for p in points], [p.hva1_monitor for p in points], :steelblue),
        ("HVA2", [p.hva2_daq for p in points], [p.hva2_monitor for p in points], :tomato),
    ]

    for (hva_name, daq_v, mon_v, c) in configs
        fig = Figure(size = (950, 750))
        Label(fig[0, 1:2], "$eod_name — $hva_name Voltage vs Beam Center";
              fontsize = 16, font = :bold, tellwidth = false)

        ax1 = Axis(fig[1, 1], title = "$hva_name DAQ Output vs Center X",
                   xlabel = "$hva_name DAQ Output (V)", ylabel = "Center X (px)")
        ax2 = Axis(fig[1, 2], title = "$hva_name DAQ Output vs Center Y",
                   xlabel = "$hva_name DAQ Output (V)", ylabel = "Center Y (px)")
        ax3 = Axis(fig[2, 1], title = "$hva_name Monitor vs Center X",
                   xlabel = "$hva_name Monitor (V)", ylabel = "Center X (px)")
        ax4 = Axis(fig[2, 2], title = "$hva_name Monitor vs Center Y",
                   xlabel = "$hva_name Monitor (V)", ylabel = "Center Y (px)")

        scatterlines!(ax1, daq_v, cx; color = c, marker = :circle, markersize = 6)
        scatterlines!(ax2, daq_v, cy; color = c, marker = :circle, markersize = 6)
        scatterlines!(ax3, mon_v, cx; color = c, marker = :circle, markersize = 6)
        scatterlines!(ax4, mon_v, cy; color = c, marker = :circle, markersize = 6)

        display(fig)
        outpath = joinpath(dir, "$(eod_name)_$(hva_name).png")
        save(outpath, fig)
        println("Saved: $outpath")
    end
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
    plot_eod(points, eod_name, DATA_DIR)
end
