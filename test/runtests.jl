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
end
