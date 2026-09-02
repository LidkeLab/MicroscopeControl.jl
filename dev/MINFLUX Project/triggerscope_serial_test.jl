# triggerscope_serial_test.jl
# Raw serial diagnostic for the Triggerscope4, bypassing the Triggerscope4/MicroscopeControl
# wrapper entirely. Useful when commands sent through `setdac`/`clearall`/etc. are timing out
# and it's unclear whether the device is replying at all.
#
# Unlike Triggerscope's `readresponse` (which uses `readline` and therefore blocks until it
# sees a trailing '\n'), this polls the input buffer directly with `bytesavailable`/
# `nonblocking_read`, so it will show us any bytes the device sends back even if they're
# not newline-terminated.

using LibSerialPort

println("Available serial ports:")
for p in get_port_list()
    println("  ", p)
end
println()

# ── Edit these to match your setup ───────────────────────────────────────────
portname = "COM4"
baudrate = 115200

sp = LibSerialPort.open(portname, baudrate)
sp_flush(sp, SP_BUF_BOTH)

println("Port opened. Waiting for device boot/reset...")
sleep(2)

# Drain and show anything sitting in the buffer at boot (e.g. an Arduino startup message)
boot_bytes = nonblocking_read(sp)
if isempty(boot_bytes)
    println("Boot buffer: (empty)")
else
    println("Boot buffer (", length(boot_bytes), " bytes): ", repr(String(boot_bytes)))
end
println()

# Sends a command, then polls for up to `listen_time` seconds for any bytes back —
# does NOT require a newline terminator, unlike Triggerscope's readresponse/readline.
function send_and_listen(sp, cmd::String; listen_time::Float64 = 3.0, poll_interval::Float64 = 0.05)
    sp_flush(sp, SP_BUF_BOTH)
    write(sp, cmd)
    println("Sent: ", repr(cmd))
    elapsed = 0.0
    received = UInt8[]
    while elapsed < listen_time
        if bytesavailable(sp) > 0
            append!(received, nonblocking_read(sp))
        end
        sleep(poll_interval)
        elapsed += poll_interval
    end
    if isempty(received)
        println("  -> No bytes received within $(listen_time)s")
    else
        println("  -> Received ", length(received), " bytes: ", repr(String(received)))
    end
    println()
    return received
end

send_and_listen(sp, "*\n")
send_and_listen(sp, "CLEAR_ALL\n")
send_and_listen(sp, "STAT?\n")

close(sp)

# To run:
# include("dev/MINFLUX Project/triggerscope_serial_test.jl")
#
# What to look for:
# - If the boot buffer has text but every send_and_listen shows "No bytes received":
#   the device replies once on boot but doesn't respond to commands -> wrong baud rate,
#   wrong protocol/firmware, or a wiring/driver issue. Not fixable from the Julia side.
# - If send_and_listen DOES receive bytes but they don't end in '\n': that's the actual
#   bug — Triggerscope's readresponse (readline-based) would hang/timeout on this even
#   though the device answered correctly.
# - If nothing comes back at all, ever: check the device is powered, the port/cable are
#   right, and try a different USB port.
