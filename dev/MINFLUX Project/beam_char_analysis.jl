# Beam characterization data analysis
# Loads HDF5 files from a directory, fits 2D Gaussian profiles to each frame,
# and plots FWHM_x, FWHM_y, and ellipticity vs stage position for each ODE mode.
# Includes control measurement as a dashed reference line.

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/movig EDO1/MAR_3"

# ============================================================================
# Gaussian fitting helpers (profile-based, fast)
# ============================================================================

function background(frame; frac = 0.05)
    thresh = quantile(vec(frame), frac)
    return mean(filter(<=(thresh), vec(frame)))
end

function fit_fwhm(frame)
    # find peak
    idx = argmax(frame)
    cx, cy = idx[1], idx[2]
    bg = background(frame)

    # FWHM along x (column profile through center row)
    xprof = frame[:, cy] .- bg
    xprof = max.(xprof, 0.0)
    x_half = maximum(xprof) / 2
    x_above = findall(>=(x_half), xprof)
    fwhm_x = length(x_above) >= 2 ? Float64(x_above[end] - x_above[1]) : 0.0

    # FWHM along y (row profile through center column)
    yprof = frame[cx, :] .- bg
    yprof = max.(yprof, 0.0)
    y_half = maximum(yprof) / 2
    y_above = findall(>=(y_half), yprof)
    fwhm_y = length(y_above) >= 2 ? Float64(y_above[end] - y_above[1]) : 0.0

    ellipticity = max(fwhm_x, fwhm_y) / max(min(fwhm_x, fwhm_y), 1.0)
    return fwhm_x, fwhm_y, ellipticity
end

# ============================================================================
# Load all measurements from DATA_DIR
# ============================================================================

struct Measurement
    position::Float64
    fwhm_x::Float64
    fwhm_y::Float64
    ellipticity::Float64
    frame::Matrix{Float64}
end

function load_all(dir)
    groups = Dict{String, Vector{Measurement}}()

    for fname in sort(filter(f -> endswith(f, ".h5"), readdir(dir)))
        group = if startswith(fname, "ODE_G")
            "ODE G"
        elseif startswith(fname, "ODE_P")
            "ODE P"
        elseif startswith(fname, "control")
            "Control"
        else
            continue
        end

        try
            h5open(joinpath(dir, fname), "r") do f
                frame    = read(f["frame"])
                position = Float64(HDF5.read_attribute(f, "position"))
                fwhm_x, fwhm_y, ellip = fit_fwhm(frame)
                m = Measurement(position, fwhm_x, fwhm_y, ellip, Float64.(frame))
                push!(get!(groups, group, Measurement[]), m)
            end
            print(".")
        catch e
            @warn "Skipping $fname: $e"
        end
    end
    println()

    # sort each group by position
    for v in values(groups)
        sort!(v, by = m -> m.position)
    end
    return groups
end

# ============================================================================
# Plot
# ============================================================================

function plot_analysis(groups)
    fig = Figure(size = (1100, 850), title = "Beam Characterization — ODE Drift Analysis")

    ax_fx = Axis(fig[1, 1], title = "FWHM X vs Position",
                 xlabel = "Stage Position", ylabel = "FWHM X (px)")
    ax_fy = Axis(fig[1, 2], title = "FWHM Y vs Position",
                 xlabel = "Stage Position", ylabel = "FWHM Y (px)")
    ax_el = Axis(fig[2, 1:2], title = "Ellipticity vs Position",
                 xlabel = "Stage Position", ylabel = "Ellipticity (max/min FWHM)")

    palette = Dict("ODE G" => (:steelblue, :circle),
                   "ODE P" => (:tomato,    :rect),
                   "Control" => (:gray40,  :diamond))

    # extract control single-point values for reference lines (if present)
    ctrl = get(groups, "Control", nothing)
    if ctrl !== nothing && !isempty(ctrl)
        ref_fx = mean(m.fwhm_x     for m in ctrl)
        ref_fy = mean(m.fwhm_y     for m in ctrl)
        ref_el = mean(m.ellipticity for m in ctrl)
        for ax in (ax_fx, ax_fy, ax_el)
            ref_val = ax === ax_fx ? ref_fx : ax === ax_fy ? ref_fy : ref_el
            hlines!(ax, [ref_val]; color = (:gray40, 0.7), linestyle = :dash, linewidth = 2)
        end
    end

    for (label, meas) in sort(collect(groups); by = first)
        label == "Control" && continue  # already drawn as reference lines
        c, mk = palette[label]
        pos  = [m.position    for m in meas]
        fxs  = [m.fwhm_x      for m in meas]
        fys  = [m.fwhm_y      for m in meas]
        els  = [m.ellipticity  for m in meas]

        scatterlines!(ax_fx, pos, fxs, color = c, marker = mk, label = label, markersize = 10)
        scatterlines!(ax_fy, pos, fys, color = c, marker = mk, label = label, markersize = 10)
        scatterlines!(ax_el, pos, els, color = c, marker = mk, label = label, markersize = 10)
    end

    # build legend manually so it works regardless of empty-array plots
    legend_elems  = []
    legend_labels = String[]
    for (label, _) in sort(collect(groups); by = first)
        label == "Control" && continue
        c, mk = palette[label]
        push!(legend_elems,  [MarkerElement(color = c, marker = mk, markersize = 10),
                               LineElement(color = c, linewidth = 2)])
        push!(legend_labels, label)
    end
    if ctrl !== nothing && !isempty(ctrl)
        push!(legend_elems,  LineElement(color = (:gray40, 0.7), linestyle = :dash, linewidth = 2))
        push!(legend_labels, "Control (ref)")
    end
    !isempty(legend_elems) && Legend(fig[2, 3], legend_elems, legend_labels, "ODE Mode",
                                     framevisible = true)

    display(fig)
    return fig
end

# ============================================================================
# Video generation (one MP4 per EOD group)
# ============================================================================

function make_videos(groups, dir; framerate = 10)
    eod_groups = filter(kv -> kv.first != "Control", collect(groups))

    for (label, meas) in sort(eod_groups; by = first)
        isempty(meas) && continue
        tag     = replace(label, " " => "_")
        outpath = joinpath(dir, "$(tag)_video.mp4")

        # build a figure for rendering — tight layout, no extra rows
        fig = Figure(size = (600, 600), backgroundcolor = :black)
        ax  = Axis(fig[1, 1], aspect = DataAspect(),
                   backgroundcolor = :black)
        hidedecorations!(ax)
        hidespines!(ax)
        rowgap!(fig.layout, 0)
        colgap!(fig.layout, 0)

        frame_obs = Observable(meas[1].frame)
        clim      = (0.0, maximum(maximum(m.frame) for m in meas))
        heatmap!(ax, frame_obs; colormap = :inferno, colorrange = clim)

        # position text overlay — top right corner, white on dark background
        pos_obs = Observable("pos: $(round(meas[1].position, digits=3))")
        text!(ax, pos_obs;
              position = (0.98, 0.98), space = :relative,
              align = (:right, :top), color = :white,
              fontsize = 16, font = :bold)

        println("Recording $outpath  ($(length(meas)) frames @ $(framerate) fps)")
        record(fig, outpath, meas; framerate = framerate) do m
            frame_obs[] = m.frame
            pos_obs[]   = "pos: $(round(m.position, digits=3))"
        end
        println("  Saved: $outpath")
    end
end

# ============================================================================
# Run
# ============================================================================

println("Loading HDF5 files from:\n  $DATA_DIR\n")
groups = load_all(DATA_DIR)

println("\nLoaded:")
for (g, v) in sort(collect(groups); by = first)
    positions = [m.position for m in v]
    println("  $g: $(length(v)) files  pos=$(round(minimum(positions), digits=3))–$(round(maximum(positions), digits=3))")
end


fig = plot_analysis(groups)
name_dir = joinpath(DATA_DIR, "beam_quality_plot.png")
save(name_dir, fig)

make_videos(groups, DATA_DIR)