# graph_beam_drift.jl
# Loads beam characterization HDF5 files and plots beam characterization vs EOD position.
# Each metric is saved as a separate PNG in the same directory as the data.
#
# Output files:
#   01_beam_displacement.png
#   02_center_x.png
#   03_center_y.png
#   04_fwhm.png                  (if Gaussian data)
#   05_ellipticity.png           (if Gaussian data)  or  05_extinction_ratio.png (if donut)
#   06_beam_omega.png            (if data)
#   07_max_photons.png           (if data)
#   08_fit_quality_r2.png        (if data)

using HDF5, GLMakie, Statistics

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/movig EDO1"

# Position calibration: raw position value × POS_TO_32IN = position in 1/32 inch
# Calibrated from: raw 0.100 → 4/32 in  ⟹  scale = 4 / (32 × 0.100) × 32 = 40
const POS_TO_32IN = 40.0

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
                position       = haskey(a, "position")          ? Float64(a["position"])          : 0.0,
                center_x       = haskey(a, "center_x")          ? Float64(a["center_x"])          : NaN,
                center_y       = haskey(a, "center_y")          ? Float64(a["center_y"])          : NaN,
                fwhm_x         = haskey(a, "fwhm_x")            ? Float64(a["fwhm_x"])            : NaN,
                fwhm_y         = haskey(a, "fwhm_y")            ? Float64(a["fwhm_y"])            : NaN,
                ellipticity    = haskey(a, "ellipticity")        ? Float64(a["ellipticity"])       : NaN,
                ext_ratio      = haskey(a, "extinction_ratio")   ? Float64(a["extinction_ratio"])  : NaN,
                omega          = haskey(a, "omega")              ? Float64(a["omega"])             : NaN,
                optim_r2       = haskey(a, "optim_r_squared")    ? Float64(a["optim_r_squared"])   : NaN,
                approx_r2      = haskey(a, "approx_r_squared")   ? Float64(a["approx_r_squared"])  : NaN,
                max_photons    = haskey(a, "max_photon_count")   ? Float64(a["max_photon_count"])  : NaN,
                min_photons    = haskey(a, "min_photon_count")   ? Float64(a["min_photon_count"])  : NaN,
                amplitude      = haskey(a, "C")                  ? Float64(a["C"])                 : NaN,
                beam_type      = haskey(a, "beam_type")          ? String(a["beam_type"])          : "unknown",
                timestamp      = haskey(a, "timestamp")          ? String(a["timestamp"])          : "",
                filename       = basename(f),
            )
        end
    end

    data    = [load_file(f) for f in sort(data_files)]
    control = isempty(control_files) ? nothing : load_file(first(sort(control_files)))
    return data, control
end

"""
    beam_distance(d, ref_cx, ref_cy)

Euclidean beam center displacement from a reference point (pixels).
"""
function beam_distance(d, ref_cx, ref_cy)
    sqrt((d.center_x - ref_cx)^2 + (d.center_y - ref_cy)^2)
end

# helper: pick the better R² value (optim preferred, fall back to approx)
best_r2(d) = isnan(d.optim_r2) ? d.approx_r2 : d.optim_r2

# helper: draw a horizontal dashed reference line from a control measurement
function ctrl_hline!(ax, ctrl, getter, color; label="")
    ctrl === nothing && return
    v = getter(ctrl)
    isnan(v) && return
    hlines!(ax, [v], color = color, linestyle = :dash, linewidth = 1.5, label = label)
end

# ============================================================================
# Main function
# ============================================================================

function graph_beam_drift(data_dir::String = DATA_DIR)

    println("Loading osc1 series...")
    osc1_data, osc1_ctrl = load_series(data_dir, "osc1")
    println("  $(length(osc1_data)) data files, control: $(osc1_ctrl !== nothing)")

    println("Loading osc2G series...")
    osc2_data, osc2_ctrl = load_series(data_dir, "osc2G")
    println("  $(length(osc2_data)) data files, control: $(osc2_ctrl !== nothing)")

    # Reference origin: control file center if available, else first data point
    ref1_cx = osc1_ctrl !== nothing ? osc1_ctrl.center_x : osc1_data[1].center_x
    ref1_cy = osc1_ctrl !== nothing ? osc1_ctrl.center_y : osc1_data[1].center_y
    ref2_cx = osc2_ctrl !== nothing ? osc2_ctrl.center_x : osc2_data[1].center_x
    ref2_cy = osc2_ctrl !== nothing ? osc2_ctrl.center_y : osc2_data[1].center_y

    # Sort both series by position
    osc1_pos_raw = [d.position for d in osc1_data]
    osc2_pos_raw = [d.position for d in osc2_data]
    osc1_ord = sortperm(osc1_pos_raw)
    osc2_ord = sortperm(osc2_pos_raw)

    ord1(v) = v[osc1_ord]
    ord2(v) = v[osc2_ord]

    osc1_pos    = ord1(osc1_pos_raw) .* POS_TO_32IN   # now in 1/32 in
    osc2_pos    = ord2(osc2_pos_raw) .* POS_TO_32IN   # now in 1/32 in
    osc1_dist   = ord1([beam_distance(d, ref1_cx, ref1_cy) for d in osc1_data])
    osc2_dist   = ord2([beam_distance(d, ref2_cx, ref2_cy) for d in osc2_data])
    osc1_cx     = ord1([d.center_x    for d in osc1_data])
    osc1_cy     = ord1([d.center_y    for d in osc1_data])
    osc2_cx     = ord2([d.center_x    for d in osc2_data])
    osc2_cy     = ord2([d.center_y    for d in osc2_data])
    osc1_fwhm_x = ord1([d.fwhm_x      for d in osc1_data])
    osc1_fwhm_y = ord1([d.fwhm_y      for d in osc1_data])
    osc2_fwhm_x = ord2([d.fwhm_x      for d in osc2_data])
    osc2_fwhm_y = ord2([d.fwhm_y      for d in osc2_data])
    osc1_ellip  = ord1([d.ellipticity  for d in osc1_data])
    osc2_ellip  = ord2([d.ellipticity  for d in osc2_data])
    osc1_extr   = ord1([d.ext_ratio    for d in osc1_data])
    osc2_extr   = ord2([d.ext_ratio    for d in osc2_data])
    osc1_omega  = ord1([d.omega        for d in osc1_data])
    osc2_omega  = ord2([d.omega        for d in osc2_data])
    osc1_r2     = ord1([best_r2(d)     for d in osc1_data])
    osc2_r2     = ord2([best_r2(d)     for d in osc2_data])
    osc1_maxph  = ord1([d.max_photons  for d in osc1_data])
    osc2_maxph  = ord2([d.max_photons  for d in osc2_data])

    has_fwhm  = !all(isnan, osc1_fwhm_x) || !all(isnan, osc2_fwhm_x)
    has_ellip = !all(isnan, osc1_ellip)  || !all(isnan, osc2_ellip)
    has_extr  = !all(isnan, osc1_extr)   || !all(isnan, osc2_extr)
    has_omega = !all(isnan, osc1_omega)  || !all(isnan, osc2_omega)
    has_r2    = !all(isnan, osc1_r2)     || !all(isnan, osc2_r2)
    has_maxph = !all(isnan, osc1_maxph)  || !all(isnan, osc2_maxph)

    c1 = :royalblue;  c1b = :cornflowerblue
    c2 = :orangered;  c2b = :tomato

    SZ = (800, 500)   # size for every single-panel figure
    figs = Figure[]

    # helper: save + display + collect
    function finish!(f, filename)
        path = joinpath(data_dir, filename)
        save(path, f)
        println("  Saved → $path")
        display(f)
        push!(figs, f)
    end

    println("\nBuilding figures...")

    # ─────────────────────────────────────────────────────────────────────────
    # 01 — Beam center displacement
    # ─────────────────────────────────────────────────────────────────────────
    let f = Figure(size = SZ)
        ax = Axis(f[1, 1],
            title  = "Beam Center Displacement vs EOD Position",
            xlabel = "EOD Position (1/32 in)",
            ylabel = "Displacement (px)",
        )
        lines!(ax, osc1_pos, osc1_dist, color = c1, linewidth = 2, label = "osc1")
        scatter!(ax, osc1_pos, osc1_dist, color = c1, markersize = 7)
        lines!(ax, osc2_pos, osc2_dist, color = c2, linewidth = 2, label = "osc2G")
        scatter!(ax, osc2_pos, osc2_dist, color = c2, markersize = 7)
        if osc1_ctrl !== nothing
            scatter!(ax, [osc1_ctrl.position], [0.0], color = c1,
                marker = :star5, markersize = 16, label = "osc1 ctrl")
        end
        if osc2_ctrl !== nothing
            scatter!(ax, [osc2_ctrl.position], [0.0], color = c2,
                marker = :star5, markersize = 16, label = "osc2G ctrl")
        end
        axislegend(ax, position = :lt)
        finish!(f, "01_beam_displacement.png")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 02 — Center X
    # ─────────────────────────────────────────────────────────────────────────
    let f = Figure(size = SZ)
        ax = Axis(f[1, 1],
            title  = "Beam Center X vs EOD Position",
            xlabel = "EOD Position (1/32 in)",
            ylabel = "Center X (px)",
        )
        lines!(ax, osc1_pos, osc1_cx, color = c1, linewidth = 2, label = "osc1")
        scatter!(ax, osc1_pos, osc1_cx, color = c1, markersize = 7)
        lines!(ax, osc2_pos, osc2_cx, color = c2, linewidth = 2, label = "osc2G")
        scatter!(ax, osc2_pos, osc2_cx, color = c2, markersize = 7)
        ctrl_hline!(ax, osc1_ctrl, d -> d.center_x, c1, label = "osc1 ctrl")
        ctrl_hline!(ax, osc2_ctrl, d -> d.center_x, c2, label = "osc2G ctrl")
        axislegend(ax, position = :lt)
        finish!(f, "02_center_x.png")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 03 — Center Y
    # ─────────────────────────────────────────────────────────────────────────
    let f = Figure(size = SZ)
        ax = Axis(f[1, 1],
            title  = "Beam Center Y vs EOD Position",
            xlabel = "EOD Position (1/32 in)",
            ylabel = "Center Y (px)",
        )
        lines!(ax, osc1_pos, osc1_cy, color = c1, linewidth = 2, label = "osc1")
        scatter!(ax, osc1_pos, osc1_cy, color = c1, markersize = 7)
        lines!(ax, osc2_pos, osc2_cy, color = c2, linewidth = 2, label = "osc2G")
        scatter!(ax, osc2_pos, osc2_cy, color = c2, markersize = 7)
        ctrl_hline!(ax, osc1_ctrl, d -> d.center_y, c1, label = "osc1 ctrl")
        ctrl_hline!(ax, osc2_ctrl, d -> d.center_y, c2, label = "osc2G ctrl")
        axislegend(ax, position = :lt)
        finish!(f, "03_center_y.png")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 04 — FWHM (Gaussian only)
    # ─────────────────────────────────────────────────────────────────────────
    if has_fwhm
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Beam FWHM vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "FWHM (px)",
            )
            if !all(isnan, osc1_fwhm_x)
                lines!(ax, osc1_pos, osc1_fwhm_x, color = c1,  linewidth = 2, label = "osc1 x")
                lines!(ax, osc1_pos, osc1_fwhm_y, color = c1b, linewidth = 2, linestyle = :dash, label = "osc1 y")
            end
            if !all(isnan, osc2_fwhm_x)
                lines!(ax, osc2_pos, osc2_fwhm_x, color = c2,  linewidth = 2, label = "osc2G x")
                lines!(ax, osc2_pos, osc2_fwhm_y, color = c2b, linewidth = 2, linestyle = :dash, label = "osc2G y")
            end
            ctrl_hline!(ax, osc1_ctrl, d -> d.fwhm_x, c1,  label = "osc1 ctrl x")
            ctrl_hline!(ax, osc1_ctrl, d -> d.fwhm_y, c1b, label = "osc1 ctrl y")
            ctrl_hline!(ax, osc2_ctrl, d -> d.fwhm_x, c2,  label = "osc2G ctrl x")
            ctrl_hline!(ax, osc2_ctrl, d -> d.fwhm_y, c2b, label = "osc2G ctrl y")
            axislegend(ax, position = :lt)
            finish!(f, "04_fwhm.png")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 05 — Ellipticity (Gaussian) or Extinction ratio (donut)
    # ─────────────────────────────────────────────────────────────────────────
    if has_ellip
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Beam Ellipticity vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "Ellipticity (FWHM_max / FWHM_min)",
            )
            lines!(ax, osc1_pos, osc1_ellip, color = c1, linewidth = 2, label = "osc1")
            scatter!(ax, osc1_pos, osc1_ellip, color = c1, markersize = 7)
            lines!(ax, osc2_pos, osc2_ellip, color = c2, linewidth = 2, label = "osc2G")
            scatter!(ax, osc2_pos, osc2_ellip, color = c2, markersize = 7)
            ctrl_hline!(ax, osc1_ctrl, d -> d.ellipticity, c1, label = "osc1 ctrl")
            ctrl_hline!(ax, osc2_ctrl, d -> d.ellipticity, c2, label = "osc2G ctrl")
            hlines!(ax, [1.0], color = :gray50, linestyle = :dot, linewidth = 1)
            axislegend(ax, position = :lt)
            finish!(f, "05_ellipticity.png")
        end
    elseif has_extr
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Donut Extinction Ratio vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "Extinction Ratio",
            )
            lines!(ax, osc1_pos, osc1_extr, color = c1, linewidth = 2, label = "osc1")
            scatter!(ax, osc1_pos, osc1_extr, color = c1, markersize = 7)
            lines!(ax, osc2_pos, osc2_extr, color = c2, linewidth = 2, label = "osc2G")
            scatter!(ax, osc2_pos, osc2_extr, color = c2, markersize = 7)
            ctrl_hline!(ax, osc1_ctrl, d -> d.ext_ratio, c1, label = "osc1 ctrl")
            ctrl_hline!(ax, osc2_ctrl, d -> d.ext_ratio, c2, label = "osc2G ctrl")
            axislegend(ax, position = :lt)
            finish!(f, "05_extinction_ratio.png")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 06 — Beam omega (1/e² radius)
    # ─────────────────────────────────────────────────────────────────────────
    if has_omega
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Beam Radius ω (1/e²) vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "ω (px)",
            )
            lines!(ax, osc1_pos, osc1_omega, color = c1, linewidth = 2, label = "osc1")
            scatter!(ax, osc1_pos, osc1_omega, color = c1, markersize = 7)
            lines!(ax, osc2_pos, osc2_omega, color = c2, linewidth = 2, label = "osc2G")
            scatter!(ax, osc2_pos, osc2_omega, color = c2, markersize = 7)
            ctrl_hline!(ax, osc1_ctrl, d -> d.omega, c1, label = "osc1 ctrl")
            ctrl_hline!(ax, osc2_ctrl, d -> d.omega, c2, label = "osc2G ctrl")
            axislegend(ax, position = :lt)
            finish!(f, "06_beam_omega.png")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 07 — Max photon count
    # ─────────────────────────────────────────────────────────────────────────
    if has_maxph
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Max Photon Count vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "Max photon count",
            )
            lines!(ax, osc1_pos, osc1_maxph, color = c1, linewidth = 2, label = "osc1")
            scatter!(ax, osc1_pos, osc1_maxph, color = c1, markersize = 7)
            lines!(ax, osc2_pos, osc2_maxph, color = c2, linewidth = 2, label = "osc2G")
            scatter!(ax, osc2_pos, osc2_maxph, color = c2, markersize = 7)
            ctrl_hline!(ax, osc1_ctrl, d -> d.max_photons, c1, label = "osc1 ctrl")
            ctrl_hline!(ax, osc2_ctrl, d -> d.max_photons, c2, label = "osc2G ctrl")
            axislegend(ax, position = :lt)
            finish!(f, "07_max_photons.png")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 08 — Fit quality R²
    # ─────────────────────────────────────────────────────────────────────────
    if has_r2
        let f = Figure(size = SZ)
            ax = Axis(f[1, 1],
                title  = "Fit Quality R² vs EOD Position",
                xlabel = "EOD Position (1/32 in)",
                ylabel = "R²",
            )
            lines!(ax, osc1_pos, osc1_r2, color = c1, linewidth = 2, label = "osc1")
            scatter!(ax, osc1_pos, osc1_r2, color = c1, markersize = 7)
            lines!(ax, osc2_pos, osc2_r2, color = c2, linewidth = 2, label = "osc2G")
            scatter!(ax, osc2_pos, osc2_r2, color = c2, markersize = 7)
            ctrl_hline!(ax, osc1_ctrl, d -> best_r2(d), c1, label = "osc1 ctrl")
            ctrl_hline!(ax, osc2_ctrl, d -> best_r2(d), c2, label = "osc2G ctrl")
            ylims!(ax, 0, 1.05)
            hlines!(ax, [0.99], color = :gray50, linestyle = :dot, linewidth = 1)
            axislegend(ax, position = :lb)
            finish!(f, "08_fit_quality_r2.png")
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Console summary
    # ─────────────────────────────────────────────────────────────────────────
    for (label, ctrl, pos, dist, fwhm_x, fwhm_y, ellip, extr, omega, r2, maxph) in [
        ("osc1",  osc1_ctrl, osc1_pos, osc1_dist, osc1_fwhm_x, osc1_fwhm_y, osc1_ellip, osc1_extr, osc1_omega, osc1_r2, osc1_maxph),
        ("osc2G", osc2_ctrl, osc2_pos, osc2_dist, osc2_fwhm_x, osc2_fwhm_y, osc2_ellip, osc2_extr, osc2_omega, osc2_r2, osc2_maxph),
    ]
        println("\n=== $label summary ===")
        println("  Position range  : $(round(minimum(pos), digits=2)) → $(round(maximum(pos), digits=2)) (1/32 in)")
        println("  Max displacement: $(round(maximum(dist), digits=2)) px")
        !all(isnan, fwhm_x) && println("  Mean FWHM x     : $(round(mean(filter(!isnan, fwhm_x)), digits=2)) px")
        !all(isnan, fwhm_y) && println("  Mean FWHM y     : $(round(mean(filter(!isnan, fwhm_y)), digits=2)) px")
        !all(isnan, ellip)  && println("  Mean ellipticity: $(round(mean(filter(!isnan, ellip)), digits=3))")
        !all(isnan, extr)   && println("  Mean ext. ratio : $(round(mean(filter(!isnan, extr)), digits=2))")
        !all(isnan, omega)  && println("  Mean ω (1/e²)   : $(round(mean(filter(!isnan, omega)), digits=2)) px")
        !all(isnan, r2)     && println("  Mean R²         : $(round(mean(filter(!isnan, r2)), digits=4))")
        !all(isnan, maxph)  && println("  Mean max photons: $(round(mean(filter(!isnan, maxph)), digits=0))")
        if ctrl !== nothing
            println("  --- control reference ---")
            !isnan(ctrl.center_x)    && println("  ctrl center X   : $(round(ctrl.center_x, digits=2)) px")
            !isnan(ctrl.center_y)    && println("  ctrl center Y   : $(round(ctrl.center_y, digits=2)) px")
            !isnan(ctrl.fwhm_x)      && println("  ctrl FWHM x     : $(round(ctrl.fwhm_x, digits=2)) px")
            !isnan(ctrl.fwhm_y)      && println("  ctrl FWHM y     : $(round(ctrl.fwhm_y, digits=2)) px")
            !isnan(ctrl.ellipticity) && println("  ctrl ellipticity: $(round(ctrl.ellipticity, digits=3))")
            !isnan(ctrl.ext_ratio)   && println("  ctrl ext. ratio : $(round(ctrl.ext_ratio, digits=2))")
            !isnan(ctrl.omega)       && println("  ctrl ω (1/e²)   : $(round(ctrl.omega, digits=2)) px")
            !isnan(best_r2(ctrl))    && println("  ctrl R²         : $(round(best_r2(ctrl), digits=4))")
            !isnan(ctrl.max_photons) && println("  ctrl max photons: $(round(ctrl.max_photons, digits=0))")
        end
    end

    return figs
end

# To run:
# graph_beam_drift()
# Or with a custom path:
# graph_beam_drift("path/to/your/data")
