# The TLD001 ignores LD_SetLaserSetPoint while its output is disabled and runs
# on its stored setpoint at the next enable (642 nm rig, 2026-09-28). These
# cases pin the order the driver sends things in, against the fake controller
# in `tcube_fake_sdk.jl`, which models that behaviour.
using Test
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.TCubeLaserControl

@testset "TCube setpoint follows the output (0.2.4)" begin
    TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl
    FK = Main.FakeKinesis

    # A fresh, initialized laser on a controller holding a stale
    # above-full-scale setpoint word, as found on the rig.
    function fresh()
        FK.reset!(stored = 32767)
        l = TCubeLaser("00000000")
        redirect_stdout(devnull) do
            initialize(l)
        end
        empty!(FK.calls)
        empty!(FK.setpoints)
        return l
    end
    quiet(f) = redirect_stdout(f, devnull)
    last_index(op) = findlast(==(op), FK.calls)
    first_index(op) = findfirst(==(op), FK.calls)

    @testset "a: setpower with output off, then light_on" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
            light_on(l)
        end
        @test FK.output_on[]
        @test FK.stored[] == TCube.setpoint_code(l, 10.0)
        @test last_index("LD_SetLaserSetPoint") > first_index("LD_EnableOutput")
        @test FK.enable_log == [32767]   # it ran on the stale word only until the setpoint
    end

    @testset "b: light_off zeroes before disable; next light_on starts dark" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
            light_on(l)
            empty!(FK.calls); empty!(FK.setpoints)
            light_off(l)
        end
        @test FK.setpoints == [0x0000]
        @test first_index("LD_SetLaserSetPoint") < first_index("LD_DisableOutput")
        @test FK.stored[] == 0
        @test !FK.output_on[]
        @test l.drive_current == 10.0
        quiet() do
            light_on(l)
        end
        @test last(FK.enable_log) == 0
        @test FK.stored[] == TCube.setpoint_code(l, 10.0)
    end

    @testset "c: shutdown zeroes before disable" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
            light_on(l)
            empty!(FK.calls)
            shutdown(l)
        end
        @test first_index("LD_SetLaserSetPoint") < first_index("LD_DisableOutput")
        @test FK.stored[] == 0
        @test "LD_Close" in FK.calls
    end

    @testset "d: light_on without setpower sends 0 and warns" begin
        l = fresh()
        @test_logs (:warn, r"setpoint 0") match_mode = :any quiet() do
            light_on(l)
        end
        @test FK.stored[] == 0
    end

    @testset "e: light_on above the ceiling never enables" begin
        l = fresh()
        l.drive_current = TCube.effective_max_current(l) + 1
        @test_throws ArgumentError quiet() do
            light_on(l)
        end
        @test !("LD_EnableOutput" in FK.calls)
    end

    @testset "f: setpoint failing after enable disables the output" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
        end
        FK.fail!("LD_SetLaserSetPoint")
        @test_logs (:error, r"output disabled") match_mode = :any begin
            @test_throws ErrorException quiet() do
                light_on(l)
            end
        end
        @test last_index("LD_DisableOutput") > first_index("LD_EnableOutput")
        @test !FK.output_on[]
        @test !l.properties.is_on
    end

    @testset "g: failed zero in light_off is logged, output still off" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
            light_on(l)
        end
        FK.fail!("LD_SetLaserSetPoint")
        @test_logs (:error, r"zeroing the setpoint") match_mode = :any quiet() do
            light_off(l)
        end
        @test !FK.output_on[]
        @test !l.properties.is_on
    end

    @testset "h: failed disable throws and is_on stays true" begin
        l = fresh()
        quiet() do
            setpower(l, 10.0)
            light_on(l)
        end
        FK.fail!("LD_DisableOutput")
        @test_throws ErrorException quiet() do
            light_off(l)
        end
        @test l.properties.is_on
    end

    FK.reset!()
end
