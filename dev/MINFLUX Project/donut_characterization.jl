# donut_characterization.jl
# Compare a captured donut beam to its stored LG ideal and a fitted Gaussian.
#
# HDF5 file contains:
#   frame       — captured image (1280 × 1024)
#   ideal_fit   — ideal LG donut model computed during acquisition
#   x_profile   — column profile through beam center
#   y_profile   — row profile through beam center
# Attributes: C, omega, center_x, center_y, approx_r_squared,
#             extinction_ratio, beam_type
#
# Outputs (CairoMakie, static PNG):
#   donut_2d_comparison.png   — 2D maps: measured | LG ideal | Gaussian | residuals
#   donut_profiles.png        — X, Y, and radial profiles for all three
#   donut_summary.png         — metrics bar chart (R², extinction ratio)

using HDF5, CairoMakie, Statistics, Optim

const DATA_DIR = "/Volumes/lidke-lrs/Projects/NSF-MINFLUX/projects/Data/Evaluation Experiments/EOD Driver test/beam characterizatiom/donut/apr29"

# ============================================================================
# Data loading
# ============================================================================

struct DonutData
    frame::Matrix{Float64}
    ideal_fit::Matrix{Float64}
    x_profile::Vector{Float64}
    y_profile::Vector{Float64}
    center_x::Float64
    center_y::Float64
    C::Float64
    omega::Float64
    approx_r2::Float64
    optim_r2::Float64
    extinction_ratio::Float64
    timestamp::String
end

function read_attr(f, key, default = 0.0)
    try; Float64(HDF5.read_attribute(f, key)); catch; default; end
end

function load_donut_file(path)
    h5open(path, "r") do f
        frame    = read(f["frame"])
        ideal    = read(f["ideal_fit"])
        xp       = read(f["x_profile"])
        yp       = read(f["y_profile"])
        DonutData(
            Float64.(frame), Float64.(ideal),
            Float64.(xp), Float64.(yp),
            read_attr(f, "center_x"), read_attr(f, "center_y"),
            read_attr(f, "C"), read_attr(f, "omega"),
            read_attr(f, "approx_r_squared"), read_attr(f, "optim_r_squared"),
            read_attr(f, "extinction_ratio"),
            try String(HDF5.read_attribute(f, "timestamp")) catch; "unknown" end,
        )
    end
end

function find_h5_files(dir)
    sort(filter(f -> endswith(f, ".h5"), readdir(dir, join = true)))
end

# ============================================================================
# Gaussian fitting (ported from voltage_supply_beam_char.jl)
# ============================================================================

function set_baseline(frame; frac = 0.05)
    thresh = quantile(vec(frame), frac)
    mean(filter(<=(thresh), vec(frame)))
end

function insert_subimage(sub_img, cx, cy, bg, frame)
    int_cx = round(Int, cx);  int_cy = round(Int, cy)
    out = fill(bg, size(frame))
    h, w = size(sub_img)
    r0 = int_cx - h ÷ 2;  c0 = int_cy - w ÷ 2
    for i in 1:h, j in 1:w
        ri = r0 + i - 1;  ci = c0 + j - 1
        if 1 <= ri <= size(frame, 1) && 1 <= ci <= size(frame, 2)
            out[ri, ci] = sub_img[i, j]
        end
    end
    return out
end

function coeff_of_determination(ideal, data)
    avg = mean(data)
    ss_res = sum((data[i] - ideal[i])^2 for i in eachindex(data))
    ss_tot = sum((data[i] - avg)^2      for i in eachindex(data))
    return ss_tot == 0 ? 0.0 : 1 - ss_res / ss_tot
end

function make_r_grid(nx, ny)
    x = collect(1:nx);  y = collect(1:ny)
    cx = (nx + 1) / 2;  cy = (ny + 1) / 2
    x_grid = repeat(x, 1, ny)
    y_grid = repeat(y', nx, 1)
    return sqrt.((x_grid .- cx).^2 .+ (y_grid .- cy).^2)
end

function gauss_model(C, ω, bg, r_grid)
    C .* exp.((-2 .* r_grid.^2) ./ (ω.^2)) .+ bg
end

function gauss_cost(inputs, sub_img)
    C, ω, bg = inputs
    r_grid = make_r_grid(size(sub_img)...)
    ideal  = gauss_model(C, ω, bg, r_grid)
    sum((sub_img .- ideal).^2)
end

function fit_gaussian(frame; sub_frame_size = 120)
    peak_idx = argmax(frame)
    cx = Float64(peak_idx[1]);  cy = Float64(peak_idx[2])
    int_cx = round(Int, cx);    int_cy = round(Int, cy)
    bg = set_baseline(frame)
    C0 = maximum(frame) - bg

    # ω from FWHM of profile through center
    profile  = frame[:, int_cy]
    half_max = (maximum(profile) + bg) / 2
    above    = findall(>=(half_max), profile)
    ω0 = length(above) >= 2 ? (above[end] - above[1]) / (2 * sqrt(log(2))) : 50.0

    x_range = max(int_cx - sub_frame_size ÷ 2, 1) : min(int_cx + sub_frame_size ÷ 2, size(frame, 1))
    y_range = max(int_cy - sub_frame_size ÷ 2, 1) : min(int_cy + sub_frame_size ÷ 2, size(frame, 2))
    sub_img = frame[x_range, y_range]

    result = optimize(p -> gauss_cost(p, sub_img),
                      [C0, ω0, bg], NelderMead())
    C, ω, bg_fit = Optim.minimizer(result)

    r_grid_sub = make_r_grid(size(sub_img)...)
    ideal_sub  = gauss_model(C, ω, bg_fit, r_grid_sub)
    ideal_full = insert_subimage(ideal_sub, cx, cy, bg_fit, frame)
    r2         = coeff_of_determination(ideal_sub, sub_img)

    return ideal_full, r2, C, ω, bg_fit, cx, cy
end

# ============================================================================
# Radial profile (mean intensity vs radius from center)
# ============================================================================

function radial_profile(img, cx, cy; n_bins = 120, max_r = nothing)
    nr, nc = size(img)
    max_r_val = max_r === nothing ? min(cx, cy, nr - cx, nc - cy) : Float64(max_r)
    edges  = range(0, max_r_val, length = n_bins + 1)
    counts = zeros(n_bins);  sums = zeros(n_bins)
    for i in 1:nr, j in 1:nc
        r = sqrt((i - cx)^2 + (j - cy)^2)
        k = searchsortedlast(edges, r)
        if 1 <= k <= n_bins
            sums[k]   += img[i, j]
            counts[k] += 1
        end
    end
    radii = [(edges[k] + edges[k+1]) / 2 for k in 1:n_bins]
    vals  = [counts[k] > 0 ? sums[k] / counts[k] : 0.0 for k in 1:n_bins]
    return Float64.(radii), Float64.(vals)
end

# ============================================================================
# Figure — X, Y and radial profiles
# ============================================================================

function plot_profiles(d::DonutData, gauss_full, gauss_r2)
    cx_i = round(Int, d.center_x);  cy_i = round(Int, d.center_y)
    pad  = 80

    xp_meas  = d.frame[:,     cy_i]
    xp_lg    = d.ideal_fit[:, cy_i]
    xp_gauss = gauss_full[:,  cy_i]

    yp_meas  = d.frame[cx_i,    :]
    yp_lg    = d.ideal_fit[cx_i,:]
    yp_gauss = gauss_full[cx_i, :]

    r_meas,  v_meas  = radial_profile(d.frame,    d.center_x, d.center_y; n_bins = 120)
    r_lg,    v_lg    = radial_profile(d.ideal_fit, d.center_x, d.center_y; n_bins = 120)
    r_gauss, v_gauss = radial_profile(gauss_full,  d.center_x, d.center_y; n_bins = 120)

    c_meas  = :royalblue
    c_lg    = :darkorange
    c_gauss = :seagreen

    fig = Figure(size = (1200, 950))
    Label(fig[0, 1:2],
          "Donut Beam — Profile Comparison  ($(d.timestamp))\n" *
          "LG R² = $(round(d.approx_r2, digits=4))   " *
          "Gaussian R² = $(round(gauss_r2, digits=4))   " *
          "ω = $(round(d.omega, digits=2)) px   " *
          "Extinction = $(round(d.extinction_ratio, digits=4))";
          fontsize = 13, font = :bold, tellwidth = false)

    # ── X profile zoomed ───────────────────────────────────────────────────────
    zx = max(cx_i - pad, 1) : min(cx_i + pad, length(xp_meas))
    ax_x = Axis(fig[1, 1],
                title  = "X Profile  (±$(pad) px around center)",
                xlabel = "Column pixel", ylabel = "Intensity (photons)")
    lines!(ax_x, collect(zx), xp_meas[zx];  color = c_meas,  linewidth = 2,   label = "Measured")
    lines!(ax_x, collect(zx), xp_lg[zx];    color = c_lg,    linewidth = 1.5, linestyle = :dash, label = "LG Ideal")
    lines!(ax_x, collect(zx), xp_gauss[zx]; color = c_gauss, linewidth = 1.5, linestyle = :dot,  label = "Gaussian")
    vlines!(ax_x, [cx_i]; color = :gray70, linestyle = :dash, linewidth = 1)
    axislegend(ax_x; position = :rt, framevisible = true, labelsize = 11)

    # ── Y profile zoomed ───────────────────────────────────────────────────────
    zy = max(cy_i - pad, 1) : min(cy_i + pad, length(yp_meas))
    ax_y = Axis(fig[1, 2],
                title  = "Y Profile  (±$(pad) px around center)",
                xlabel = "Row pixel", ylabel = "Intensity (photons)")
    lines!(ax_y, collect(zy), yp_meas[zy];  color = c_meas,  linewidth = 2,   label = "Measured")
    lines!(ax_y, collect(zy), yp_lg[zy];    color = c_lg,    linewidth = 1.5, linestyle = :dash, label = "LG Ideal")
    lines!(ax_y, collect(zy), yp_gauss[zy]; color = c_gauss, linewidth = 1.5, linestyle = :dot,  label = "Gaussian")
    vlines!(ax_y, [cy_i]; color = :gray70, linestyle = :dash, linewidth = 1)
    axislegend(ax_y; position = :rt, framevisible = true, labelsize = 11)

    # ── Radial profile ─────────────────────────────────────────────────────────
    ax_r = Axis(fig[2, 1:2],
                title  = "Radial Profile — azimuthal average",
                xlabel = "Radius (px)", ylabel = "Mean Intensity (photons)")
    lines!(ax_r, r_meas,  v_meas;  color = c_meas,  linewidth = 2,   label = "Measured")
    lines!(ax_r, r_lg,    v_lg;    color = c_lg,    linewidth = 1.5, linestyle = :dash, label = "LG Ideal  R²=$(round(d.approx_r2, digits=4))")
    lines!(ax_r, r_gauss, v_gauss; color = c_gauss, linewidth = 1.5, linestyle = :dot,  label = "Gaussian  R²=$(round(gauss_r2, digits=4))")
    axislegend(ax_r; position = :rt, framevisible = true, labelsize = 11)

    out = joinpath(DATA_DIR, "donut_profiles.png")
    save(out, fig);  println("Saved: $out")
    return fig
end

# ============================================================================
# Run
# ============================================================================

files = find_h5_files(DATA_DIR)
isempty(files) && error("No .h5 files found in $DATA_DIR")

for fpath in files
    println("\nProcessing: $(basename(fpath))")
    d = load_donut_file(fpath)
    println("  center: ($(round(d.center_x, digits=1)), $(round(d.center_y, digits=1)))")
    println("  ω = $(round(d.omega, digits=2)) px   C = $(round(d.C, digits=3))")
    println("  LG R² = $(round(d.approx_r2, digits=4))   extinction = $(round(d.extinction_ratio, digits=4))")

    println("  Fitting Gaussian…")
    gauss_full, gauss_r2, g_C, g_ω, g_bg, _, _ = fit_gaussian(d.frame)
    println("  Gaussian: C=$(round(g_C, digits=3))  ω=$(round(g_ω, digits=2)) px  " *
            "bg=$(round(g_bg, digits=3))  R²=$(round(gauss_r2, digits=4))")

    println("  Plotting…")
    plot_profiles(d, gauss_full, gauss_r2)
end

println("\nDone.")
