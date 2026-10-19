# No emission. 1) restore 64849775 (MA's 642) to what inventory found: source 5, closed loop, output off.
# 2) read the state of the other two cubes.
using .TM
let T = Main.TM
    T.SER[] = "64849775"
    c = T.ld_open(); println("open 64849775 -> $c")
    if c == 0
        T.ld_startpoll(50); sleep(0.3)
        T.ld_setsrc(5); T.ld_closedloop(); sleep(0.2)
        b = T.status_fresh()
        println("64849775 restored: source ", T.source_fresh(), "  status 0x", string(b; base=16), " ", T.decode_status(b))
        T.ld_stoppoll(); T.ld_close()
    end
    for s in ("64864827", "64865766")
        T.SER[] = s
        c = T.ld_open(); println("\n== $s: open -> $c"); c == 0 || continue
        try
            T.ld_startpoll(50); sleep(0.3)
            b = T.status_fresh(); println("status 0x", string(b; base=16), " ", T.decode_status(b))
            println("control source ", T.source_fresh(), "   current limit ", round(T.limit_fresh_mA(); digits=2), " mA")
            T.twice(T.ld_reqdigpot); println("digpot ", T.ld_getdigpot())
            T.twice(T.ld_reqwa); println("W/A ", T.ld_getwa())
            T.twice(T.ld_reqread); println("PD word ", T.ld_pd(), "  current ", round(T.word_to_mA(T.ld_cur()); digits=2), " mA")
        finally
            T.ld_stoppoll(); T.ld_close()
        end
    end
    T.SER[] = ""   # nothing selected until the new laser is confirmed
end
