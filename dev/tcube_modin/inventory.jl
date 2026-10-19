# Step 0: inventory, no emission. NI devices/channels/timing, TLD001 state, Triggerscope presence.
include("lib.jl")
println("== NI-DAQmx ", library_version())
for d in device_names()
    println("device $d: ", product_type(d), "  serial ", try serial_number(d) catch; "?" end, " simulated=", is_simulated(d))
    for (lab, f) in (("AI", ai_channels), ("AO", ao_channels), ("DI", di_lines), ("DO", do_lines), ("CI", ci_channels), ("CO", co_channels))
        ch = try f(d) catch e; ["<$e>"] end
        println("  $lab ($(length(ch))): ", join(ch, ", "))
    end
    println("  AI ranges: ", try ai_voltage_ranges(d) catch e; e end)
    println("  AO ranges: ", try ao_voltage_ranges(d) catch e; e end)
    # sample-clock timing support: try to configure (not start) a clocked AI and AO task
    for (lab, mk) in (("AI", () -> (t = AITask(); add_ai_voltage!(t, "$d/ai0"); t)), ("AO", () -> (t = AOTask(); add_ao_voltage!(t, first(ao_channels(d))); t)))
        try
            t = mk()
            configure_timing!(t; rate = 1000.0, samples_per_channel = 1000)
            println("  $lab sample-clock timing: configure_timing! accepted")
            clear!(t)
        catch e
            println("  $lab sample-clock timing: REFUSED ($(sprint(showerror, e)[1:min(end,200)]))")
        end
    end
end
println("\n== serial ports"); try run(`powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames()"`) catch e; println(e) end

println("\n== TLD001 $SERIAL (output kept off)")
ld_build(); sleep(0.2)
c = ld_open(); println("LD_Open -> $c"); c == 0 || exit(1)
try
    ld_startpoll(50); sleep(0.3)
    b = status_fresh(); println("status 0x", string(b; base = 16), " ", decode_status(b))
    println("control source ", source_fresh())
    println("current limit ", round(limit_fresh_mA(); digits = 2), " mA")
    twice(ld_reqdigpot); println("digpot ", ld_getdigpot())
    twice(ld_reqwa); println("W/A on cube ", ld_getwa())
    println("setpoint word (stale with output off) ", sp_fresh())
    twice(ld_reqread); println("PD word ", ld_pd(), "  current ", round(word_to_mA(ld_cur()); digits = 2), " mA  voltage word ", ld_volt())
finally
    ld_stoppoll(); ld_close()
end
