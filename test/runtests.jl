using MicroscopeControl
using Test

const BeamSteeringInterface = MicroscopeControl.HardwareInterfaces.BeamSteeringInterface

# A beam-steering backend that records what it was told to write instead of moving
# hardware, so the voltage/angle/limit/scan logic can be tested with no Triggerscope and
# no NI card present. Must be at top level — a struct cannot be defined inside a testset.
mutable struct RecordingBackend <: SteeringBackend
    writes::Vector{Tuple{Float64,Float64}}
    opened::Int
    closed::Int
end
RecordingBackend() = RecordingBackend(Tuple{Float64,Float64}[], 0, 0)

BeamSteeringInterface.backend_limits(::RecordingBackend) = ((-10.0, 10.0), (-10.0, 10.0))
BeamSteeringInterface.openbackend!(b::RecordingBackend) = (b.opened += 1; nothing)
BeamSteeringInterface.closebackend!(b::RecordingBackend) = (b.closed += 1; nothing)
BeamSteeringInterface.write_voltages!(b::RecordingBackend, vx::Float64, vy::Float64) =
    (push!(b.writes, (vx, vy)); nothing)

@testset "MicroscopeControl.jl" begin
    @testset "Simulated Camera" begin
        cam = SimCamera()
        
        @test initialize(cam) === nothing
        
        # Test exposure time setting
        @test setexposuretime(cam, 0.1) === nothing
        @test cam.exposure_time ≈ 0.1
        
        # Test ROI setting
        @test setroi!(cam, [1,100,1,100]) === nothing
        @test cam.roi == [1,100,1,100]
        
        # Test image capture
        img = capture(cam)
        @test size(img) == (100,100)  # Based on ROI
        
        @test shutdown(cam) === nothing
    end

    @testset "Simulated Stage" begin
        stage = SimStage()
        
        @test initialize(stage) === nothing
        
        # Test position setting and getting
        initial_pos = getposition(stage)
        @test length(initial_pos) == 3  # x,y,z coordinates
        
        new_pos = [1.0, 2.0, 3.0]
        @test move(stage, new_pos) === nothing
        @test all(getposition(stage) .≈ new_pos)
        
        # Test range limits
        range = getrange(stage)
        @test length(range) == 3  # min and max for each axis
        
        @test shutdown(stage) === nothing
    end

    @testset "Simulated Light Source" begin
        light = SimLight()
        
        @test initialize(light) === nothing
        
        # Test power setting
        @test setpower(light, 50.0) === nothing
        @test light.power ≈ 50.0
        
        # Test on/off functionality
        @test light_on(light) === nothing
        @test light.is_on == true
        
        @test light_off(light) === nothing
        @test light.is_on == false
        
        @test shutdown(light) === nothing
    end

    @testset "Export State" begin
        # Test export_state for each simulated device
        cam = SimCamera()
        stage = SimStage()
        light = SimLight()
        
        for device in [cam, stage, light]
            initialize(device)
            attrs, data, children = export_state(device)
            
            @test attrs isa Dict
            @test haskey(attrs, "Type")
            @test children isa Dict
            
            shutdown(device)
        end
    end

    @testset "Beam Steering" begin
        @testset "AngleCalibration" begin
            @test_throws ArgumentError AngleCalibration([1.0 0.0 0.0; 0.0 1.0 0.0])
            @test_throws ArgumentError AngleCalibration([1.0 2.0; 2.0 4.0])   # singular

            cal = AngleCalibration(mrad_per_volt_x = 0.5, mrad_per_volt_y = 0.25)
            @test voltage_to_angle(cal, 2.0, 4.0) == (1.0, 1.0)
            @test angle_to_voltage(cal, 1.0, 1.0) == (2.0, 4.0)

            # round trip with cross-coupling and a non-zero rest point
            c2 = AngleCalibration([0.451 0.012; -0.008 0.423], v_offset = [0.13, -0.05])
            vx, vy = angle_to_voltage(c2, voltage_to_angle(c2, 1.7, -2.3)...)
            @test vx ≈ 1.7 && vy ≈ -2.3
            @test angle_to_voltage(c2, 0.0, 0.0) == (0.13, -0.05)
        end

        @testset "Galvo" begin
            b = RecordingBackend()
            galvo = Galvo(b, calibration = AngleCalibration(mrad_per_volt_x = 0.5, mrad_per_volt_y = 0.5),
                xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "TestGalvo")

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
            galvo = Galvo(b, xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0))
            initialize(galvo)
            setvoltage(galvo, 0.5, 0.5)

            visited = gridscan(galvo, 0.1, 3; settle = 0.0)
            @test length(visited) == 9
            @test getvoltage(galvo) == (0.5, 0.5)   # returned to where it started

            out = gridscan(galvo, 0.1, 2; settle = 0.0) do dev, x, y
                x + y
            end
            @test length(out) == 4 && eltype(out) == Float64

            # a grid that would run off the end fails before moving
            n = length(b.writes)
            @test_throws ArgumentError gridscan(galvo, 10.0, 3; settle = 0.0)
            @test length(b.writes) == n
            @test_throws ArgumentError gridscan(galvo, 0.1, 3; units = :nonsense, settle = 0.0)
        end

        @testset "EOD amplifier" begin
            eod = EOD(RecordingBackend(), amplifier_gain = 20.0, invert = true,
                xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5))
            initialize(eod)

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

            @test_throws ArgumentError EOD(RecordingBackend(), calibration_basis = :bogus)
            @test_throws ArgumentError EOD(RecordingBackend(), amplifier_gain = 0)
        end

        @testset "EOD angle basis" begin
            # The same matrix means different things depending on which voltage it was
            # measured against; getting it wrong is an error of the amplifier gain.
            cal = AngleCalibration(mrad_per_volt_x = 0.003, mrad_per_volt_y = 0.003)

            crystal = EOD(RecordingBackend(), calibration = cal, calibration_basis = :crystal,
                amplifier_gain = 20.0, invert = true, xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5))
            initialize(crystal)
            setangle(crystal, 0.3, 0.0)
            @test all(isapprox.(getvoltage(crystal), (-5.0, 0.0)))     # 100 crystal V
            @test all(isapprox.(getangle(crystal), (0.3, 0.0)))

            daqbasis = EOD(RecordingBackend(), calibration = cal, calibration_basis = :daq,
                amplifier_gain = 20.0, invert = true, xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5))
            initialize(daqbasis)
            setvoltage(daqbasis, 5.0, 0.0)
            @test all(isapprox.(getangle(daqbasis), (0.015, 0.0)))

            # gridscan's pre-flight check has to land on DAQ volts for an EOD too: 0.1 mrad
            # is 33.3 crystal V but only 1.67 DAQ V, which is inside the limit.
            setvoltage(crystal, 0.0, 0.0)
            @test length(gridscan(crystal, 0.1, 3; units = :angle, settle = 0.0)) == 9
            @test_throws ArgumentError gridscan(crystal, 1.0, 5; units = :angle, settle = 0.0)

            setvoltage(crystal, 5.0, 0.0)
            attrs, _, _ = export_state(crystal)
            @test attrs["amplifier_gain"] == 20.0
            @test attrs["calibration_basis"] == "crystal"
            @test isapprox(attrs["crystal_voltage_x"], -100.0)
        end
    end
end

