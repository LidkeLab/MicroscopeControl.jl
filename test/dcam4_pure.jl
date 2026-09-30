# The DCAM library is absent on the machines that run this suite, so this file tests only what
# runs without it. The capture error paths, getdata's poll and stop_and_release! call the DCAM
# library first and cannot run without a swappable-library fake (a follow-up). The refusal and the
# cache are tested because they come before any library call.
@testset "DCAM4 (no library)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    CameraInterface = MicroscopeControl.HardwareInterfaces.CameraInterface

    # A camera built with no library call, through the positional constructor.
    fake_camera() = DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        DC.CameraROI(0, 0, 1, 1), DC.LIVE, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 10, DC.DCAMERR_SUCCESS,
        false, 0, zeros(UInt16, 1, 1), NaN)

    @testset "capture_timeout_ms" begin
        @test DC.capture_timeout_ms(0.0125, 0.043) == 1111
        @test DC.capture_timeout_ms(0.25, 0.25) == 2000
        @test DC.capture_timeout_ms(0, 0) == 1000
        @test DC.capture_timeout_ms(0.25, 0.25) isa Int32
        @test_throws ErrorException DC.capture_timeout_ms(NaN, 0)
        @test_throws ErrorException DC.capture_timeout_ms(Inf, 0)
        @test_throws ErrorException DC.capture_timeout_ms(-0.001, 0)
        @test_throws ErrorException DC.capture_timeout_ms(0, -1)
        @test_throws ErrorException DC.capture_timeout_ms(0, NaN)
        @test_throws ErrorException DC.capture_timeout_ms(1e7, 0)
    end

    @testset "wait parameter struct" begin
        @test DC.DCAMWAIT_START(Int32(2), Int32(1000)).size == 16
        @test DC.DCAMWAIT_START(Int32(2), Int32(1000)).size == sizeof(DC.DCAMWAIT_START)
    end

    @testset "an unbounded wait is refused before any library call" begin
        @test_throws r"bounded" DC.dcamwait_event(C_NULL, Int32(2), Int32(-1))
        @test_throws r"bounded" DC.dcamwait_event(C_NULL, Int32(2), reinterpret(Int32, 0x80000000))
    end

    @testset "capture refuses while running, before any library call" begin
        cam = fake_camera()
        cam.is_running = true
        cam.capture_mode = DC.LIVE
        @test_throws r"Stop the live view or sequence first" CameraInterface.capture(cam)
        @test cam.capture_mode == DC.LIVE
        @test cam.is_running
    end

    @testset "cached readout time" begin
        cam = fake_camera()
        cam.readout_s = 0.043
        @test DC.cached_readout_time(cam) == 0.043
    end
end
