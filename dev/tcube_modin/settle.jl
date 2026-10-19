# Run 2: a USB write, then a MOD IN step after delay d; external PD traced at 2 kS/s.
# Each trial: MOD 0, wait 1.5 s, USB write (sets the register outright), wait d, MOD step, trace 3 s more.
# SETTLE_CFG (set by the wrapper): vector of (loop, base, alt, step) — alt = second USB value (writes alternate).
const DELAYS = [0.0, 0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0, 1.1, 1.2, 1.4, 1.7, 2.0]
const REPS = 3
const TRATE = 2000.0
st_rows = NamedTuple[]; st_traces = Dict{String,Any}()
with_session(modchan = MOD_CHAN) do
    for (loop, base, alt, step) in SETTLE_CFG
        start_loop(loop, 3)
        usb_set(loop, base); MOD.vmax = 1.0
        vstep = step / (loop == :closed ? CLOSED_WORD_PER_V[] : OPEN_mA_PER_V[])
        say("Run 2 $loop base $base/$alt step $step ($(round(vstep; digits=4)) V)")
        k = 0
        for rep in 1:REPS, d in DELAYS
            k += 1; usb = isodd(k) ? alt : base
            modin_write(0.0); sleep(1.5)
            a = xpd_start(; rate = TRATE, n = round(Int, (0.3 + d + 3.0) * TRATE))
            sleep(0.3)
            tw = time(); loop == :closed ? ld_setsp_raw(Int(usb)) : ol_set(usb)
            while time() < tw + d; end                      # busy-wait: d is the point of the run
            tm = time(); modin_write(vstep)
            tr = xpd_read(a)
            s = settled(settle = 0.0, n = 8)
            fin = loop == :closed ? s.pd : s.cur
            frac = (fin - usb) / step
            i_w = (tw - a.t0) * TRATE; i_m = (tm - a.t0) * TRATE
            push!(st_rows, (loop = loop == :closed ? 1 : 0, base = Float64(base), usb = Float64(usb), step = Float64(step), delay = d,
                            rep = rep, d_actual = tm - tw, final = fin, frac = frac, i_write = i_w, i_mod = i_m, t0 = a.t0, xpd_end = mean(tr[end-999:end])))
            st_traces["trace_$(loop)_$(base)_$(k)"] = tr
            say(@sprintf("  %-6s usb %6.1f d %.2f (%.3f) final %7.2f frac %5.2f  XPDend %.3f", loop, usb, d, tm - tw, fin, frac, mean(tr[end-999:end])))
        end
        safe_off()
    end
end
merge!(st_traces, columns(st_rows))
h5save("settle_" * join(["$(c[1])$(c[2])" for c in SETTLE_CFG], "_"), st_traces; attrs = Dict{String,Any}("rate" => TRATE, "source" => 3))
