# Angle analysis
# ODE1: hva1_daq_output and hva1_monitor vs center_x / center_y
# ODE2: hva2_daq_output and hva2_monitor vs center_x / center_y
# Control file shown as a reference point on every plot.

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/angle/mar_11"

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
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_angle_data(dir)
    groups = Dict{String, Vector{AngleMeasurement}}()

    h5files = sort(filter(f -> endswith(f, ".h5"), readdir(dir)))
    println("  Found $(length(h5files)) HDF5 files:")
    for f in h5files; println("    $f"); end
    println()

    for fname in h5files
        # must check eod1/eod2 BEFORE plain "control"
        group = if occursin("eod1", lowercase(fname))
            "ODE1"
        elseif occursin("eod2", lowercase(fname))
            "ODE2"
        elseif startswith(lowercase(fname), "control")
            "Control"
        else
            @warn "Unmatched file (check naming): $fname"
            continue
        end

        try
            h5open(joinpath(dir, fname), "r") do f
                frame = read(f["frame"])

                cx = read_attr(f, "center_x", NaN)
                cy = read_attr(f, "center_y", NaN)
                if isnan(cx) || isnan(cy)
                    idx = argmax(frame)
                    cx, cy = Float64(idx[1]), Float64(idx[2])
                end

                m = AngleMeasurement(
                    read_attr(f, "hva1_daq_output"),
                    read_attr(f, "hva1_monitor"),
                    read_attr(f, "hva2_daq_output"),
                    read_attr(f, "hva2_monitor"),
                    cx, cy
                )
                push!(get!(groups, group, AngleMeasurement[]), m)
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()

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

        delta_x = [m.center_x - ref_x for m in meas]
        delta_y = [m.center_y - ref_y for m in meas]

        fig = Figure(size = (900, 750))

        Label(fig[0, 1:2], "$gkey — Beam Center Displacement vs $prefix Voltage";
              fontsize = 16, font = :bold, tellwidth = false)

        # ── row 1: DAQ output ──────────────────────────────────────────────
        ax_dx = Axis(fig[1, 1],
                     title  = "$prefix DAQ Output vs ΔCenter X",
                     xlabel = "$prefix DAQ Output (V)",
                     ylabel = "ΔCenter X (px)")
        ax_dy = Axis(fig[1, 2],
                     title  = "$prefix DAQ Output vs ΔCenter Y",
                     xlabel = "$prefix DAQ Output (V)",
                     ylabel = "ΔCenter Y (px)")

        daq_v = daq_fn.(meas)
        scatterlines!(ax_dx, daq_v, delta_x;
                      color = :steelblue, marker = :circle, markersize = 10,
                      label = gkey)
        scatterlines!(ax_dy, daq_v, delta_y;
                      color = :steelblue, marker = :circle, markersize = 10,
                      label = gkey)

        add_control_point!(ax_dx, ctrl, daq_fn)
        add_control_point!(ax_dy, ctrl, daq_fn)

        # ── row 2: Monitor ────────────────────────────────────────────────
        ax_mx = Axis(fig[2, 1],
                     title  = "$prefix Monitor vs ΔCenter X",
                     xlabel = "$prefix Monitor (V)",
                     ylabel = "ΔCenter X (px)")
        ax_my = Axis(fig[2, 2],
                     title  = "$prefix Monitor vs ΔCenter Y",
                     xlabel = "$prefix Monitor (V)",
                     ylabel = "ΔCenter Y (px)")

        mon_v = mon_fn.(meas)
        scatterlines!(ax_mx, mon_v, delta_x;
                      color = :tomato, marker = :circle, markersize = 10,
                      label = gkey)
        scatterlines!(ax_my, mon_v, delta_y;
                      color = :tomato, marker = :circle, markersize = 10,
                      label = gkey)

        add_control_point!(ax_mx, ctrl, mon_fn)
        add_control_point!(ax_my, ctrl, mon_fn)

        # ── legend ────────────────────────────────────────────────────────
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
        Legend(fig[3, 1:2], legend_elems, legend_labels, "$prefix Channel";
               orientation = :horizontal, framevisible = true)

        display(fig)
        outpath = joinpath(dir, "$(gkey)_angle_plot.png")
        save(outpath, fig)
        println("Saved: $outpath")
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
