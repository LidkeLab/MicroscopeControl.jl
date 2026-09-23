using MicroscopeControl
using Test

const HDF5 = MicroscopeControl.HDF5

@testset "MicroscopeControl.jl" begin
    @testset "Simulated Camera" begin
        cam = SimCamera(exposure_time=0.01)

        @test cam isa Camera
        @test cam.exposure_time ≈ 0.01
        @test cam.roi.width == 1024
        @test cam.roi.height == 1024

        # Single frame capture: data follows the (H, W) convention
        capture(cam)
        @test cam.capture_mode == MicroscopeControl.HardwareImplementations.SimulatedCamera.SINGLE_FRAME
        @test size(getdata(cam)) == (1024, 1024)

        # ROI change is reflected in the returned frame size (H, W)
        cam.roi = CameraROI(1, 1, 100, 50)
        @test size(getdata(cam)) == (50, 100)
        @test size(getlastframe(cam)) == (50, 100)

        # Sequence acquisition returns (H, W, N)
        cam.sequence_length = 3
        sequence(cam)
        @test cam.is_running == true
        @test size(getdata(cam)) == (50, 100, 3)
        abort(cam)
        @test cam.is_running == false

        # Live mode returns a single (H, W) frame
        live(cam)
        @test size(getdata(cam)) == (50, 100)
        abort(cam)
    end

    @testset "Simulated Stage" begin
        stage = SimStage3d()

        @test stage isa Stage
        @test stage.connectionstatus == false
        initialize(stage)
        @test stage.connectionstatus == true

        # Motion updates the target, getposition syncs the real position
        move(stage, 1.0, 2.0, 3.0)
        @test (stage.targ_x, stage.targ_y, stage.targ_z) == (1.0, 2.0, 3.0)
        getposition(stage)
        @test (stage.real_x, stage.real_y, stage.real_z) == (1.0, 2.0, 3.0)

        # Range limits: one (min, max) tuple per axis
        r = getrange(stage)
        @test length(r) == 3
        @test all(length(ax) == 2 for ax in r)

        home(stage)
        @test (stage.real_x, stage.real_y, stage.real_z) == (0.0, 0.0, 0.0)

        servo(stage, true, false, true)
        @test stage.servostatus == (true, false, true)

        stopmotion(stage)
        shutdown(stage)
        @test stage.connectionstatus == false

        # Lower-dimensional variants share the same contract
        s2 = SimStage2d()
        initialize(s2)
        move(s2, 5.0, 6.0)
        getposition(s2)
        @test (s2.real_x, s2.real_y) == (5.0, 6.0)
        @test length(getrange(s2)) == 2
        shutdown(s2)

        s1 = SimStage1d()
        initialize(s1)
        move(s1, 7.0)
        getposition(s1)
        @test s1.real_x == 7.0
        shutdown(s1)
    end

    @testset "Simulated Light Source" begin
        light = SimLight()

        @test light isa LightSource
        initialize(light)
        @test light.properties.is_on == true

        setpower(light, 50.0)
        @test light.properties.power ≈ 50.0

        light_off(light)
        @test light.properties.is_on == false
        light_on(light)
        @test light.properties.is_on == true

        shutdown(light)
        @test light.properties.is_on == false
    end

    # No Thorlabs TCube on any build machine, so nothing here touches the
    # Kinesis DLL. What *is* testable without one is the part of the driver
    # that decides whether a current ever reaches the diode, which is
    # deliberately factored out of the SDK path (`check_current`,
    # `effective_max_current`, `record_controller_limit!`) for exactly that
    # reason. See CHANGELOG 0.3.0: hardware verification NOT DONE.
    @testset "TCube Laser (no hardware)" begin
        TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl

        @testset "Constructor defaults" begin
            laser = TCubeLaser("00000000")
            # 60.0 mA used to be the default floor: not a floor at all, since
            # it is a *lower* bound, so it only rejected safe small currents.
            @test laser.min_current == 0.0
            @test laser.max_current == 160.0
            # `initialize` records the controller's limit here, not over the
            # caller's `max_current`; NaN means "not read yet".
            @test isnan(laser.controller_max_current)
            # setpower takes mA and now says so.
            @test laser.properties.power_unit == "mA"
            @test laser.daq_device === nothing
            @test laser.ao_channel === nothing
        end

        @testset "Current validation" begin
            laser = TCubeLaser("00000000")

            @test TCube.check_current(laser, 100.0) == 100.0
            @test TCube.check_current(laser, 0.0) == 0.0
            @test_throws ArgumentError TCube.check_current(laser, 500.0)
            @test_throws ArgumentError TCube.check_current(laser, -1.0)
            # The message must name the request and both bounds: the old code
            # logged exactly this information and then proceeded anyway, so an
            # informative message is not evidence of an enforced limit --
            # hence the throw assertions above and the ordering test below.
            err = try
                TCube.check_current(laser, 500.0)
            catch e
                e
            end
            @test occursin("500.0", err.msg)
            @test occursin("160.0", err.msg)
            @test occursin("0.0", err.msg)

            # A caller floor is honoured.
            floored = TCubeLaser("00000000"; min_current=20.0)
            @test_throws ArgumentError TCube.check_current(floored, 10.0)

            # Above the setpoint DAC's full scale is rejected as out of range
            # rather than dying in `UInt16(...)` with an InexactError.
            wide = TCubeLaser("00000000"; max_current=400.0)
            @test TCube.effective_max_current(wide) == wide.max_setcurrent
            @test_throws ArgumentError TCube.check_current(wide, 300.0)
        end

        @testset "Caller ceiling survives the controller's limit" begin
            # The 1b-bis regression: `initialize` used to assign the
            # controller's limit straight over `max_current`, so a rig that
            # asked for 80 mA on a weak diode silently got the controller's
            # 160-220 mA, and `setpower` then validated against the
            # controller. `record_controller_limit!` is the field-writing half
            # of `initialize` with the SDK read removed.
            laser = TCubeLaser("00000000"; max_current=80.0)
            raw = UInt16(round(160.0 / laser.max_setcurrent * laser.max_setpoint))
            TCube.record_controller_limit!(laser, raw)

            @test laser.max_current == 80.0 # untouched
            # rtol, not the default: the raw reading is a UInt16 setpoint, so
            # 160.0 mA round-trips as 160.003 mA.
            @test laser.controller_max_current ≈ 160.0 rtol = 1e-3 # recorded separately
            @test TCube.effective_max_current(laser) == 80.0
            @test_throws ArgumentError TCube.check_current(laser, 100.0)

            # ... and the controller wins when it is the stricter of the two.
            strict = TCubeLaser("00000000"; max_current=200.0)
            TCube.record_controller_limit!(strict, UInt16(round(120.0 / strict.max_setcurrent * strict.max_setpoint)))
            @test TCube.effective_max_current(strict) ≈ 120.0 rtol = 1e-3
            @test_throws ArgumentError TCube.check_current(strict, 150.0)
        end

        @testset "setpower rejects before touching the SDK" begin
            # Ordering, not just rejection. `setpower`'s first statement is
            # the range check, so an out-of-range request must fail with the
            # check's own `ArgumentError`. Under the old code the check was an
            # `@error` log and execution continued, so the exception *type* is
            # what distinguishes "refused" from "attempted".
            #
            # 200.0 mA is the case that matters and the reason it is here
            # rather than 500.0 alone: it is over the 160 mA ceiling but under
            # `max_setcurrent`, so it converts to a valid `UInt16` setpoint and
            # the old code carried it all the way into the
            # `LD_SetLaserSetPoint` ccall (executed against the pre-fix driver:
            # `ErrorException`, "could not load library ...LaserDiode.dll" --
            # on a Windows rig that call would have driven 200 mA into the
            # diode). 500.0 and -5.0 happen to die earlier, in `UInt16(...)`
            # with an `InexactError`, which is a crash rather than a refusal.
            laser = TCubeLaser("00000000")
            @test_throws ArgumentError setpower(laser, 200.0)
            @test_throws ArgumentError setpower(laser, 500.0)
            @test_throws ArgumentError setpower(laser, -5.0)
            # A refused request must not be recorded as the laser's state.
            # The old code wrote it before the call: `setpower(laser, 200.0)`
            # left `properties.power == 125.0` (executed).
            @test laser.properties.power == 0.0
        end

        @testset "export_state" begin
            laser = TCubeLaser("00000000"; daq_device="Dev2", ao_channel="Dev2/ao1")
            attrs, data, children = export_state(laser) # 1-arg: used to throw
            @test attrs isa Dict{String,Any}
            @test attrs["power_unit"] == "mA"
            @test attrs["min_current"] == 0.0
            @test attrs["max_current"] == 160.0
            @test isnan(attrs["controller_max_current"])
            @test attrs["daq_device"] == "Dev2"
            @test attrs["ao_channel"] == "Dev2/ao1"
            @test data === nothing
            @test haskey(children, "daq")
            # `nothing` is not writable as an HDF5 attribute; unset must be "".
            @test export_state(TCubeLaser("00000000"))[1]["daq_device"] == ""
        end
    end

    @testset "Export State" begin
        devices = [SimCamera(), SimStage3d(), SimStage2d(), SimStage1d(), SimLight()]

        for device in devices
            attrs, data, children = export_state(device)
            @test attrs isa Dict{String,Any}
            @test !isempty(attrs)
            @test children isa Dict
        end

        # Round trip through HDF5 using the export_state tuple format
        mktempdir() do dir
            for device in devices
                filename = joinpath(dir, "$(device isa SimCamera ? "cam" : device isa SimLight ? "light" : "stage_$(device.dimensions)d").h5")
                attrs, data, children = export_state(device)
                save_attributes_and_data(filename, "Main", attrs, data, children)
                @test isfile(filename)
                HDF5.h5open(filename, "r") do h5
                    @test haskey(h5, "Main")
                    saved = HDF5.attrs(h5["Main"])
                    for (k, v) in attrs
                        @test haskey(saved, k)
                    end
                end
            end
        end
    end

    include("contract.jl")
    include("skills.jl")
    include("gui.jl")
end
