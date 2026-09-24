# SmarAct MCS2 motion characterisation: long range, small range, and the two
# combined. Not part of the package test suite — it needs the real stage.
#
# Usage:
#   julia --project dev/test_smaract_motion.jl            # runs all three
#   julia --project dev/test_smaract_motion.jl long       # one or more of:
#   julia --project dev/test_smaract_motion.jl small combined
#
# Every target is clamped into the controller's software limits before it is
# sent, so nothing here can command the stage into a mechanical end stop.
# Moves go through move_abs! (blocking, one channel at a time) so each axis is
# characterised independently.

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))
using MicroscopeControl
using Statistics
using Printf

include(joinpath(@__DIR__, "smaract_rig_config.jl"))

const M = MicroscopeControl.HardwareImplementations.MCS2Stage_mod

# ---------------------------------------------------------------------------
# Parameters

const SETTLE_S    = 0.30   # dwell after a move before reading position
const EDGE_MARGIN = 5.0    # µm kept clear of each software limit
const N_REPEATS   = 5      # repeats for repeatability statistics

# Step sizes for the small-range sweep, µm. The bottom of this list is below
# the resolution floor of a stick-slip actuator on purpose — the point is to
# find where commanded and achieved stop agreeing.
const SMALL_STEPS_UM = [0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0]

const AXES = (1 => "X", 2 => "Y")   # stage channel index => label

# ---------------------------------------------------------------------------
# Helpers

"""
    safe_bounds_um(stage, i) -> (lo, hi)

Working window of one axis in µm, inset by EDGE_MARGIN.

The authority is `RIG_SAFE_WINDOW_UM`, **not** the controller's software
limits. Those limits are whatever the last session happened to write; they are
accepted by the controller even when far wider than the real travel, so
deriving a sweep from them is how you end up commanding ±20 mm on a stage with
0.45 mm of travel. They are intersected in when they are narrower, never
trusted to widen the window.
"""
function safe_bounds_um(stage, i)
    lo, hi = rig_window_um(rig_axis(i))

    soft_lo = stage.min_pm[i] / 1e6
    soft_hi = stage.max_pm[i] / 1e6
    if soft_hi > soft_lo                      # 0/0 means "no limit configured"
        if soft_lo < lo - 1e-6 || soft_hi > hi + 1e-6
            @warn "Axis $(rig_axis(i)): controller limits ($soft_lo, $soft_hi) µm are wider " *
                  "than the safe window ($lo, $hi) µm — using the safe window."
        end
        lo = max(lo, soft_lo)
        hi = min(hi, soft_hi)
    end

    hi - lo > 2 * EDGE_MARGIN ||
        error("Axis $(rig_axis(i)): usable window ($lo, $hi) µm is too small to test.")
    return (lo + EDGE_MARGIN, hi - EDGE_MARGIN)
end

clamp_um(x, bounds) = clamp(x, bounds[1], bounds[2])

"""
    goto_um(stage, i, target_um) -> position reached, µm

Blocking absolute move of one axis, with two guards: the target must already
lie inside the safe window, and the move must finish without a fault bit set.

Both matter. A faulted move has not arrived, so its position is not data — and
continuing past one means every later move repeats the same grind against the
stop. Abort instead.
"""
function goto_um(stage, i, target_um; settle_s = SETTLE_S)
    lo, hi = safe_bounds_um(stage, i)
    lo - 1e-6 <= target_um <= hi + 1e-6 ||
        error("Refusing to move axis $(rig_axis(i)) to $(target_um) µm: " *
              "outside the safe window ($lo, $hi) µm.")

    M.move_abs!(stage, i, round(Int64, target_um * 1e6))
    sleep(settle_s)

    ch    = stage.channel_ids[i]
    state = M._get_i32(stage, ch, M.SA_CTL_PKEY_CHANNEL_STATE)
    faults = [name for (bit, name) in M._CH_FAULT_BITS if (state & bit) != 0]
    isempty(faults) ||
        error("Axis $(rig_axis(i)) faulted moving to $(target_um) µm " *
              "($(join(faults, ", "))) — aborting. The move did not arrive, so " *
              "nothing measured past this point would be meaningful.")

    M.query_positions!(stage)
    return stage.pos_pm[i] / 1e6
end

function summarise(label, errors_um)
    @printf("  %-34s n=%2d  mean %+8.4f  std %7.4f  max|e| %7.4f µm\n",
            label, length(errors_um), mean(errors_um), std(errors_um),
            maximum(abs.(errors_um)))
end

# ---------------------------------------------------------------------------
# 1. Long range — accuracy across the full travel, and direction dependence
#
# Sweeps the usable range forward then backward over the same points. The
# forward-minus-backward difference at each point is hysteresis: for a
# stick-slip stage it is the clearest single number for "does it matter which
# way I approached this position".

function test_long_range(stage)
    println("\n=== Long range: accuracy across full travel ===")

    for (i, name) in AXES
        stage.connected[i] || continue
        lo, hi = safe_bounds_um(stage, i)
        points = collect(range(lo, hi; length = 9))

        @printf("\nAxis %s: sweeping %.1f → %.1f µm (%.1f µm span), 9 points\n",
                name, lo, hi, hi - lo)

        fwd = [goto_um(stage, i, p) for p in points]
        rev = reverse([goto_um(stage, i, p) for p in reverse(points)])

        fwd_err = fwd .- points
        rev_err = rev .- points
        hyst    = fwd .- rev

        println("   target µm   forward err   reverse err   hysteresis")
        for k in eachindex(points)
            @printf("  %+9.2f   %+10.4f   %+11.4f   %+10.4f\n",
                    points[k], fwd_err[k], rev_err[k], hyst[k])
        end
        summarise("$name forward error",  fwd_err)
        summarise("$name reverse error",  rev_err)
        summarise("$name hysteresis",     hyst)
    end
end

# ---------------------------------------------------------------------------
# 2. Small range — minimum incremental motion
#
# From mid-range, takes N_REPEATS consecutive steps of each size and measures
# what actually happened. A stick-slip closed loop has a floor: below it the
# achieved step collapses towards zero or scatters wildly. The ratio column is
# achieved/commanded — it should sit near 1.00 until you cross that floor.

function test_small_range(stage)
    println("\n=== Small range: minimum incremental motion ===")

    for (i, name) in AXES
        stage.connected[i] || continue
        lo, hi = safe_bounds_um(stage, i)
        centre = (lo + hi) / 2

        @printf("\nAxis %s: stepping from %.1f µm, %d steps per size\n",
                name, centre, N_REPEATS)
        println("   step µm    mean achieved    std      ratio")

        for step in SMALL_STEPS_UM
            # Restart from centre each time so drift over the sweep does not
            # walk us into a limit.
            goto_um(stage, i, centre)
            prev = stage.pos_pm[i] / 1e6

            achieved = Float64[]
            for k in 1:N_REPEATS
                target = clamp_um(centre + k * step, (lo, hi))
                here   = goto_um(stage, i, target)
                push!(achieved, here - prev)
                prev = here
            end

            @printf("  %8.3f   %+12.5f   %7.5f   %6.3f\n",
                    step, mean(achieved), std(achieved), mean(achieved) / step)
        end
    end
end

# ---------------------------------------------------------------------------
# 3. Both together — fine positioning immediately after a long traverse
#
# The case that actually bites during acquisition: a long move to a new field,
# then a small step. Two things are measured — whether the fine step lands
# correctly right after a traverse (settling), and whether the same target is
# reached from far below and far above (bidirectional repeatability).

function test_combined(stage)
    println("\n=== Combined: fine steps after a long traverse ===")

    for (i, name) in AXES
        stage.connected[i] || continue
        lo, hi = safe_bounds_um(stage, i)
        centre = (lo + hi) / 2
        fine   = 1.0   # µm

        @printf("\nAxis %s: traverse, then a %.1f µm step, ×%d each direction\n",
                name, fine, N_REPEATS)

        step_err = Float64[]
        for k in 1:N_REPEATS
            far = isodd(k) ? lo : hi          # alternate approach direction
            goto_um(stage, i, far)            # long traverse
            base   = goto_um(stage, i, centre)
            landed = goto_um(stage, i, centre + fine)
            push!(step_err, (landed - base) - fine)
        end
        summarise("$name fine step after traverse", step_err)

        # Bidirectional repeatability at one target.
        from_below = Float64[]
        from_above = Float64[]
        for _ in 1:N_REPEATS
            goto_um(stage, i, lo)
            push!(from_below, goto_um(stage, i, centre))
            goto_um(stage, i, hi)
            push!(from_above, goto_um(stage, i, centre))
        end
        summarise("$name repeatability from below", from_below .- centre)
        summarise("$name repeatability from above", from_above .- centre)
        @printf("  %-34s %+8.4f µm\n", "$name directional bias",
                mean(from_below) - mean(from_above))
    end
end

# ---------------------------------------------------------------------------
# Runner

"""
    setup_stage(; reference = false) -> stage

Opens the stage and puts it in a state where the tests mean something:
referencing verified, and the controller's volatile range limits rewritten
from the rig's safe window.

Both referencing and the range limits are **volatile** — a power cycle clears
them — so a fresh session normally finds `is_referenced == false` and limits
of 0/0.

`reference = true` homes any connected axis that is not yet referenced.
It is opt-in because referencing *moves the stage*: `find_reference!` drives
forward until it finds the reference mark, and if the mark lies behind the
current position that search runs into the end stop instead. On this rig that
is not harmless — see `dev/smaract_bringup.md` on end-stop creep. Reference
from somewhere near mid-travel, or jog clear first.

Exported separately from `main` so a single test can be run from the REPL
without hand-repeating the setup — and without the limits being left at
whatever the previous session wrote. Remember to `teardown` afterwards: the
MCS2 allows only one open connection.
"""
function setup_stage(; reference::Bool = false)
    stage = MCS2Stage(stagelabel = "SmarAct MCS2",
                      n_channels = 3, channel_ids = Int32[0, 1, 2])
    initialize(stage)

    try
        # An unreferenced channel reports positions against an arbitrary zero,
        # so every number below would be meaningless. Refuse, don't produce it.
        for (i, name) in AXES
            stage.connected[i] || continue
            stage.is_referenced[i] && continue

            # Don't home behind the caller's back — moving the stage is their
            # call to make, and the search direction may be into the end stop.
            reference ||
                error("Axis $name (channel $(stage.channel_ids[i])) is not referenced, " *
                      "so its positions are against an arbitrary zero and nothing " *
                      "measured would be meaningful.\n" *
                      "Referencing moves the stage. When the stage is clear of its " *
                      "end stops, re-run with:\n" *
                      "    setup_stage(reference = true)\n" *
                      "or, from a script:  julia --project dev/test_smaract_motion.jl --reference")

            M.find_reference!(stage, i)
        end

        # Range limits are volatile and initialize! only reads them, so
        # whatever the last session wrote is still in the controller. Write the
        # safe window now, so the controller refuses an out-of-range move even
        # if something here asks for one.
        println("Establishing controller range limits from the rig's safe window ...")
        for (i, _) in AXES
            stage.connected[i] || continue
            lo_pm, hi_pm = rig_window_pm(rig_axis(i))
            M.set_range_limits!(stage, i, lo_pm, hi_pm)
        end
    catch
        shutdown(stage)   # don't leak the handle if setup fails
        rethrow()
    end
    return stage
end

"Return the stage to `start_pm` and close the device."
function teardown(stage, start_pm = nothing)
    try
        if start_pm !== nothing
            println("\nReturning to starting position ...")
            M.move_all!(stage, start_pm)
            M.query_positions!(stage)
        end
    finally
        shutdown(stage)
    end
end

function main(which; reference::Bool = false)
    stage = setup_stage(; reference = reference)
    start = copy(stage.pos_pm)
    try
        "long"     in which && test_long_range(stage)
        "small"    in which && test_small_range(stage)
        "combined" in which && test_combined(stage)
    finally
        teardown(stage, start)
    end
end

# Only run when executed as a script. `include`ing this file from a REPL
# defines the functions and runs nothing, so a single test can be driven by
# hand:
#
#   include("dev/test_smaract_motion.jl")
#   stage = setup_stage()            # add reference = true on a fresh power-up
#   start = copy(stage.pos_pm)
#   test_small_range(stage)
#   teardown(stage, start)
#
if abspath(PROGRAM_FILE) == @__FILE__
    args      = copy(ARGS)
    reference = "--reference" in args
    filter!(a -> a != "--reference", args)

    which = isempty(args) ? ["long", "small", "combined"] : args
    valid = ["long", "small", "combined"]
    bad   = setdiff(which, valid)
    isempty(bad) || error("Unknown test(s): $(join(bad, ", ")). " *
                          "Choose from: $(join(valid, ", ")), plus the --reference flag.")
    main(which; reference = reference)
end
