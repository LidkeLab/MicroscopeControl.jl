# Is the controller's W/A factor in the closed-loop MOD IN path? 64865766, closed loop, source 3, base 800,
# MOD-only steps 0/0.5/1 V at the current W/A, then at 2x (LD_SetWACalibFactor, not persisted), then restored.
ld_setwa(x) = kerr(ccall((:LD_SetWACalibFactor, DLL), Cshort, (Cstring, Cfloat), SER[], Cfloat(x)), "LD_SetWACalibFactor")
wa_fresh() = (twice(ld_reqwa); ld_getwa())
wa_rows = NamedTuple[]
wa0 = NaN
with_session(modchan = MOD_CHAN) do
    global wa0 = wa_fresh(); say("W/A at start: $wa0")
    try
        for (label, wa) in (("current", wa0), ("2x", 2wa0), ("restored", wa0))
            label == "current" || (ld_setwa(wa); sleep(0.3))
            rb = wa_fresh(); say("W/A $label: set $wa, readback $rb")
            start_loop(:closed, 3); usb_set(:closed, 800); MOD.vmax = 1.0; sleep(1.5)
            ls = []
            for v in (0.0, 0.5, 1.0, 0.0)
                modin_write(v); l = level(settle = 2.0); push!(ls, (v, l))
                push!(wa_rows, (wa_set = Float64(wa), wa_readback = rb, v = v, sp = l.sp, pd = l.pd, cur = l.cur, xpd = l.xpd, status = l.status))
                say(@sprintf("  W/A %-8s %.1f V: ", label, v), fmt(l))
            end
            k_pd = (ls[3][2].pd - ls[1][2].pd) / 1.0; k_x = (ls[3][2].xpd - ls[1][2].xpd) / 1.0
            say(@sprintf("  -> W/A %s (%.2f): %.1f words/V (monitor PD), %.4f V/V (external PD), %.4f ext-PD V per 1000 words",
                label, rb, k_pd, k_x, 1000 * k_x / k_pd))
            safe_off()
        end
    finally
        try ld_setwa(wa0); say("W/A restored, readback ", wa_fresh()) catch e; say("W/A RESTORE FAILED: ", e) end
    end
end
h5save("wa_test", columns(wa_rows); attrs = Dict{String,Any}("wa_start" => wa0, "note" => "closed loop, source 3, base 800, MOD 0/0.5/1/0 V"))
