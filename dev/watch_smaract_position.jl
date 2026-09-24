# Live, read-only position monitor for the SmarAct MCS2.
#
# Commands nothing. It only reads SA_CTL_PKEY_POSITION, so it is safe to leave
# running while you jog the stage from the controller's hand control module.
#
# Usage:
#   julia --project dev/watch_smaract_position.jl
#
# Ctrl-C to stop; the device handle is always closed on the way out. That
# matters here — the MCS2 allows only one open connection, so a leaked handle
# locks out the next script until the process dies.
#
# Why this exists
# ---------------
# An unreferenced channel reports position against an arbitrary zero, so the
# absolute numbers mean nothing. The *differences* are still real. That is
# enough to do two things without referencing:
#
#   * find the usable travel — jog gently to each end and read the span;
#   * park the stage at mid-range, so a later reference search has room to
#     find the mark in either direction instead of grinding into a stop.
#
# The end-stop figures in dev/smaract_rig_config.jl are flagged provisional.
# Jogging by hand while watching this is a gentler way to check them than
# driving into the stop under closed-loop control, because you can feel and
# see the stage stop and back off immediately.

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))
using MicroscopeControl
using Printf

include(joinpath(@__DIR__, "smaract_rig_config.jl"))

const M      = MicroscopeControl.HardwareImplementations.MCS2Stage_mod
const POLL_S = 0.1

function watch()
    stage = MCS2Stage(stagelabel = "SmarAct MCS2",
                      n_channels = 3, channel_ids = Int32[0, 1, 2])
    initialize(stage)

    axes = Tuple{Int,Symbol}[]
    lo   = Dict{Int,Float64}()
    hi   = Dict{Int,Float64}()

    try
        for i in 1:2
            stage.connected[i] || continue
            push!(axes, (i, rig_axis(i)))
        end
        isempty(axes) && error("No connected axes to watch.")

        println("\nJog the stage from the hand control module. Ctrl-C to stop.")
        println("Unreferenced, so the absolute value is arbitrary — watch the span.\n")

        while true
            parts = String[]
            for (i, name) in axes
                p = M._get_i64(stage, stage.channel_ids[i], M.SA_CTL_PKEY_POSITION) / 1e6
                lo[i] = min(get(lo, i,  Inf), p)
                hi[i] = max(get(hi, i, -Inf), p)
                push!(parts, @sprintf("%s %+9.3f µm [span %8.3f]", name, p, hi[i] - lo[i]))
            end
            print("\r\e[2K", join(parts, "    "))
            flush(stdout)
            sleep(POLL_S)
        end
    catch e
        e isa InterruptException || rethrow()
        println("\n\nStopped. Observed travel (relative to an arbitrary zero):")
        for (i, name) in axes
            haskey(lo, i) || continue
            @printf("  %s: %+9.3f … %+9.3f µm   span %8.3f µm   midpoint %+9.3f µm\n",
                    name, lo[i], hi[i], hi[i] - lo[i], (lo[i] + hi[i]) / 2)
        end
        println("\nPark near the midpoint before referencing.")
    finally
        shutdown(stage)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    watch()
end
