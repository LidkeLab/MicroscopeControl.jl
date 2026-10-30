# Beam steering: the BeamSteerer interface, the Galvo and EOD devices, and the
# voltage/angle/scan arithmetic they share. Runs against RecordingBackend (see
# beam_steering_fake_backend.jl), so none of this needs hardware.

const MC = MicroscopeControl

@testset "Beam Steering" begin

    @testset "AngleCalibration" begin
        @test_throws ArgumentError AngleCalibration([1.0 0.0 0.0; 0.0 1.0 0.0])
        @test_throws ArgumentError AngleCalibration([1.0 2.0; 2.0 4.0])   # singular

        cal = AngleCalibration(mrad_per_volt_x=0.5, mrad_per_volt_y=0.25)
        @test MC.voltage_to_angle(cal, 2.0, 4.0) == (1.0, 1.0)
        @test MC.angle_to_voltage(cal, 1.0, 1.0) == (2.0, 4.0)

        # round trip with cross-coupling and a non-zero rest point
        c2 = AngleCalibration([0.451 0.012; -0.008 0.423], v_offset=[0.13, -0.05])
        vx, vy = MC.angle_to_voltage(c2, MC.voltage_to_angle(c2, 1.7, -2.3)...)
        @test vx ≈ 1.7 && vy ≈ -2.3
        @test MC.angle_to_voltage(c2, 0.0, 0.0) == (0.13, -0.05)
    end

    @testset "Galvo" begin
        b = RecordingBackend()
        galvo = Galvo(b, calibration=AngleCalibration(mrad_per_volt_x=0.5, mrad_per_volt_y=0.5),
            xlimits=(-2.0, 2.0), ylimits=(-2.0, 2.0), unique_id="TestGalvo")

        @test galvo isa BeamSteerer
        @test_throws ArgumentError setvoltage(galvo, 0.1, 0.1)   # not initialized yet

        @test initialize(galvo) === nothing
        @test getvoltage(galvo) == (0.0, 0.0)

        setvoltage(galvo, 1.5, -1.5)
        @test getvoltage(galvo) == (1.5, -1.5)
        @test b.writes[end] == (1.5, -1.5)

        # out of range throws and writes nothing
        n = length(b.writes)
        @test_throws ArgumentError setvoltage(galvo, 2.5, 0.0)
        @test length(b.writes) == n
        @test getvoltage(galvo) == (1.5, -1.5)

        setangle(galvo, 0.5, -0.5)
        @test getvoltage(galvo) == (1.0, -1.0)
        @test all(isapprox.(getangle(galvo), (0.5, -0.5)))
        @test_throws ArgumentError setangle(galvo, 1.5, 0.0)   # needs 3 V

        zeroaxes(galvo)
        @test getvoltage(galvo) == (0.0, 0.0)

        attrs, data, children = export_state(galvo)
        @test attrs["unique_id"] == "TestGalvo"
        @test attrs["calibration_matrix"] == [0.5 0.0; 0.0 0.5]

        @test shutdown(galvo) === nothing
        @test b.closed == 1
    end

    @testset "Scans" begin
        @test length(MC.gridpoints(1.0, 3)) == 9
        @test MC.gridpoints(1.0, 1) == [(0.0, 0.0)]
        @test_throws ArgumentError MC.gridpoints(1.0, 0)

        b = RecordingBackend()
        galvo = Galvo(b, xlimits=(-2.0, 2.0), ylimits=(-2.0, 2.0))
        initialize(galvo)
        setvoltage(galvo, 0.5, 0.5)

        visited = gridscan(galvo, 0.1, 3; settle=0.0)
        @test length(visited) == 9
        @test getvoltage(galvo) == (0.5, 0.5)   # returned to where it started

        out = gridscan(galvo, 0.1, 2; settle=0.0) do dev, x, y
            x + y
        end
        @test length(out) == 4 && eltype(out) == Float64

        # a grid that would run off the end fails before moving
        n = length(b.writes)
        @test_throws ArgumentError gridscan(galvo, 10.0, 3; settle=0.0)
        @test length(b.writes) == n
        @test_throws ArgumentError gridscan(galvo, 0.1, 3; units=:nonsense, settle=0.0)
    end

    @testset "EOD amplifier" begin
        eod = EOD(RecordingBackend(), amplifier_gain=20.0, invert=true, max_crystal_volts=150.0,
            xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
        initialize(eod)

        @test eod isa BeamSteerer
        @test MC.amplifier_factor(eod) == -20.0
        @test MC.tocrystal(eod, 5.0) == -100.0
        @test MC.todaq(eod, 100.0) == -5.0

        setcrystalvoltage(eod, 100.0, -40.0)
        @test getvoltage(eod) == (-5.0, 2.0)
        @test all(isapprox.(getcrystalvoltage(eod), (100.0, -40.0)))

        # an inverting amplifier swaps the ends of the range
        @test MC.crystal_limits(eod)[1] == (-150.0, 150.0)

        before = getvoltage(eod)
        @test_throws ArgumentError setcrystalvoltage(eod, 1000.0, 0.0)
        @test getvoltage(eod) == before

        @test_throws ArgumentError EOD(RecordingBackend(), calibration_basis=:bogus, max_crystal_volts=150.0)
        @test_throws ArgumentError EOD(RecordingBackend(), amplifier_gain=0, max_crystal_volts=150.0)
    end

    @testset "EOD angle basis" begin
        # The same matrix means different things depending on which voltage it was
        # measured against; getting it wrong is an error of the amplifier gain.
        cal = AngleCalibration(mrad_per_volt_x=0.003, mrad_per_volt_y=0.003)

        crystal = EOD(RecordingBackend(), calibration=cal, calibration_basis=:crystal,
            amplifier_gain=20.0, invert=true, max_crystal_volts=150.0, xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
        initialize(crystal)
        setangle(crystal, 0.3, 0.0)
        @test all(isapprox.(getvoltage(crystal), (-5.0, 0.0)))     # 100 crystal V
        @test all(isapprox.(getangle(crystal), (0.3, 0.0)))

        daqbasis = EOD(RecordingBackend(), calibration=cal, calibration_basis=:daq,
            amplifier_gain=20.0, invert=true, max_crystal_volts=150.0, xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
        initialize(daqbasis)
        setvoltage(daqbasis, 5.0, 0.0)
        @test all(isapprox.(getangle(daqbasis), (0.015, 0.0)))

        # gridscan's pre-flight check has to land on DAQ volts for an EOD too: 0.1 mrad
        # is 33.3 crystal V but only 1.67 DAQ V, which is inside the limit.
        setvoltage(crystal, 0.0, 0.0)
        @test length(gridscan(crystal, 0.1, 3; units=:angle, settle=0.0)) == 9
        @test_throws ArgumentError gridscan(crystal, 1.0, 5; units=:angle, settle=0.0)

        setvoltage(crystal, 5.0, 0.0)
        attrs, _, _ = export_state(crystal)
        @test attrs["amplifier_gain"] == 20.0
        @test attrs["calibration_basis"] == "crystal"
        @test isapprox(attrs["crystal_voltage_x"], -100.0)
    end

    @testset "Backends" begin
        # Range table: pure arithmetic, no device of any kind.
        @test MC.rangelimits(PLUSMINUS10) == (-10.0, 10.0)
        @test MC.rangelimits(PLUSMINUS2_5) == (-2.5, 2.5)
        @test MC.rangelimits(ZEROTOFIVE) == (0.0, 5.0)

        # The NI backend is constructed without touching a card: it only records the
        # channel names, and its tasks are created by initialize, so writing before that
        # is refused rather than reaching NI-DAQmx.
        daq = DAQmxBackend("Dev2/ao0", "Dev2/ao1"; vmin=-10.0, vmax=10.0)
        @test BeamSteeringInterface.backend_limits(daq) == ((-10.0, 10.0), (-10.0, 10.0))
        @test_throws ArgumentError BeamSteeringInterface.write_voltages!(daq, 1.0, 1.0)
        @test_throws ArgumentError DAQmxBackend("Dev2/ao0", "Dev2/ao0")
        @test_throws ArgumentError DAQmxBackend("Dev2/ao0", "Dev2/ao1"; vmin=5.0, vmax=-5.0)

        # Triggerscope4's constructor builds a LibSerialPort.SerialPort eagerly, which
        # throws SP_ERR_ARG where the named port does not exist -- so a machine with no
        # serial port (CI) cannot construct one at all, while Windows happens to accept a
        # name for a port that is not there. Everything above this point is therefore
        # unconditional and the rest is skipped where no port can be opened.
        scope = try
            Triggerscope4()
        catch e
            @info "No serial port available; skipping the Triggerscope backend checks" exception = e
            nothing
        end

        if scope !== nothing
            # 16-bit DAC: the finest addressable step is the range span / 65535.
            @test isapprox(MC.min_voltage_step(TriggerscopeBackend(scope; range=PLUSMINUS10)), 20.0 / 65535)
            @test isapprox(MC.min_voltage_step(TriggerscopeBackend(scope; range=PLUSMINUS2_5)), 5.0 / 65535)

            @test BeamSteeringInterface.backend_limits(
                TriggerscopeBackend(scope; range=PLUSMINUS5)) == ((-5.0, 5.0), (-5.0, 5.0))
            @test_throws ArgumentError TriggerscopeBackend(scope; x_channel=3, y_channel=3)
            @test_throws ArgumentError TriggerscopeBackend(scope; x_channel=99)
        end
    end
end

@testset "Beam steering stubs throw" begin
    bare = _BareBackend()
    @test_throws "not implemented" BeamSteeringInterface.write_voltages!(bare, 0.0, 0.0)
    @test_throws "not implemented" BeamSteeringInterface.openbackend!(bare)
    @test_throws "not implemented" BeamSteeringInterface.closebackend!(bare)
    # A backend that cannot report its range must be given explicit limits rather than
    # silently defaulting to something the hardware may not be able to produce.
    @test BeamSteeringInterface.backend_limits(bare) === nothing
    @test_throws ArgumentError Galvo(bare)
end

@testset "EOD negative zero" begin
    # An inverting amplifier turns a commanded 0 V into -0.0, which displays as "-0.0 V"
    # and gets saved that way. The conversions normalise it.
    eod = EOD(RecordingBackend(), amplifier_gain=20.0, invert=true, max_crystal_volts=150.0,
        xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
    initialize(eod)
    @test !signbit(MC.tocrystal(eod, 0.0))
    @test !signbit(MC.todaq(eod, 0.0))
    @test all(!signbit, getcrystalvoltage(eod))
    attrs, _, _ = export_state(eod)
    @test !signbit(attrs["crystal_voltage_x"])
    # the sign of a real value is of course untouched
    @test MC.tocrystal(eod, 1.0) == -20.0
    @test MC.todaq(eod, -20.0) == 1.0
end

@testset "Beam steering limits" begin
    # An explicit limit the backend cannot produce is refused, not warned about: on a
    # Triggerscope it would go out as a DAC code outside the 16-bit protocol.
    @test_throws ArgumentError Galvo(RecordingBackend(), xlimits=(-11.0, 2.0), ylimits=(-2.0, 2.0))
    @test_throws ArgumentError Galvo(RecordingBackend(), xlimits=(-2.0, 2.0), ylimits=(-2.0, 10.5))
    @test_throws ArgumentError Galvo(RecordingBackend(), xlimits=(2.0, -2.0))
    @test Galvo(RecordingBackend()).xlimits == (-10.0, 10.0)

    # A quantizing backend's limits move inward onto its grid, so rounding a command to the
    # nearest code cannot cross a limit. One narrower than a step holds nothing and throws.
    g = Galvo(QuantizedBackend(), xlimits=(-1.1, 1.1), ylimits=(-2.0, 2.0))
    @test g.xlimits == (-1.0, 1.0)
    @test g.ylimits == (-2.0, 2.0)
    @test_throws ArgumentError Galvo(QuantizedBackend(), xlimits=(0.05, 0.2))
end

@testset "EOD crystal ceiling" begin
    # Required: the backend's ±10 V would otherwise be ±200 V on the crystal at gain 20.
    @test_throws ArgumentError EOD(RecordingBackend())
    @test_throws ArgumentError EOD(RecordingBackend(), max_crystal_volts=0.0)
    @test_throws ArgumentError EOD(RecordingBackend(), max_crystal_volts=-150.0)

    # Omitted limits are the backend range narrowed to the ceiling, in DAQ volts.
    eod = EOD(RecordingBackend(), amplifier_gain=20.0, invert=true, max_crystal_volts=150.0)
    @test eod.xlimits == (-7.5, 7.5) && eod.ylimits == (-7.5, 7.5)
    @test MC.crystal_limits(eod) == ((-150.0, 150.0), (-150.0, 150.0))

    # Explicit limits beyond the ceiling throw; inside it they are kept.
    @test_throws ArgumentError EOD(RecordingBackend(), max_crystal_volts=150.0, xlimits=(-8.0, 8.0))
    @test EOD(RecordingBackend(), max_crystal_volts=150.0, xlimits=(-2.0, 5.0)).xlimits == (-2.0, 5.0)

    # And it is enforced: 160 crystal V needs 8 DAQ V, past the 7.5 V the ceiling allows.
    initialize(eod)
    @test_throws ArgumentError setcrystalvoltage(eod, 160.0, 0.0)
    @test getvoltage(eod) == (0.0, 0.0)
    @test export_state(eod)[1]["max_crystal_volts"] == 150.0
end

@testset "Beam steering lifecycle" begin
    b = RecordingBackend()
    galvo = Galvo(b, xlimits=(-2.0, 2.0), ylimits=(-2.0, 2.0))
    @test shutdown(galvo) === nothing          # not initialized: nothing to release
    @test b.closed == 0

    initialize(galvo)
    @test_throws ArgumentError initialize(galvo)   # a second initialize would re-open the backend
    @test b.opened == 1
    shutdown(galvo)
    @test !galvo.isopen && b.closed == 1
    initialize(galvo)                              # and after shutdown it can be opened again
    @test b.opened == 2
    shutdown(galvo)
end

@testset "Beam steering partial failures" begin
    # X went out and Y did not: the axes are somewhere unknown, so the record says NaN
    # rather than keeping the previous pair.
    b = FailingBackend()
    galvo = Galvo(b, xlimits=(-2.0, 2.0), ylimits=(-2.0, 2.0))
    initialize(galvo)
    setvoltage(galvo, 0.5, 0.5)
    b.fail_y = true
    @test_throws ErrorException setvoltage(galvo, 1.0, 1.0)
    @test b.writes[end] == (:x, 1.0)
    @test all(isnan, getvoltage(galvo))
    @test all(isnan, getangle(galvo))
    b.fail_y = false
    setvoltage(galvo, 0.25, 0.25)                  # the next good write makes it known again
    @test getvoltage(galvo) == (0.25, 0.25)

    # A failed park throws from shutdown after the backend is released, and the record
    # says NaN rather than (0, 0).
    b.fail_park = true
    @test_throws ErrorException shutdown(galvo)
    @test b.closed == 1
    @test !galvo.isopen
    @test all(isnan, getvoltage(galvo))

    # A scan that fails partway still goes back to where it started, and throws.
    b2 = RecordingBackend()
    g2 = Galvo(b2, xlimits=(-2.0, 2.0), ylimits=(-2.0, 2.0))
    initialize(g2)
    setvoltage(g2, 0.5, -0.5)
    calls = Ref(0)
    @test_throws ErrorException gridscan(g2, 0.1, 3; settle=0.0) do dev, x, y
        (calls[] += 1) == 3 && error("fake camera failure")
        nothing
    end
    @test calls[] == 3
    @test getvoltage(g2) == (0.5, -0.5)
    @test b2.writes[end] == (0.5, -0.5)
end

@testset "Triggerscope backend limits" begin
    # Needs a Triggerscope4 object, which needs a serial port name LibSerialPort accepts
    # (see "Backends" above); skipped where there is none.
    scope = try
        Triggerscope4()
    catch
        nothing
    end
    if scope !== nothing
        # Snapped limits sit on whole DAC codes, so every voltage inside them rounds to a
        # code inside them.
        tb = TriggerscopeBackend(scope; range=PLUSMINUS10)
        step = MC.min_voltage_step(tb)
        lo, hi = MC.snap_limits(tb, (-1.0, 1.0))
        @test -1.0 <= lo && hi <= 1.0
        @test isapprox((lo + 10.0) / step, round((lo + 10.0) / step); atol=1e-6)
        @test isapprox((hi + 10.0) / step, round((hi + 10.0) / step); atol=1e-6)
        @test MC.snap_limits(tb, (-10.0, 10.0))[1] == -10.0
        @test isapprox(MC.snap_limits(tb, (-10.0, 10.0))[2], 10.0)

        # A ±2.5 V Triggerscope cannot take ±10 V limits; this was a warning, and sent
        # DAC1,98302 for 5 V.
        @test_throws ArgumentError Galvo(TriggerscopeBackend(scope; range=PLUSMINUS2_5),
            xlimits=(-10.0, 10.0), ylimits=(-2.0, 2.0))
    end
end
