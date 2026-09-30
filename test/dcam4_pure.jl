# The DCAM library is absent on the machines that run this suite, so this file tests only what
# runs without it. The capture error paths call the DCAM library first and cannot be exercised
# without a swappable-library fake, which is a follow-up.
@testset "DCAM4 (no library)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4

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

    @testset "dcamwait_close is never destructured" begin
        src = read(pkgdir(MicroscopeControl, "src", "hardware_implementations", "dcam4_camera",
                          "interface_methods.jl"), String)
        @test !occursin(r",\s*\w+\s*=\s*dcamwait_close\(", src)
    end
end
