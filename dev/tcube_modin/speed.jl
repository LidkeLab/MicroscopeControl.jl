# MOD IN speed: step responses (up at 0.1 s, down at 0.2 s) on the external PD at 10 kS/s, and
# software-timed square waves. Configs cover closed/open loop and source 3 (sw + ext) / 2 (ext only).
# Rise/fall = 10-90 % on the external PD (its own bandwidth is unknown: an upper bound on the laser's).
const SRATE = 10_000.0
sp_rows = NamedTuple[]; sp_tr = Dict{String,Any}()
function edge_stats(tr, i_edge, i_end, up::Bool)
    pre = mean(tr[max(1, i_edge - 200):i_edge-5]); post = mean(tr[i_end-200:i_end-5]); Δ = post - pre
    seg = tr[i_edge:i_end]
    f(x) = (x - pre) / Δ
    i10 = findfirst(x -> f(x) >= 0.1, seg); i90 = findfirst(x -> f(x) >= 0.9, seg)
    over = maximum(f.(seg)) - 1
    (pre = pre, post = post, lat10_ms = i10 === nothing ? NaN : (i10 - 1) / SRATE * 1e3,
     rise_ms = (i10 === nothing || i90 === nothing) ? NaN : (i90 - i10) / SRATE * 1e3, overshoot = over)
end
function step_case(name, v_lo, v_hi; reps = 5)
    for r in 1:reps
        modin_write(v_lo); sleep(0.5)
        a = xpd_start(; rate = SRATE, n = 3000)                 # 0.3 s
        sleep(0.1); t1 = time(); modin_write(v_hi); t1b = time()
        while time() < t1 + 0.1; end
        t2 = time(); modin_write(v_lo); t2b = time()
        tr = xpd_read(a); sample()                   # sample() trips on a drive current above CURRENT_TRIP_mA (a loop lock)
        i1 = round(Int, (t1 - a.t0) * SRATE); i2 = round(Int, (t2 - a.t0) * SRATE)
        u = edge_stats(tr, i1, i2, true); dn = edge_stats(tr, i2, length(tr), false)
        push!(sp_rows, (case = length(sp_tr) + 1, rep = r, v_lo = v_lo, v_hi = v_hi, write_ms = (t1b - t1) * 1e3,
            lo = u.pre, hi = u.post, up_lat_ms = u.lat10_ms, up_rise_ms = u.rise_ms, up_over = u.overshoot,
            dn_lat_ms = dn.lat10_ms, dn_fall_ms = dn.rise_ms, dn_over = dn.overshoot, back = dn.post))
        sp_tr["$(name)_$r"] = tr
        say(@sprintf("  %-28s r%d  XPD %.3f->%.3f->%.3f V  up: lat %.2f rise %.2f ms over %+.2f | down: lat %.2f fall %.2f ms over %+.2f | write %.2f ms",
            name, r, u.pre, u.post, dn.post, u.lat10_ms, u.rise_ms, u.overshoot, dn.lat10_ms, dn.rise_ms, dn.overshoot, (t1b - t1) * 1e3))
    end
end
function square_case(name, v_lo, v_hi; halfs = (0.0005, 0.001, 0.002, 0.005, 0.01), dur = 0.3)
    for h in halfs
        modin_write(v_lo); sleep(0.3)
        a = xpd_start(; rate = SRATE, n = round(Int, (dur + 0.2) * SRATE))
        sleep(0.1); t0 = time(); n = 0; hi = false
        while time() < t0 + dur
            hi = !hi; modin_write(hi ? v_hi : v_lo); n += 1
            tn = t0 + n * h; while time() < tn; end
        end
        tend = time(); modin_write(v_lo)
        tr = xpd_read(a); sample()                   # sample() trips on a drive current above CURRENT_TRIP_mA (a loop lock)
        i0 = round(Int, (t0 - a.t0) * SRATE) + 50; i1 = round(Int, (tend - a.t0) * SRATE) - 10
        seg = tr[i0:i1]
        q = sort(seg); lo, hi_ = q[max(1, round(Int, 0.05 * length(q)))], q[round(Int, 0.95 * length(q))]
        realhalf = (tend - t0) / n * 1e3
        push!(sp_rows, (case = -1, rep = 0, v_lo = v_lo, v_hi = v_hi, write_ms = realhalf, lo = lo, hi = hi_, up_lat_ms = h * 1e3,
            up_rise_ms = NaN, up_over = NaN, dn_lat_ms = NaN, dn_fall_ms = NaN, dn_over = NaN, back = NaN))
        sp_tr["$(name)_sq$(round(Int, h * 1e4))"] = tr
        say(@sprintf("  %-28s half-period %.1f ms (achieved %.2f ms): p5-p95 %.3f..%.3f V", name, h * 1e3, realhalf, lo, hi_))
    end
end
W, M = CLOSED_WORD_PER_V[], OPEN_mA_PER_V[]
with_session(modchan = MOD_CHAN) do
    say("closed loop, source 3, USB base 800 words"); start_loop(:closed, 3); usb_set(:closed, 800); MOD.vmax = 3.2; sleep(1.5)
    step_case("cl3 800+300w", 0.0, 300 / W); step_case("cl3 800+2000w", 0.0, 2000 / W)
    square_case("cl3 800+300w", 0.0, 300 / W)
    safe_off()
    say("closed loop, source 3, USB base 0 (dark)"); start_loop(:closed, 3); MOD.vmax = 3.2; sleep(1.5)
    step_case("cl3 0+1000w (dark->on)", 0.0, 1000 / W); step_case("cl3 0+3000w (dark->on)", 0.0, 3000 / W)
    square_case("cl3 0+1000w (dark->on)", 0.0, 1000 / W)
    safe_off()
    say("closed loop, source 2"); start_loop(:closed, 2); MOD.vmax = 3.2; sleep(0.5)
    step_case("cl2 0->1000w", 0.0, 1000 / W); step_case("cl2 1000->1300w", 1000 / W, 1300 / W)
    square_case("cl2 1000->1300w", 1000 / W, 1300 / W)
    safe_off()
    say("open loop, source 3, USB base 80 mA"); start_loop(:open, 3); usb_set(:open, 80.0); MOD.vmax = 1.5; sleep(1.5)
    step_case("ol3 80+5mA", 0.0, 5 / M); step_case("ol3 80+20mA", 0.0, 20 / M)
    square_case("ol3 80+5mA", 0.0, 5 / M)
    safe_off()
    say("open loop, source 3, USB base 65 mA (below threshold)"); start_loop(:open, 3); usb_set(:open, 65.0); MOD.vmax = 2.0; sleep(1.5)
    step_case("ol3 65+20mA (dark->on)", 0.0, 20 / M)
    safe_off()
    say("open loop, source 2"); start_loop(:open, 2); MOD.vmax = 5.0; sleep(0.5)
    step_case("ol2 4.5->5.0V (to 76.5 mA)", 4.5, 5.0)
    safe_off()
end
merge!(sp_tr, columns(sp_rows))
h5save("speed", sp_tr; attrs = Dict{String,Any}("rate" => SRATE, "closed_word_per_V" => W, "open_mA_per_V" => M))
