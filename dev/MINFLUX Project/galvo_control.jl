# galvo_control.jl
# A minimal, standalone reference for driving the galvo mirrors through the Triggerscope4.
# No camera, no GUI, no calibration matrix — just the raw voltage calls, extracted from
# the same pattern used in laser_tracking.jl / galvo_calibration.jl.
#
# Channel convention (matches the rest of the MINFLUX project scripts):
#   DAC channel 1 -> X galvo
#   DAC channel 2 -> Y galvo

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

# ── Setup ────────────────────────────────────────────────────────────────────
# Sets both channels to a known voltage range and zeroes them.
# Call this once after `initialize(scope)`.
function setup_galvos(scope::Triggerscope4; range::Range = PLUSMINUS10)
    sleep(2)  # Triggerscope resets on port open (Arduino DTR reset) and needs time to boot before it responds
    clearall(scope)
    setrange(scope, 1, range)
    setrange(scope, 2, range)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
end

# ── Move ─────────────────────────────────────────────────────────────────────
# Sets the X and Y galvo voltages directly. Voltages must be within the range
# passed to setup_galvos (default ±10 V).
function move_galvo(scope::Triggerscope4, x_volts::Float64, y_volts::Float64)
    setdac(scope, 1, x_volts)
    setdac(scope, 2, y_volts)
end

# Reset both galvos to their center (0 V) position.
function zero_galvos(scope::Triggerscope4)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
end

# ── Example: step through a small grid of positions ──────────────────────────
function example_grid_scan(scope::Triggerscope4; step::Float64 = 1.0, points::Int = 5, settle::Float64 = 0.2)
    half = (points - 1) / 2
    for i in 0:(points - 1), j in 0:(points - 1)
        x_volts = (i - half) * step
        y_volts = (j - half) * step
        move_galvo(scope, x_volts, y_volts)
        sleep(settle)
    end
    zero_galvos(scope)
end

# To run:
# scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)
# initialize(scope)
# setup_galvos(scope)
# move_galvo(scope, 2.0, -1.5)   # move to a specific voltage position
# zero_galvos(scope)
# example_grid_scan(scope)        # step through a small grid, then re-zero
# shutdown(scope)
