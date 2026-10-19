# Does any NI AI see the laser? Read all AIs (RSE, ±10 V, 1 kS/s x 200) dark and at 110 mA open loop.
function ai_snapshot()
    out = Dict{String,Tuple{Float64,Float64}}()
    for dev in ("Dev1", "Dev2"), k in 0:7
        ch = "$dev/ai$k"
        t = AITask(); add_ai_voltage!(t, ch; terminal_config = RSE, min_val = -10.0, max_val = 10.0)
        configure_timing!(t; rate = 1000.0, samples_per_channel = 200)
        start!(t); v = vec(read(t; samples_per_channel = 200)); stop!(t); clear!(t)
        out[ch] = (mean(v), std(v))
    end
    out
end
dark = lit = nothing
with_session() do
    ld_openloop(); sleep(0.2); ld_setsrc(1); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(0.5)
    global dark = ai_snapshot()
    for I in 80.0:10.0:110.0; ol_set(I); sleep(0.3); end
    sleep(1.0); global lit = ai_snapshot()
    ol_set(0.0)
end
for ch in sort(collect(keys(dark)))
    say(@sprintf("%-9s dark %8.4f (sd %.4f)   110 mA %8.4f (sd %.4f)   diff %+8.4f V", ch, dark[ch]..., lit[ch]..., lit[ch][1] - dark[ch][1]))
end
