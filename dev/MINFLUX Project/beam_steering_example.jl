# beam_steering_example.jl
#
# Setting up and driving the galvo mirrors and the EOD through the package's
# beam-steering interface, over either the Triggerscope or the NI card.
#
# Three pieces, independent of each other:
#
#   backend      what physically puts the two voltages out   TriggerscopeBackend / DAQmxBackend
#   device       what you steer                              Galvo / EOD
#   calibration  how an angle becomes those voltages         AngleCalibration (2x2, mrad/V)
#
# Because they are independent, the control half of this file never mentions the
# Triggerscope or the NI card: the same setvoltage/setangle/gridscan calls drive any of
# the four combinations below. Moving the galvo from the Triggerscope to the NI card is a
# one-line change to the setup, and nothing downstream moves.
#
# This file deliberately does NOT include dev_helper_funcs.jl, so it loads and runs on its
# own. The camera is only needed to MEASURE a calibration, and that part takes the
# position-measuring function as an argument — see "Measuring the angle calibration" near
# the bottom, which shows how to pass the camera in.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope   # Triggerscope4, Range, MM_PROTOCOL

# ─────────────────────────────────────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────────────────────────────────────
# Each function below builds one device and returns it, not yet initialized. Call
# `initialize(dev)` when you are ready to claim the hardware; it parks both axes at 0 V.
#
# `xlimits`/`ylimits` are the voltages the device will refuse to go outside. They default
# to the full range the backend can produce; narrowing them is the cheap safety net, and
# it is worth doing — an out-of-range command throws before anything reaches the hardware.

# ── 1. Galvo on the Triggerscope ─────────────────────────────────────────────
# Wiring: Triggerscope DAC 1 -> galvo X, DAC 2 -> galvo Y (same convention as
# galvo_control.jl and the rest of the MINFLUX scripts).
#
# The DAC is 16 bit over the selected range, so the finest step it can address is
# range_span / 65535: about 305 uV on +/-10 V, about 76 uV on +/-2.5 V. Pick the narrowest
# range that still reaches the deflection you need and the steps get finer for free;
# `min_voltage_step(galvo.backend)` reports what you are actually getting.
#
# `owns_device = true` (the default) means initialize(galvo) opens the Triggerscope's
# serial port and shutdown(galvo) closes it. Pass `owns_device = false` if the same
# Triggerscope also drives TTLs or another DAC pair in your script and you are calling
# initialize(scope)/shutdown(scope) yourself — then the port must already be open.
function setup_galvo_triggerscope(;
    port::String="COM5",
    x_channel::Int=1,
    y_channel::Int=2,
    range::Range=PLUSMINUS10,
    volt_limit::Float64=2.0,
    calibration::AngleCalibration=AngleCalibration([1.0 0.0; 0.0 1.0]),
    owns_device::Bool=true)

    scope = Triggerscope4(portname=port, protocol=MM_PROTOCOL)
    backend = TriggerscopeBackend(scope;
        x_channel=x_channel, y_channel=y_channel, range=range, owns_device=owns_device)

    return Galvo(backend;
        calibration=calibration,
        xlimits=(-volt_limit, volt_limit),
        ylimits=(-volt_limit, volt_limit),
        unique_id="galvo (Triggerscope DAC $x_channel/$y_channel)")
end

# ── 2. Galvo on the NI card ──────────────────────────────────────────────────
# Wiring: Dev2/ao0 -> galvo X, Dev2/ao1 -> galvo Y.
#
# One NI analog-output task per axis is created and started by initialize(galvo) and held
# open until shutdown(galvo), so each move costs a single write rather than building and
# tearing down a task every time. That is what makes a scan usable.
function setup_galvo_nidaq(;
    x_channel::String="Dev2/ao0",
    y_channel::String="Dev2/ao1",
    volt_limit::Float64=2.0,
    calibration::AngleCalibration=AngleCalibration([1.0 0.0; 0.0 1.0]))

    backend = DAQmxBackend(x_channel, y_channel; vmin=-10.0, vmax=10.0)

    return Galvo(backend;
        calibration=calibration,
        xlimits=(-volt_limit, volt_limit),
        ylimits=(-volt_limit, volt_limit),
        unique_id="galvo (NI $x_channel/$y_channel)")
end

# ── 3. EOD on the NI card, through the HVA200 amplifiers ─────────────────────
# Wiring, from voltage_supply_beam_char.jl:
#   Dev2/ao0 -> HVA1 -> EOD X crystal      (monitor on Dev2/ai0)
#   Dev2/ao1 -> HVA2 -> EOD Y crystal      (monitor on Dev2/ai2)
# The HVA200 has a gain of 20 and inverts, which is why the monitor trace has to be
# negated and scaled by 20 to recover the real output. `amplifier_gain = 20.0` and
# `invert = true` tell the device that, so it can convert between the two.
#
# `daq_volt_limit` is in DAQ volts, because that is what actually gets written; 7.5 V in
# is 150 V on the crystal. `crystal_limits(eod)` prints the same bound the other way round.
#
# `calibration_basis` says which voltage the mrad/V matrix was measured against:
#   :crystal  the matrix is mrad per volt ACROSS THE CRYSTAL — this is what
#             compute_angle_calibration in angle_defle.jl produces, because it works from
#             the amplifier monitor
#   :daq      the matrix is mrad per volt OUT OF THE CARD
# Getting this wrong is a silent factor-of-20 error on every angle, which is why it is an
# explicit field rather than an assumption. The default is :crystal.
function setup_eod_nidaq(;
    x_channel::String="Dev2/ao0",
    y_channel::String="Dev2/ao1",
    mrad_per_crystal_volt::Float64=0.003,   # fabricator spec: 3 mrad/kV
    daq_volt_limit::Float64=7.5,            # 7.5 V in -> 150 V on the crystal
    amplifier_gain::Float64=20.0,
    invert::Bool=true)

    backend = DAQmxBackend(x_channel, y_channel; vmin=-10.0, vmax=10.0)

    return EOD(backend;
        calibration=AngleCalibration(mrad_per_volt_x=mrad_per_crystal_volt,
            mrad_per_volt_y=mrad_per_crystal_volt),
        calibration_basis=:crystal,
        amplifier_gain=amplifier_gain,
        invert=invert,
        xlimits=(-daq_volt_limit, daq_volt_limit),
        ylimits=(-daq_volt_limit, daq_volt_limit),
        unique_id="EOD (NI $x_channel/$y_channel, HVA200)")
end

# ── 4. EOD on the Triggerscope ───────────────────────────────────────────────
# Same EOD and same amplifiers, fed from two Triggerscope DAC channels instead of the NI
# card. Nothing about the device changes — only which object emits the volts.
#
# Note the range: the amplifier input limit, not the DAC's. At gain 20, +/-7.5 V in is
# +/-150 V on the crystal, so PLUSMINUS10 is the right DAC range and the device limits do
# the actual protecting.
function setup_eod_triggerscope(;
    port::String="COM5",
    x_channel::Int=3,
    y_channel::Int=4,
    mrad_per_crystal_volt::Float64=0.003,
    daq_volt_limit::Float64=7.5,
    owns_device::Bool=true)

    scope = Triggerscope4(portname=port, protocol=MM_PROTOCOL)
    backend = TriggerscopeBackend(scope;
        x_channel=x_channel, y_channel=y_channel, range=PLUSMINUS10, owns_device=owns_device)

    return EOD(backend;
        calibration=AngleCalibration(mrad_per_volt_x=mrad_per_crystal_volt,
            mrad_per_volt_y=mrad_per_crystal_volt),
        calibration_basis=:crystal,
        amplifier_gain=20.0,
        invert=true,
        xlimits=(-daq_volt_limit, daq_volt_limit),
        ylimits=(-daq_volt_limit, daq_volt_limit),
        unique_id="EOD (Triggerscope DAC $x_channel/$y_channel, HVA200)")
end

# ── Sharing one Triggerscope between the galvo and the EOD ───────────────────
# Two devices on the same board: build the Triggerscope4 once, hand it to both backends
# with `owns_device = false`, and manage the serial port yourself. Otherwise whichever
# device you shut down first closes the port out from under the other.
#
# Returns (scope, galvo, eod) — initialize(scope) first, then each device.
function setup_both_on_one_triggerscope(; port::String="COM5", volt_limit::Float64=2.0,
    daq_volt_limit::Float64=7.5)

    scope = Triggerscope4(portname=port, protocol=MM_PROTOCOL)

    galvo = Galvo(TriggerscopeBackend(scope; x_channel=1, y_channel=2,
            range=PLUSMINUS10, owns_device=false);
        xlimits=(-volt_limit, volt_limit), ylimits=(-volt_limit, volt_limit),
        unique_id="galvo (shared Triggerscope)")

    eod = EOD(TriggerscopeBackend(scope; x_channel=3, y_channel=4,
            range=PLUSMINUS10, owns_device=false);
        calibration=AngleCalibration(mrad_per_volt_x=0.003, mrad_per_volt_y=0.003),
        calibration_basis=:crystal, amplifier_gain=20.0, invert=true,
        xlimits=(-daq_volt_limit, daq_volt_limit),
        ylimits=(-daq_volt_limit, daq_volt_limit),
        unique_id="EOD (shared Triggerscope)")

    return scope, galvo, eod
end

# ─────────────────────────────────────────────────────────────────────────────
# CONTROL
# ─────────────────────────────────────────────────────────────────────────────
# Everything from here works on any BeamSteerer, over any backend.

# Walk through every control call against a live device and print what happens. Safe to
# run on either a Galvo or an EOD: it stays well inside the limits and returns to 0 V.
#
#     galvo = setup_galvo_triggerscope(); initialize(galvo); show_control(galvo)
function show_control(dev; step::Float64=0.05)
    println("─"^72)
    println(dev)
    println("  limits      : x $(dev.xlimits) V, y $(dev.ylimits) V")
    println("  calibration : ", dev.calibration.M, " mrad/V, offset ", dev.calibration.v_offset)

    # Voltage. This is the direct form; whatever the backend is, these are the volts it puts out.
    setvoltage(dev, step, -step)
    println("  setvoltage($step, $(-step))  -> getvoltage = ", getvoltage(dev))

    # Angle. Uses the device's AngleCalibration; with the default identity matrix the
    # numbers come out the same as volts, which is the sign you have not calibrated yet.
    setangle(dev, 0.0, 0.0)
    println("  setangle(0, 0)              -> getvoltage = ", getvoltage(dev),
        ", getangle = ", getangle(dev))

    # An EOD additionally speaks crystal volts, on the far side of the amplifier.
    if dev isa EOD
        println("  amplifier                   : gain $(dev.amplifier_gain), inverting=$(dev.invert)",
            " -> $(amplifier_factor(dev)) crystal V per DAQ V")
        println("  crystal_limits              : ", crystal_limits(dev), " V")
        setcrystalvoltage(dev, 20.0, 0.0)
        println("  setcrystalvoltage(20, 0)    -> DAQ ", getvoltage(dev),
            " V, crystal ", getcrystalvoltage(dev), " V")
    end

    # The finest step the hardware can actually resolve, where the backend knows it.
    if dev.backend isa TriggerscopeBackend
        println("  min_voltage_step            : ", min_voltage_step(dev.backend), " V")
    end

    # Out of range throws, and nothing is written — the device stays where it was.
    before = getvoltage(dev)
    try
        setvoltage(dev, 1e6, 0.0)
    catch e
        println("  setvoltage(1e6, 0)          -> refused: ", sprint(showerror, e))
    end
    @assert getvoltage(dev) == before "a refused command must not move the device"

    zeroaxes(dev)
    println("  zeroaxes                    -> ", getvoltage(dev))
    println("─"^72)
    return nothing
end

# ── Scanning ─────────────────────────────────────────────────────────────────
# gridscan walks a square grid, settling at each point, and puts the device back where it
# started. The whole grid is range-checked before the first move, so a scan that would run
# off the end fails immediately rather than halfway through.

# Plain sweep in volts, nothing recorded.
sweep_volts(dev; step=0.01, points=5, settle=0.2) =
    gridscan(dev, step, points; settle=settle)

# Sweep in milliradians of beam deflection. Needs a real calibration on the device.
sweep_angles(dev; step_mrad=0.05, points=5, settle=0.2) =
    gridscan(dev, step_mrad, points; units=:angle, settle=settle)

# Sweep and record something at every point. `measure` is called after the device has
# settled and its return value is collected, so this is where a camera frame, a monitor
# reading or a photon count goes.
#
#     scan_and_measure(galvo; measure = () -> find_beam_centroid(getlastframe(camera)'))
function scan_and_measure(dev; measure, step=0.01, points=5, settle=0.2, units=:volt)
    return gridscan(dev, step, points; units=units, settle=settle) do d, x, y
        (setpoint=(x, y), voltage=getvoltage(d), measured=measure())
    end
end

# The positions a scan will visit, without touching the hardware — useful for working out
# how long a scan will take, or for pre-allocating.
scan_positions(; step=0.01, points=5, center=(0.0, 0.0)) =
    gridpoints(step, points, center=center)

# ── Measuring the angle calibration ──────────────────────────────────────────
# Sweep each axis, watch where the beam lands, and convert displacement into mrad with the
# same trigonometry angle_defle.jl uses: theta = atan(displacement / distance).
#
# `measure_position` must return the beam position as (x, y) in camera pixels. Keeping it
# an argument is what lets this file stay camera-free; with the MINFLUX helpers loaded it
# is simply:
#
#     include("./dev_helper_funcs.jl")
#     measure = () -> find_beam_centroid(getlastframe(camera)')
#     cal, sweeps = measure_calibration(galvo, measure)
#     galvo.calibration = cal          # from here, setangle(galvo, ...) is in real mrad
#
# The off-diagonal entries of the result are the cross-coupling: how far the X voltage
# moves the beam along camera Y, and vice versa. A perfectly aligned pair has them near
# zero; a rotated mount does not, and that is exactly what the 2x2 form is for.
#
# For an EOD whose `calibration_basis` is `:crystal` (the default), sweep in crystal volts
# by passing `units = :crystal`, so the matrix comes out in mrad per crystal volt and
# matches what the device expects.
function measure_calibration(dev, measure_position;
    vmin::Float64=-1.0, vmax::Float64=1.0, steps::Int=11, settle::Float64=0.3,
    pixel_size_um::Float64=5.2, distance_mm::Float64=350.0, units::Symbol=:volt)

    units in (:volt, :crystal) || throw(ArgumentError("units must be :volt or :crystal"))
    set = if units === :crystal
        dev isa EOD || throw(ArgumentError("units = :crystal only applies to an EOD"))
        setcrystalvoltage
    else
        setvoltage
    end

    px_to_mrad(p) = atan(p * pixel_size_um * 1e-6 / (distance_mm * 1e-3)) * 1e3

    function sweep(axis::Symbol)
        volts = collect(range(vmin, vmax, length=steps))
        cx, cy = Float64[], Float64[]
        for v in volts
            axis === :x ? set(dev, v, 0.0) : set(dev, 0.0, v)
            sleep(settle)
            x, y = measure_position()
            push!(cx, x)
            push!(cy, y)
        end
        set(dev, 0.0, 0.0)
        dv = volts[end] - volts[1]
        return (volts=volts, cx=cx, cy=cy,
            mrad_x_per_volt=px_to_mrad(cx[end] - cx[1]) / dv,
            mrad_y_per_volt=px_to_mrad(cy[end] - cy[1]) / dv)
    end

    sx, sy = sweep(:x), sweep(:y)
    M = [sx.mrad_x_per_volt sy.mrad_x_per_volt;
        sx.mrad_y_per_volt sy.mrad_y_per_volt]

    @info "Measured angle calibration (mrad per $(units === :crystal ? "crystal" : "DAQ") volt)" M
    return AngleCalibration(M), (x=sx, y=sy)
end

# ─────────────────────────────────────────────────────────────────────────────
# To run
# ─────────────────────────────────────────────────────────────────────────────
#
# ── Galvo on the Triggerscope ────────────────────────────────────────────────
# galvo = setup_galvo_triggerscope(port = "COM5", volt_limit = 2.0)
# initialize(galvo)                 # opens the serial port, parks both axes at 0 V
# show_control(galvo)               # every control call, printed
#
# setvoltage(galvo, 0.2, -0.2)
# getvoltage(galvo)
# zeroaxes(galvo)
# sweep_volts(galvo, step = min_voltage_step(galvo.backend), points = 5)   # finest grid the DAC can address
# shutdown(galvo)                   # parks at 0 V, then closes the port
#
# ── The same galvo on the NI card ────────────────────────────────────────────
# Only this line differs; every call above works unchanged.
# galvo = setup_galvo_nidaq(x_channel = "Dev2/ao0", y_channel = "Dev2/ao1")
#
# ── EOD on the NI card, through the HVA200 ───────────────────────────────────
# eod = setup_eod_nidaq(daq_volt_limit = 7.5)
# initialize(eod)
# setvoltage(eod, 2.0, 0.0)         # 2 V out of the card
# setcrystalvoltage(eod, 100.0, 0.0) # 100 V across the crystal -> -5 V out of the card
# getcrystalvoltage(eod)
# crystal_limits(eod)               # the DAQ limits, expressed across the crystal
# setangle(eod, 0.3, 0.0)           # 0.3 mrad, via the :crystal-basis calibration
# sweep_angles(eod, step_mrad = 0.05, points = 5)
# shutdown(eod)
#
# ── EOD on the Triggerscope instead ──────────────────────────────────────────
# eod = setup_eod_triggerscope(port = "COM5", x_channel = 3, y_channel = 4)
#
# ── Both on one Triggerscope ─────────────────────────────────────────────────
# scope, galvo, eod = setup_both_on_one_triggerscope(port = "COM5")
# initialize(scope)                 # you own the port now, not the devices
# initialize(galvo); initialize(eod)
# setvoltage(galvo, 0.1, 0.1); setcrystalvoltage(eod, 50.0, 0.0)
# shutdown(galvo); shutdown(eod)
# shutdown(scope)
#
# ── Calibrating, with a camera ───────────────────────────────────────────────
# include("./dev_helper_funcs.jl")          # see the note at the top of this file
# camera = ThorcamDCXCamera(); initialize(camera); live(camera)
# measure = () -> find_beam_centroid(getlastframe(camera)')
# cal, sweeps = measure_calibration(galvo, measure; vmin = -1.0, vmax = 1.0)
# galvo.calibration = cal
# setangle(galvo, 0.5, 0.0)                 # now in real milliradians
#
# tracked = scan_and_measure(galvo; measure = measure, step = 0.05, points = 5)
#
# ── Saving the state alongside your data ─────────────────────────────────────
# attrs, data, children = export_state(eod)   # voltages, angles, limits, calibration, gain
# save_h5("run.h5", export_state(eod))
