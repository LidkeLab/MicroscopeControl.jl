using MicroscopeControl
using Test

@testset "MicroscopeControl.jl" begin
    @testset "Simulated Camera" begin
        cam = SimCamera()
        
        @test initialize(cam) == nothing
        
        # Test exposure time setting
        @test setexposuretime(cam, 0.1) == nothing
        @test cam.exposure_time ≈ 0.1
        
        # Test ROI setting
        @test setroi!(cam, [1,100,1,100]) == nothing
        @test cam.roi == [1,100,1,100]
        
        # Test image capture
        img = capture(cam)
        @test size(img) == (100,100)  # Based on ROI
        
        @test shutdown(cam) == nothing
    end

    @testset "Simulated Stage" begin
        stage = SimStage()
        
        @test initialize(stage) == nothing
        
        # Test position setting and getting
        initial_pos = getposition(stage)
        @test length(initial_pos) == 3  # x,y,z coordinates
        
        new_pos = [1.0, 2.0, 3.0]
        @test move(stage, new_pos) == nothing
        @test all(getposition(stage) .≈ new_pos)
        
        # Test range limits
        range = getrange(stage)
        @test length(range) == 3  # min and max for each axis
        
        @test shutdown(stage) == nothing
    end

    @testset "Simulated Light Source" begin
        light = SimLight()
        
        @test initialize(light) == nothing
        
        # Test power setting
        @test setpower(light, 50.0) == nothing
        @test light.power ≈ 50.0
        
        # Test on/off functionality
        @test light_on(light) == nothing
        @test light.is_on == true
        
        @test light_off(light) == nothing
        @test light.is_on == false
        
        @test shutdown(light) == nothing
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
end

