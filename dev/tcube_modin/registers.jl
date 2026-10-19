# Run 1 (one register?), Run 4 (open-loop disarm), Run 3 (source 2 = external only), levels only.
# Every MOD change comes >= 2.5 s after the last USB write (outside the ~1 s settle window).
rg_rows = NamedTuple[]
function rec(run, step, loop, l; usb = NaN, v = MOD.last)
    push!(rg_rows, (run = run, step = step, loop = loop == :closed ? 1 : 0, usb = Float64(usb), v = v,
                    sp = l.sp, pd = l.pd, cur = l.cur, xpd = l.xpd, status = l.status))
    say(@sprintf("  run%d.%d %-6s usb %7.1f  MOD %.4f V: ", run, step, loop, usb, v), fmt(l))
end
unit(loop, l) = loop == :closed ? l.pd : l.cur
const WPV, MPV = CLOSED_WORD_PER_V[], OPEN_mA_PER_V[]
with_session(modchan = MOD_CHAN) do
    # ---- Run 1: USB B; MOD +m; USB B+d; MOD 0.  manual: B, B+m, B+d+m, B+d.  one register: B, B+m, B+d, B+d-m
    for (loop, B, d, m) in ((:closed, 1000, 300, 500), (:open, 80.0, 5.0, 10.0))
        say("Run 1, $loop: B=$B d=$d m=$m")
        for rep in 1:2
            start_loop(loop, 3); MOD.vmax = 2.0
            vm = m / (loop == :closed ? WPV : MPV)
            usb_set(loop, B); sleep(0.5); l = level(settle = 2.0); rec(1, 1, loop, l; usb = B)
            modin_write(vm); l = level(settle = 2.0); rec(1, 2, loop, l; usb = B)
            usb_set(loop, B + d; from = B); l = level(settle = 2.5); rec(1, 3, loop, l; usb = B + d)
            modin_write(0.0); l = level(settle = 2.0); rec(1, 4, loop, l; usb = B + d)
            say(@sprintf("  -> rep %d levels %s; manual %s; one-register %s", rep,
                join([@sprintf("%.1f", unit(loop, r)) for r in rg_rows[end-3:end]], "/"),
                join(string.((B, B + m, B + d + m, B + d)), "/"), join(string.((B, B + m, B + d, B + d - m)), "/")))
            safe_off()
        end
    end
    # ---- Run 4 (open loop, source 3): MOD +a; raw USB write (same value); MOD +b; MOD 0; then a different USB value
    say("Run 4, open loop")
    start_loop(:open, 3); MOD.vmax = 2.0
    usb_set(:open, 80.0); sleep(0.5); l = level(); rec(4, 1, :open, l; usb = 80)
    modin_write(0.3); l = level(); rec(4, 2, :open, l; usb = 80)                     # +4.6 mA
    usb_set(:open, 80.0); l = level(settle = 2.5); rec(4, 3, :open, l; usb = 80)      # same value re-written
    modin_write(0.6); l = level(); rec(4, 4, :open, l; usb = 80)                     # +0.3 V more
    modin_write(0.0); l = level(); rec(4, 5, :open, l; usb = 80)
    usb_set(:open, 85.0); l = level(settle = 2.5); rec(4, 6, :open, l; usb = 85)
    modin_write(0.6); l = level(); rec(4, 7, :open, l; usb = 85)
    modin_write(0.0); l = level(); rec(4, 8, :open, l; usb = 85)
    safe_off()
    # ---- Run 3: source 2 (external only)
    say("Run 3, open loop, source 2 (0-5 V = 0-76.5 mA if absolute)")
    start_loop(:open, 2); MOD.vmax = 5.0
    for v in (0.0, 1.0, 2.0, 3.0, 4.0, 4.5, 4.8, 5.0)
        modin_write(v); l = level(); rec(3, 1, :open, l; usb = 0)
    end
    usb_set(:open, 20.0); l = level(settle = 2.5); rec(3, 2, :open, l; usb = 20)    # ignored? additive would be ~96 mA
    usb_set(:open, 0.0);  l = level(settle = 2.5); rec(3, 3, :open, l; usb = 0)
    ld_disable(); l = level(); rec(3, 4, :open, l; usb = 0)                           # output off, MOD held at 5 V
    ld_enable(); l = level(); rec(3, 5, :open, l; usb = 0)                            # on again, no USB write
    safe_off()
    say("Run 3, closed loop, source 2")
    start_loop(:closed, 2); MOD.vmax = min(4.0, (CAP_CLOSED_WORD - 600) / WPV)
    for v in (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 2.0, 1.0)
        modin_write(v); l = level(); rec(3, 6, :closed, l; usb = 0)
    end
    usb_set(:closed, 500); l = level(settle = 2.5); rec(3, 7, :closed, l; usb = 500)  # additive would be +500 words
    ld_setsp_raw(0); l = level(settle = 2.5); rec(3, 8, :closed, l; usb = 0)
    ld_disable(); l = level(); rec(3, 9, :closed, l; usb = 0)
    ld_enable(); l = level(); rec(3, 10, :closed, l; usb = 0)
    for v in (0.5, 0.0); modin_write(v); l = level(); rec(3, 11, :closed, l; usb = 0); end
    safe_off()
end
h5save("registers", columns(rg_rows); attrs = Dict{String,Any}("closed_word_per_V" => WPV, "open_mA_per_V" => MPV, "mod_chan" => MOD_CHAN))
