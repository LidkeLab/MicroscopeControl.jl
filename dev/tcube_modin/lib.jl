# Raw Kinesis + DAQmx helpers for the TLD001 MOD IN experiments (2026-10-19).
#
# Deliberately NOT the MicroscopeControl driver: the driver adds the modulation level
# to every USB write, so a test through it measures the driver, not the controller.
# Everything here is a bare ccall or a bare DAQmx.jl call, plus the safety rails.
#
# Units: the TLD001 setpoint/readings are 16-bit words.
#   open loop  : current word, 32767 = 220 mA (Kinesis header)
#   closed loop: photocurrent word, 32767 = the reported TIA range (10 mA on this cube)
#   PD reading : signed photocurrent word, same scale; -32768 = over range
# The absolute photocurrent is undetermined on this cube (MA, 2026-09-29: the raw word
# did not change with the DIP range), so results are quoted as words and as uA on the
# reported range, which is a label, not a calibration.

using DAQmx, HDF5, Statistics, Dates, Printf

const DLL = "C:\\Program Files\\Thorlabs\\Kinesis\\Thorlabs.MotionControl.TCube.LaserDiode.dll"
const SERIAL = "64865766"           # the NEW 642 on the PD (Keith, 2026-10-19); 64849775 is MA's, never touch
const MAX_CURRENT_mA = 160.0        # MA's max_current; never exceeded
const FULL_mA = 220.0               # current-word full scale
const WMAX = 32767

# Operating ceilings for these experiments (below max_current, with margin)
const CAP_OPEN_mA = 145.0           # open-loop setpoint cap (L-I sweeps); MOD runs use OPEN_MOD_CAP_mA
const CAP_CLOSED_WORD = 4300        # closed-loop total PD word, 1 mA range after LD_FindTIAGain (~107 mA; the external PD is linear to ~105 mA)
const CURRENT_TRIP_mA = 147.0       # a drive-current reading above this aborts (controller limit 150.6 mA: a lock at the limit trips)

const OUTDIR = normpath(joinpath(@__DIR__, "..", "output", "tcube-modin"))

# ---------------------------------------------------------------- Kinesis, raw
const SER = Ref(SERIAL)   # the cube under test; set SER[] before session_open
kerr(code, what) = code == 0 || error("$what returned $code")
ld_build() = ccall((:TLI_BuildDeviceList, DLL), Cshort, ())
ld_open() = ccall((:LD_Open, DLL), Cshort, (Cstring,), SER[])
ld_close() = ccall((:LD_Close, DLL), Cvoid, (Cstring,), SER[])
ld_startpoll(ms) = ccall((:LD_StartPolling, DLL), Bool, (Cstring, Cint), SER[], ms)
ld_stoppoll() = ccall((:LD_StopPolling, DLL), Cvoid, (Cstring,), SER[])
ld_enable() = kerr(ccall((:LD_EnableOutput, DLL), Cshort, (Cstring,), SER[]), "LD_EnableOutput")
ld_disable() = kerr(ccall((:LD_DisableOutput, DLL), Cshort, (Cstring,), SER[]), "LD_DisableOutput")
ld_openloop() = kerr(ccall((:LD_SetOpenLoopMode, DLL), Cshort, (Cstring,), SER[]), "LD_SetOpenLoopMode")
ld_closedloop() = kerr(ccall((:LD_SetClosedLoopMode, DLL), Cshort, (Cstring,), SER[]), "LD_SetClosedLoopMode")
ld_setsp_raw(w) = kerr(ccall((:LD_SetLaserSetPoint, DLL), Cshort, (Cstring, Cushort), SER[], UInt16(w)), "LD_SetLaserSetPoint")
ld_getsp() = Int(ccall((:LD_GetLaserSetPoint, DLL), Cushort, (Cstring,), SER[]))
ld_reqsp() = ccall((:LD_RequestLaserSetPoint, DLL), Cshort, (Cstring,), SER[])
ld_reqstatus() = ccall((:LD_RequestStatusBits, DLL), Cshort, (Cstring,), SER[])
ld_status() = UInt32(ccall((:LD_GetStatusBits, DLL), Cuint, (Cstring,), SER[]))
ld_reqread() = ccall((:LD_RequestReadings, DLL), Cshort, (Cstring,), SER[])
ld_pd() = Int(ccall((:LD_GetPhotoCurrentReading, DLL), Cshort, (Cstring,), SER[]))
ld_cur() = Int(ccall((:LD_GetLaserDiodeCurrentReading, DLL), Cshort, (Cstring,), SER[]))
ld_volt() = Int(ccall((:LD_GetVoltageReading, DLL), Cushort, (Cstring,), SER[]))
ld_reqsrc() = ccall((:LD_RequestControlSource, DLL), Cshort, (Cstring,), SER[])
ld_getsrc() = Int(ccall((:LD_GetControlSource, DLL), Cuint, (Cstring,), SER[]))
ld_setsrc(n) = kerr(ccall((:LD_SetControlSource, DLL), Cshort, (Cstring, Cuint), SER[], UInt32(n)), "LD_SetControlSource")
ld_reqlim() = ccall((:LD_RequestLaserDiodeMaxCurrentLimit, DLL), Cshort, (Cstring,), SER[])
ld_getlim() = Int(ccall((:LD_GetLaserDiodeMaxCurrentLimit, DLL), Cushort, (Cstring,), SER[]))
ld_reqdigpot() = ccall((:LD_RequestMaxCurrentDigPot, DLL), Cshort, (Cstring,), SER[])
ld_getdigpot() = Int(ccall((:LD_GetMaxCurrentDigPot, DLL), Cushort, (Cstring,), SER[]))
ld_reqwa() = ccall((:LD_RequestWACalibFactor, DLL), Cshort, (Cstring,), SER[])
ld_getwa() = Float64(ccall((:LD_GetWACalibFactor, DLL), Cfloat, (Cstring,), SER[]))
# NOTE: LD_PersistSettings is deliberately not bound.

"The cube answers one request behind: request twice."
twice(req) = (req(); sleep(0.1); req(); sleep(0.1))

status_fresh() = (twice(ld_reqstatus); ld_status())
source_fresh() = (twice(ld_reqsrc); ld_getsrc())
limit_fresh_mA() = (twice(ld_reqlim); ld_getlim() / WMAX * FULL_mA)
sp_fresh() = (twice(ld_reqsp); ld_getsp())

mA_to_word(mA) = floor(Int, mA / FULL_mA * WMAX)
word_to_mA(w) = w / WMAX * FULL_mA

const TIA_BITS = ((0x10, 10e-6), (0x20, 100e-6), (0x40, 1e-3), (0x80, 10e-3))
function tia_range(bits)
    r = [a for (b, a) in TIA_BITS if bits & b != 0]
    length(r) == 1 ? r[1] : NaN
end
decode_status(b) = (on = b & 0x1 != 0, key = b & 0x2 != 0, closed = b & 0x4 != 0, interlock = b & 0x8 != 0,
                    tia = tia_range(b), limit = b & 0x400 != 0, opencircuit = b & 0x800 != 0,
                    tia_over = b & 0x2000 != 0, tia_under = b & 0x4000 != 0)

"""
One sample: request readings, read PD word, drive-current mA, status word, setpoint word.
Each getter returns the cache, refreshed by the request ~one exchange later.
"""
function sample()
    ld_reqread(); ld_reqstatus(); ld_reqsp()
    sleep(0.06)
    t = time()
    pd = ld_pd(); cur = word_to_mA(ld_cur()); st = ld_status(); sp = ld_getsp()
    cur > CURRENT_TRIP_mA && throw(ErrorException("drive current $(cur) mA above trip $(CURRENT_TRIP_mA) mA"))
    return (t = t, pd = pd, cur = cur, status = st, sp = sp)
end

"Settled level: wait `settle` s, then average `n` samples. Returns means, sds and the raw samples."
function settled(; settle = 2.0, n = 10)
    sleep(settle)
    xs = [sample() for _ in 1:n]
    pds = [x.pd for x in xs]; curs = [x.cur for x in xs]
    st = xs[end].status
    return (pd = mean(pds), pd_sd = std(pds), cur = mean(curs), cur_sd = std(curs),
            sp = xs[end].sp, status = st, limit = st & 0x400 != 0, tia_over = st & 0x2000 != 0,
            tia_under = st & 0x4000 != 0, samples = xs)
end

# ---------------------------------------------------------------- MOD IN (NI AO)
mutable struct ModIn
    task::Union{Nothing,DAQmx.Task}
    chan::String
    vmax::Float64      # clamp for the current phase; every write is clamped to [vmin, vmax]
    vmin::Float64
    last::Float64
end
const MOD = ModIn(nothing, "", 0.0, 0.0, NaN)

function modin_open(chan::String)
    t = AOTask()
    add_ao_voltage!(t, chan; min_val = 0.0, max_val = 5.0)   # USB-6008: 0-5 V only
    start!(t)
    MOD.task = t; MOD.chan = chan; MOD.vmax = 0.0; MOD.vmin = 0.0
    modin_write(0.0)
    return t
end
function modin_write(v::Real)
    MOD.task === nothing && error("MOD IN output not open")
    v = Float64(v)
    (MOD.vmin - 1e-9 <= v <= MOD.vmax + 1e-9) || error("MOD IN write $(v) V outside the clamp [$(MOD.vmin), $(MOD.vmax)] V")
    write_scalar(MOD.task, v)
    MOD.last = v
    return v
end
modin_zero() = (MOD.task === nothing || (write_scalar(MOD.task, 0.0); MOD.last = 0.0); nothing)
function modin_close()
    MOD.task === nothing && return
    try write_scalar(MOD.task, 0.0) catch end
    try stop!(MOD.task) catch end
    try clear!(MOD.task) catch end
    MOD.task = nothing
end

# ---------------------------------------------------------------- session
mutable struct Session
    src0::Int
    closed0::Bool
    lim_mA::Float64
end
const SESSION = Session(-1, false, NaN)

"Open, poll, read the starting control source, check key/interlock/limit. Leaves the output OFF."
function session_open()
    ld_build(); sleep(0.2)
    c = ld_open(); c == 0 || error("LD_Open($(SER[])) returned $c (2 = held by another process)")
    ld_startpoll(50) || error("LD_StartPolling failed")
    sleep(0.3)
    # output off first, whatever left it on
    try ld_setsp_raw(0) catch end
    ld_disable()
    SESSION.src0 = source_fresh()
    lim = limit_fresh_mA(); SESSION.lim_mA = lim
    lim <= MAX_CURRENT_mA + 0.5 || (session_close(); error("controller limit $(lim) mA is above max_current $(MAX_CURRENT_mA)"))
    b = status_fresh(); d = decode_status(b)
    SESSION.closed0 = d.closed
    (d.key && d.interlock) || (session_close(); error("key or interlock not set (status 0x$(string(b; base=16)))"))
    @info "session open" control_source = SESSION.src0 limit_mA = lim status = "0x$(string(b; base=16))" tia = d.tia
    return nothing
end

"0 V, setpoint 0, output off, restore control source, open loop, close. Never throws."
function safe_off()
    for f in (modin_zero, () -> ld_setsp_raw(0), () -> sleep(0.05), ld_disable)
        try f() catch e; @error "safe_off step failed" exception = e end
    end
end
function session_close()
    safe_off()
    try
        SESSION.src0 > 0 && ld_setsrc(SESSION.src0)
    catch e; @error "restore control source failed" exception = e end
    try SESSION.closed0 ? ld_closedloop() : ld_openloop() catch end   # the loop mode found at open
    try ld_stoppoll() catch end
    try ld_close() catch end
    modin_close()
    nothing
end

"Run `f` with the laser session open; always ends dark and restored."
function with_session(f; modchan = nothing)
    session_open()
    try
        modchan === nothing || modin_open(modchan)
        return f()
    finally
        session_close()
    end
end

# ---------------------------------------------------------------- setpoint helpers
"Open loop: enable output (if off), then the current setpoint. Checks the cap."
function ol_set(mA)
    mA <= CAP_OPEN_mA || error("open-loop setpoint $mA mA above cap $CAP_OPEN_mA")
    ld_setsp_raw(mA_to_word(mA))
end
"Closed loop: ramp the setpoint word from `from` to `to` in steps (upward only)."
function cl_ramp(from::Int, to::Int; step = 400, dt = 0.05)
    to <= CAP_CLOSED_WORD || error("closed-loop word $to above cap $CAP_CLOSED_WORD")
    if to > from + step
        for w in (from + step):step:(to - 1)
            ld_setsp_raw(w); sleep(dt)
        end
    end
    ld_setsp_raw(to)
end

# ---------------------------------------------------------------- output files
function h5save(name::String, data::Dict{String,Any}; attrs = Dict{String,Any}())
    mkpath(OUTDIR)
    fn = joinpath(OUTDIR, name * "_" * Dates.format(now(), "yyyymmdd_HHMMSS") * ".h5")
    h5open(fn, "w") do f
        for (k, v) in attrs
            HDF5.attributes(f)[k] = v isa Symbol ? string(v) : v
        end
        HDF5.attributes(f)["serial"] = SER[]
        HDF5.attributes(f)["written"] = string(now())
        for (k, v) in data
            f[k] = v
        end
    end
    @info "wrote $fn"
    return fn
end
"Flatten a vector of NamedTuples with scalar fields into Dict of column vectors."
function columns(rows)
    isempty(rows) && return Dict{String,Any}()
    ks = keys(rows[1])
    Dict{String,Any}(string(k) => [r[k] isa Bool ? Int(r[k]) : (r[k] isa Unsigned ? Int(r[k]) : r[k]) for r in rows] for k in ks
                     if all(x -> x isa Number, (r[k] for r in rows)))
end

# ---------------------------------------------------------------- run log (REPL output is collected only at the end)
const LOG = Ref{Union{Nothing,IO}}(nothing)
function log_open(name)
    mkpath(OUTDIR)
    fn = joinpath(OUTDIR, name * "_" * Dates.format(now(), "yyyymmdd_HHMMSS") * ".log")
    LOG[] = open(fn, "w"); say("log $fn  serial $(SER[])  $(now())")
    return fn
end
function say(args...)
    s = string(args...)
    println(s)
    LOG[] === nothing || (println(LOG[], s); flush(LOG[]))
end
log_close() = (LOG[] === nothing || close(LOG[]); LOG[] = nothing)
const RUN_NAME = Ref("")

# ---------------------------------------------------------------- external PD on Dev2/ai0 (+) / ai4 (-), differential
# Found 2026-10-19 by ai_scan: a photodiode that sees the new laser (origin: an old LCA setup).
const XPD_CHAN = "Dev2/ai0"
"Clocked, finite acquisition of the external PD; start it, act, then xpd_read. Returns the task."
function xpd_start(; rate = 10_000.0, n = 10_000, vmax = 20.0)
    t = AITask(); add_ai_voltage!(t, XPD_CHAN; terminal_config = Differential, min_val = -vmax, max_val = vmax)
    configure_timing!(t; rate = rate, samples_per_channel = n)
    start!(t); return (task = t, t0 = time(), rate = rate, n = n)
end
function xpd_read(a)
    v = vec(read(a.task; samples_per_channel = a.n, timeout = a.n / a.rate + 10.0))
    stop!(a.task); clear!(a.task); return v
end
"Mean external-PD voltage over `dur` s."
xpd_level(; dur = 0.2, rate = 5000.0) = (a = xpd_start(; rate = rate, n = round(Int, dur * rate)); mean(xpd_read(a)))
const OPEN_MOD_CAP_mA = 108.0       # open-loop setpoint + MOD IN total for the modulation runs (external PD linear to ~105 mA)
const MOD_CHAN = "Dev2/ao1"         # wired to 64865766 MOD IN only (ao_probe 2026-10-19, confirmed by Keith)
const OPEN_mA_PER_V = Ref(NaN)      # measured by modscale; manual: limit/10 V
const CLOSED_WORD_PER_V = Ref(NaN)  # measured by modscale; manual: 32767/10 V

"Monitor PD + drive current (settled, averaged) and the external PD, at once."
function level(; settle = 2.0, n = 8)
    s = settled(settle = settle, n = n)
    x = xpd_level()
    return (pd = s.pd, cur = s.cur, sp = s.sp, xpd = x, status = Int(s.status), limit = s.limit)
end
fmt(l) = @sprintf("sp %5d  PD %7.1f  cur %7.2f mA  XPD %7.4f V%s", l.sp, l.pd, l.cur, l.xpd, l.limit ? " LIMIT" : "")

"Enter a loop with the output on at setpoint 0, then set the source with the output ON (the arming rule)."
function start_loop(loop::Symbol, src::Int)
    safe_off(); sleep(0.2)
    loop == :closed ? ld_closedloop() : ld_openloop(); sleep(0.2)
    decode_status(status_fresh()).closed == (loop == :closed) || error("loop mode $loop not set")
    ld_setsrc(src); sleep(0.2)
    ld_enable(); ld_setsp_raw(0); sleep(0.3)
    ld_setsrc(src); sleep(0.3)
end
"USB setpoint in the loop's own unit: mA (open) or PD word (closed, ramped up from `from`)."
usb_set(loop::Symbol, x; from = 0) = loop == :closed ? cl_ramp(Int(from), Int(x); step = 300, dt = 0.05) : ol_set(x)
"Clamp MOD IN so base + V * scale never passes the loop's cap."
function set_clamp!(loop::Symbol, base)
    if loop == :closed
        MOD.vmax = min(5.0, (CAP_CLOSED_WORD - base) / CLOSED_WORD_PER_V[])
    else
        MOD.vmax = min(5.0, (OPEN_MOD_CAP_mA - base) / OPEN_mA_PER_V[])
    end
    MOD.vmin = 0.0
    MOD.vmax
end

# measured MOD IN scales persist across lib re-includes in a small text file
const SCALES_FILE = joinpath(OUTDIR, "modin_scales.txt")
function save_scales()
    mkpath(OUTDIR)
    write(SCALES_FILE, "open_mA_per_V=$(OPEN_mA_PER_V[])\nclosed_word_per_V=$(CLOSED_WORD_PER_V[])\n")
end
if isfile(SCALES_FILE)
    for ln in eachline(SCALES_FILE)
        k, v = split(ln, "="); x = parse(Float64, v)
        k == "open_mA_per_V" && (OPEN_mA_PER_V[] = x)
        k == "closed_word_per_V" && (CLOSED_WORD_PER_V[] = x)
    end
end
