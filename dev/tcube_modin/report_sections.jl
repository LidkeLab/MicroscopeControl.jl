# Sections for report.jl beyond the L-I curve (included by report.jl as extra_sections()).
using Statistics
tbl(header, rows) = "<table><tr>" * join(["<th>$h</th>" for h in header]) * "</tr>" *
    join(["<tr>" * join(["<td>$c</td>" for c in r]) * "</tr>" for r in rows]) * "</table>"
f1(x) = @sprintf("%.1f", x); f2(x) = @sprintf("%.2f", x); f3(x) = @sprintf("%.3f", x)

function sec_inventory()
    push!(SECTIONS, "0. Inventory" => """<p>TCubes on USB: 64849775 (MicroscopeAdapt's 642, <b>not</b> under test; an L-I sweep ran on it by mistake before the serial was confirmed, then restored), 64864827 (key off, old 782), <b>64865766</b> (the new 642 nm, same diode type, limit 150.6 mA, control source 5 at start, restored at the end of every run).
NI: two USB-6008 (Dev1 29131200, Dev2 26787819): AO 0-5 V only, software-timed (no AO sample clock); AI clocked to 10 kS/s. <b>Dev2/ao1 drives MOD IN</b> (probe: only it moved the loop; Keith: cable goes only to MOD IN). <b>Dev2/ai0-ai4</b> (differential) carries a photodiode that sees this laser (the external PD below; type and bandwidth not known). Triggerscope on COM3: not opened.
PD RANGE: reported 10 mA at start; Keith moved the DIP to 1 mA; after a power cycle the cube reported 1 mA, and the reading clipped (code 0x8000, no TIA flag) above ~6000 words until <code>LD_EnableTIAGainAdjust(1)</code> + <code>LD_FindTIAGain</code> at 145 mA; then linear to 145 mA (9180 words). Not persisted.</p>""")
end

function sec_xpd()
    f = latest("xpd_cal"); f === nothing && return
    h5open(f) do h
        cur = read(h, "cur"); pd = read(h, "pd"); x = read(h, "xpd")
        svg = svgplot([(cur, pd ./ 1000, "monitor PD (k words, 1 mA range)", "#2a6fdb", :dot), (cur, x, "external PD (V)", "#e07a1f", :dot)];
            xlabel = "drive current (mA)", ylabel = "k words / V", title = "Monitor PD and external PD vs drive current (open loop)")
        push!(SECTIONS, "1. Detectors after the range change" => svg * """<p>Threshold ~74.5 mA. Monitor PD (1 mA range, gain re-optimised) linear to 145 mA. External PD linear to ~105 mA, saturated (~12.2 V) above ~115 mA: every modulation run stays at or below ~105 mA. W/A and an absolute mW scale need a power meter: not possible today. Reference ratio (1a): no stored reference for this laser.</p><p class="src">$(basename(f))</p>""")
    end
end

function sec_modscale()
    f = latest("modscale"); f === nothing && return
    h5open(f) do h
        a = attrs(h); lp = read(h, "loop"); v = read(h, "v"); pd = read(h, "pd"); cur = read(h, "cur"); x = read(h, "xpd")
        c = lp .== 1; o = lp .== 0
        s1 = svgplot([(v[c], pd[c], "closed loop: monitor PD (words)", "#2a6fdb", :dot)]; xlabel = "MOD IN (V)", ylabel = "words", title = "Closed loop, source 3, base 1000 words")
        s2 = svgplot([(v[o], cur[o], "open loop: drive current (mA)", "#e07a1f", :dot)]; xlabel = "MOD IN (V)", ylabel = "mA", title = "Open loop, source 3, base 76 mA")
        push!(SECTIONS, "2. MOD IN transfer (absolute-control part 1)" => s1 * s2 * """<p>Closed loop: <b>$(f2(a["closed_word_per_V"])) words/V</b>, linear (max residual 3.6 words over 0-2.9 V, up and down, no hysteresis). The manual's "10 V = full scale" would be 3277 words/V: the measured scale is 31 % of that (10 V = 10 155 words). Open loop: <b>$(f3(a["open_mA_per_V"])) mA/V</b> = limit/10 V + 1.7 % (limit 150.58 mA), max residual 0.08 mA. The setpoint readback includes the MOD IN contribution in both loops (one register).</p><p class="src">$(basename(f))</p>""")
    end
end

function sec_registers()
    f = latest("registers"); f === nothing && return
    h5open(f) do h
        run = read(h, "run"); st = read(h, "step"); lp = read(h, "loop"); usb = read(h, "usb"); v = read(h, "v")
        pd = read(h, "pd"); cur = read(h, "cur"); x = read(h, "xpd"); sp = read(h, "sp")
        rows(sel) = [[run[i] == 3 && st[i] in (1, 6, 11) ? "sweep" : string(st[i]), lp[i] == 1 ? "closed" : "open", f1(usb[i]), f3(v[i]), string(sp[i]), f1(pd[i]), f2(cur[i]), f3(x[i])] for i in findall(sel)]
        hdr = ["step", "loop", "USB set", "MOD V", "setpoint readback", "monitor PD", "drive mA", "ext PD V"]
        push!(SECTIONS, "3. Run 1: one register or two?" => tbl(hdr, rows(run .== 1)) * """<p>Sequence: USB B; MOD +m; (2.5 s) USB B+d; MOD 0. Manual (sum of two sources) predicts B / B+m / B+d+m / B+d; one register predicts B / B+m / B+d / B+d-m. <b>Measured: one register</b>, both loops, both repeats, on all three signals (photocurrent, drive current, external PD). Closed: 998 / 1500 / 1297 / 797 words vs 1000/1500/1300/800. Open: 80.0 / 90.0 / 85.0 / 75.0 mA exactly. A USB write sets the register outright; a MOD IN change adds its difference.</p>""")
        push!(SECTIONS, "4. Run 4: open-loop disarm?" => tbl(hdr, rows(run .== 4)) * """<p><b>No disarm on this cube</b> (contradicts the 2026-10-13 note for the other unit): after a USB re-write of the same 80 mA with 0.3 V applied, the current fell to 80.0 (the 0.3 V absorbed), the next +0.3 V added +4.6 mA (its difference), and 0 V then gave 75.4 mA. Every step is the one-register model; MOD IN kept working after every USB write. Arming: source set while the output is on (as in the 10-13 rule), not re-tested otherwise.</p>""")
        push!(SECTIONS, "5. Run 3: source 2 (external only) = absolute control" => tbl(hdr, rows(run .== 3)) * """<p><b>Absolute in both loops.</b> Closed loop: 0 V dark (0 mA), then ~1013 words/V from zero (998 at 1 V, 2013 at 2 V, 3033 at 3 V), the same on the way down, and restored to the same level after output off/on with no USB write. Open loop: 15.3 mA/V from zero, so 0-5 V reaches only 76.5 mA (threshold): open-loop source 2 is not usable above threshold with a 0-5 V DAC. The USB setpoint is ignored, except that each USB write moved the level by a small fixed amount (-7 words closed, -0.46 mA open) that stayed until the next MOD change: re-quantisation of the register, not addition. The setpoint readback reports the MOD-derived value.</p><p class="src">$(basename(f))</p>""")
    end
end

function sec_settle()
    for f in filter(x -> startswith(x, "settle_") && endswith(x, ".h5"), readdir(RDIR))
        h5open(joinpath(RDIR, f)) do h
            lp = read(h, "loop"); base = read(h, "base"); d = read(h, "d_actual"); fr = read(h, "frac")
            ser = Tuple[]; cols = ("#2a6fdb", "#e07a1f", "#2aa198")
            for (k, b) in enumerate(unique(base))
                s = base .== b
                push!(ser, (d[s], fr[s], "$(lp[findfirst(s)] == 1 ? "closed" : "open") base $(b)", cols[k], :dot))
            end
            svg = svgplot(ser; xlabel = "MOD step delay after the USB write (s)", ylabel = "fraction of the step applied (settled)", title = "Run 2: settle window ($f)")
            push!(SECTIONS, "6. Run 2: settle window ($(lp[1] == 1 ? "closed" : "open") loop)" => svg * (isdefined(@__MODULE__, :settle_text) ? settle_text(h, f) : "") * "<p class=\"src\">$f</p>")
        end
    end
end


function settle_text(h, f)
    lp = read(h, "loop"); base = read(h, "base"); usb = read(h, "usb"); da = read(h, "d_actual"); fr = read(h, "frac"); im = read(h, "i_mod")
    rate = 2000.0
    bstr(b) = isinteger(b) && lp[1] == 1 ? string(Int(b)) : string(b)
    key(r) = "trace_$(lp[r] == 1 ? "closed" : "open")_$(bstr(base[r]))_$(count(==(base[r]), base[1:r]))"
    nom = round.(da; digits = 1)
    rows = [[f2(d), string(count(nom .== d)), f2(mean(fr[nom .== d])), f2(minimum(fr[nom .== d])), f2(maximum(fr[nom .== d]))] for d in sort(unique(nom))]
    # example traces: first lost (d ~ 0.4) and first applied (d ~ 1.1) at the first base, aligned on the MOD step
    ex = Tuple[]
    for (target, lab, col) in ((0.4, "step at 0.4 s after the write (lost)", "#d33"), (1.1, "step at 1.1 s (applied)", "#2a6fdb"))
        r = findfirst(i -> abs(da[i] - target) < 0.02 && base[i] == base[1], eachindex(da)); r === nothing && continue
        tr = read(h, key(r)); m = round(Int, im[r]); idx = max(1, m - 100):min(length(tr), m + 1200)
        push!(ex, (((idx .- m) ./ rate .* 1000), tr[idx], lab, col, :line))
    end
    svg = isempty(ex) ? "" : svgplot(ex; xlabel = "time from the MOD IN step (ms)", ylabel = "external PD (V)", title = "Example traces, base $(bstr(base[1]))")
    tbl(["delay (s)", "n", "mean fraction", "min", "max"], rows) * svg *
    "<p>Fraction = (settled level - USB value) / step, from the monitor PD (closed loop) or drive current (open loop); external PD traced at 2 kS/s.</p>"
end


const SPEED_CODE = joinpath(@__DIR__, "speed_traces_lib.jl")
function sec_speed()
    fs = sort(filter(x -> startswith(x, "speed_") && endswith(x, ".h5"), readdir(RDIR))); isempty(fs) && return
    f = joinpath(RDIR, fs[end]); rate = 10_000.0
    logs = sort(filter(x -> startswith(x, "speed_") && endswith(x, ".log"), readdir(RDIR)))
    lat = Dict{String,Vector{Float64}}()
    for l in readlines(joinpath(RDIR, logs[end]))
        m = match(r"^  (.+?)\s+r\d+\s+XPD ([-\d.]+)->.*up: lat ([-\d.NaN]+) ", l)
        m === nothing && continue
        parse(Float64, m[2]) < 0.05 && push!(get!(lat, strip(m[1]), Float64[]), parse(Float64, m[3]))   # only clean dark starts
    end
    rows = Vector{Vector{String}}(); ex = Tuple[]
    h5open(f) do h
        names = sort(filter(n -> occursin(r"_\d+$", n) && !occursin("_sq", n), collect(keys(h))))
        for g in unique([replace(n, r"_\d+$" => "") for n in names])
            U = []; D = []
            for n in filter(n -> replace(n, r"_\d+$" => "") == g, names)
                tr = read(h, n); lo, hi, up, dn = edges(tr)
                isempty(up) || push!(U, step_metrics(tr, up[1], 1)); isempty(dn) || push!(D, step_metrics(tr, dn[end], -1))
            end
            md(v, fn) = isempty(v) ? NaN : median([fn(x) for x in v])
            push!(rows, [g, string(length(U)), f3(md(U, x -> x.pre)) * " → " * f3(md(U, x -> x.post)), f2(md(U, x -> x.rise_ms)),
                @sprintf("%+.0f %%", 100 * md(U, x -> x.over)), f1(md(U, x -> x.settle_ms)), f2(md(D, x -> x.rise_ms)),
                @sprintf("%+.0f %%", 100 * md(D, x -> x.over)), haskey(lat, g) ? f1(median(lat[g])) : "-"])
        end
        for (g, col) in (("ol3 80+5mA", "#2a6fdb"), ("cl3 800+300w", "#d33"), ("cl3 0+1000w (dark->on)", "#2aa198"))
            n = g * "_1"; haskey(h, n) || continue
            tr = read(h, n); lo, hi, up, dn = edges(tr); isempty(up) && continue
            e = up[1]; idx = max(1, e - 20):min(length(tr), e + 60)
            y = (tr[idx] .- lo) ./ (hi - lo)
            push!(ex, (((idx .- e) ./ rate .* 1000), y, g, col, :line))
        end
    end
    svg = isempty(ex) ? "" : svgplot(ex; xlabel = "time from the edge (ms)", ylabel = "normalised external PD", title = "Step responses (10 kS/s), first repeat")
    sqrows = Vector{Vector{String}}()
    for l in readlines(joinpath(RDIR, logs[end]))
        m = match(r"^  (.+?)\s+half-period ([\d.]+) ms \(achieved ([\d.]+) ms\): p5-p95 ([-\d.]+)\.\.([-\d.]+) V", l)
        m === nothing || push!(sqrows, [strip(m[1]), m[2], m[3], m[4] * " .. " * m[5]])
    end
    push!(SECTIONS, "7. MOD IN speed" => tbl(["case", "n", "ext PD low → high (V)", "rise 10-90 (ms)", "overshoot up", "settle ±2 % (ms)", "fall 90-10 (ms)", "overshoot down", "dark→on delay* (ms)"], rows) * svg *
        """<p>External PD at 10 kS/s, so 0.1 ms per sample: 0.1-0.2 ms means "within one or two samples" (sample-limited), and the PD's own bandwidth is unknown. cl = closed loop, ol = open loop, 3 = software + external, 2 = external only; w = PD words. Edges are found in the traces themselves. *Delay is from the host's write call to 10 % of the step, shown only for steps from dark, where the "before" level is clean. It includes an unknown host-to-DAQ offset, so compare it between cases: open loop from below threshold read 0.9 ms; closed loop from dark read about 10 ms.</p>
<p><b>Open loop:</b> sample-limited (≤0.15 ms) up and down, no overshoot, any base. <b>Closed loop from a lasing base:</b> the light jumps within one sample, overshoots by about 2/3 of the step (both directions), and settles within about 1 ms. <b>Closed loop from dark:</b> no overshoot, a 0.5-0.6 ms rise, and about 10 ms extra delay before it starts (the loop has to drive the diode up to threshold). <b>Open loop, source 2, near threshold:</b> 27-40 ms to settle within 2 % (small signal at the knee).</p>""" *
        tbl(["case", "half-period asked (ms)", "achieved (ms)", "ext PD p5 .. p95 (V)"], sqrows) *
        "<p>Square waves are software-timed AO writes; the USB-6008 has no AO clock, so 0.5 ms half-period (1 kHz) is the fastest tested. Open loop keeps exactly the static levels at every rate. Closed loop above threshold swings past the static levels at every rate (the overshoot); from dark, full depth with no overshoot.</p><p class=\"src\">$(basename(f))</p>")
end

function sec_summary()
    push!(SECTIONS, "Findings" => """<ol>
<li><b>MOD IN can set power absolutely: closed loop, control source 2 (external only).</b> The voltage sets the photocurrent target from zero: 0 V is dark (0 mA), then 1013-1015 PD words/V, linear (max residual ~4 words), with no hysteresis. It holds through output off/on, and the USB setpoint is ignored. A 0-5 V DAC reaches ~5000 words (~110 mA on this diode). The one caveat: each USB write nudged the level by a fixed -7 words (re-quantised register) until the next MOD change.</li>
<li><b>Open loop, source 2, is absolute in mA (15.3 mA/V from zero)</b>, but 0-5 V reaches only 76.5 mA, i.e. threshold. It needs a ±10 V / 0-10 V output to be useful.</li>
<li><b>Source 3 (software + external) has ONE setpoint register</b>, in both loops, on all three signals: a USB write sets it outright, and a MOD IN change adds its difference. The manual's "sum of sources" is wrong for this firmware. (Matches the 2026-10-13 note for the other unit.)</li>
<li><b>Settle window: a MOD IN change up to 0.91 s after a USB write is lost, and every change from 1.00 s on applies.</b> 117 of 117 trials, closed loop at two bases and open loop. A lost step <i>does</i> appear: within 20 ms at ~60-70 % of its size, then the controller pulls it back within 20-300 ms. The firmware re-asserts the USB setpoint for ~1 s; this is not the PD loop, since open loop does the same. The driver's MOD_SETTLE_S = 1.3 s is consistent.</li>
<li><b>No open-loop "disarm" on this cube:</b> MOD IN kept acting after every USB write (by its difference). The source was always set with the output on.</li>
<li><b>Speed.</b> Open loop: ≤0.15 ms rise and fall (sample-limited at 10 kS/s), no overshoot, and full depth at 1 kHz (the fastest a software-timed USB-6008 output goes). Closed loop from a lasing base: one-sample jump, then <b>~65 % overshoot</b> both ways, settling in ~1 ms. Closed loop from dark: no overshoot, 0.5 ms rise, and ~10 ms extra start delay. For fast, clean edges use open loop, or closed loop from a dark base; for absolute level use closed loop with source 2, and accept the 1 ms transient.</li>
<li><b>Scale vs manual:</b> closed loop 1015 words/V = 31 % of "10 V = full scale" (3277 words/V); open loop 15.31 mA/V = the controller's limit/10 V + 1.7 %. Calibrate per unit, as the driver's modulation_scale cannot be taken from the manual in closed loop.</li>
<li><b>Monitor PD range:</b> after the DIP move to 1 mA (and a power cycle to be reported), the reading clipped to the over-range code at ~6000 words with <i>no</i> TIA-over flag, until LD_EnableTIAGainAdjust + LD_FindTIAGain at 145 mA (LD_FindTIAGain alone did nothing). Not persisted: a power cycle may undo it. The driver's initialize does not catch this.</li>
<li><b>Not measured:</b> W/A and mW (no power meter); the external PD's identity and bandwidth (rise times are upper bounds); latency from the write (host and DAQ clocks not shared); Triggerscope (not opened).</li>
</ol>""")
end

function sec_followup()
    f = latest("followup"); f === nothing && return
    h5open(f) do h
        part = read(h, "part"); st = read(h, "step"); v = read(h, "v"); sp = read(h, "sp"); pd = read(h, "pd"); cur = read(h, "cur"); x = read(h, "xpd"); tia = read(h, "tia")
        p1 = findall(part .== 1); p2 = findall(part .== 2)
        vv = v[p1]; yy = pd[p1]; xm, ym = mean(vv), mean(yy); b = sum((vv .- xm) .* (yy .- ym)) / sum((vv .- xm) .^ 2)
        notes2 = ["base, MOD 0"; vcat([["cycle $c: MOD step", "cycle $c: output off", "cycle $c: on" * (c > 3 ? " + USB 80 mA rewrite" : " (no USB write)"), "cycle $c: MOD step after on", "cycle $c: MOD 0"] for c in 1:6]...)]
        t1 = tbl(["MOD V", "setpoint readback", "monitor PD (words)", "drive mA", "ext PD V", "reported TIA range (A)"], [[f3(v[i]), string(sp[i]), f1(pd[i]), f2(cur[i]), f3(x[i]), string(tia[i])] for i in p1])
        t2 = tbl(["step", "MOD V", "setpoint readback", "drive mA", "monitor PD", "ext PD V"], [[notes2[k], f3(v[i]), string(sp[i]), f2(cur[i]), f1(pd[i]), f3(x[i])] for (k, i) in enumerate(p2)])
        push!(SECTIONS, "8. Follow-ups (MicroscopeControl.jl-kitt)" => """<h3>8a. Closed-loop MOD scale at the current TIA gain</h3>""" * t1 *
            @sprintf("<p>Source 3, base 800 words, MOD-only steps: <b>%.1f words/V</b> = <b>%.1f µA/V</b> decoded with the reported 1 mA range (manual, 10 V = full scale: 3277 words/V = 100 µA/V; measured = %.0f %%). Same as modscale (1015.5). The range readback was 1 mA at every point. <b>The TIA gain cannot be read or set in software</b>: the Kinesis DLL exports only LD_EnableTIAGainAdjust and LD_FindTIAGain (header checked), so the pre-FindTIAGain state can only come back by power cycling, if at all, and this was not done. One pre-FindTIAGain point does exist, on the 10 mA range before the DIP change: +56 words for +0.1 V at base 300 (ao_probe), i.e. ~560 words/V = ~171 µA/V on that range (manual 1000 µA/V, 17 %%). The PD slope against drive current was the same (×10.1) before and after FindTIAGain on the 1 mA range; FindTIAGain removed the clip at ~6000 words.</p>", b, b / 32767 * 1e3, 100 * b / 3276.7) *
            """<h3>8b. Open-loop off/on: disarm?</h3>""" * t2 *
            """<p>Open loop, source 3 set with the output on, base 80 mA, +0.2 V = +3.07 mA. <b>Off/on does not disarm MOD IN.</b> Cycles 1-3 (no USB write after the enable): the output comes back at the full register including the MOD contribution (83.07 mA), the next step adds its difference (+3.07 mA), and MOD 0 returns to 79.99 mA. 3 of 3. Cycles 4-6 (USB re-write of 80 mA right after the enable, as the driver's light_on does): the write absorbs the applied 0.2 V (80.0 mA), the next +0.2 V adds +3.07 mA, and MOD 0 then gives 76.9 mA (= 80 - 3.07). 3 of 3, the one-register model exactly. A driver that re-writes the bare request on light_on/setcurrent! makes MOD IN look disarmed or offset, and a first change within ~1 s of that write is lost (section 6). That is a likely account of the earlier "disarm" report, not a measurement on that unit.</p><p class="src">""" * basename(f) * "</p>")
    end
end
