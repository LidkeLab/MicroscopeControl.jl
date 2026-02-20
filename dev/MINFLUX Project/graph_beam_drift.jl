# graph_beam_drift.jl
# Loads beam characterization HDF5 files and plots beam center displacement vs position
# Separates osc1 and osc2G series, uses control file as reference origin

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/movig EDO1"

# ============================================================================
# Load data from all HDF5 files in a directory, grouped by series name
# ============================================================================

"""
    load_series(dir, tag)

Load all HDF5 files whose filename contains `tag` (e.g. "osc1" or "osc2G").
Control files (containing "control") are excluded from the main series
but returned separately.
Returns (data, control) where each is a Vector of NamedTuples.
"""
function load_series(dir::String, tag::String)
    files = filter(f -> endswith(f, ".h5") && occursin(tag, f), readdir(dir, join=true))
    control_files = filter(f -> occursin("control", f), files)
    data_files    = filter(f -> !occursin("control", f), files)

    load_file = f -> begin
        h5open(f, "r") do h5
            a = attrs(h5)
            (
                position    = haskey(a, "position")    ? Float64(read(a["position"]))    : 0.0,
                center_x    = haskey(a, "center_x")    ? Float64(read(a["center_x"]))    : NaN,
                center_y    = haskey(a, "center_y")    ? Float64(read(a["center_y"]))    : NaN,
                fwhm_x      = haskey(a, "fwhm_x")      ? Float64(read(a["fwhm_x"]))      : NaN,
                fwhm_y      = haskey(a, "fwhm_y")      ? Float64(read(a["fwhm_y"]))       : NaN,
                ellipticity = haskey(a, "ellipticity") ? Float64(read(a["ellipticity"])) : NaN,
                ext_ratio   = haskey(a, "extinction_ratio") ? Float64(read(a["extinction_ratio"])) : NaN,
                beam_type   = haskey(a, "beam_type")   ? String(read(a["beam_type"]))    : "unknown",
                timestamp   = haskey(a, "timestamp")   ? String(read(a["timestamp"]))    : "",
                filename    = basename(f),
            )
        end
    end

    data    = [load_file(f) for f in sort(data_files)]
    control = isempty(control_files) ? nothing : load_file(first(sort(control_files)))
    return data, control
end

"""
    beam_distance(data, ref_cx, ref_cy)

Compute the Euclidean beam center displacement from a reference point (in pixels).
"""
function beam_distance(d, ref_cx, ref_cy)
    sqrt((d.center_x - ref_cx)^2 + (d.center_y - ref_cy)^2)
end

# ============================================================================
# Main plotting function
# ============================================================================

function graph_beam_drift(data_dir::String = DATA_DIR)

    println("Loading osc1 series...")
    osc1_data, osc1_ctrl = load_series(data_dir, "osc1")
    println("  $(length(osc1_data)) data files, control: $(osc1_ctrl !== nothing)")

    println("Loading osc2G series...")
    osc2_data, osc2_ctrl = load_series(data_dir, "osc2G")
    println("  $(length(osc2_data)) data files, control: $(osc2_ctrl !== nothing)")

    # Reference origin: use control file center if available, else first data point
    ref1_cx = osc1_ctrl !== nothing ? osc1_ctrl.center_x : osc1_data[1].center_x
    ref1_cy = osc1_ctrl !== nothing ? osc1_ctrl.center_y : osc1_data[1].center_y
    ref2_cx = osc2_ctrl !== nothing ? osc2_ctrl.center_x : osc2_data[1].center_x
    ref2_cy = osc2_ctrl !== nothing ? osc2_ctrl.center_y : osc2_data[1].center_y

    # Extract position and distance vectors
    osc1_pos  = [d.position for d in osc1_data]
    osc1_dist = [beam_distance(d, ref1_cx, ref1_cy) for d in osc1_data]
    osc2_pos  = [d.position for d in osc2_data]
    osc2_dist = [beam_distance(d, ref2_cx, ref2_cy) for d in osc2_data]

    # Sort by position
    osc1_ord  = sortperm(osc1_pos)
    osc2_ord  = sortperm(osc2_pos)
    osc1_pos  = osc1_pos[osc1_ord];  osc1_dist = osc1_dist[osc1_ord]
    osc2_pos  = osc2_pos[osc2_ord];  osc2_dist = osc2_dist[osc2_ord]

    # FWHM and beam quality (Gaussian only)
    osc1_fwhm_x = [osc1_data[i].fwhm_x for i in osc1_ord]
    osc1_fwhm_y = [osc1_data[i].fwhm_y for i in osc1_ord]
    osc2_fwhm_x = [osc2_data[i].fwhm_x for i in osc2_ord]
    osc2_fwhm_y = [osc2_data[i].fwhm_y for i in osc2_ord]
    has_fwhm = !all(isnan, osc1_fwhm_x) || !all(isnan, osc2_fwhm_x)

    # ========== Build figure ==========
    fig = Figure(size = (1000, has_fwhm ? 700 : 400), title = "Beam Drift Analysis")

    # --- Plot 1: Position vs Beam Center Displacement ---
    ax1 = Axis(fig[1, 1],
        title  = "Beam Center Displacement vs EOD Position",
        xlabel = "EOD Position",
        ylabel = "Beam Displacement (px)",
    )

    lines!(ax1,  osc1_pos, osc1_dist, color = :royalblue,  linewidth = 2, label = "osc1")
    scatter!(ax1, osc1_pos, osc1_dist, color = :royalblue,  markersize = 8)
    lines!(ax1,  osc2_pos, osc2_dist, color = :orangered,  linewidth = 2, label = "osc2G")
    scatter!(ax1, osc2_pos, osc2_dist, color = :orangered,  markersize = 8)

    # mark control reference points
    if osc1_ctrl !== nothing
        scatter!(ax1, [osc1_ctrl.position], [0.0], color = :royalblue, marker = :star5, markersize = 16, label = "osc1 control")
    end
    if osc2_ctrl !== nothing
        scatter!(ax1, [osc2_ctrl.position], [0.0], color = :orangered, marker = :star5, markersize = 16, label = "osc2G control")
    end

    axislegend(ax1, position = :lt)

    # --- Plot 2: FWHM vs Position (if Gaussian data available) ---
    if has_fwhm
        ax2 = Axis(fig[2, 1],
            title  = "Beam FWHM vs EOD Position",
            xlabel = "EOD Position",
            ylabel = "FWHM (px)",
        )
        if !all(isnan, osc1_fwhm_x)
            lines!(ax2,  osc1_pos, osc1_fwhm_x, color = :royalblue,    linewidth = 2, label = "osc1 FWHM x")
            lines!(ax2,  osc1_pos, osc1_fwhm_y, color = :cornflowerblue, linewidth = 2, linestyle = :dash, label = "osc1 FWHM y")
        end
        if !all(isnan, osc2_fwhm_x)
            lines!(ax2,  osc2_pos, osc2_fwhm_x, color = :orangered,    linewidth = 2, label = "osc2G FWHM x")
            lines!(ax2,  osc2_pos, osc2_fwhm_y, color = :tomato,       linewidth = 2, linestyle = :dash, label = "osc2G FWHM y")
        end
        axislegend(ax2, position = :lt)
    end

    display(fig)

    # Print summary table
    println("\n=== osc1 summary ===")
    println("  Position range: $(minimum(osc1_pos)) → $(maximum(osc1_pos))")
    println("  Max displacement: $(round(maximum(osc1_dist), digits=2)) px")
    if !all(isnan, osc1_fwhm_x)
        println("  Mean FWHM x: $(round(mean(filter(!isnan, osc1_fwhm_x)), digits=2)) px")
        println("  Mean FWHM y: $(round(mean(filter(!isnan, osc1_fwhm_y)), digits=2)) px")
    end

    println("\n=== osc2G summary ===")
    println("  Position range: $(minimum(osc2_pos)) → $(maximum(osc2_pos))")
    println("  Max displacement: $(round(maximum(osc2_dist), digits=2)) px")
    if !all(isnan, osc2_fwhm_x)
        println("  Mean FWHM x: $(round(mean(filter(!isnan, osc2_fwhm_x)), digits=2)) px")
        println("  Mean FWHM y: $(round(mean(filter(!isnan, osc2_fwhm_y)), digits=2)) px")
    end

    return fig
end

# To run:
# graph_beam_drift()
# Or with a custom path:
# graph_beam_drift("path/to/your/data")
