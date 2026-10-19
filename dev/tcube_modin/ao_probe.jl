# Step 0: which NI AO reaches MOD IN? Closed loop, source 3, base 300 PD words (~97 mA);
# each AO 0 -> 0.10 V (~ +328 words if wired: 10 V = 32767 words) -> 0 V. Source 3 set before AND after enable.
const PROBE_CHANS = ["Dev1/ao0", "Dev1/ao1", "Dev2/ao0", "Dev2/ao1"]
const PROBE_V = 0.10
const PROBE_BASE = 300
probe_rows = NamedTuple[]
with_session() do
    ld_closedloop(); sleep(0.2)
    decode_status(status_fresh()).closed || error("closed loop not set")
    ld_setsrc(3); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(0.5)
    ld_setsrc(3); sleep(0.3)                 # again with the output ON (the 10-13 open-loop arming rule)
    cl_ramp(0, PROBE_BASE; step = 50, dt = 0.1)
    s = settled(settle = 2.0, n = 8)
    say(@sprintf("base: sp %d  PD %.1f  cur %.2f mA  st 0x%x", s.sp, s.pd, s.cur, s.status))
    for ch in PROBE_CHANS
        modin_open(ch); MOD.vmax = PROBE_V
        try
            for (lab, v) in (("0V", 0.0), ("step", PROBE_V), ("back", 0.0))
                modin_write(v)
                s = settled(settle = 2.0, n = 8)
                push!(probe_rows, (chan = ch, phase = lab, v = v, sp = s.sp, pd = s.pd, cur = s.cur, status = Int(s.status)))
                say(@sprintf("%-9s %-4s %.3f V: sp %5d  PD %6.1f  cur %7.2f mA  st 0x%x", ch, lab, v, s.sp, s.pd, s.cur, s.status))
            end
        finally
            modin_close()
        end
    end
end
d = Dict{String,Any}("chan" => [r.chan for r in probe_rows], "phase" => [r.phase for r in probe_rows])
merge!(d, columns([(v = r.v, sp = r.sp, pd = r.pd, cur = r.cur, status = r.status) for r in probe_rows]))
h5save("ao_probe", d; attrs = Dict{String,Any}("base_word" => PROBE_BASE, "step_V" => PROBE_V, "source" => 3, "loop" => "closed"))
