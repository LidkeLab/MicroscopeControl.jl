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
        false, 0, zeros(UInt16, 1, 1), NaN, 0)

    @testset "a superseded wait touches nothing, before any library call" begin
        cam = fake_camera()
        cam.last_error = DC.DCAMERR_SUCCESS
        @test DC.wait_not_busy(cam, 1000, "test"; current = () -> false) == false
        @test cam.last_error == DC.DCAMERR_SUCCESS
    end

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

    @testset "@dcamcall trace" begin
        # The macro is named by its full path: it must resolve while the file is parsed, before DC exists.
        # libc stands in for the DCAM library: the macro takes the same syntax as @ccall.
        f(s) = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall strlen(s::Cstring)::Csize_t
        g(x) = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall abs(x::Cint)::Cint
        DC.dcam_trace!(nothing)
        @test f("hello") == 5
        @test g(Cint(-3)) == 3

        n = Ref(0)
        h() = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall abs((n[] += 1; Cint(-7))::Cint)::Cint
        @test h() == 7
        @test n[] == 1

        path = tempname()
        DC.dcam_trace!(path)
        @test f("hello") == 5
        @test h() == 7
        @test n[] == 2
        DC.dcam_trace_note("marker")
        lines = readlines(path)   # read while the file is still open: every line is flushed
        DC.dcam_trace!(nothing)
        @test length(lines) == 5
        @test occursin(r"tid=\d+ BEGIN strlen args=\(String\)", lines[1])
        @test occursin(r"tid=\d+ END strlen elapsed_ms=[\d.]+ ret=5 gc_ms=[\d.]+ sp_total_ms=[\d.]+ sp_max_ms=[\d.]+", lines[2])
        @test occursin(r"BEGIN strlen args=\(String\) gc_ms=[\d.]+ sp_total_ms=[\d.]+ sp_max_ms=[\d.]+", lines[1])
        @test occursin("BEGIN abs args=(-7)", lines[3])
        @test occursin("NOTE  marker", lines[5])

        # A Ref to a struct logs its Int32 fields, so a wait's timeout shows.
        @test occursin("DCAMWAIT_START{size=16,eventhappened=0,eventmask=2,timeout=1000}", DC.trace_arg(Ref(DC.DCAMWAIT_START(Int32(2), Int32(1000)))))

        @test DC.trace_arg(Ptr{Cvoid}(UInt(0x10))) == "0x10"

        # Off again: nothing is written.
        size0 = filesize(path)
        @test f("hello") == 5
        @test filesize(path) == size0
        rm(path)
    end
end
