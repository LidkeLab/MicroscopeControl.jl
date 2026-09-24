# Between-run state check and reset for the SmarAct MCS2.
#
# Answers "why won't the next run start, and what do I have to clear first".
# Read-only by default: it opens the device, prints what state every channel
# is actually in, and closes again. The two things that can be cleared are
# opt-in flags.
#
# Usage:
#   julia --project dev/reset_smaract.jl             # report only, commands nothing
#   julia --project dev/reset_smaract.jl --stop      # + stop every channel
#   julia --project dev/reset_smaract.jl --limits    # + rewrite range limits
#   julia --project dev/reset_smaract.jl --stop --limits
#
# What actually needs clearing between runs, and what does not
# ------------------------------------------------------------
#
# 1. The device handle — the usual culprit. GUARANTEE (vendor): the MCS2
#    permits exactly one open connection. A REPL or script that called
#    `initialize` and never called `shutdown` still holds it, and the next
#    attempt fails as "No SmarAct MCS2 devices found", which reads like a
#    cabling fault. Nothing in this script can clear that from the outside:
#    the handle belongs to the other process. Call `shutdown(stage)` there, or
#    close that Julia session. Killing the process also releases it, because
#    the OS closes the USB handle when the process dies.
#
# 2. Latched channel faults — END_STOP_REACHED / MOVEMENT_FAILED. LIMITATION:
#    these are reported in CHANNEL_STATE and persist after the move that set
#    them. `--stop` issues SA_CTL_Stop on every channel, which is the normal
#    way to end a failed move; whether the bits clear on the stop or only on
#    the next successful move is not something this repo has pinned down, so
#    the script re-reads and reports the state afterwards rather than
#    promising anything. If a bit survives both, the stage is still physically
#    against its stop — jog it clear, don't command it clear.
#
# 3. Range limits — volatile, and `initialize!` only reads them. POLICY: every
#    session writes them from `RIG_SAFE_WINDOW_UM` before moving. Both motion
#    scripts already do this at startup, so `--limits` is only useful when you
#    are about to drive the stage from the REPL or the GUI by hand.
#
# 4. Referencing — also volatile, cleared by a power cycle. NOT cleared or set
#    here on purpose: referencing *moves the stage*, and if the mark lies
#    behind the current position the search drives into the end stop. That is
#    `setup_stage(reference = true)` in dev/test_smaract_motion.jl, run
#    deliberately from near mid-travel.
#
# 5. Position — nothing to clear. Sub-µm relaxation between sessions is
#    expected once the hold ends; see dev/smaract_bringup.md.

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))
using MicroscopeControl
using Printf

include(joinpath(@__DIR__, "smaract_rig_config.jl"))

const M = MicroscopeControl.HardwareImplementations.MCS2Stage_mod

const AXES = (1 => "X", 2 => "Y")

"Fault bit names currently latched on one channel, `String[]` when clean."
function faults_on(stage, ch::Int32)
    state = M._get_i32(stage, ch, M.SA_CTL_PKEY_CHANNEL_STATE)
    return [name for (bit, name) in M._CH_FAULT_BITS if (state & bit) != 0]
end

function report(stage; heading)
    println("\n$heading")
    for (i, name) in AXES
        ch = stage.channel_ids[i]
        if !stage.connected[i]
            @printf("  %s (ch %d): not connected — no positioner detected\n", name, ch)
            continue
        end
        f = faults_on(stage, ch)
        @printf("  %s (ch %d): %+10.3f µm   referenced=%-5s calibrated=%-5s limits %.1f … %.1f µm   %s\n",
                name, ch, stage.pos_pm[i] / 1e6,
                stage.is_referenced[i], stage.is_calibrated[i],
                stage.min_pm[i] / 1e6, stage.max_pm[i] / 1e6,
                isempty(f) ? "clean" : "FAULTS: " * join(f, ", "))
    end
end

function reset(; stop::Bool = false, limits::Bool = false)
    stage = MCS2Stage(stagelabel = "SmarAct MCS2",
                      n_channels = 3, channel_ids = Int32[0, 1, 2])

    # If this throws "No SmarAct MCS2 devices found", nothing here can help:
    # another process holds the one allowed connection. See note 1 above.
    initialize(stage)

    try
        report(stage; heading = "State as found:")

        if stop
            println("\nStopping every connected channel ...")
            M.stop_all!(stage)
            M.query_positions!(stage)
            M.query_channel_states!(stage)
            report(stage; heading = "State after stop:")
        end

        if limits
            println("\nWriting range limits from RIG_SAFE_WINDOW_UM ...")
            for (i, name) in AXES
                stage.connected[i] || continue
                lo_pm, hi_pm = rig_window_pm(rig_axis(i))
                M.set_range_limits!(stage, i, lo_pm, hi_pm)
                @printf("  %s: %.1f … %.1f µm\n", name, lo_pm / 1e6, hi_pm / 1e6)
            end
        end

        # Referencing is the one piece of session state this script will not
        # touch, so say plainly when it is missing rather than leaving the
        # next run to discover it.
        unref = [name for (i, name) in AXES if stage.connected[i] && !stage.is_referenced[i]]
        if !isempty(unref)
            println("\nNot referenced: $(join(unref, ", ")). Positions above are against an " *
                    "arbitrary zero.\nPark near mid-travel, then run:\n" *
                    "    julia --project dev/test_smaract_motion.jl --reference")
        end
    finally
        shutdown(stage)   # never leak the handle — that is failure mode 1
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    args  = copy(ARGS)
    stop  = "--stop"   in args
    lims  = "--limits" in args
    bad   = setdiff(args, ["--stop", "--limits"])
    isempty(bad) || error("Unknown option(s): $(join(bad, ", ")). " *
                          "Choose from: --stop, --limits.")
    reset(; stop = stop, limits = lims)
end
