# kitt follow-ups (2026-10-19), 64865766 only.
# 1. Closed-loop MOD scale at the current TIA gain (post-FindTIAGain), source 3, MOD-only steps; range readback each point.
#    The TIA gain itself has no getter/setter in the Kinesis API (only EnableTIAGainAdjust/FindTIAGain).
# 2. Open-loop off/on disarm: source 3 set with output on; MOD step; off; on; MOD step ... (3x without a USB write
#    after the enable, then 3x with a USB re-write of the base after the enable, like the driver's light_on).
fu_rows = NamedTuple[]
fr(part, step, note, l; v = MOD.last) = (push!(fu_rows, (part = part, step = step, v = v, sp = l.sp, pd = l.pd, cur = l.cur, xpd = l.xpd, status = l.status,
    tia = decode_status(UInt32(l.status)).tia)); say(@sprintf("  %d.%-2d %-34s MOD %.3f V: ", part, step, note, v), fmt(l), "  tia ", decode_status(UInt32(l.status)).tia))
with_session(modchan = MOD_CHAN) do
    say("Part 1: closed loop, source 3, base 800 words")
    start_loop(:closed, 3); usb_set(:closed, 800); MOD.vmax = 3.2; sleep(1.5)
    vs = [0.0, 0.5, 1.0, 2.0, 3.0, 0.0]
    for (i, v) in enumerate(vs); modin_write(v); fr(1, i, "MOD-only step", level(settle = 2.0)); end
    safe_off()
    say("Part 2: open loop, source 3, base 80 mA")
    start_loop(:open, 3); usb_set(:open, 80.0); MOD.vmax = 1.5; sleep(1.5)
    fr(2, 0, "base, MOD 0", level())
    v = 0.0; st = 0
    for cyc in 1:6
        rewrite = cyc > 3
        v += 0.2; modin_write(v); st += 1; fr(2, st, "cycle $cyc: MOD step before off", level())
        ld_disable(); st += 1; fr(2, st, "cycle $cyc: output off", level(settle = 1.0))
        ld_enable(); rewrite && ol_set(80.0)
        st += 1; fr(2, st, "cycle $cyc: on" * (rewrite ? " + USB 80 rewrite" : " (no USB write)"), level(settle = 2.0))
        sleep(rewrite ? 0.5 : 0.0)   # level() already waited >= 2 s since the enable / write
        v += 0.2; modin_write(v); st += 1; fr(2, st, "cycle $cyc: MOD step after on", level())
        v = 0.0; modin_write(0.0); st += 1; fr(2, st, "cycle $cyc: MOD back to 0", level())
    end
    safe_off()
end
h5save("followup", columns(fu_rows); attrs = Dict{String,Any}("note" => "part 1 closed MOD scale at post-FindTIAGain gain; part 2 open-loop off/on disarm"))
