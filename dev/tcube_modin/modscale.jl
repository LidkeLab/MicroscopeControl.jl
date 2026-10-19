# MOD IN transfer (absolute-control part 1): source 3, MOD changes only (no USB write within 1.5 s).
# Closed loop: words per volt from the monitor PD (the loop target) and the external PD.
# Open loop: mA per volt from the drive-current reading.
ms_rows = NamedTuple[]
function linfit(x, y)
    xm, ym = mean(x), mean(y); b = sum((x .- xm) .* (y .- ym)) / sum((x .- xm) .^ 2)
    a = ym - b * xm; r = y .- (a .+ b .* x); (a = a, b = b, maxres = maximum(abs.(r)))
end
with_session(modchan = MOD_CHAN) do
    for (loop, base, probe) in ((:closed, 1000, 0.05), (:open, 76.0, 0.10))
        start_loop(loop, 3)
        usb_set(loop, base); MOD.vmax = probe
        l0 = level(settle = 2.0); say("$loop base $base, 0 V: ", fmt(l0))
        modin_write(probe); l1 = level(settle = 2.0); say("$loop $(probe) V: ", fmt(l1))
        k = loop == :closed ? (l1.pd - l0.pd) / probe : (l1.cur - l0.cur) / probe
        say(@sprintf("  probe scale: %.2f %s/V", k, loop == :closed ? "words" : "mA"))
        (isfinite(k) && k > 0) || error("no MOD IN response in $loop loop")
        loop == :closed ? (CLOSED_WORD_PER_V[] = k) : (OPEN_mA_PER_V[] = k)
        vmax = 0.9 * set_clamp!(loop, base)
        vs = collect(range(0.0, vmax; length = 7)); vs = vcat(vs, reverse(vs)[2:end])
        for (i, v) in enumerate(vs)
            modin_write(v); l = level(settle = 2.0)
            push!(ms_rows, (loop = loop == :closed ? 1 : 0, base = Float64(base), v = v, sp = l.sp, pd = l.pd, cur = l.cur, xpd = l.xpd, status = l.status))
            say(@sprintf("  %-6s %.4f V: ", loop, v), fmt(l))
        end
        modin_write(0.0)
        rs = [r for r in ms_rows if r.loop == (loop == :closed ? 1 : 0)]
        f = linfit([r.v for r in rs], loop == :closed ? [r.pd for r in rs] : [r.cur for r in rs])
        fx = linfit([r.v for r in rs], [r.xpd for r in rs])
        fs = linfit([r.v for r in rs], Float64[r.sp for r in rs])
        say(@sprintf("  FIT %s: %.3f %s/V, intercept %.2f, max resid %.2f | setpoint readback %.2f /V | XPD %.4f V/V, max resid %.4f",
            loop, f.b, loop == :closed ? "words" : "mA", f.a, f.maxres, fs.b, fx.b, fx.maxres))
        loop == :closed ? (CLOSED_WORD_PER_V[] = f.b) : (OPEN_mA_PER_V[] = f.b)
        safe_off()
    end
    save_scales()
end
h5save("modscale", columns(ms_rows); attrs = Dict{String,Any}("closed_word_per_V" => CLOSED_WORD_PER_V[], "open_mA_per_V" => OPEN_mA_PER_V[],
    "source" => 3, "mod_chan" => MOD_CHAN))
