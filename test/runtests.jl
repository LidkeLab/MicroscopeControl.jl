using MicroscopeControl
using Test

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

    # The MCS2 stage needs a SmarAct controller for anything that moves, so this
    # covers what can be checked without one: construction, unit conversion, the
    # travel-limit guard, export_state, and that every hardware operation refuses
    # cleanly while disconnected. It also touches the SDK, which is skipped when
    # SmarActCTL.dll is not installed.
    @testset "SmarAct MCS2" begin
        MCS2 = MicroscopeControl.HardwareImplementations.SmarActMCS2
        stage = MCS2Stage()

        @test stage.connectionstatus == false
        @test stage.units == "Microns"
        @test stage.dimensions == 2

        # Unit conversion between the microns this package uses and the
        # picometres the controller expects
        @test MCS2.um2pm(1.0) == 1_000_000
        @test MCS2.pm2um(1_000_000) == 1.0
        @test MCS2.pm2um(MCS2.um2pm(-1234.5678)) ≈ -1234.5678

        # Axis and channel mapping
        @test MCS2.axisindex(:x) == 1
        @test MCS2.axisindex(:z) == 3
        @test_throws ArgumentError MCS2.axisindex(:w)
        @test MCS2.channelof(stage, :y) == 1
        @test_throws ArgumentError MCS2.channelof(stage, 3)  # 2D stage has no z

        # Nothing that talks to hardware may run while disconnected
        for call in (() -> move(stage, 0.0, 0.0),
            () -> getposition(stage),
            () -> stopmotion(stage),
            () -> home(stage),
            () -> findreference(stage),
            () -> calibrate(stage),
            () -> waitformotion(stage),
            () -> deviceinfo(stage),
            () -> numchannels(stage),
            () -> moveaxis(stage, :x, 0.0),
            () -> moverelative(stage, 1.0, 1.0),
            () -> setvelocity!(stage, 100.0),
            () -> zeroposition!(stage))
            @test_throws ErrorException call()
        end

        # getrange falls back to the struct defaults when disconnected
        @test getrange(stage) == (stage.range_x, stage.range_y)

        attrs, data, children = export_state(stage)
        @test attrs isa Dict{String,Any}
        @test data === nothing
        @test children isa Dict{String,Any}
        @test attrs["units"] == "Microns"
        @test attrs["range_x"] == collect(stage.range_x)

        # shutdown while disconnected is a no-op rather than an error
        @test shutdown(stage) === nothing

        # Travel-limit and arity guards run before any call into the SDK
        stage.connectionstatus = true
        try
            @test_throws ErrorException move(stage, 1e9, 0.0)
            @test_throws ErrorException move(stage, 0.0, -1e9)
            @test_throws ArgumentError move(stage, 0.0)
            @test_throws ArgumentError move(stage, 0.0, 0.0, 0.0)
            @test_throws ArgumentError moverelative(stage, 1.0)
        finally
            stage.connectionstatus = false
        end

        # Exercise the SDK itself where it is installed; neither call needs a
        # controller to be attached.
        sdkinstalled = try
            mcs2version() isa String
        catch
            false
        end
        if sdkinstalled
            @test mcs2version() isa String
            @test findmcs2devices() isa Vector{String}
        else
            @info "SmarActCTL.dll not available, skipping MCS2 SDK checks"
        end
    end
end

