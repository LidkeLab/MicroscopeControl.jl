# External modulation through the TLD001's rear MOD IN, driven by a DAQ analog output
# (`enable_modulation!`/`setmodulation!`), against the fake controller in
# `tcube_fake_sdk.jl`. The DAQ is replaced by a writer that records each voltage and tells
# the fake what the external input adds, so the closed loop's photocurrent includes it.
using Test
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.TCubeLaserControl
using MicroscopeControl.HardwareInterfaces.LightSourceInterface

@testset "TCube external modulation (MOD IN)" begin
    TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl
    FK = Main.FakeKinesis
    props() = LightSourceProperties("mW", 0.0, false, 1.0, 70.0)
    cp(; kw...) = TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                             tec_stabilised=missing, properties=props(), max_current=160.0,
                             lock_check_s=0.1, ramp_step_s=0.0, kw...)
    quiet(f) = redirect_stdout(f, devnull)
    ready(; kw...) = (FK.reset!(); FK.limit_follows_pot[] = true; l = cp(; kw...); quiet(() -> initialize(l)); l)
    # The test DAQ: records the voltage and sets the fake's external contribution (closed loop).
    writer(l) = v -> begin
        push!(FK.mod_volts, v); push!(FK.calls, "MOD $v")
        FK.ext_words[] = Int(TCube.photocurrent_code(l, max(v, 0.0) * TCube.modulation_scale(l) / 1000 / 224.2))
        nothing
    end
    enable!(l; v_range=(0.0, 5.0)) = enable_modulation!(l; writer=writer(l), v_range)
    idx(op) = findfirst(==(op), FK.calls)
    lastidx(op) = findlast(==(op), FK.calls)

    @testset "off by default; a laser without MOD IN never needs it" begin
        l = ready()
        @test !l.modulation.enabled && modulation_level(l) == 0.0
        @test_throws "enable_modulation!" setmodulation!(l, 5.0)
        quiet() do; setoutputpower!(l, 20.0); light_on(l); light_off(l); end
        @test isempty(FK.mod_volts) && "LD_SetControlSource" ∉ FK.calls
    end

    @testset "enable: 0 V first, then software + external; scale from tia_range x W/A" begin
        l = ready()
        empty!(FK.calls)
        enable!(l)
        @test l.modulation.enabled && FK.mod_volts == [0.0]
        @test idx("MOD 0.0") < idx("LD_SetControlSource")
        @test FK.source[] == 3 && l.modulation.prev_source == 5
        @test TCube.modulation_scale(l) ≈ 22.42   # mW per volt: 1 mA x 224.2 W/A / 10 V
        enable!(l)                                # a no-op the second time
        @test FK.mod_volts == [0.0]
    end

    @testset "setmodulation!: one write, the right voltage, every total checked" begin
        l = ready(); enable!(l)
        quiet() do; setoutputpower!(l, 20.0); light_on(l); end
        n = length(FK.calls)
        setmodulation!(l, 10.0)
        @test length(FK.calls) == n + 1 && startswith(FK.calls[end], "MOD ")   # no controller call at all
        @test FK.mod_volts[end] ≈ 10.0 / 22.42
        @test modulation_level(l) == 10.0
        @test_throws ArgumentError setmodulation!(l, 60.0)   # 20 + 60 > 70 mW
        @test_throws ArgumentError setmodulation!(l, -1.0)   # below the USB-6008's 0 V
        @test_throws ArgumentError setmodulation!(l, NaN)
        @test modulation_level(l) == 10.0                    # refusals change nothing
        @test_throws ArgumentError setoutputpower!(l, 65.0)  # 65 + 10 > 70: setpoints respect the modulation too
        @test l.properties.is_on
        quiet() do; light_off(l); end
    end

    @testset "the lock check expects setpoint + modulation" begin
        l = ready(); enable!(l)
        quiet() do; setoutputpower!(l, 20.0); end
        setmodulation!(l, 30.0)       # applied once the output is on; the loop then holds 50 mW
        quiet() do; light_on(l); end  # would read 2.5x the setpoint alone and trip as a lock
        @test l.properties.is_on
        quiet() do; setoutputpower!(l, 25.0); end
        @test l.properties.is_on
        quiet() do; light_off(l); end
    end

    # Rig 2026-10-13: the TLD001 keeps ONE setpoint register; a USB write sets it outright and MOD IN
    # changes add their difference. Sending only the request while modulated absorbed the modulation:
    # 10 on, +5, setoutputpower! 12 read 12 mW, and +0 then read 7. The driver now sends request + level.
    @testset "a setpoint written while modulated keeps the modulation on top" begin
        l = ready(); enable!(l)
        word(mW) = Int(TCube.photocurrent_code(l, mW / 1000 / 224.2))
        near(mW) = abs(FK.held_total() - word(mW)) <= 2
        quiet() do; setoutputpower!(l, 10.0); light_on(l); end
        setmodulation!(l, 5.0);                @test near(15.0)
        quiet(() -> setoutputpower!(l, 20.0)); @test near(25.0)   # up, with the ramp
        setmodulation!(l, 0.0);                @test near(20.0)
        setmodulation!(l, 5.0)
        quiet(() -> setoutputpower!(l, 12.0)); @test near(17.0)   # down
        setmodulation!(l, 0.0);                @test near(12.0)   # the request alone, not 12 - 5
        @test l.pd.output_power_requested == 12.0
        @test l.pd.photocurrent_requested ≈ 12.0 / 1000 / 224.2 atol = 1e-7   # the request without the modulation (one code is 3e-8 A)
        quiet() do; light_off(l); end
        setmodulation!(l, 8.0)                 # set while off: light_on sends 12 + 8
        quiet(() -> light_on(l));              @test near(20.0)
        setmodulation!(l, 0.0);                @test near(12.0)
        quiet() do; light_off(l); end
    end

    @testset "light_off, failures and shutdown write 0 V before the disable" begin
        l = ready(); enable!(l)
        quiet() do; setoutputpower!(l, 20.0); light_on(l); end
        setmodulation!(l, 10.0)
        empty!(FK.calls)
        quiet() do; light_off(l); end
        @test idx("MOD 0.0") < idx("LD_DisableOutput") && modulation_level(l) == 0.0

        quiet() do; light_on(l); end
        setmodulation!(l, 10.0)
        empty!(FK.calls)
        FK.throw!("LD_SetLaserSetPoint")
        @test_throws "fake Kinesis failure" quiet(() -> setoutputpower!(l, 30.0))
        @test idx("MOD 0.0") < lastidx("LD_DisableOutput") && !l.properties.is_on
        delete!(FK.throws, "LD_SetLaserSetPoint")

        quiet() do; light_on(l); end
        setmodulation!(l, 5.0)
        empty!(FK.calls)
        quiet() do; shutdown(l); end
        @test idx("MOD 0.0") < idx("LD_DisableOutput") < idx("LD_Close")
        @test FK.source[] == 5 && !l.modulation.enabled   # the source read at enable is back
    end

    @testset "disable_modulation! and a failing DAQ" begin
        l = ready(); enable!(l)
        setmodulation!(l, 5.0)
        disable_modulation!(l)
        @test FK.mod_volts[end] == 0.0 && FK.source[] == 5 && !l.modulation.enabled
        @test_throws "enable_modulation!" setmodulation!(l, 1.0)
        disable_modulation!(l)   # a no-op now

        l = ready()
        enable_modulation!(l; writer=v -> (v == 0.0 ? nothing : error("DAQ gone")), v_range=(0.0, 5.0))
        @test_throws "DAQ gone" setmodulation!(l, 5.0)
        @test modulation_level(l) == 0.0   # a failed write does not record the level
    end

    @testset "control source: software required, sums accepted" begin
        l = ready()
        @test control_source(l) == 5
        set_control_source!(l, 7)
        @test control_source(l) == 7
        @test_throws ArgumentError set_control_source!(l, 2)   # without software, setpoints would stop
        @test_throws ArgumentError set_control_source!(l, 8)
    end

    @testset "open loop: mA per volt = the controller's limit / 10" begin
        FK.reset!()
        l = TCubeLaser("00000000"; mode=ConstantCurrent())
        @test_throws "initialize first" TCube.modulation_scale(l)
        quiet(() -> initialize(l))
        @test TCube.modulation_scale(l) ≈ l.controller_max_current / 10
        # Refused in open loop: on the rig's TLD001 the input acted only after the source was set while on,
        # every setcurrent! disarmed it, and re-arming left the current up to 5 mA off (2026-10-13).
        empty!(FK.calls)
        @test_throws "refused in open loop" enable_modulation!(l; writer=v -> nothing, v_range=(0.0, 5.0), output_id="Dev2/ao1")
        @test !l.modulation.enabled && "LD_SetControlSource" ∉ FK.calls && !haskey(TCube.MODULATION_OUTPUTS, "Dev2/ao1")
        quiet(() -> setcurrent!(l, 70.0))   # open loop without modulation works as before
        @test l.drive_current == 70.0
    end

    @testset "several lasers: each claims its own output, one with and one without modulation" begin
        a = ready()
        b = cp(); quiet(() -> initialize(b))
        b2 = TCubeLaser("11111111"; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                        tec_stabilised=missing, properties=props(), max_current=160.0, lock_check_s=0.1, ramp_step_s=0.0)
        quiet(() -> initialize(b2))
        enable_modulation!(a; writer=writer(a), v_range=(0.0, 5.0), output_id="Dev2/ao1")
        @test a.modulation.output == "Dev2/ao1" && TCube.MODULATION_OUTPUTS["Dev2/ao1"] == a.serialNo
        @test_throws "already driving the MOD IN of TCubeLaser 00000000" enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="Dev2/ao1")
        @test !b2.modulation.enabled && modulation_level(b2) == 0.0   # refused: nothing changed on the second laser
        quiet() do; setoutputpower!(b2, 10.0); end                  # a laser without modulation works as before
        @test b2.pd.output_power_requested == 10.0
        enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="Triggerscope COM3 DAC 3")
        @test b2.modulation.enabled && b2.modulation.output == "Triggerscope COM3 DAC 3"
        setmodulation!(a, 5.0)
        @test modulation_level(a) == 5.0 && modulation_level(b2) == 0.0   # per laser
        disable_modulation!(a)
        @test !haskey(TCube.MODULATION_OUTPUTS, "Dev2/ao1")              # released
        disable_modulation!(b2)
        enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="Dev2/ao1")
        @test TCube.MODULATION_OUTPUTS["Dev2/ao1"] == "11111111"          # free again, the other laser can take it
        disable_modulation!(b2)
        # a failed enable leaves the output free
        @test_throws "DAQ gone" enable_modulation!(b; writer=v -> error("DAQ gone"), v_range=(0.0, 5.0), output_id="Dev2/ao0")
        @test !haskey(TCube.MODULATION_OUTPUTS, "Dev2/ao0") && !b.modulation.enabled
        @test isempty(TCube.MODULATION_OUTPUTS)
    end

    @testset "export_state records the modulation" begin
        l = ready(); enable!(l); setmodulation!(l, 3.0)
        a = export_state(l)[1]
        @test a["modulation_enabled"] === true && a["modulation_level"] == 3.0 && a["modulation_per_volt"] ≈ 22.42
    end
end
