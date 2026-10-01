# Opt-in per-call trace of the DCAM library calls. A hang inside a DCAM ccall leaves no Julia frame
# to inspect, so `@dcamcall` (used at every DCAM ccall site in place of `@ccall`) can write a BEGIN
# line before and an END line after each call, flushed at once so a killed process leaves its last
# BEGIN on disk. GC counters are on every BEGIN and END line. `total_time` is only the collection
# pause. When another thread requests a GC while this thread sits in a long ccall, which is not a GC
# safe point, the GC waits for this thread to reach a safe point, and that wait is counted in
# `time_to_safepoint`. A jump in `sp_total_ms`/`sp_max_ms` between a call's BEGIN and END is that
# wait. `gc_num` is updated only when a collection finishes, so while the hang is still going these
# numbers do not move; the heartbeat is the in-flight signal.
#
# While tracing is on, a heartbeat task writes a NOTE line every second. While a DCAM call's BEGIN has
# no END, heartbeats that keep coming mean the call is simply blocking in the library; heartbeats that
# stop mean every Julia thread is held at a GC stop, waiting for that call. The heartbeat runs on the
# default pool, so it needs a default-pool thread other than the caller's. On Julia 1.12+ the main task
# runs on the interactive thread, so the default thread 1.12+ starts with is enough. On 1.11 start Julia
# with `-t 2` or more. With a single thread in all, the heartbeat goes silent during every ccall.
#
# Off by default; the cost when off is one `Ref{Bool}` check per call. Turn on with
# `dcam_trace!(path)` (`dcam_trace!(nothing)` turns it off); there is no other way on.

using Dates: Dates

const TRACE_ON = Ref(false)
const TRACE_IO = Ref{Union{IOStream, Nothing}}(nothing)
const TRACE_LOCK = ReentrantLock()
const TRACE_CTL_LOCK = ReentrantLock()   # serializes dcam_trace!; the heartbeat never takes it
const HEARTBEAT_S = 1.0
const HEARTBEAT = Ref{Union{Nothing, Tuple{Task, Threads.Atomic{Bool}}}}(nothing)

"""
    dcam_trace!(path)
    dcam_trace!(nothing)

Append a trace line for every DCAM library call to `path`, or stop tracing and close the file.
This is the only way to turn tracing on.

`path` must be on a local disk: a write to a network path can stall, and a stalled write stalls the
DCAM call it brackets. Line formats, each after a timestamp and `tid=`:

    BEGIN <name> id=<n> args=(...) gc_ms=.. sp_total_ms=.. sp_max_ms=..
    END <name> id=<n> elapsed_ms=<ms> ret=<ret> gc_ms=.. sp_total_ms=.. sp_max_ms=..
    THROW <name> id=<n> elapsed_ms=<ms> err=<Type>: <message> gc_ms=.. sp_total_ms=.. sp_max_ms=..
    NOTE  <text>

A failed write to the file turns tracing off with one warning; the DCAM call still runs.

Ids count up from 1 in each process and are not reset. The file is appended to, so each
`NOTE  trace on` line starts a segment, and a BEGIN pairs with the END or THROW of the same id only
within its segment.

While tracing is on, a heartbeat writes `NOTE  heartbeat gc_ms=..` every second. Heartbeats that keep
coming while a BEGIN has no END mean the call is blocking in the library; heartbeats that stop mean
every Julia thread is held at a GC stop, waiting for that call. The heartbeat runs on the default pool,
so it needs a default-pool thread other than the caller's. On Julia 1.12+ the main task runs on the
interactive thread, so the default thread that 1.12+ starts with is enough. On 1.11 start Julia with
`-t 2` or more. With a single thread in all, the heartbeat goes silent during every ccall.

Reading a trace: first check the console for the `tracing is now off` warning; if it fired, the file
stops there because the trace stopped, not because a call hung. Then find the last BEGIN with no END or
THROW of the same id in the last segment. Heartbeats after that BEGIN mean the call is blocking in the
library; heartbeats that stopped mean every Julia thread is held at a GC stop, waiting for that call
(given the thread rule above).
"""
function dcam_trace!(path::Union{AbstractString, Nothing})
    lock(TRACE_CTL_LOCK) do
        hb = HEARTBEAT[]
        if hb !== nothing
            # Never wait on the old heartbeat: one stuck behind a hung call would block this forever while
            # it holds TRACE_CTL_LOCK. It checks its stop flag under TRACE_LOCK before each write, so once
            # the swap below has happened it can no longer write, and it exits on its next tick.
            hb[2][] = true
            HEARTBEAT[] = nothing
        end
        lock(TRACE_LOCK) do
            TRACE_ON[] = false
            if TRACE_IO[] !== nothing
                trace_line(() -> " trace off", "NOTE", "")
                TRACE_IO[] === nothing || close(TRACE_IO[])   # a failed write has already closed it
            end
            TRACE_IO[] = nothing
            if path !== nothing
                TRACE_IO[] = open(path, "a")
                trace_line("NOTE", "") do
                    string(" trace on pid=", getpid(), " julia=", VERSION,
                        " threads=interactive:", Threads.nthreads(:interactive), ",default:", Threads.nthreads(:default),
                        " caller_tid=", Threads.threadid(), " caller_pool=", Threads.threadpool())
                end
                TRACE_ON[] = TRACE_IO[] !== nothing
            end
        end
        if path !== nothing
            stop = Threads.Atomic{Bool}(false)
            HEARTBEAT[] = (Threads.@spawn(:default, heartbeat_loop(stop)), stop)
        end
    end
    return nothing
end

function heartbeat_loop(stop::Threads.Atomic{Bool})
    last = 0.0
    while !stop[] && TRACE_ON[]
        if time() - last >= HEARTBEAT_S || last == 0.0
            trace_line("NOTE", ""; guard = stop) do
                " heartbeat" * gc_fields()
            end
            last = time()
        end
        sleep(0.1)
    end
    return nothing
end

# `build()` returns the text after the name. It runs under TRACE_LOCK, and whatever it throws, an
# InterruptException included, is turned into a note: no line-building failure may reach the DCAM call
# or replace the caller's exception. `guard` is a stop flag, checked under the lock so a superseded
# heartbeat cannot write into a newer file.
function trace_line(build, kind, name; guard = nothing)
    lock(TRACE_LOCK) do
        io = TRACE_IO[]
        io === nothing && return
        guard !== nothing && guard[] && return
        rest = try
            build()
        catch e
            string(" (trace line not built: ", typeof(e), ")")
        end
        try
            t = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS.sss")
            println(io, t, " tid=", Threads.threadid(), " ", kind, " ", name, rest)
            flush(io)
        catch err
            err isa InterruptException && rethrow()
            TRACE_ON[] = false
            try
                close(io)
            catch
            end
            TRACE_IO[] = nothing
            @warn "DCAM4 trace: writing the trace file failed; tracing is now off" exception = err
        end
    end
    return nothing
end

function gc_fields()
    g = Base.gc_num()
    return string(" gc_ms=", round(g.total_time / 1e6, digits = 3),
                  " sp_total_ms=", round(g.total_time_to_safepoint / 1e6, digits = 3),
                  " sp_max_ms=", round(g.max_time_to_safepoint / 1e6, digits = 3))
end

"""
    dcam_trace_note(msg)

Write a marker line to the trace, if tracing is on.
"""
function dcam_trace_note(msg)
    TRACE_ON[] && trace_line(() -> " " * string(msg), "NOTE", "")
    return nothing
end

function trace_arg(v)
    v isa Base.RefValue && (v = v[])
    if v isa Integer || v isa AbstractFloat
        return string(v)
    elseif v isa Ptr
        return string("0x", string(UInt(v), base = 16))
    elseif isstructtype(typeof(v)) && !(v isa Union{AbstractArray, AbstractString}) && fieldcount(typeof(v)) > 0
        parts = String[]
        for f in fieldnames(typeof(v))
            fv = getfield(v, f)
            fv isa Int32 && push!(parts, string(f, "=", fv))
        end
        return string(typeof(v).name.name, "{", join(parts, ","), "}")
    else
        return string(typeof(v))
    end
end

const TRACE_SEQ = Threads.Atomic{Int}(0)

function trace_begin(name, vals)
    id = Threads.atomic_add!(TRACE_SEQ, 1) + 1
    trace_line("BEGIN", name) do
        args = try
            join(map(trace_arg, vals), ", ")
        catch
            "(args not built)"
        end
        string(" id=", id, " args=(", args, ")", gc_fields())
    end
    return (id, time_ns())
end

function trace_end(name, id, t0, ret)
    ms = (time_ns() - t0) / 1e6
    trace_line("END", name) do
        string(" id=", id, " elapsed_ms=", round(ms, digits = 3), " ret=", ret, gc_fields())
    end
    return nothing
end

function trace_throw(name, id, t0, err)
    ms = (time_ns() - t0) / 1e6
    trace_line("THROW", name) do
        msg = first(replace(sprint(showerror, err), '\n' => ' '), 200)
        string(" id=", id, " elapsed_ms=", round(ms, digits = 3), " err=", typeof(err), ": ", msg, gc_fields())
    end
    return nothing
end

"""
    @dcamcall [lib.]fn(arg::T, ...)::Ret

`@ccall`, plus a BEGIN and an END (or THROW) trace line when tracing is on (see `dcam_trace!`). Each argument
expression is evaluated once.
"""
macro dcamcall(expr)
    Meta.isexpr(expr, :(::), 2) && Meta.isexpr(expr.args[1], :call) || error("@dcamcall: expected fn(args...)::Ret")
    call, ret = expr.args
    target = call.args[1]
    fname = string(target isa Expr ? target.args[end] : target)
    fname = startswith(fname, ":") ? fname[2:end] : fname
    binds = Expr[]
    tmps = Symbol[]
    newargs = Any[target]
    for a in call.args[2:end]
        Meta.isexpr(a, :(::), 2) || error("@dcamcall: every argument needs a type annotation, got $a")
        t = gensym("arg")
        push!(binds, :($t = $(a.args[1])))
        push!(tmps, t)
        push!(newargs, Expr(:(::), t, a.args[2]))
    end
    plain = :(Base.@ccall $(Expr(:(::), Expr(:call, newargs...), ret)))
    r = gensym("ret"); t0 = gensym("t0"); id = gensym("id"); e = gensym("err")
    on = GlobalRef(@__MODULE__, :TRACE_ON)
    return esc(quote
        let $(binds...)
            if $on[]
                ($id, $t0) = $(GlobalRef(@__MODULE__, :trace_begin))($fname, ($(tmps...),))
                $r = try
                    $plain
                catch $e
                    $(GlobalRef(@__MODULE__, :trace_throw))($fname, $id, $t0, $e)
                    rethrow()
                end
                $(GlobalRef(@__MODULE__, :trace_end))($fname, $id, $t0, $r)
                $r
            else
                $plain
            end
        end
    end)
end
