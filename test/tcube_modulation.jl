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
    ready(; kw...) = (FK.reset!(); empty!(TCube.MODULATION_OUTPUTS); FK.limit_follows_pot[] = true; l = cp(; kw...); quiet(() -> initialize(l)); l)
    # The test DAQ: records the voltage and sets the fake's external contribution (closed loop).
    # A negative voltage subtracts, as on the TLD001 (manual section 5.5); nothing is clipped here.
    writer(l) = v -> begin
        push!(FK.mod_volts, v); push!(FK.calls, "MOD $v")
        FK.apply_ext!(Int(sign(v)) * Int(TCube.photocurrent_code(l, abs(v) * TCube.modulation_scale(l) / 1000 / l.pd.wa_calibration)))
        nothing
    end
    enable!(l; v_range=(0.0, 5.0)) = enable_modulation!(l; writer=writer(l), v_range, output_id="test output")
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
        @test_throws ArgumentError setmodulation!(l, -1.0)   # below the output's 0 V
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

    # Seen on a TLD001 (2026-10-13): it keeps ONE setpoint register; a USB write sets it outright and MOD IN
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
        enable_modulation!(l; writer=v -> (v == 0.0 ? nothing : error("DAQ gone")), v_range=(0.0, 5.0), output_id="test output")
        @test_throws "DAQ gone" setmodulation!(l, 5.0)
        @test modulation_level(l) == 0.0   # a failed write does not record the level
    end

    @testset "the output must be named: no default channel, no guessed range" begin
        l = ready()
        empty!(FK.calls)
        @test_throws "no analogue output is named" enable_modulation!(l)   # neither a DAQ channel nor a writer
        @test_throws "name the output" enable_modulation!(l; writer=v -> nothing, v_range=(0.0, 5.0))
        @test_throws "voltage range" enable_modulation!(l; writer=v -> nothing, output_id="test output")
        @test !l.modulation.enabled && "LD_SetControlSource" ∉ FK.calls && isempty(TCube.MODULATION_OUTPUTS)
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
        l = TCubeLaser("00000000"; mode=ConstantCurrent(), max_current=160.0)
        @test_throws "initialize first" TCube.modulation_scale(l)
        quiet(() -> initialize(l))
        @test TCube.modulation_scale(l) ≈ l.controller_max_current / 10
        # Refused in open loop: on the TLD001 tested the input acted only after the source was set while on,
        # every setcurrent! disarmed it, and re-arming left the current up to 5 mA off (2026-10-13).
        empty!(FK.calls)
        @test_throws "refused in open loop" enable_modulation!(l; writer=v -> nothing, v_range=(0.0, 5.0), output_id="DevA/ao0")
        @test !l.modulation.enabled && "LD_SetControlSource" ∉ FK.calls && !haskey(TCube.MODULATION_OUTPUTS, "DevA/ao0")
        quiet(() -> setcurrent!(l, 70.0))   # open loop without modulation works as before
        @test l.drive_current == 70.0
    end

    @testset "several lasers: each claims its own output, one with and one without modulation" begin
        a = ready()
        b = cp(); quiet(() -> initialize(b))
        b2 = TCubeLaser("11111111"; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                        tec_stabilised=missing, properties=props(), max_current=160.0, lock_check_s=0.1, ramp_step_s=0.0)
        quiet(() -> initialize(b2))
        enable_modulation!(a; writer=writer(a), v_range=(0.0, 5.0), output_id="DevA/ao0")
        @test a.modulation.output == "DevA/ao0" && TCube.MODULATION_OUTPUTS["DevA/ao0"] === a
        @test_throws "already driving the MOD IN of TCubeLaser 00000000" enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="DevA/ao0")
        @test !b2.modulation.enabled && modulation_level(b2) == 0.0   # refused: nothing changed on the second laser
        quiet() do; setoutputpower!(b2, 10.0); end                  # a laser without modulation works as before
        @test b2.pd.output_power_requested == 10.0
        enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="Triggerscope DAC 3")
        @test b2.modulation.enabled && b2.modulation.output == "Triggerscope DAC 3"
        setmodulation!(a, 5.0)
        @test modulation_level(a) == 5.0 && modulation_level(b2) == 0.0   # per laser
        disable_modulation!(a)
        @test !haskey(TCube.MODULATION_OUTPUTS, "DevA/ao0")              # released
        disable_modulation!(b2)
        enable_modulation!(b2; writer=v -> nothing, v_range=(0.0, 5.0), output_id="DevA/ao0")
        @test TCube.MODULATION_OUTPUTS["DevA/ao0"] === b2                  # free again, the other laser can take it
        disable_modulation!(b2)
        # a failed enable leaves the output free
        @test_throws "DAQ gone" enable_modulation!(b; writer=v -> error("DAQ gone"), v_range=(0.0, 5.0), output_id="DevA/ao1")
        @test !haskey(TCube.MODULATION_OUTPUTS, "DevA/ao1") && !b.modulation.enabled
        @test isempty(TCube.MODULATION_OUTPUTS)
    end

    @testset "export_state records the modulation" begin
        l = ready(); enable!(l); setmodulation!(l, 3.0)
        a = export_state(l)[1]
        @test a["modulation_enabled"] === true && a["modulation_level"] == 3.0 && a["modulation_per_volt"] ≈ 22.42
    end

    # ---- PR #83 review (2026-10-14) ----

    # Item 1, reproduced by the reviewer on 03f1b48: setmodulation! checked against the OLD setpoint while a
    # setoutputpower! was in flight, and the controller then held 30.02 mW against a 28 mW ceiling.
    @testset "review 1: setmodulation! during a setpoint change is refused, never above the ceiling" begin
        for (target, level, ceiling) in ((25.0, 5.0, 28.0), (25.0, 15.0, 30.0))
            l = ready(; properties=LightSourceProperties("mW", 0.0, false, 1.0, ceiling), lock_check_s=0.5)
            enable!(l)
            quiet() do; setoutputpower!(l, 10.0); light_on(l); end
            t = @async setoutputpower!(l, target)
            sleep(0.25)                                   # task A is inside its write / lock check
            @test_throws "setpoint lock" setmodulation!(l, level)
            wait(t)
            @test l.properties.is_on && modulation_level(l) == 0.0
            per_mW = TCube.photocurrent_code(l, 1.0 / 1000 / 224.2)
            @test FK.held_total() / per_mW <= ceiling
            @test_throws ArgumentError setmodulation!(l, level)   # once A is done, the check sees the new base
            setmodulation!(l, ceiling - target)                  # and what fits is accepted
            @test FK.held_total() / per_mW <= ceiling + 0.05
            quiet(() -> shutdown(l))
        end
        # light_off waits for a setpoint in flight instead of interleaving with it
        l = ready(; lock_check_s=0.3); enable!(l)
        quiet() do; setoutputpower!(l, 10.0); light_on(l); end
        t = @async setoutputpower!(l, 20.0)
        sleep(0.1)
        quiet(() -> light_off(l))
        @test istaskdone(t) && !istaskfailed(t) && !l.properties.is_on
        # held by another task: refused at once, nothing written
        n = length(FK.mod_volts)
        lock(l.modulation.lock)
        msg = try
            fetch(@async try setmodulation!(l, 1.0); "accepted" catch e; sprint(showerror, e) end)
        finally
            unlock(l.modulation.lock)
        end
        @test occursin("setpoint lock", msg) && length(FK.mod_volts) == n
    end

    @testset "review 1: the free path stays fast (200 Hz needs well under 5 ms per change)" begin
        l = ready(); enable_modulation!(l; writer=v -> nothing, v_range=(0.0, 5.0), output_id="test output")
        quiet() do; setoutputpower!(l, 10.0); light_on(l); end
        setmodulation!(l, 1.0)
        t = @elapsed for k in 1:1000
            setmodulation!(l, isodd(k) ? 20.0 : 0.0)
        end
        @test t / 1000 < 1e-4     # the driver's own share: the lock, the checks, the scale
        quiet(() -> light_off(l))
    end

    @testset "review 2: light_on re-checks the ceiling in closed loop" begin
        l = ready(); enable!(l)
        quiet() do; setoutputpower!(l, 30.0); end
        setmodulation!(l, 20.0)
        l.properties.max_power = 40.0                     # lowered after both were accepted
        empty!(FK.calls)
        @test_throws ArgumentError quiet(() -> light_on(l))
        @test !l.properties.is_on && "LD_EnableOutput" ∉ FK.calls
        setmodulation!(l, 5.0)                            # 35 fits again
        quiet(() -> light_on(l)); @test l.properties.is_on
        quiet(() -> light_off(l))
        l.properties.max_power = 25.0                     # the request alone (30) is now above it
        @test_throws "outside the allowed range" quiet(() -> light_on(l))
        @test !l.properties.is_on
    end

    @testset "review 3: disable keeps the modulation while a stale voltage can still add" begin
        fail = Ref(false)
        w(l) = v -> (fail[] && v == 0.0 && error("DAQ gone"); writer(l)(v))
        # previous source 7 includes the external input: restoring it leaves the input live
        l = ready(); FK.source[] = 7; closes = Ref(0)
        enable_modulation!(l; writer=w(l), v_range=(0.0, 5.0), output_id="test output", close=() -> (closes[] += 1))
        setmodulation!(l, 5.0)
        fail[] = true
        @test_throws "DAQ gone" disable_modulation!(l)
        @test l.modulation.enabled && modulation_level(l) == 5.0 && closes[] == 0
        @test TCube.MODULATION_OUTPUTS["test output"] === l
        # The 0 V write threw, so the voltage is unknown: setpoint writes refuse until 0 V is confirmed (PR #83 re-review)
        @test l.modulation.faulted
        @test_throws "voltage on MOD IN is unknown" quiet(() -> setoutputpower!(l, 10.0))
        fail[] = false
        disable_modulation!(l)                            # a retry finishes the job
        @test !l.modulation.enabled && closes[] == 1 && isempty(TCube.MODULATION_OUTPUTS)
        # previous source 5 ignores the input: restoring it is enough, the zero failure is still reported
        l = ready(); closes[] = 0
        enable_modulation!(l; writer=w(l), v_range=(0.0, 5.0), output_id="test output", close=() -> (closes[] += 1))
        setmodulation!(l, 5.0); fail[] = true
        @test_throws "DAQ gone" disable_modulation!(l)
        @test !l.modulation.enabled && FK.source[] == 5 && closes[] == 1 && isempty(TCube.MODULATION_OUTPUTS)
        fail[] = false
    end

    @testset "review 4: the output is released on disable, shutdown and a failed enable" begin
        closes = Ref(0)
        en!(l; w=writer(l)) = enable_modulation!(l; writer=w, v_range=(0.0, 5.0), output_id="test output", close=() -> (closes[] += 1))
        l = ready(); en!(l); disable_modulation!(l)
        @test closes[] == 1 && isempty(TCube.MODULATION_OUTPUTS)
        for k in 1:10                                     # enable/disable cycles on one output
            en!(l); disable_modulation!(l)
        end
        @test closes[] == 11 && isempty(TCube.MODULATION_OUTPUTS)
        en!(l); quiet(() -> shutdown(l))
        @test closes[] == 12 && !l.modulation.enabled && isempty(TCube.MODULATION_OUTPUTS)
        l = ready(); FK.throw!("LD_SetControlSource")
        @test_throws "fake Kinesis failure" en!(l)
        delete!(FK.throws, "LD_SetControlSource")
        @test closes[] == 13 && !l.modulation.enabled && isempty(TCube.MODULATION_OUTPUTS)
        # a release that fails keeps the claim, so no other laser takes a channel a task may still hold
        l = ready()
        enable_modulation!(l; writer=writer(l), v_range=(0.0, 5.0), output_id="test output", close=() -> error("task stuck"))
        @test_throws "task stuck" disable_modulation!(l)
        @test !l.modulation.enabled && TCube.MODULATION_OUTPUTS["test output"] === l
        other = cp(); quiet(() -> initialize(other))     # (ready() would empty the claims)
        @test_throws "already driving" enable_modulation!(other; writer=v -> nothing, v_range=(0.0, 5.0), output_id="test output")
        empty!(TCube.MODULATION_OUTPUTS)
        # the DAQ path takes no close= (it deletes its own task)
        @test_throws "close= is for a writer" enable_modulation!(ready(); ao_channel="DevA/ao0", close=() -> nothing)
    end

    @testset "smaller: claims per laser object, scale follows W/A, a writer that throws after applying" begin
        a = ready()
        a2 = cp(); quiet(() -> initialize(a2))           # a second object for the same serial
        enable!(a)
        @test_throws "another TCubeLaser object for the same serial" enable!(a2)
        disable_modulation!(a)

        l = ready(); enable!(l)
        l.pd.wa_calibration = 112.1                       # the scale halves: 1 V is now 11.21 mW
        setmodulation!(l, 10.0)
        @test FK.mod_volts[end] ≈ 10.0 / 11.21 && l.modulation.per_volt ≈ 11.21

        applied = Float64[]
        l = ready()
        enable_modulation!(l; writer=v -> (push!(applied, v); v > 0 && error("serial timeout after the write")),
                           v_range=(0.0, 5.0), output_id="test output")
        @test_throws "serial timeout" setmodulation!(l, 5.0)
        @test applied[end] == 0.0 && modulation_level(l) == 0.0   # put back at a known 0 V
    end

    # Rig 2026-10-14 (settle_window*.jl): a MOD IN change up to ~0.95 s after a setpoint write was LOST by the TLD001
    # (the light kept the old total, later changes counted from it); from 1.0 s on every change was applied.
    @testset "MOD_SETTLE_S: the slow calls wait it out, setmodulation! refuses inside it" begin
        old = TCube.MOD_SETTLE_S[]
        TCube.MOD_SETTLE_S[] = 0.3
        try
            l = ready(); enable!(l)
            quiet(() -> setoutputpower!(l, 10.0))                 # output off: no write, no wait
            quiet(() -> light_on(l))
            @test time() - l.modulation.written_at >= 0.3          # light_on returned only once settled
            setmodulation!(l, 5.0); @test modulation_level(l) == 5.0
            quiet(() -> setoutputpower!(l, 12.0))
            @test time() - l.modulation.written_at >= 0.3          # so did setoutputpower!
            setmodulation!(l, 0.0)
            l.modulation.written_at = time()                       # a write from a path that does not wait
            @test_throws "still settling" setmodulation!(l, 6.0)
            @test modulation_level(l) == 0.0                       # nothing written
            sleep(0.35); setmodulation!(l, 6.0); @test modulation_level(l) == 6.0
            quiet(() -> light_off(l))                              # light_off's zero does not start the window
            setmodulation!(l, 2.0); @test modulation_level(l) == 2.0   # the next light_on re-sends and waits itself
            disable_modulation!(l)
            t = @elapsed quiet(() -> (light_on(l); setoutputpower!(l, 11.0)))   # no modulation: no waiting
            @test t < 0.3 + 0.1 * 2 + 0.2                          # two lock checks (0.1 s each) and no settle waits
            quiet(() -> light_off(l))
        finally
            TCube.MOD_SETTLE_S[] = old
        end
    end

    # ---- PR #83 re-review (2026-10-15) ----

    @testset "re-review 1: the settle wait runs outside the lock, so light_off is not held up" begin
        old = TCube.MOD_SETTLE_S[]
        TCube.MOD_SETTLE_S[] = 0.8
        try
            l = ready(); enable!(l)
            quiet() do; setoutputpower!(l, 10.0); light_on(l); end
            t = @async quiet(() -> setoutputpower!(l, 12.0))
            # wait until the write is done and the call sits in its settle wait (lock free, call not returned)
            t0 = time()
            while (islocked(l.modulation.lock) || l.pd.output_power_requested != 12.0) && time() - t0 < 5; sleep(0.005); end
            @test !istaskdone(t)
            dt = @elapsed quiet(() -> light_off(l))
            @test dt < 0.3 && !l.properties.is_on                # not the 0.8 s settle wait
            wait(t)
            @test istaskdone(t) && !istaskfailed(t)
            # the wait loops: another write during it extends it
            quiet(() -> light_on(l))
            t1 = time(); l.modulation.written_at = t1 + 0.3     # as if another task wrote 0.3 s later
            TCube.wait_modulation_settled(l)
            @test time() - t1 >= 0.3 + 0.8 - 0.02
            quiet(() -> light_off(l))
        finally
            TCube.MOD_SETTLE_S[] = old
        end
    end

    @testset "re-review 2: an unknown MOD IN voltage marks modulation faulted until 0 V is confirmed" begin
        # The reviewer's case: at 20 + 10 (ceiling 30) a change applies 5 mW, then throws, and the 0 V rescue fails too.
        fail_after = Ref(false); zero_fails = Ref(false)
        l = ready(; properties=LightSourceProperties("mW", 0.0, false, 1.0, 30.0))
        w = writer(l)
        enable_modulation!(l; writer=v -> (v == 0.0 && zero_fails[] && error("zero failed");
                                            w(v); fail_after[] && v > 0 && error("applied, then threw")),
                           v_range=(0.0, 5.0), output_id="test output")
        quiet() do; setoutputpower!(l, 20.0); light_on(l); end
        setmodulation!(l, 10.0)
        fail_after[] = true; zero_fails[] = true
        @test_throws "applied, then threw" setmodulation!(l, 5.0)
        @test l.modulation.faulted
        fail_after[] = false
        per_mW = TCube.photocurrent_code(l, 1.0 / 1000 / 224.2)
        # nothing may now add to the unknown voltage: a level, a setpoint, a switch-on
        @test_throws "voltage on MOD IN is unknown" setmodulation!(l, 10.0)
        @test_throws "voltage on MOD IN is unknown" quiet(() -> setoutputpower!(l, 20.0))
        @test FK.held_total() / per_mW <= 30.0 + 0.05        # the reviewer's 35 mW is not reachable
        quiet(() -> light_off(l))                             # switch-off still works; its 0 V fails again
        @test !l.properties.is_on && l.modulation.faulted
        @test_throws "voltage on MOD IN is unknown" quiet(() -> light_on(l))
        zero_fails[] = false
        setmodulation!(l, 0.0)                                # 0 V confirmed: the fault clears
        @test !l.modulation.faulted && modulation_level(l) == 0.0
        quiet(() -> light_on(l)); setmodulation!(l, 10.0)
        @test FK.held_total() / per_mW <= 30.0 + 0.05 && l.properties.is_on
        @test export_state(l)[1]["modulation_faulted"] === false
        quiet(() -> light_off(l))
    end

    @testset "follow-ups: a calibration edit with a level on, a failed release retried, the guard ignores is_on" begin
        # The level written at the old scale is re-recorded at the new one before it is used.
        l = ready(); enable!(l)
        quiet() do; setoutputpower!(l, 10.0); light_on(l); end
        setmodulation!(l, 10.0)                                # 10 mW = 0.446 V at 22.42 mW/V
        l.pd.wa_calibration = 112.1                            # the same 0.446 V now adds 5 mW
        quiet(() -> setoutputpower!(l, 12.0))
        @test modulation_level(l) ≈ 5.0 && l.modulation.per_volt ≈ 11.21
        quiet(() -> light_off(l)); l.pd.wa_calibration = 224.2

        # A release that failed is retried by the next disable, and by enable (which refuses while it fails).
        tries = Ref(0)
        l = ready()
        enable_modulation!(l; writer=writer(l), v_range=(0.0, 5.0), output_id="test output",
                           close=() -> ((tries[] += 1) <= 2 && error("task stuck")))
        @test_throws "task stuck" disable_modulation!(l)
        @test !l.modulation.enabled && TCube.MODULATION_OUTPUTS["test output"] === l && l.modulation.close !== nothing
        @test_throws "could not be released earlier" enable_modulation!(l; writer=writer(l), v_range=(0.0, 5.0), output_id="test output")
        @test TCube.MODULATION_OUTPUTS["test output"] === l    # the claim is never dropped under the stuck task
        disable_modulation!(l)                                 # third try succeeds
        @test isempty(TCube.MODULATION_OUTPUTS) && l.modulation.close === nothing && tries[] == 3

        # The settle refusal holds even when the driver records the output off (front-panel enable).
        l = ready(); enable!(l)
        old = TCube.MOD_SETTLE_S[]; TCube.MOD_SETTLE_S[] = 0.3
        try
            l.modulation.written_at = time(); l.properties.is_on = false
            @test_throws "still settling" setmodulation!(l, 1.0)
        finally
            TCube.MOD_SETTLE_S[] = old
        end
    end

    @testset "the fake models the settle window, and the driver's waits beat it" begin
        old = TCube.MOD_SETTLE_S[]
        word(l, mW) = Int(TCube.photocurrent_code(l, mW / 1000 / 224.2))
        try
            # without the driver's wait the fake loses the change, as the rig did
            l = ready(); FK.settle_s[] = 0.25; TCube.MOD_SETTLE_S[] = 0.0
            enable!(l); quiet() do; setoutputpower!(l, 10.0); light_on(l); end
            setmodulation!(l, 5.0)
            @test abs(FK.held_total() - word(l, 10.0)) <= 2       # lost: still 10 mW, the record says 15
            quiet(() -> light_off(l))
            # with it, a change the instant each slow call returns lands
            l = ready(); FK.settle_s[] = 0.25; TCube.MOD_SETTLE_S[] = 0.3
            enable!(l); quiet() do; setoutputpower!(l, 10.0); light_on(l); end
            setmodulation!(l, 5.0);                @test abs(FK.held_total() - word(l, 15.0)) <= 2
            quiet(() -> setoutputpower!(l, 12.0)); setmodulation!(l, 0.0)
            @test abs(FK.held_total() - word(l, 12.0)) <= 2
            quiet(() -> light_off(l))
        finally
            TCube.MOD_SETTLE_S[] = old; FK.settle_s[] = 0.0
        end
    end

    @testset "a Triggerscope DAC as the output (dac_output), no port needed" begin
        TS = MicroscopeControl.HardwareImplementations.Triggerscope
        scope = TS.Triggerscope4(portname = "COM_TEST")       # not opened
        @test TS.dac_range_volts(TS.ZEROTOFIVE) == (0.0, 5.0) && TS.dac_range_volts(TS.PLUSMINUS10) == (-10.0, 10.0)
        o = TS.dac_output(scope, 3)                            # the driver's record: the constructor's ±10 V
        @test o.v_range == (-10.0, 10.0) && o.output_id == "Triggerscope COM_TEST DAC 3" && o.writer isa Function
        scope.dacranges[16] = TS.ZEROTOFIVE
        @test TS.dac_output(scope, 16).v_range == (0.0, 5.0)  # any DAC 1..16
        @test_throws ArgumentError TS.dac_output(scope, 17)
        @test_throws "outside its range" TS.volttooutput(scope, 16, 5.5)   # never a wrapped 16-bit code
        @test TS.volttooutput(scope, 16, 5.0) == 65535 && TS.volttooutput(scope, 16, 0.0) == 0
        @test scope.lock isa ReentrantLock
        # it plugs straight into enable_modulation! (here with the test writer standing in for the serial write)
        l = ready(); scope.dacranges[3] = TS.ZEROTOFIVE
        enable_modulation!(l; TS.dac_output(scope, 3)..., writer=writer(l))
        @test l.modulation.output == "Triggerscope COM_TEST DAC 3" && l.modulation.v_max == 5.0
        # two lasers on two DACs of one scope; the same DAC for a second laser is refused
        l2 = TCubeLaser("22222222"; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                        tec_stabilised=missing, properties=props(), max_current=160.0, lock_check_s=0.1, ramp_step_s=0.0)
        quiet(() -> initialize(l2))
        @test_throws "already driving" enable_modulation!(l2; TS.dac_output(scope, 3)..., writer=v -> nothing)
        enable_modulation!(l2; TS.dac_output(scope, 4)..., writer=v -> nothing)
        @test l2.modulation.output == "Triggerscope COM_TEST DAC 4" && length(TCube.MODULATION_OUTPUTS) == 2
        disable_modulation!(l); disable_modulation!(l2)
        @test isempty(TCube.MODULATION_OUTPUTS)
        # one on a DAQ-style output and one on the scope, at the same time
        l3 = ready(); scope.dacranges[5] = TS.ZEROTOFIVE
        enable_modulation!(l3; writer=writer(l3), v_range=(0.0, 5.0), output_id="DevA/ao1")
        enable_modulation!(l2; TS.dac_output(scope, 5)..., writer=v -> nothing)
        @test Set(keys(TCube.MODULATION_OUTPUTS)) == Set(["DevA/ao1", "Triggerscope COM_TEST DAC 5"])
        disable_modulation!(l3); disable_modulation!(l2)
    end
end
