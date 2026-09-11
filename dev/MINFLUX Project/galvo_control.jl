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
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./dev_helper_funcs.jl")

# ── Live view ────────────────────────────────────────────────────────────────
# Simple brightest-pixel finder — enough to show where the beam is without pulling in
# the full donut/Gaussian fitting from beam_characterization.jl.
find_beam_center(frame) = (peak = argmax(frame); (Float64(peak[1]), Float64(peak[2])))

# Opens a live camera feed with a beam-center marker so you can watch the galvo move
# as you call move_galvo/zero_galvos/example_grid_scan. Reuses live_camera_display from
# dev_helper_funcs.jl (same as galvo_calibration_gui). Closing the window shuts the camera
# down — don't close it until you're done driving the galvo with this camera.
function live_galvo_view(camera; frame_rate::Float64 = 30.0, exposure_time::Real = 0.01, window_size::Tuple{Int,Int} = (1400, 1050))
    fig, ax, frame_obs = live_camera_display(camera; frame_rate = frame_rate, exposure_time = exposure_time, window_size = window_size)

    center_x = Observable(0.0)
    center_y = Observable(0.0)
    scatter!(ax, center_x, center_y, color = :teal, markersize = 10)

    @async begin
        while Bool(camera.is_running) == 1
            center_x[], center_y[] = find_beam_center(frame_obs[])
            sleep(1 / frame_rate)
        end
    end

    return fig, ax, frame_obs
end

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
# Smallest voltage increment the 16-bit DAC can actually address for a given channel's
# currently-set range (e.g. ~305 uV for the default PLUSMINUS10; ~76 uV for PLUSMINUS2_5).
function min_voltage_step(scope::Triggerscope4, channel::Int)
    span = Dict(
        PLUSMINUS10  => 20.0,
        PLUSMINUS5   => 10.0,
        ZEROTOTEN    => 10.0,
        ZEROTOFIVE   => 5.0,
        PLUSMINUS2_5 => 5.0,
    )[scope.dacranges[channel]]
    return span / 65535
end

# step defaults to the finest step the DAC can address (see min_voltage_step) — pass a
# larger value if you want bigger jumps.
function example_grid_scan(scope::Triggerscope4; step::Union{Float64,Nothing} = nothing, points::Int = 5, settle::Float64 = 0.2)
    step = step === nothing ? min_voltage_step(scope, 1) : step
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
# camera = ThorcamDCXCamera()
# fig, ax, frame_obs = live_galvo_view(camera)   # opens the live view; keep this window open
# move_galvo(scope, .2, -.2)   # move to a specific voltage position, watch it in the live view
# zero_galvos(scope)    
# example_grid_scan(scope)        # step through a small grid at the finest addressable voltage step
# example_grid_scan(scope, step = 0.001)          # or force a specific step size, e.g. 1 mV
# setup_galvos(scope, range = PLUSMINUS2_5); example_grid_scan(scope)  # switch to a narrower range for an even finer step (~76 uV vs ~305 uV)
# shutdown(scope)
# shutdown(camera)                # or just close the live view window, which does this for you
