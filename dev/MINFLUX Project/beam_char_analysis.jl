# Beam characterization data analysis
# Loads HDF5 files from a directory, fits 2D Gaussian profiles to each frame,
# and plots FWHM_x, FWHM_y, and ellipticity vs stage position for each ODE mode.
# Includes control measurement as a dashed reference line.

using HDF5, GLMakie, Statistics, FFTW

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
# Cross-correlation beam quality
# ============================================================================

"""
    xcorr2d(ref, frame) -> NCC map (fftshifted, zero-lag at centre)

Normalised 2-D cross-correlation via FFT.
Peak value = 1.0 when frames are identical (up to a global shift).
"""
function xcorr2d(ref, frame)
    r = ref   .- mean(ref)
    f = frame .- mean(frame)
    cc    = real(ifft(fft(r) .* conj(fft(f))))
    denom = sqrt(sum(r .^ 2) * sum(f .^ 2))
    return denom > 0 ? fftshift(cc) ./ denom : fftshift(cc)
end

"""
    xcorr_metrics(ref, frame) -> (peak_ncc, fwhm_cc_px, dx, dy)

- `peak_ncc`   : peak of the normalised cross-correlation (0–1).  1 = perfect match.
- `fwhm_cc_px` : FWHM of the xcorr peak (px).  Narrower = sharper / better beam.
- `dx`, `dy`   : sub-pixel beam displacement relative to reference (px).
"""
function xcorr_metrics(ref, frame)
    cc  = xcorr2d(ref, frame)
    nx, ny = size(cc)
    cx0, cy0 = nx ÷ 2 + 1, ny ÷ 2 + 1          # index of zero-lag after fftshift

    peak_val = maximum(cc)
    pidx     = argmax(cc)
    dx       = Float64(pidx[1] - cx0)
    dy       = Float64(pidx[2] - cy0)

    # FWHM of xcorr peak: average of x and y profiles through the peak
    half = peak_val / 2
    xprof = cc[:, pidx[2]]
    yprof = cc[pidx[1], :]
    ax = findall(>=(half), xprof)
    ay = findall(>=(half), yprof)
    fwhm_x = length(ax) >= 2 ? Float64(ax[end] - ax[1]) : 0.0
    fwhm_y = length(ay) >= 2 ? Float64(ay[end] - ay[1]) : 0.0
    fwhm_cc = (fwhm_x + fwhm_y) / 2

    return peak_val, fwhm_cc, dx, dy
end

struct XCorrResult
    position::Float64
    peak_ncc::Float64       # 0–1, similarity to reference
    fwhm_cc::Float64        # xcorr peak width (px) — narrower = sharper beam
    dx::Float64             # beam displacement x vs reference (px)
    dy::Float64             # beam displacement y vs reference (px)
end

"""
    compute_xcorr_quality(groups) -> Dict{String, Vector{XCorrResult}}

Uses the mean Control frame as the reference.  Returns xcorr metrics for
every measurement in each group, sorted by position.
"""
function compute_xcorr_quality(groups)
    ctrl = get(groups, "Control", nothing)
    if isnothing(ctrl) || isempty(ctrl)
        @warn "No Control group found — cannot compute cross-correlation quality"
        return nothing
    end

    # average all control frames → reference
    ref = mean(Float64.(m.frame) for m in ctrl)

    results = Dict{String, Vector{XCorrResult}}()
    for (label, meas) in groups
        res = XCorrResult[]
        for m in meas
            peak, fwhm_cc, dx, dy = xcorr_metrics(ref, Float64.(m.frame))
            push!(res, XCorrResult(m.position, peak, fwhm_cc, dx, dy))
        end
        sort!(res, by = r -> r.position)
        results[label] = res
    end
    return results
end

function plot_xcorr_quality(xcorr_results)
    isnothing(xcorr_results) && return

    fig = Figure(size = (1100, 900))
    Label(fig[0, 1:3], "Beam Quality — 2D Cross-Correlation vs Control Reference";
          fontsize = 16, font = :bold, tellwidth = false)

    ax_ncc  = Axis(fig[1, 1], title = "Peak NCC (similarity to control)",
                   xlabel = "Stage Position", ylabel = "Peak NCC (0–1)")
    ax_fwhm = Axis(fig[1, 2], title = "Xcorr Peak FWHM (beam sharpness)",
                   xlabel = "Stage Position", ylabel = "Xcorr FWHM (px)")
    ax_dx   = Axis(fig[2, 1], title = "Beam Displacement ΔX vs Control",
                   xlabel = "Stage Position", ylabel = "ΔX (px)")
    ax_dy   = Axis(fig[2, 2], title = "Beam Displacement ΔY vs Control",
                   xlabel = "Stage Position", ylabel = "ΔY (px)")

    palette = Dict("ODE G"   => (:steelblue, :circle),
                   "ODE P"   => (:tomato,    :rect),
                   "Control" => (:gray40,    :diamond))

    # control reference lines: NCC = 1, FWHM = self-correlation peak, displacement = 0
    ctrl_res = get(xcorr_results, "Control", nothing)
    if !isnothing(ctrl_res) && !isempty(ctrl_res)
        ref_ncc  = mean(r.peak_ncc  for r in ctrl_res)
        ref_fwhm = mean(r.fwhm_cc   for r in ctrl_res)
        hlines!(ax_ncc,  [ref_ncc];  color = (:gray40, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_fwhm, [ref_fwhm]; color = (:gray40, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_dx,   [0.0];      color = (:gray40, 0.7), linestyle = :dash, linewidth = 2)
        hlines!(ax_dy,   [0.0];      color = (:gray40, 0.7), linestyle = :dash, linewidth = 2)
    end

    legend_elems  = []
    legend_labels = String[]

    for (label, res) in sort(collect(xcorr_results); by = first)
        label == "Control" && continue
        c, mk = get(palette, label, (:black, :circle))
        pos  = [r.position  for r in res]
        ncc  = [r.peak_ncc  for r in res]
        fwhm = [r.fwhm_cc   for r in res]
        dxs  = [r.dx        for r in res]
        dys  = [r.dy        for r in res]

        scatterlines!(ax_ncc,  pos, ncc;  color = c, marker = mk, markersize = 10)
        scatterlines!(ax_fwhm, pos, fwhm; color = c, marker = mk, markersize = 10)
        scatterlines!(ax_dx,   pos, dxs;  color = c, marker = mk, markersize = 10)
        scatterlines!(ax_dy,   pos, dys;  color = c, marker = mk, markersize = 10)

        push!(legend_elems,  [MarkerElement(color = c, marker = mk, markersize = 10),
                               LineElement(color = c, linewidth = 2)])
        push!(legend_labels, label)
    end

    if !isnothing(ctrl_res) && !isempty(ctrl_res)
        push!(legend_elems,  LineElement(color = (:gray40, 0.7), linestyle = :dash, linewidth = 2))
        push!(legend_labels, "Control (ref)")
    end
    !isempty(legend_elems) && Legend(fig[1:2, 3], legend_elems, legend_labels, "ODE Mode",
                                     framevisible = true)

    display(fig)
    outpath = joinpath(DATA_DIR, "beam_quality_xcorr.png")
    save(outpath, fig)
    println("Saved: $outpath")
    return fig
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

function make_videos(groups, dir; seconds_per_frame = 2)
    eod_groups = filter(kv -> kv.first != "Control", collect(groups))

    # Makie requires integer framerate; repeat each frame to achieve desired duration
    fps        = 10
    n_repeat   = max(1, round(Int, fps * seconds_per_frame))

    for (label, meas) in sort(eod_groups; by = first)
        isempty(meas) && continue
        tag     = replace(label, " " => "_")
        outpath = joinpath(dir, "$(tag)_video.mp4")

        # figure sized to the native frame resolution — fills entire video
        nx, ny = size(meas[1].frame)   # frame is (width, height)
        fig = Figure(size = (nx, ny), backgroundcolor = :black, figure_padding = 0)
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

        println("Recording $outpath  ($(length(meas)) frames, $(seconds_per_frame)s each @ $(fps) fps)")
        record(fig, outpath; framerate = fps) do io
            for m in meas
                frame_obs[] = m.frame
                pos_obs[]   = "pos: $(round(m.position, digits=3))"
                for _ in 1:n_repeat
                    recordframe!(io)
                end
            end
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

println("\nComputing cross-correlation beam quality…")
xcorr_results = compute_xcorr_quality(groups)
plot_xcorr_quality(xcorr_results)

make_videos(groups, DATA_DIR)