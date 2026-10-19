# Optimise the TIA gain (LD_FindTIAGain) at 145 mA open loop, as the manual says (max drive current),
# then sweep to see where the PD now over-ranges. NOT persisted (LD_PersistSettings never called).
ld_findgain() = Int(ccall((:LD_FindTIAGain, DLL), Cshort, (Cstring,), SER[]))
tg_rows = NamedTuple[]
with_session() do
    ld_openloop(); sleep(0.2); ld_setsrc(1); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(0.5)
    for I in 80.0:10.0:140.0; ol_set(I); sleep(0.3); end
    ol_set(145.0); s = settled(settle = 2.0, n = 6)
    say(@sprintf("before: 145 mA  PD %.1f  st 0x%x", s.pd, s.status))
    ea = Int(ccall((:LD_EnableTIAGainAdjust, DLL), Cshort, (Cstring, Cuint), SER[], 1)); say("LD_EnableTIAGainAdjust(1) -> $ea"); sleep(0.5)
    r = ld_findgain(); say("LD_FindTIAGain -> $r"); sleep(3.0)
    eb = Int(ccall((:LD_EnableTIAGainAdjust, DLL), Cshort, (Cstring, Cuint), SER[], 0)); say("LD_EnableTIAGainAdjust(0) -> $eb")
    for k in 1:10
        s = settled(settle = 1.0, n = 4)
        say(@sprintf("  +%2d s: cur %.2f  PD %.1f  st 0x%x", k, s.cur, s.pd, s.status))
    end
    for I in [145.0, 140.0, 130.0, 120.0, 118.0, 110.0, 100.0, 90.0, 80.0, 75.0, 70.0, 0.0]
        ol_set(I); s = settled(settle = 1.5, n = 8)
        push!(tg_rows, (set_mA = I, cur = s.cur, pd = s.pd, status = Int(s.status), over = s.tia_over, under = s.tia_under))
        say(@sprintf("set %5.1f  cur %7.2f  PD %8.1f  tia %s st 0x%x%s%s", I, s.cur, s.pd, decode_status(s.status).tia, s.status,
            s.tia_over ? " OVER" : "", s.tia_under ? " under" : ""))
    end
end
h5save("tia_gain", columns(tg_rows); attrs = Dict{String,Any}("note" => "after LD_FindTIAGain at 145 mA, open loop, source 1, not persisted"))
