# Build dev/output/tcube-modin/report.html from the run HDF5 files: inline SVG, no plotting package.
# Standalone: julia --project=dev/tcube_modin dev/tcube_modin/report.jl   (or include into TM)
using HDF5, Printf, Dates

const RDIR = normpath(joinpath(@__DIR__, "..", "output", "tcube-modin"))

latest(prefix) = (fs = sort(filter(f -> startswith(f, prefix) && endswith(f, ".h5"), readdir(RDIR))); isempty(fs) ? nothing : joinpath(RDIR, fs[end]))

"Scatter/line SVG. series = [(x, y, label, color, :line|:dot)]."
function svgplot(series; w = 640, h = 360, xlabel = "", ylabel = "", title = "")
    xs = reduce(vcat, [s[1] for s in series]); ys = reduce(vcat, [s[2] for s in series])
    x0, x1 = extrema(xs); y0, y1 = extrema(ys)
    y0 = min(y0, 0.0); dx = x1 - x0 == 0 ? 1 : x1 - x0; dy = y1 - y0 == 0 ? 1 : y1 - y0
    L, R, T, B = 64, 16, 28, 44
    px(x) = L + (x - x0) / dx * (w - L - R); py(y) = h - B - (y - y0) / dy * (h - T - B)
    io = IOBuffer()
    print(io, """<svg viewBox="0 0 $w $h" width="100%" style="max-width:$(w)px" xmlns="http://www.w3.org/2000/svg" font-family="system-ui" font-size="12">""")
    print(io, """<text x="$(w/2)" y="16" text-anchor="middle" font-weight="600" fill="var(--fg)">$title</text>""")
    for k in 0:4
        yv = y0 + k * dy / 4; xv = x0 + k * dx / 4
        print(io, """<line x1="$L" x2="$(w-R)" y1="$(py(yv))" y2="$(py(yv))" stroke="var(--grid)"/>""")
        print(io, """<text x="$(L-6)" y="$(py(yv)+4)" text-anchor="end" fill="var(--muted)">$(round(yv; sigdigits=3))</text>""")
        print(io, """<text x="$(px(xv))" y="$(h-B+16)" text-anchor="middle" fill="var(--muted)">$(round(xv; sigdigits=3))</text>""")
    end
    print(io, """<text x="$(w/2)" y="$(h-6)" text-anchor="middle" fill="var(--fg)">$xlabel</text>""")
    print(io, """<text x="14" y="$(h/2)" text-anchor="middle" fill="var(--fg)" transform="rotate(-90 14 $(h/2))">$ylabel</text>""")
    for (i, (x, y, lab, col, kind)) in enumerate(series)
        if kind == :line
            print(io, """<polyline fill="none" stroke="$col" stroke-width="2" points="$(join(["$(px(a)),$(py(b))" for (a, b) in zip(x, y)], " "))"/>""")
        else
            for (a, b) in zip(x, y)
                print(io, """<circle cx="$(px(a))" cy="$(py(b))" r="3" fill="$col"/>""")
            end
        end
        print(io, """<rect x="$(L+10)" y="$(T+4+16*(i-1))" width="10" height="10" fill="$col"/><text x="$(L+26)" y="$(T+13+16*(i-1))" fill="var(--fg)">$lab</text>""")
    end
    print(io, "</svg>")
    String(take!(io))
end

const SECTIONS = Pair{String,String}[]   # title => html, filled by section builders below

function li_section()
    f = latest("li_curve"); f === nothing && return
    h5open(f) do h
        a = attrs(h); cur = read(h, "cur_mA"); pd = read(h, "pd_word"); n = length(cur); nu = (n + 1) ÷ 2
        thr, sl = a["threshold_mA"], a["slope_words_per_mA"]
        xf = [thr, maximum(cur)]; yf = [0.0, sl * (maximum(cur) - thr)]
        svg = svgplot([(cur[1:nu], pd[1:nu], "up sweep", "#2a6fdb", :dot), (cur[nu+1:end], pd[nu+1:end], "down sweep", "#e07a1f", :dot),
                       (xf, yf, @sprintf("fit: %.2f words/mA, threshold %.1f mA", sl, thr), "#888", :line)];
                      xlabel = "drive current reading (mA)", ylabel = "monitor PD (words)", title = "Open-loop L-I, $(a["serial"])")
        txt = @sprintf("""<p>Open loop, control source 1 (software only), 1.2 s settle, 8 readings per point. Threshold <b>%.2f mA</b> (up) / %.2f mA (down); slope <b>%.2f words/mA</b> = %.2f uA/mA on the reported 10 mA range (a label: the absolute photocurrent is not calibrated); R² %.5f. At 145 mA the PD reads %d words, %.1f %% of full scale: the PD RANGE DIP switch should be stepped to 1 mA (needs a person). No TIA over/under flag at any point. W/A: not measurable without a power meter. Reference ratio (1a): no stored reference for this laser.</p><p class="src">%s</p>""",
            thr, a["threshold_down_mA"], sl, sl * 10e-3 / 32767 * 1e6, a["r2"], round(Int, maximum(pd)), 100 * maximum(pd) / 32767, basename(f))
        push!(SECTIONS, "1b. L-I curve, 10 mA range (before the range change)" => svg * txt)
    end
end

include(joinpath(@__DIR__, "speed_traces_lib.jl"))
include(joinpath(@__DIR__, "report_sections.jl"))

function write_report()
    empty!(SECTIONS)
    sec_summary(); sec_inventory(); sec_xpd(); li_section(); sec_modscale(); sec_registers(); sec_settle()
    isdefined(@__MODULE__, :sec_speed) && sec_speed()
    sec_followup(); sec_wa()
    body = join(["<section><h2>$t</h2>$h</section>" for (t, h) in SECTIONS], "\n")
    html = """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>TLD001 MOD IN</title><style>
:root{--bg:#fff;--fg:#1d1d1f;--muted:#666;--grid:#e5e5e5}
@media (prefers-color-scheme:dark){:root{--bg:#161618;--fg:#eee;--muted:#999;--grid:#333}}
body{background:var(--bg);color:var(--fg);font-family:system-ui;margin:0 auto;max-width:760px;padding:16px;line-height:1.45}
h1{font-size:1.4em}h2{font-size:1.1em;margin-top:2em}.src{color:var(--muted);font-size:.85em}table{border-collapse:collapse}td,th{padding:2px 8px;border-bottom:1px solid var(--grid);text-align:right}
</style></head><body><h1>TLD001 MOD IN, monitor PD only</h1>
<p class="src">New 642 nm laser on TCube 64865766, $(Dates.format(now(), "yyyy-mm-dd HH:MM")). Signals: monitor-photodiode words and the drive-current reading; nothing external.</p>
$body</body></html>"""
    fn = joinpath(RDIR, "report.html"); write(fn, html); println("report: $fn"); fn
end

abspath(PROGRAM_FILE) == (@__FILE__) && write_report()
