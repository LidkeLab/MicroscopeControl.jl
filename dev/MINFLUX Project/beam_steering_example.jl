# beam_steering_example.jl
# How to drive the galvo mirrors and the EOD through the package's beam-steering
# interface, instead of writing raw DAC calls the way galvo_control.jl does.
#
# The point of the interface is that these three things are independent:
#
#   backend      what actually puts the two voltages out   TriggerscopeBackend / DAQmxBackend
#   device       what you steer                            Galvo / EOD
#   calibration  how an angle becomes those voltages       AngleCalibration (2x2, mrad/V)
#
# so the same experiment code runs whether the mirrors hang off the Triggerscope or an NI
# card, and whether you think in volts or in milliradians. Everything below is a function
# you can call from your own script; the "To run" block at the bottom has the sequence.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./dev_helper_funcs.jl")

# ── Galvo on the Triggerscope ────────────────────────────────────────────────
# Channel convention matches the rest of the MINFLUX scripts: DAC 1 is X, DAC 2 is Y.
#
# `owns_device = true` means initialize(galvo) opens the Triggerscope's serial port and
# shutdown(galvo) closes it. Set it to false if the same Triggerscope is also driving
# something else in your script and you are calling initialize(scope) yourself.
function make_galvo(; port::String = "COM5",
                      x_channel::Int = 1,
                      y_channel::Int = 2,
                      range::Range = PLUSMINUS10,
                      calibration::AngleCalibration = AngleCalibration([1.0 0.0; 0.0 1.0]),
                      volt_limit::Float64 = 2.0)

    scope = Triggerscope4(portname = port, protocol = MM_PROTOCOL)
    backend = TriggerscopeBackend(scope; x_channel = x_channel, y_channel = y_channel, range = range)

    # Limits default to the full DAC range. Narrowing them to the span you actually use
    # means a typo or a runaway scan throws instead of slamming the mirrors to the rail.
    return Galvo(backend;
        calibration = calibration,
        xlimits = (-volt_limit, volt_limit),
        ylimits = (-volt_limit, volt_limit),
        unique_id = "MINFLUX galvo")
end

# ── Galvo on the NI card ─────────────────────────────────────────────────────
# Same device, same calls, different backend — nothing downstream changes.
function make_galvo_nidaq(; x_channel::String = "Dev2/ao0",
                            y_channel::String = "Dev2/ao1",
                            calibration::AngleCalibration = AngleCalibration([1.0 0.0; 0.0 1.0]),
                            volt_limit::Float64 = 2.0)

    backend = DAQmxBackend(x_channel, y_channel; vmin = -10.0, vmax = 10.0)
    return Galvo(backend;
        calibration = calibration,
        xlimits = (-volt_limit, volt_limit),
        ylimits = (-volt_limit, volt_limit),
        unique_id = "MINFLUX galvo (NI)")
end

# ── EOD on the NI card, through the HVA200 amplifiers ────────────────────────
# Port map from voltage_supply_beam_char.jl: AO0 -> HVA1, AO1 -> HVA2, gain 20, inverting
# (which is why the monitor trace has to be negated and scaled by 20 to recover the real
# output voltage).
#
# `calibration_basis = :crystal` says the mrad/V matrix was measured against the real
# high voltage — which is what compute_angle_calibration in angle_defle.jl produces,
# since it works from the monitor. Passing :daq there instead would be wrong by the
# factor of 20, silently, on every angle.
function make_eod(; x_channel::String = "Dev2/ao0",
                    y_channel::String = "Dev2/ao1",
                    mrad_per_crystal_volt::Float64 = 0.003,   # fabricator spec: 3 mrad/kV
                    daq_volt_limit::Float64 = 7.5)            # 7.5 V in -> 150 V on the crystal

    backend = DAQmxBackend(x_channel, y_channel; vmin = -10.0, vmax = 10.0)
    return EOD(backend;
        calibration = AngleCalibration(mrad_per_volt_x = mrad_per_crystal_volt,
                                       mrad_per_volt_y = mrad_per_crystal_volt),
        calibration_basis = :crystal,
        amplifier_gain = 20.0,
        invert = true,
        xlimits = (-daq_volt_limit, daq_volt_limit),
        ylimits = (-daq_volt_limit, daq_volt_limit),
        unique_id = "MINFLUX EOD")
end

# ── Measuring the angle calibration ──────────────────────────────────────────
# Sweep one axis, watch the beam move on the camera, and turn displacement into mrad/V
# with the same trigonometry angle_defle.jl uses: theta = atan(displacement / distance).
#
# This fills in one column of the 2x2 matrix per call — sweep X to get how X voltage moves
# the beam in both directions, then sweep Y. `calibrate_angle_matrix` below does both and
# assembles the matrix.
#
# `voltage_basis` must match how you will later set `calibration_basis` on the device: pass
# :crystal and crystal volts for an EOD whose calibration you want in mrad per crystal volt.
function sweep_axis(dev, camera, axis::Symbol;
                    vmin::Float64, vmax::Float64, steps::Int = 11,
                    settle::Float64 = 0.3,
                    pixel_size_um::Float64 = 5.2,
                    distance_mm::Float64 = 350.0)

    axis in (:x, :y) || throw(ArgumentError("axis must be :x or :y, got :$axis"))

    volts = collect(range(vmin, vmax, length = steps))
    cx = Float64[]
    cy = Float64[]

    for v in volts
        axis === :x ? setvoltage(dev, v, 0.0) : setvoltage(dev, 0.0, v)
        sleep(settle)
        x, y = find_beam_centroid(getlastframe(camera)')
        push!(cx, x)
        push!(cy, y)
    end
    setvoltage(dev, 0.0, 0.0)

    # mrad of beam deflection per volt, in each camera direction
    px_to_mrad = p -> atan(p * pixel_size_um * 1e-6 / (distance_mm * 1e-3)) * 1e3
    dv = volts[end] - volts[1]
    mrad_x_per_volt = px_to_mrad(cx[end] - cx[1]) / dv
    mrad_y_per_volt = px_to_mrad(cy[end] - cy[1]) / dv

    return (volts = volts, centers_x = cx, centers_y = cy,
            mrad_x_per_volt = mrad_x_per_volt, mrad_y_per_volt = mrad_y_per_volt)
end

# Sweep both axes and assemble the 2x2 mrad/V matrix. The off-diagonal entries are the
# cross-coupling: how much the X voltage moves the beam along camera Y, and vice versa.
function calibrate_angle_matrix(dev, camera; vmin::Float64 = -1.0, vmax::Float64 = 1.0,
                                steps::Int = 11, settle::Float64 = 0.3,
                                pixel_size_um::Float64 = 5.2, distance_mm::Float64 = 350.0)

    kw = (steps = steps, settle = settle, pixel_size_um = pixel_size_um, distance_mm = distance_mm)
    sx = sweep_axis(dev, camera, :x; vmin = vmin, vmax = vmax, kw...)
    sy = sweep_axis(dev, camera, :y; vmin = vmin, vmax = vmax, kw...)

    M = [sx.mrad_x_per_volt  sy.mrad_x_per_volt;
         sx.mrad_y_per_volt  sy.mrad_y_per_volt]

    @info "Measured angle calibration (mrad per volt)" M
    return AngleCalibration(M), (x = sx, y = sy)
end

# ── Scanning ─────────────────────────────────────────────────────────────────
# gridscan walks a square grid and hands each position to your callback after it settles.
# This is the replacement for example_grid_scan in galvo_control.jl, and it works in angle
# as well as in volts.

# Step through a grid in volts and keep the beam centroid at each point.
function scan_and_track(dev, camera; step::Float64 = 0.05, points::Int = 5, settle::Float64 = 0.2)
    return gridscan(dev, step, points; settle = settle) do d, vx, vy
        (voltage = (vx, vy), center = find_beam_centroid(getlastframe(camera)'))
    end
end

# Same, but the grid is specified in milliradians of beam deflection. Needs a real
# calibration on the device — with the default identity matrix this is just volts again.
function scan_angles(dev, camera; step_mrad::Float64 = 0.05, points::Int = 5, settle::Float64 = 0.2)
    return gridscan(dev, step_mrad, points; units = :angle, settle = settle) do d, ax, ay
        (angle_mrad = (ax, ay), voltage = getvoltage(d),
         center = find_beam_centroid(getlastframe(camera)'))
    end
end

# The finest step worth asking a Triggerscope-backed device for: anything smaller rounds
# to the voltage the 16-bit DAC is already at.
finest_step(dev) = min_voltage_step(dev.backend)

# ── Live view ────────────────────────────────────────────────────────────────
# Same live camera window as galvo_control.jl, with a marker on the beam centre, so you
# can watch the device move as you call setvoltage/setangle by hand.
function live_steering_view(camera; frame_rate::Float64 = 30.0, exposure_time::Real = 0.01,
                            window_size::Tuple{Int,Int} = (1400, 1050))

    fig, ax, frame_obs = live_camera_display(camera; frame_rate = frame_rate,
        exposure_time = exposure_time, window_size = window_size)

    center_x = Observable(0.0)
    center_y = Observable(0.0)
    scatter!(ax, center_x, center_y, color = :teal, markersize = 10)

    @async begin
        while Bool(camera.is_running) == 1
            center_x[], center_y[] = find_beam_centroid(frame_obs[])
            sleep(1 / frame_rate)
        end
    end

    return fig, ax, frame_obs
end

# ── To run ───────────────────────────────────────────────────────────────────
#
# GALVO, on the Triggerscope:
#
# galvo = make_galvo(port = "COM5", volt_limit = 2.0)
# initialize(galvo)                      # opens the serial port and parks both axes at 0 V
# camera = ThorcamDCXCamera()
# fig, ax, frame_obs = live_steering_view(camera)    # keep this window open while you work
#
# setvoltage(galvo, 0.2, -0.2)           # volts, as before
# zeroaxes(galvo)                        # back to 0 V
# getvoltage(galvo)                      # what was last commanded
# gridscan(galvo, finest_step(galvo), 5; settle = 0.2)    # finest grid the DAC can address
# tracked = scan_and_track(galvo, camera; step = 0.05, points = 5)
#
# # measure the calibration, then steer in milliradians
# cal, sweeps = calibrate_angle_matrix(galvo, camera; vmin = -1.0, vmax = 1.0)
# galvo.calibration = cal
# setangle(galvo, 0.5, 0.0)              # 0.5 mrad on X
# getangle(galvo)
# scan_angles(galvo, camera; step_mrad = 0.05, points = 5)
#
# shutdown(galvo)
# shutdown(camera)                       # or just close the live view window
#
# The same galvo on the NI card instead — every line after this one is identical:
# galvo = make_galvo_nidaq(x_channel = "Dev2/ao0", y_channel = "Dev2/ao1")
#
# EOD, through the HVA200 pair:
#
# eod = make_eod(daq_volt_limit = 7.5)
# initialize(eod)
# setvoltage(eod, 2.0, 0.0)              # 2 V out of the DAQ
# setcrystalvoltage(eod, 100.0, 0.0)     # 100 V across the crystal -> -5 V out of the DAQ
# getcrystalvoltage(eod)
# crystal_limits(eod)                    # the DAQ limits, in crystal volts
# setangle(eod, 0.3, 0.0)                # 0.3 mrad, via the :crystal-basis calibration
# gridscan(eod, 0.05, 5; units = :angle, settle = 0.3)
# shutdown(eod)
#
# Out-of-range commands throw before anything reaches the hardware, and say what the
# command worked out to:
#
#   setangle(eod, 50.0, 0.0)
#   ERROR: ArgumentError: MINFLUX EOD: angle (50.0, 0.0) mrad needs (-833.3333, 0.0) V
#   out of the DAQ (crystal basis), which is out of range. ...
#
# Saving the state alongside your data:
#
# attrs, data, children = export_state(eod)   # voltages, angles, limits, calibration, gain
