# Is 64865766 the new laser on the PD? Open loop, source 1, low currents only; ends dark and restored.
let T = Main.TM
    T.SER[] = "64865766"
    T.with_session() do
        T.ld_openloop(); sleep(0.2)
        T.ld_setsrc(1); sleep(0.2)
        T.ld_enable(); T.ld_setsp_raw(0); sleep(1.0)
        for I in (0.0, 30.0, 60.0, 70.0, 80.0, 90.0)
            T.ol_set(I)
            s = T.settled(settle = 1.0, n = 6)
            d = T.decode_status(s.status)
            println("set $(I) mA -> read $(round(s.cur; digits=2)) mA  PD $(round(s.pd; digits=1))  status 0x$(string(s.status; base=16)) opencircuit=$(d.opencircuit) limit=$(d.limit) tia=$(d.tia)")
            if I >= 30 && s.cur < 0.5 * I
                println("drive current does not follow: stopping"); break
            end
        end
    end
    println("after: source ", (T.session_open(); x = T.source_fresh(); b = T.status_fresh(); T.session_close(); (x, "0x" * string(b; base=16))))
end
