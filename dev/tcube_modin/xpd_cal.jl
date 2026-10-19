# External PD vs drive current and monitor PD, open loop, source 1 (and saturation check).
xc_rows = NamedTuple[]
with_session() do
    ld_openloop(); sleep(0.2); ld_setsrc(1); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(0.5)
    x0 = xpd_level(); say(@sprintf("dark XPD %.4f V", x0))
    for I in vcat(0.0, 60.0:5.0:70.0, 72.0:2.0:90.0, 95.0:5.0:145.0)
        ol_set(I); s = settled(settle = 1.0, n = 6); x = xpd_level()
        push!(xc_rows, (set_mA = I, cur = s.cur, pd = s.pd, xpd = x, status = Int(s.status)))
        say(@sprintf("set %5.1f  cur %7.2f  PD %7.1f  XPD %8.4f V", I, s.cur, s.pd, x))
    end
end
h5save("xpd_cal", columns(xc_rows); attrs = Dict{String,Any}("xpd" => "Dev2/ai0-ai4 differential ±20 V", "note" => "open loop, source 1"))
