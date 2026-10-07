# Beam steering: the BeamSteerer interface, the Galvo and EOD devices, and the
# voltage/angle/scan arithmetic they share. Runs against RecordingBackend (see
# beam_steering_fake_backend.jl), so none of this needs hardware.

@testset "Beam Steering" begin

    @testset "AngleCalibration" begin
        @test_throws ArgumentError AngleCalibration([1.0 0.0 0.0; 0.0 1.0 0.0])
        @test_throws ArgumentError AngleCalibration([1.0 2.0; 2.0 4.0])   # singular

        cal = AngleCalibration(mrad_per_volt_x=0.5, mrad_per_volt_y=0.25)
        @test voltage_to_angle(cal, 2.0, 4.0) == (1.0, 1.0)
        @test angle_to_voltage(cal, 1.0, 1.0) == (2.0, 4.0)

        # round trip with cross-coupling and a non-zero rest point
        c2 = AngleCalibration([0.451 0.012; -0.008 0.423], v_offset=[0.13, -0.05])
        vx, vy = angle_to_voltage(c2, voltage_to_angle(c2, 1.7, -2.3)...)
        @test vx ≈ 1.7 && vy ≈ -2.3
        @test angle_to_voltage(c2, 0.0, 0.0) == (0.13, -0.05)
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
        @test length(gridpoints(1.0, 3)) == 9
        @test gridpoints(1.0, 1) == [(0.0, 0.0)]
        @test_throws ArgumentError gridpoints(1.0, 0)

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
        eod = EOD(RecordingBackend(), amplifier_gain=20.0, invert=true,
            xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
        initialize(eod)

        @test eod isa BeamSteerer
        @test amplifier_factor(eod) == -20.0
        @test tocrystal(eod, 5.0) == -100.0
        @test todaq(eod, 100.0) == -5.0

        setcrystalvoltage(eod, 100.0, -40.0)
        @test getvoltage(eod) == (-5.0, 2.0)
        @test all(isapprox.(getcrystalvoltage(eod), (100.0, -40.0)))

        # an inverting amplifier swaps the ends of the range
        @test crystal_limits(eod)[1] == (-150.0, 150.0)

        before = getvoltage(eod)
        @test_throws ArgumentError setcrystalvoltage(eod, 1000.0, 0.0)
        @test getvoltage(eod) == before

        @test_throws ArgumentError EOD(RecordingBackend(), calibration_basis=:bogus)
        @test_throws ArgumentError EOD(RecordingBackend(), amplifier_gain=0)
    end

    @testset "EOD angle basis" begin
        # The same matrix means different things depending on which voltage it was
        # measured against; getting it wrong is an error of the amplifier gain.
        cal = AngleCalibration(mrad_per_volt_x=0.003, mrad_per_volt_y=0.003)

        crystal = EOD(RecordingBackend(), calibration=cal, calibration_basis=:crystal,
            amplifier_gain=20.0, invert=true, xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
        initialize(crystal)
        setangle(crystal, 0.3, 0.0)
        @test all(isapprox.(getvoltage(crystal), (-5.0, 0.0)))     # 100 crystal V
        @test all(isapprox.(getangle(crystal), (0.3, 0.0)))

        daqbasis = EOD(RecordingBackend(), calibration=cal, calibration_basis=:daq,
            amplifier_gain=20.0, invert=true, xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
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
        @test rangelimits(PLUSMINUS10) == (-10.0, 10.0)
        @test rangelimits(PLUSMINUS2_5) == (-2.5, 2.5)
        @test rangelimits(ZEROTOFIVE) == (0.0, 5.0)

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
            @test isapprox(min_voltage_step(TriggerscopeBackend(scope; range=PLUSMINUS10)), 20.0 / 65535)
            @test isapprox(min_voltage_step(TriggerscopeBackend(scope; range=PLUSMINUS2_5)), 5.0 / 65535)

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
    eod = EOD(RecordingBackend(), amplifier_gain=20.0, invert=true,
        xlimits=(-7.5, 7.5), ylimits=(-7.5, 7.5))
    initialize(eod)
    @test !signbit(tocrystal(eod, 0.0))
    @test !signbit(todaq(eod, 0.0))
    @test all(!signbit, getcrystalvoltage(eod))
    attrs, _, _ = export_state(eod)
    @test !signbit(attrs["crystal_voltage_x"])
    # the sign of a real value is of course untouched
    @test tocrystal(eod, 1.0) == -20.0
    @test todaq(eod, -20.0) == 1.0
end
