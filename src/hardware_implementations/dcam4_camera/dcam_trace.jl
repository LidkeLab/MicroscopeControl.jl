# Opt-in per-call trace of the DCAM library calls. A hang inside a DCAM ccall leaves no Julia frame
# to inspect, so `@dcamcall` (used at every DCAM ccall site in place of `@ccall`) can write a BEGIN
# line before and an END line after each call, flushed at once so a killed process leaves its last
# BEGIN on disk. Cumulative GC time is on every BEGIN and END line: a GC requested by another
# thread while this thread sits in a long ccall (which is not a GC safe point) makes that thread
# spin until the call returns, and shows as a jump between a call's BEGIN and END.
#
# Off by default; the cost when off is one `Ref{Bool}` check per call. Turn on with
# `dcam_trace!(path)` (`dcam_trace!(nothing)` turns it off) or ENV `MC_DCAM4_TRACE=<path>` at load.

using Dates: Dates

const TRACE_ON = Ref(false)
const TRACE_IO = Ref{Union{IOStream, Nothing}}(nothing)
const TRACE_LOCK = ReentrantLock()

"""
    dcam_trace!(path)
    dcam_trace!(nothing)

Append a BEGIN/END line for every DCAM library call to `path`, or stop tracing and close the file.
"""
function dcam_trace!(path::Union{AbstractString, Nothing})
    lock(TRACE_LOCK) do
        TRACE_ON[] = false
        TRACE_IO[] === nothing || close(TRACE_IO[])
        TRACE_IO[] = nothing
        if path !== nothing
            TRACE_IO[] = open(path, "a")
            TRACE_ON[] = true
        end
    end
    return nothing
end

function trace_line(kind, name, rest::AbstractString)
    lock(TRACE_LOCK) do
        io = TRACE_IO[]
        io === nothing && return
        t = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS.sss")
        println(io, t, " tid=", Threads.threadid(), " ", kind, " ", name, rest)
        flush(io)
    end
    return nothing
end

gc_ms() = Base.gc_num().total_time / 1e6

"""
    dcam_trace_note(msg)

Write a marker line to the trace, if tracing is on.
"""
function dcam_trace_note(msg)
    TRACE_ON[] && trace_line("NOTE", "", " " * string(msg))
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

function trace_begin(name, vals)
    trace_line("BEGIN", name, string(" args=(", join(map(trace_arg, vals), ", "), ") gc_ms=", round(gc_ms(), digits = 3)))
    return time_ns()
end

function trace_end(name, t0, ret)
    ms = (time_ns() - t0) / 1e6
    trace_line("END", name, string(" elapsed_ms=", round(ms, digits = 3), " ret=", ret, " gc_ms=", round(gc_ms(), digits = 3)))
    return nothing
end

"""
    @dcamcall [lib.]fn(arg::T, ...)::Ret

`@ccall`, plus a BEGIN and an END trace line when tracing is on (see `dcam_trace!`). Each argument
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
    r = gensym("ret"); t0 = gensym("t0")
    on = GlobalRef(@__MODULE__, :TRACE_ON)
    return esc(quote
        let $(binds...)
            if $on[]
                $t0 = $(GlobalRef(@__MODULE__, :trace_begin))($fname, ($(tmps...),))
                $r = $plain
                $(GlobalRef(@__MODULE__, :trace_end))($fname, $t0, $r)
                $r
            else
                $plain
            end
        end
    end)
end

function __init__()
    path = get(ENV, "MC_DCAM4_TRACE", "")
    isempty(path) || dcam_trace!(path)
end
