# After the DIP flip: which range does the cube report, and do the raw PD words change?
# Open loop, source 1; compare with the 10 mA-range L-I (li_curve_20261019_134920.h5).
const RC_I = isdefined(@__MODULE__, :RC_I_OVERRIDE) ? RC_I_OVERRIDE : [0.0, 80.0, 100.0, 120.0, 145.0]
const RC_REF10 = Dict(0.0 => -2.0, 80.0 => 64.0)     # measured on 10 mA range; others from the fit below
ref10(I) = get(RC_REF10, I, 13.12 * (I - 74.32))
rc_rows = NamedTuple[]
with_session() do
    b = status_fresh(); say("status 0x$(string(b; base=16)) ", decode_status(b))
    ld_openloop(); sleep(0.2); ld_setsrc(1); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(1.0)
    for I in RC_I
        ol_set(I); s = settled(settle = 1.5, n = 8)
        push!(rc_rows, (set_mA = I, cur = s.cur, pd = s.pd, status = Int(s.status), over = s.tia_over, under = s.tia_under))
        say(@sprintf("set %5.1f mA  cur %7.2f  PD %8.1f words (10 mA range: %6.1f, ratio %.2f)  tia %s  st 0x%x%s%s", I, s.cur, s.pd, ref10(I),
            s.pd / ref10(I), decode_status(s.status).tia, s.status, s.tia_over ? " OVER" : "", s.tia_under ? " under" : ""))
    end
end
h5save("range_check", columns(rc_rows); attrs = Dict{String,Any}("note" => "after DIP flip, open loop source 1"))
