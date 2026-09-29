using MicroscopeControl
using Test

const HDF5 = MicroscopeControl.HDF5

# Replaces the TCube laser's Kinesis wrappers with a recorder, so the driver's
# own `initialize`/`setpower`/`shutdown` can be run without a controller. Must
# be included at top level, before the testsets. See the file for the seam.
include("tcube_fake_sdk.jl")

# Writes the lab test record summary when LAB_TEST_SUMMARY is set; see the file.
include("lab_summary.jl")

lab_summary("Core") do
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
    # Kinesis DLL. Two things are still testable. The part of the driver that
    # decides whether a current ever reaches the diode is factored out of the
    # SDK path (`check_current`, `effective_max_current`, `setpoint_code`,
    # `record_controller_limit!`) and exercised directly. The lifecycle
    # functions themselves -- `initialize`, `setpower`, `shutdown` -- are run
    # unmodified against the recorder installed by `tcube_fake_sdk.jl`, which
    # is what makes their *own* control flow (not a helper's) a thing the suite
    # can fail on. What no test here can tell you is how a real controller
    # answers: see CHANGELOG 0.2.3 and 0.2.5, hardware verification NOT DONE.
    @testset "TCube Laser (no hardware)" begin
        TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl
        # Open-loop and closed-loop lasers as the rigs would build them. The
        # closed-loop numbers are the 642 nm rig's measured calibration.
        cc(; kw...) = TCubeLaser("00000000"; mode=ConstantCurrent(), kw...)
        cp_props() = LightSourceProperties("mW", 0.0, false, 1.0, 70.0)
        cp(; kw...) = TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2,
                                 tia_range=1e-3, tec_stabilised=missing, properties=cp_props(), max_current=160.0,
                                 lock_check_s=0.0, ramp_step_s=0.0, kw...) # no sleeping in the suite

        @testset "Constructor defaults" begin
            # Closed loop has no default clamp: it is the only real protection.
            cperr = try
                TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2,
                           tia_range=1e-3, tec_stabilised=missing, properties=cp_props())
                nothing
            catch e
                e
            end
            @test cperr isa ArgumentError
            @test occursin("max_current", cperr.msg)

            # `mode` defaults to ConstantCurrent(), the 0.2.x behaviour, so no
            # existing construction line changes meaning.
            @test TCubeLaser("00000000") isa TCubeLaser{ConstantCurrent}

            laser = cc()
            @test laser isa TCubeLaser{ConstantCurrent}
            @test laser isa DiodeLaser
            @test regulation_mode(laser) === ConstantCurrent()
            # 60.0 mA used to be the default floor: not a floor at all, since
            # it is a *lower* bound, so it only rejected safe small currents.
            @test laser.min_current == 0.0
            @test laser.max_current == 160.0
            # `initialize` records the controller's limit here, not over the
            # caller's `max_current`; NaN means "not read yet".
            @test isnan(laser.controller_max_current)
            # `setcurrent!` records what it accepted here; NaN = nothing yet.
            @test isnan(laser.drive_current)
            @test isnan(laser.threshold_current)
            @test laser.pd === nothing
            # The unit label no longer says mW for a laser commanded in mA.
            @test laser.properties.power_unit == "mA"
            @test laser.daq_device === nothing
            @test laser.ao_channel === nothing
        end

        @testset "Positional construction, old arity and new" begin
            # The fields added since 0.2.2 sit at the end of the struct so that
            # the ten- and fourteen-argument positional calls a pre-0.2.5
            # caller wrote still construct -- as open-loop lasers, since only
            # the keyword form can supply a photodiode calibration.
            props = LightSourceProperties("mW", 0.0, false, 0.0, 100.0)
            old = TCubeLaser("TCubeLaser", props, "red", 0.0, 160.0,
                220.0, 32767.0, "00000000", 0, NIdaq())
            @test old isa TCubeLaser{ConstantCurrent}
            @test old.serialNo == "00000000"
            @test old.max_current == 160.0
            @test old.max_setcurrent == 220.0 # slot 6, as in 0.2.2
            @test old.max_setpoint == 32767.0 # slot 7
            @test isnan(old.controller_max_current)
            @test old.daq_device === nothing
            @test old.ao_channel === nothing
            @test isnan(old.drive_current)
            @test isnan(old.threshold_current)
            @test old.pd === nothing

            full = TCubeLaser("TCubeLaser", props, "red", 0.0, 160.0,
                220.0, 32767.0, "00000000", 0, NIdaq(),
                150.0, "Dev2", "Dev2/ao1", 40.0)
            @test full isa TCubeLaser{ConstantCurrent}
            @test full.controller_max_current == 150.0
            @test full.daq_device == "Dev2"
            @test full.ao_channel == "Dev2/ao1"
            @test full.drive_current == 40.0

            # A caller-supplied `properties` is kept as given.
            @test cc(; properties=LightSourceProperties("mA", 0.0, false, 0.0, 220.0)).properties.max_power == 220.0
        end

        @testset "Power-mode construction refuses what it cannot run" begin
            laser = cp()
            @test laser isa TCubeLaser{ConstantPhotocurrent}
            @test regulation_mode(laser) === ConstantPhotocurrent()
            @test laser.pd isa PhotodiodeLoop
            @test laser.pd.wa_calibration == 224.2
            @test laser.pd.tia_range == 1e-3
            @test laser.pd.tec_stabilised === missing
            # Nothing has been programmed or commanded yet.
            @test isnan(laser.pd.max_current_clamp)
            @test isnan(laser.pd.output_power_requested)
            @test isnan(laser.pd.photocurrent_requested)
            @test isnan(laser.drive_current) # the loop owns the current

            msg(f) = try
                f()
                ""
            catch e
                e isa ArgumentError || rethrow()
                e.msg
            end
            # Every calibration keyword is required, and the message names the absent ones.
            m = msg(() -> TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2))
            @test occursin("tia_range", m) && occursin("tec_stabilised", m) && occursin("properties", m)
            @test !occursin("wa_calibration,", m)
            # A photodiode calibration on an open-loop laser is a contradiction.
            @test occursin("ConstantPhotocurrent", msg(() -> cc(; wa_calibration=224.2)))
            # Only the TLD001's four amplifier ranges exist.
            @test occursin("DIP", msg(() -> cp(; tia_range=2e-3)))
            # A power range the amplifier cannot reach is refused up front:
            # 224.2 W/A x 1 mA is 224.2 mW of full scale, so 300 mW is not reachable.
            @test occursin("full scale", msg(() -> cp(; properties=LightSourceProperties("mW", 0.0, false, 1.0, 300.0))))
            @test occursin("min_power", msg(() -> cp(; properties=LightSourceProperties("mW", 0.0, false, 5.0, 5.0))))
            # A ceiling below the potentiometer's lowest position cannot be clamped.
            @test occursin("potentiometer", msg(() -> cp(; max_current=10.0)))
            # A requested drive current would be a fiction in closed loop.
            @test occursin("drive_current", msg(() -> cp(; drive_current=40.0)))
            @test_throws ArgumentError PhotodiodeLoop(; wa_calibration=-1.0, tia_range=1e-3, tec_stabilised=true)
        end

        @testset "Current validation" begin
            laser = cc()

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
            floored = cc(; min_current=20.0)
            @test_throws ArgumentError TCube.check_current(floored, 10.0)

            # Above the setpoint DAC's full scale is rejected as out of range
            # rather than dying in `UInt16(...)` with an InexactError.
            wide = cc(; max_current=400.0)
            @test TCube.effective_max_current(wide) == wide.max_setcurrent
            @test_throws ArgumentError TCube.check_current(wide, 300.0)
        end

        @testset "Caller ceiling survives the controller's limit" begin
            # The 1b-bis regression: `initialize` used to assign the
            # controller's limit straight over `max_current`, so a rig that
            # asked for 80 mA on a weak diode silently got the controller's
            # 160-220 mA. `record_controller_limit!` is the field-writing half
            # of `initialize` with the SDK read removed.
            laser = cc(; max_current=80.0)
            raw = UInt16(round(160.0 / laser.max_setcurrent * laser.max_setpoint))
            TCube.record_controller_limit!(laser, raw)

            @test laser.max_current == 80.0 # untouched
            # rtol, not the default: the raw reading is a UInt16 setpoint, so
            # 160.0 mA round-trips as 160.003 mA.
            @test laser.controller_max_current ≈ 160.0 rtol = 1e-3 # recorded separately
            @test TCube.effective_max_current(laser) == 80.0
            @test_throws ArgumentError TCube.check_current(laser, 100.0)

            # ... and the controller wins when it is the stricter of the two.
            strict = cc(; max_current=200.0)
            TCube.record_controller_limit!(strict, UInt16(round(120.0 / strict.max_setcurrent * strict.max_setpoint)))
            @test TCube.effective_max_current(strict) ≈ 120.0 rtol = 1e-3
            @test_throws ArgumentError TCube.check_current(strict, 150.0)
        end

        @testset "setcurrent! rejects before touching the SDK" begin
            # Ordering, not just rejection. The range check is the first
            # statement, so an out-of-range request fails with the check's own
            # `ArgumentError` and reaches nothing. 200.0 mA is the case that
            # matters: over the 160 mA ceiling but under `max_setcurrent`, so
            # it converts to a valid setpoint -- before v0.2.3 it was sent.
            FakeKinesis.reset!()
            laser = cc()
            @test_throws ArgumentError setcurrent!(laser, 200.0)
            @test_throws ArgumentError setcurrent!(laser, 500.0)
            @test_throws ArgumentError setcurrent!(laser, -5.0)
            @test isnan(laser.drive_current) # nothing was commanded
            @test isempty(FakeKinesis.setpoints)
            @test isempty(FakeKinesis.calls)
        end

        @testset "setpower forwards in open loop (deprecated), throws in closed loop" begin
            # `setpower` took mA. On a ConstantCurrent laser the mode is a type
            # parameter, so forwarding to setcurrent! can never change unit;
            # on a ConstantPhotocurrent laser it would, so it throws.
            FakeKinesis.reset!()
            c = cc()
            initialize(c)
            @test_deprecated setpower(c, 80.0)
            @test c.drive_current == 80.0
            FakeKinesis.reset!()
            laser = cp()
            err = try
                setpower(laser, 80.0)
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("setoutputpower!", err.msg) && occursin("setlevel!", err.msg)
            @test occursin("ConstantPhotocurrent", err.msg)
            @test isempty(FakeKinesis.calls)
            # ... and each unit-true setter exists only in its own mode.
            @test_throws "not implemented" setoutputpower!(cc(), 10.0)
            @test_throws "not implemented" setcurrent!(cp(), 80.0)
            @test_throws "not implemented" indicated_output_power(cc())
            @test isempty(FakeKinesis.calls)
        end

        @testset "initialize keeps the caller's ceiling (fake SDK)" begin
            # The regression this driver was fixed for lives inside
            # `initialize`, so this runs the real `initialize` against the fake
            # Kinesis SDK. Restoring the old `light.max_current = ...`
            # assignment must fail this testset.
            # The controller reports a 160 mA limit and the pot follows the rig's
            # scale, so initialize lowers it under the 80 mA ceiling.
            FakeKinesis.reset!()
            FakeKinesis.limit_follows_pot[] = true
            laser = cc(; max_current=80.0)
            initialize(laser)

            # The output is zeroed and disabled BEFORE the mode command.
            @test FakeKinesis.calls[1:7] == ["TLI_BuildDeviceList", "TLI_GetDeviceListSize",
                "LD_Open", "LD_StartPolling", "LD_SetLaserSetPoint", "LD_DisableOutput", "LD_SetOpenLoopMode"]
            @test FakeKinesis.calls[8:9] == ["LD_RequestReadings", "LD_RequestLaserDiodeMaxCurrentLimit"]
            @test laser.max_current == 80.0 # survived initialize
            @test laser.controller_max_current <= 80.0 # lowered, never above the caller's ceiling
            @test TCube.effective_max_current(laser) == laser.controller_max_current # the lowered limit is now the tighter one

            # A post-initialize request between the caller's ceiling and the
            # controller's is refused, and nothing reaches the SDK.
            empty!(FakeKinesis.setpoints)
            @test_throws ArgumentError setcurrent!(laser, 100.0)
            @test isempty(FakeKinesis.setpoints)
            # ... while one under the caller's ceiling is accepted. With the
            # output OFF it is only recorded: the controller would ignore it.
            # 40 mA is floor(40/220*32767) = 5957, which decodes to 39.9957 mA.
            empty!(FakeKinesis.calls)
            setcurrent!(laser, 40.0)
            @test isempty(FakeKinesis.setpoints)
            @test FakeKinesis.calls == ["LD_GetStatusBits"]
            @test laser.drive_current == 40.0 # the accepted current, in mA
            # light_on enables, THEN sends it, and confirms it.
            empty!(FakeKinesis.calls)
            light_on(laser)
            @test FakeKinesis.calls == ["LD_EnableOutput", "LD_SetLaserSetPoint", "LD_GetLaserSetPoint"]
            @test FakeKinesis.setpoints == [UInt16(5957)]
            @test FakeKinesis.setpoint_held[] == 5957
            @test Float64(5957) / laser.max_setpoint * laser.max_setcurrent <= 40.0
            # With the output on, a new current is sent and confirmed at once.
            empty!(FakeKinesis.calls)
            setcurrent!(laser, 30.0)
            @test FakeKinesis.calls == ["LD_GetStatusBits", "LD_SetLaserSetPoint", "LD_GetLaserSetPoint"]
            @test FakeKinesis.setpoint_held[] == TCube.setpoint_code(laser, 30.0)

            # A setpoint the controller does not confirm is an error, and is
            # not recorded as the laser's state.
            FakeKinesis.setpoint_readback[] = UInt16(1)
            @test_throws ErrorException setcurrent!(laser, 20.0)
            @test laser.drive_current == 30.0
            FakeKinesis.setpoint_readback[] = nothing
            # ... but one code of difference is the controller's own rounding
            # (the rig read back 10424 for 10425) and is accepted.
            FakeKinesis.setpoint_readback[] = TCube.setpoint_code(laser, 25.0) - UInt16(1)
            setcurrent!(laser, 25.0)
            @test laser.drive_current == 25.0
            FakeKinesis.setpoint_readback[] = nothing
            light_off(laser)

            # A second initialize, with a different controller reading. The
            # limit is *below* the caller's ceiling, so the `min` in
            # `effective_max_current` is exercised in the other direction too.
            FakeKinesis.reset!(limit_raw=8936) # 8936/32767*220 = 59.997 mA
            weak = cc(; max_current=80.0)
            initialize(weak)
            @test weak.controller_max_current ≈ 60.0 rtol = 1e-3
            @test weak.max_current == 80.0 # still the caller's
            @test TCube.effective_max_current(weak) == weak.controller_max_current
            @test_throws ArgumentError setcurrent!(weak, 70.0) # between the two ceilings
            @test FakeKinesis.setpoints == [UInt16(0)] # initialize's own zero, nothing from the refused request

            # Polling is a success FLAG, not a status code: `false` fails.
            FakeKinesis.reset!()
            FakeKinesis.polling_ok[] = false
            @test_throws "LD_StartPolling" initialize(cc())
            @test FakeKinesis.calls[end] == "LD_Close" # and the handle is released
        end

        @testset "initialize leaves the output off; the open-loop clamp only lowers (fake SDK)" begin
            # (a) Output left on by other software: zeroed and disabled BEFORE the mode command.
            FakeKinesis.reset!()
            FakeKinesis.bits[] |= FakeKinesis.ENABLED
            FakeKinesis.setpoint_held[] = UInt16(32767)
            laser = cc()
            laser.properties.is_on = true
            initialize(laser)
            @test FakeKinesis.bits[] & FakeKinesis.ENABLED == 0
            @test FakeKinesis.setpoint_held[] == 0
            @test laser.properties.is_on == false
            @test findfirst(==("LD_DisableOutput"), FakeKinesis.calls) <
                  findfirst(==("LD_SetOpenLoopMode"), FakeKinesis.calls)

            # (b) The controller's limit is above the ceiling: the pot is lowered.
            FakeKinesis.reset!()
            FakeKinesis.limit_follows_pot[] = true
            low = cc(; max_current=100.0)
            initialize(low)
            @test low.controller_max_current <= 100.0
            @test FakeKinesis.digpot[] < 204
            @test !isempty(FakeKinesis.digpot_sets)
            @test all(<(204), FakeKinesis.digpot_sets)

            # (c) The limit is at or below the ceiling: the pot is never raised.
            FakeKinesis.reset!()
            FakeKinesis.limit_follows_pot[] = true
            high = cc(; max_current=200.0)
            initialize(high)
            @test isempty(FakeKinesis.digpot_sets)
            @test FakeKinesis.digpot[] == 204
            @test high.controller_max_current ≈ 160.74 atol = 0.05
        end

        @testset "a failed initialize closes the connection (fake SDK)" begin
            # A controller left open refuses the next LD_Open, so a failure
            # after the open must not leak the handle -- and the error the
            # caller sees must be the one that stopped initialization.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_SetOpenLoopMode", 3)
            laser = cc()
            err = try
                initialize(laser)
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("LD_SetOpenLoopMode", err.msg)
            @test occursin("3", err.msg) # the Thorlabs code, not a cleanup error
            @test FakeKinesis.calls == ["TLI_BuildDeviceList", "TLI_GetDeviceListSize",
                "LD_Open", "LD_StartPolling", "LD_SetLaserSetPoint", "LD_DisableOutput",
                "LD_SetOpenLoopMode", "LD_StopPolling", "LD_Close"]
            @test isnan(laser.controller_max_current) # nothing recorded

            # A failure at the open itself has no handle to close.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_Open", 2)
            @test_throws ErrorException initialize(cc())
            @test "LD_Close" ∉ FakeKinesis.calls

            # A close that *throws* must not displace the error that stopped
            # initialization: the binding returns void, so raising is the only
            # failure `LD_Close` can express.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_SetOpenLoopMode", 3)
            FakeKinesis.throw!("LD_Close", "fake close explosion")
            both = cc()
            bothErr = @test_logs (:error,) match_mode = :any try
                initialize(both)
                nothing
            catch e
                e
            end
            @test bothErr isa ErrorException
            @test occursin("LD_SetOpenLoopMode", bothErr.msg) # the original failure ...
            @test occursin("3", bothErr.msg)
            @test !occursin("fake close explosion", bothErr.msg) # ... not the cleanup's
            @test FakeKinesis.calls == ["TLI_BuildDeviceList", "TLI_GetDeviceListSize",
                "LD_Open", "LD_StartPolling", "LD_SetLaserSetPoint", "LD_DisableOutput",
                "LD_SetOpenLoopMode", "LD_StopPolling", "LD_Close"]
            @test isnan(both.controller_max_current)
        end

        @testset "closed-loop initialize: the protected sequence (fake SDK)" begin
            FakeKinesis.reset!()
            FakeKinesis.limit_follows_pot[] = true      # the rig controller's pot scale
            FakeKinesis.setpoint_held[] = UInt16(11915) # an open-loop 80 mA left on the controller
            FakeKinesis.setbits!(FakeKinesis.ENABLED)   # ... and its output left on
            laser = cp(; max_current=160.0)
            laser.properties.is_on = true
            initialize(laser)

            clamp_read = "LD_RequestMaxCurrentDigPot", "LD_GetMaxCurrentDigPot"
            limit_read = "LD_RequestLaserDiodeMaxCurrentLimit", "LD_GetLaserDiodeMaxCurrentLimit"
            @test FakeKinesis.calls == ["TLI_BuildDeviceList", "TLI_GetDeviceListSize", "LD_Open",
                # polling first: the setpoint read-back only refreshes through it
                "LD_StartPolling",
                # the output left on is zeroed, then disabled, before any mode command
                "LD_SetLaserSetPoint", "LD_DisableOutput",
                # 1-2: key, interlock and the amplifier range, from a fresh read
                "LD_RequestStatusBits", "LD_GetStatusBits",
                # 3: the clamp. At position 204 the controller reports 160.74 mA,
                # over the 160 mA ceiling, so it steps to 203 (159.91 mA) and stops.
                clamp_read..., limit_read...,
                "LD_EnableMaxCurrentAdjust", "LD_SetMaxCurrentDigPot", clamp_read..., "LD_EnableMaxCurrentAdjust",
                limit_read...,
                # 4: closed loop, confirmed from the status word
                "LD_SetClosedLoopMode", "LD_RequestStatusBits", "LD_GetStatusBits",
                # 5: the display calibration, confirmed
                "LD_SetWACalibFactor", "LD_RequestWACalibFactor", "LD_GetWACalibFactor",
                # shared tail: the controller's limit
                "LD_RequestReadings", limit_read...]
            @test "LD_EnableOutput" ∉ FakeKinesis.calls  # initialize never emits
            @test FakeKinesis.bits[] & FakeKinesis.ENABLED == 0
            @test laser.properties.is_on == false
            # The stale setpoint the output was left on is zeroed before the disable.
            @test FakeKinesis.setpoints == [UInt16(0)]
            @test FakeKinesis.setpoint_held[] == 0
            # The diode flag is never raised: passed as false both times.
            @test FakeKinesis.adjust_calls == [(true, false), (false, false)]
            @test FakeKinesis.digpot_sets == [203]
            # The clamp is the controller's own reported limit, under the ceiling.
            reported = TCube.setpoint_current(laser, floor(Int, FakeKinesis.limit_mA_for(203) / 220 * 32767))
            @test laser.pd.max_current_clamp == reported
            @test laser.pd.max_current_clamp <= 160.0
            @test laser.controller_max_current == reported
            @test FakeKinesis.bits[] & FakeKinesis.CLOSED != 0
            @test FakeKinesis.wa[] == Float32(224.2)
            @test laser.max_current == 160.0
        end

        @testset "the clamp search, against the rig controller's pot scale (fake SDK)" begin
            # Highest position whose REPORTED limit is <= max_current, from any
            # starting position, never trusting the header's position scale.
            best(ceiling) = maximum(p for p in 20:255 if FakeKinesis.limit_mA_for(p) <= ceiling)
            for (ceiling, start) in ((160.0, 204), (160.0, 185), (160.0, 20), (160.0, 255), (100.0, 204), (150.0, 120))
                FakeKinesis.reset!()
                FakeKinesis.limit_follows_pot[] = true
                FakeKinesis.digpot[] = start
                laser = cp(; max_current=ceiling,
                           properties=LightSourceProperties("mW", 0.0, false, 1.0, 20.0))
                initialize(laser)
                @test FakeKinesis.digpot[] == best(ceiling)
                @test laser.pd.max_current_clamp <= ceiling
                @test ceiling - laser.pd.max_current_clamp < 0.831 + 0.01
                @test length(FakeKinesis.digpot_sets) <= 6
                @test all(==((false, false)), FakeKinesis.adjust_calls[2:2:end]) # adjust mode always left
                @test all(t -> t[2] == false, FakeKinesis.adjust_calls)          # diode flag never raised
            end
            # Already under the ceiling, and within one step of it: nothing is written.
            FakeKinesis.reset!() # fixed 160.0 mA limit
            initialize(cp(; max_current=160.0))
            @test isempty(FakeKinesis.digpot_sets)
            @test "LD_EnableMaxCurrentAdjust" ∉ FakeKinesis.calls
        end

        @testset "closed-loop initialize refuses, and closes, on each precondition (fake SDK)" begin
            function refusal(setup!; laser=cp())
                FakeKinesis.reset!()
                setup!()
                err = try
                    initialize(laser)
                    nothing
                catch e
                    e
                end
                return err, laser
            end
            closed_loop_attempted() = "LD_SetClosedLoopMode" in FakeKinesis.calls

            err, _ = refusal(() -> FakeKinesis.setbits!(FakeKinesis.KEY; on=false))
            @test occursin("key switch", err.msg)
            @test !closed_loop_attempted() && FakeKinesis.calls[end] == "LD_Close"

            err, _ = refusal(() -> FakeKinesis.setbits!(FakeKinesis.INTERLOCK; on=false))
            @test occursin("interlock", err.msg)
            @test !closed_loop_attempted()

            # A DIP switch moved since the calibration: a silent factor of ten.
            err, _ = refusal(() -> (FakeKinesis.setbits!(FakeKinesis.TIA_1mA; on=false);
                                    FakeKinesis.setbits!(FakeKinesis.TIA_10mA)))
            @test occursin("DIP", err.msg) && occursin("0.01", err.msg)
            @test !closed_loop_attempted()
            err, _ = refusal(() -> FakeKinesis.setbits!(FakeKinesis.TIA_1mA; on=false))
            @test occursin("no single photodiode range", err.msg)

            # A clamp that does not take, and reads back above the ceiling.
            err, laser = refusal(() -> (FakeKinesis.limit_follows_pot[] = true; FakeKinesis.digpot_takes[] = false))
            @test occursin("potentiometer", err.msg) && occursin("reads back", err.msg)
            @test !closed_loop_attempted()
            @test isnan(laser.pd.max_current_clamp) # never recorded from a failed read-back
            @test FakeKinesis.adjust_calls[end] == (false, false) # adjust mode was left
            @test FakeKinesis.calls[end] == "LD_Close"

            # A controller whose limit stays over the ceiling even at the lowest position.
            err, laser = refusal(() -> FakeKinesis.diode_limit_raw[] = 32767) # 220 mA, whatever the position
            @test occursin("lowest potentiometer position", err.msg)
            @test isnan(laser.pd.max_current_clamp)
            @test !closed_loop_attempted() && FakeKinesis.calls[end] == "LD_Close"

            # A mode change the status word does not confirm.
            err, _ = refusal(() -> FakeKinesis.closed_loop_takes[] = false)
            @test occursin("0x4", err.msg)

            # A calibration factor that does not read back.
            err, _ = refusal(() -> FakeKinesis.wa_readback[] = 100f0)
            @test occursin("W/A", err.msg)

            @test "LD_EnableOutput" ∉ FakeKinesis.calls
        end

        @testset "power mode re-checks the controller before emitting (fake SDK)" begin
            # A 100 mA ceiling, so a pot restored to 204 (160.74 mA) is far above the
            # clamp: the check allows 1 mA of slack, which is more than one pot step
            # (0.83 mA), so a one-step drift at a 160 mA ceiling is not caught.
            ready() = (FakeKinesis.reset!(); FakeKinesis.limit_follows_pot[] = true;
                       l = cp(; max_current=100.0); initialize(l); empty!(FakeKinesis.calls); l)
            # (a) A power cycle restored the pot: the limit is back above the clamp.
            laser = ready()
            FakeKinesis.digpot[] = 204
            @test_throws "clamp" light_on(laser)
            @test "LD_EnableOutput" ∉ FakeKinesis.calls
            @test_throws "clamp" setoutputpower!(laser, 10.0)
            # (b) The closed-loop bit is gone.
            laser = ready()
            FakeKinesis.setbits!(FakeKinesis.CLOSED; on=false)
            @test_throws "closed loop" setoutputpower!(laser, 10.0)
            @test_throws "closed loop" light_on(laser)
            @test "LD_EnableOutput" ∉ FakeKinesis.calls
            # (c) A re-initialize that fails in enter_mode! leaves no stale clamp.
            # The key switch refusal is the first step that can fail, before the
            # clamp is programmed again.
            laser = ready()
            @test !isnan(laser.pd.max_current_clamp)
            FakeKinesis.setbits!(FakeKinesis.KEY; on=false)
            @test_throws "key switch" initialize(laser)
            @test isnan(laser.pd.max_current_clamp)
        end

        @testset "the ramp starts from what the driver knows; lock detection (fake SDK)" begin
            ready(; kw...) = (FakeKinesis.reset!(); FakeKinesis.limit_follows_pot[] = true;
                              l = cp(; kw...); initialize(l); l)
            code_for(l, mW) = Int(TCube.photocurrent_code(l, mW / 1000 / 224.2))
            enabled() = FakeKinesis.bits[] & FakeKinesis.ENABLED != 0
            # (a) Measured 2x the request, output on: refused, and the output is turned off.
            laser = ready()
            setoutputpower!(laser, 10.0); light_on(laser)
            FakeKinesis.photocurrent_raw[] = 2 * code_for(laser, 30.0)
            @test_throws r"loop lock" setoutputpower!(laser, 30.0)
            @test !enabled()
            @test laser.properties.is_on == false
            @test laser.pd.output_power_requested == 10.0   # the refused request is not recorded
            # (b) The same through light_on.
            laser = ready()
            setoutputpower!(laser, 30.0)
            FakeKinesis.photocurrent_raw[] = 2 * code_for(laser, 30.0)
            @test_throws r"loop lock" light_on(laser)
            @test !enabled()
            @test laser.properties.is_on == false
            # (d) 1.2x the request does not trip.
            laser = ready()
            setoutputpower!(laser, 30.0)
            FakeKinesis.photocurrent_raw[] = round(Int, 1.2 * code_for(laser, 30.0))
            light_on(laser)
            @test enabled() && laser.properties.is_on
            # (c) With a finite ramp and the output on, a step up walks from the
            # PREVIOUS request's code: neither 0 nor the stale 65530.
            laser = ready(; ramp_step_mW=3.0)
            setoutputpower!(laser, 10.0); light_on(laser)
            FakeKinesis.photocurrent_raw[] = 0
            prev = code_for(laser, 10.0)
            step = round(Int, 3.0 / 1000 / 224.2 / 1e-3 * 32767)
            empty!(FakeKinesis.setpoints)
            setoutputpower!(laser, 50.0)
            @test prev < Int(first(FakeKinesis.setpoints)) <= prev + step
            @test Int(last(FakeKinesis.setpoints)) == code_for(laser, 50.0)
            # The ramp keywords are for closed loop only.
            @test_throws ArgumentError cc(; ramp_step_mW=3.0)
            @test_throws ArgumentError cc(; lock_ratio=2.0)
            @test cp().pd.lock_ratio == 1.5 && cp().pd.ramp_step_mW == Inf
        end

        @testset "setoutputpower! (fake SDK)" begin
            # Refused before initialize: the clamp is not programmed, and it is
            # the only real protection in closed loop.
            guard = ["LD_RequestStatusBits", "LD_GetStatusBits",
                     "LD_RequestLaserDiodeMaxCurrentLimit", "LD_GetLaserDiodeMaxCurrentLimit"]
            FakeKinesis.reset!()
            laser = cp()
            @test_throws "clamp" setoutputpower!(laser, 10.0)
            @test_throws "clamp" light_on(laser)
            @test isempty(FakeKinesis.calls)

            initialize(laser)
            # Out of the declared [1, 70] mW is refused before anything is sent.
            empty!(FakeKinesis.calls); empty!(FakeKinesis.setpoints)
            @test_throws ArgumentError setoutputpower!(laser, 80.0)
            @test_throws ArgumentError setoutputpower!(laser, 0.5)
            @test_throws ArgumentError setoutputpower!(laser, NaN)
            # (`require_clamp`'s fresh reads come first; nothing is sent.)
            @test all(c -> c in guard, FakeKinesis.calls)
            @test isempty(FakeKinesis.setpoints)
            @test isnan(laser.pd.output_power_requested)

            # 50 mW -> 50/1000/224.2 A of photocurrent -> a word of 1 mA full scale.
            # With the output off it is recorded only; light_on sends it after enabling.
            empty!(FakeKinesis.calls)
            setoutputpower!(laser, 50.0)
            i_pd = 50.0 / 1000 / 224.2
            # ... after the two fresh reads `require_clamp` makes before emitting.
            @test FakeKinesis.calls == [guard..., "LD_GetStatusBits"]
            @test isempty(FakeKinesis.setpoints)
            @test laser.pd.output_power_requested == 50.0
            empty!(FakeKinesis.calls)
            light_on(laser)
            # The ramp is off by default (jumps were reliable on the rig when last
            # tested): enable, read the held setpoint, one write, confirmed.
            @test isinf(laser.pd.ramp_step_mW)
            @test FakeKinesis.calls == [guard..., "LD_EnableOutput", "LD_SetLaserSetPoint", "LD_GetLaserSetPoint",
                                        "LD_GetPhotoCurrentReading"] # the last is check_lock's
            code = FakeKinesis.setpoints[end]
            @test code == UInt16(floor(i_pd / 1e-3 * 32767))
            @test FakeKinesis.setpoint_held[] == code
            # With the ramp enabled (the safeguard verified on the rig), the same
            # 0 -> 50 mW is walked in ~3 mW steps: ~16 intermediate sends, then
            # the final one, confirmed. It starts from 0, not from a read-back.
            light_off(laser)
            laser.pd.ramp_step_mW = 3.0
            try
                empty!(FakeKinesis.calls); empty!(FakeKinesis.setpoints)
                light_on(laser)
                @test FakeKinesis.calls[1:5] == [guard..., "LD_EnableOutput"]
                @test FakeKinesis.calls[end] == "LD_GetPhotoCurrentReading"
                @test FakeKinesis.calls[end-1] == "LD_GetLaserSetPoint"
                @test all(==("LD_SetLaserSetPoint"), FakeKinesis.calls[6:end-2])
                @test FakeKinesis.setpoints[end] == code
                step = round(Int, 3.0 / 1000 / 224.2 / 1e-3 * 32767)
                @test 15 <= length(FakeKinesis.setpoints) <= 18
                @test issorted(FakeKinesis.setpoints)
                @test all(d -> 0 < d <= step, diff(Int.(FakeKinesis.setpoints)))
            finally
                laser.pd.ramp_step_mW = Inf
            end
            # With the output on, a new power is sent and confirmed at once (after
            # checking the photodiode is not reading 0x8000, over range).
            empty!(FakeKinesis.calls)
            setoutputpower!(laser, 50.0)
            @test FakeKinesis.calls == [guard..., "LD_GetStatusBits", "LD_GetPhotoCurrentReading", "LD_SetLaserSetPoint", "LD_GetLaserSetPoint",
                                        "LD_GetPhotoCurrentReading"]
            # Downward steps are sent directly, no ramp.
            empty!(FakeKinesis.calls); empty!(FakeKinesis.setpoints)
            setoutputpower!(laser, 10.0)
            @test length(FakeKinesis.setpoints) == 1
            setoutputpower!(laser, 50.0)
            # 0x8000 is the rig controller's over-range reading: refuse, and report it.
            FakeKinesis.photocurrent_raw[] = -32768
            @test_throws "OVER" setoutputpower!(laser, 20.0)
            @test measured_photocurrent(laser) == Inf
            @test loop_status(laser).tia_over
            FakeKinesis.photocurrent_raw[] = 0
            light_off(laser)
            # The DECODED setpoint: never above the request, within one code of it.
            @test laser.pd.photocurrent_requested == Float64(code) / 32767 * 1e-3
            @test laser.pd.photocurrent_requested <= i_pd
            @test i_pd - laser.pd.photocurrent_requested < 1e-3 / 32767
            @test isnan(laser.drive_current) # the loop owns the current

            # The helper's guarantee holds across the range.
            for p in range(1.0, 70.0; length=200)
                c = TCube.photocurrent_code(laser, p / 1000 / 224.2)
                @test TCube.photocurrent_from_code(laser, c, 1e-3) <= p / 1000 / 224.2
            end
            @test_throws "DIP" TCube.photocurrent_code(laser, 2e-3)

            # The status word can refuse: over range always ...
            FakeKinesis.setbits!(FakeKinesis.TIA_OVER)
            @test_throws "OVER" setoutputpower!(laser, 20.0)
            FakeKinesis.setbits!(FakeKinesis.TIA_OVER; on=false)
            # ... under range only while the output is on.
            FakeKinesis.setbits!(FakeKinesis.TIA_UNDER)
            setoutputpower!(laser, 20.0)
            @test laser.pd.output_power_requested == 20.0
            light_on(laser)
            # UNDER range (small signal for the range) warns but is not a refusal:
            # the rig regulated correctly with it set at 1 mW.
            @test_logs (:warn,) match_mode = :any setoutputpower!(laser, 30.0)
            @test laser.pd.output_power_requested == 30.0
            FakeKinesis.setbits!(FakeKinesis.TIA_UNDER; on=false)
            # ... and a controller that left closed loop behind the driver's back.
            FakeKinesis.setbits!(FakeKinesis.CLOSED; on=false)
            @test_throws "closed loop" setoutputpower!(laser, 30.0)
            FakeKinesis.setbits!(FakeKinesis.CLOSED)
            # A setpoint the controller does not confirm is not recorded.
            FakeKinesis.setpoint_readback[] = UInt16(3)
            @test_throws ErrorException setoutputpower!(laser, 30.0)
            @test laser.pd.output_power_requested == 30.0 # the last confirmed request
        end

        @testset "light_on / light_off around the setpoint (fake SDK)" begin
            # The rig's TLD001 ignores setpoints while its output is off. So
            # light_on must send the recorded request right AFTER enabling, and
            # light_off must zero the setpoint BEFORE disabling.
            FakeKinesis.reset!()
            FakeKinesis.setpoint_held[] = FakeKinesis.STALE_SETPOINT # a controller left near full scale
            laser = cc()
            initialize(laser)
            empty!(FakeKinesis.setpoints) # initialize zeroed the output it found
            # Nothing requested yet: light_on replaces the stale word with 0.
            light_on(laser)
            @test FakeKinesis.setpoints == [UInt16(0)]
            @test laser.properties.is_on
            setcurrent!(laser, 80.0)
            empty!(FakeKinesis.calls); empty!(FakeKinesis.setpoints)
            light_off(laser)
            # One write of 0, no status read and no read-back wait, then the disable.
            @test FakeKinesis.calls == ["LD_SetLaserSetPoint", "LD_DisableOutput"]
            @test FakeKinesis.setpoints == [UInt16(0)]
            @test FakeKinesis.setpoint_held[] == 0
            @test laser.drive_current == 80.0 # the request survives the off
            # ... and light_on returns to it.
            light_on(laser)
            @test FakeKinesis.setpoint_held[] == TCube.setpoint_code(laser, 80.0)
            light_off(laser)

            # If light_on cannot confirm the setpoint, the output goes back off.
            FakeKinesis.setpoint_readback[] = UInt16(3)
            @test_throws ErrorException light_on(laser)
            @test FakeKinesis.bits[] & FakeKinesis.ENABLED == 0
            @test laser.properties.is_on == false
            FakeKinesis.setpoint_readback[] = nothing

            # A zero that fails never prevents light_off's disable.
            light_on(laser)
            FakeKinesis.fail!("LD_SetLaserSetPoint")
            @test_logs (:error, r"zeroing the setpoint") match_mode = :any light_off(laser)
            @test FakeKinesis.bits[] & FakeKinesis.ENABLED == 0
            @test laser.properties.is_on == false
            FakeKinesis.setpoint_readback[] = nothing

            # ... and if the disable fails too, the output may still be on, so
            # is_on stays true and the error says so.
            FakeKinesis.reset!()
            pl = cp()
            initialize(pl)
            setoutputpower!(pl, 20.0)
            FakeKinesis.setpoint_readback[] = UInt16(3)
            FakeKinesis.fail!("LD_DisableOutput")
            @test_logs (:error, r"may still be ON") match_mode = :any @test_throws ErrorException light_on(pl)
            @test pl.properties.is_on == true
            FakeKinesis.reset!()
        end

        @testset "readbacks (fake SDK)" begin
            FakeKinesis.reset!()
            laser = cc(; threshold_current=65.0)
            # The diode current reading is signed: -5957 is -40 mA, not ~440.
            FakeKinesis.current_raw[] = -5957
            @test measured_current(laser) ≈ -40.0 rtol = 1e-3
            FakeKinesis.current_raw[] = 40000
            @test_throws "protocol" measured_current(laser)
            FakeKinesis.current_raw[] = 5957
            @test measured_current(laser) == TCube.setpoint_current(laser, 5957)

            # Photocurrent is scaled over the range: in open loop the range the
            # status word reports, which is how a W/A calibration is measured.
            FakeKinesis.photocurrent_raw[] = 16383
            @test measured_photocurrent(laser) ≈ 0.5e-3 rtol = 1e-4
            FakeKinesis.photocurrent_raw[] = 40000
            @test_throws "protocol" measured_photocurrent(laser)
            FakeKinesis.photocurrent_raw[] = 16383

            # loop_status: one snapshot. Output off -> not "below threshold".
            s = loop_status(laser)
            @test s.word == FakeKinesis.bits[]
            @test s.key && s.interlock && s.psu_ok && !s.output_enabled && !s.closed_loop
            @test s.tia_range_A == 1e-3
            @test s.current_mA == TCube.setpoint_current(laser, 5957)
            @test s.below_threshold === false
            # On, commanded, and the current under the declared threshold: not lasing.
            FakeKinesis.setbits!(FakeKinesis.ENABLED)
            laser.drive_current = 40.0
            @test loop_status(laser).below_threshold === true
            # An unknown threshold is reported as unchecked, never as passed.
            @test loop_status(cc()).below_threshold === missing
            FakeKinesis.setbits!(0x00000400)
            @test loop_status(laser).saturated

            # Power mode: scaled over the stated range, and converted at the output.
            FakeKinesis.reset!()
            pl = cp()
            FakeKinesis.photocurrent_raw[] = 7307
            @test measured_photocurrent(pl) == 7307 / 32767 * 1e-3
            @test indicated_output_power(pl) ≈ 7307 / 32767 * 1e-3 * 224.2 * 1000
            @test indicated_output_power(pl) ≈ 50.0 rtol = 1e-3
            @test loop_status(pl).photocurrent_A == measured_photocurrent(pl)
            # Every readback is a cache read: no request, no command.
            @test all(c -> startswith(c, "LD_Get"), FakeKinesis.calls)

            # `tcube_get_current` still issues its own request.
            FakeKinesis.reset!(limit_raw=5957)
            @test TCube.tcube_get_current(cc()) == TCube.setpoint_current(cc(), 5957)
            @test "LD_RequestReadings" in FakeKinesis.calls
        end

        @testset "setlevel! maps onto each mode's declared range (fake SDK)" begin
            FakeKinesis.reset!(limit_raw=22341) # 149.99 mA: under the 150 ceiling, so the pot is left alone
            laser = cc(; min_current=70.0, max_current=150.0)
            initialize(laser)
            setlevel!(laser, 0.0)
            @test laser.drive_current == 70.0 # the floor, which still emits: not off
            setlevel!(laser, 1.0)
            @test laser.drive_current ≈ 150.0 atol = 0.02
            setlevel!(laser, 0.25)
            @test laser.drive_current ≈ 90.0 atol = 0.02
            @test_throws ArgumentError setlevel!(laser, 1.5)
            @test_throws ArgumentError setlevel!(laser, -0.1)

            FakeKinesis.reset!()
            pl = cp()
            initialize(pl)
            setlevel!(pl, 0.0)
            @test pl.pd.output_power_requested == 1.0
            setlevel!(pl, 1.0)
            @test pl.pd.output_power_requested == 70.0
            setlevel!(pl, 0.5)
            @test pl.pd.output_power_requested ≈ 35.5
        end

        @testset "shutdown closes the connection either way (fake SDK)" begin
            FakeKinesis.reset!()
            laser = cc()
            laser.properties.is_on = true
            shutdown(laser)
            # The zero is one write, with no status read and no read-back wait (a
            # setpoint sent with the output off is ignored), then the disable.
            @test FakeKinesis.calls == ["LD_SetLaserSetPoint", "LD_DisableOutput", "LD_StopPolling", "LD_Close"]
            @test laser.properties.is_on == false

            # A failed disable throws -- and the handle is closed anyway,
            # because leaving it open would block the reconnection a caller
            # needs in order to retry that disable.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_DisableOutput", 5)
            stuck = cc()
            stuck.properties.is_on = true
            err = try
                shutdown(stuck)
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("LD_DisableOutput", err.msg)
            @test FakeKinesis.calls == ["LD_SetLaserSetPoint", "LD_DisableOutput", "LD_StopPolling", "LD_Close"] # closed regardless
            # The disable failed, so the output is not recorded as off.
            @test stuck.properties.is_on == true

            # With the output on, the setpoint is zeroed BEFORE the disable, so
            # the controller is left holding 0: the next enable, by this driver or
            # any other software, starts dark instead of on a stale word.
            FakeKinesis.reset!()
            pl = cp()
            initialize(pl)
            setoutputpower!(pl, 50.0)
            light_on(pl)
            @test FakeKinesis.setpoint_held[] != 0
            empty!(FakeKinesis.calls)
            shutdown(pl)
            @test FakeKinesis.calls == ["LD_SetLaserSetPoint", "LD_DisableOutput", "LD_StopPolling", "LD_Close"]
            @test FakeKinesis.setpoint_held[] == 0
            @test pl.pd.output_power_requested == 50.0 # the request is kept
        end

        @testset "Setpoint encoding" begin
            # The ceiling has to hold at the wire, not just in the check.
            # Rounding put the 160 mA ceiling at code 23831 = 160.00305 mA on
            # the driver's own scale, so the one request sitting exactly on the
            # enforced limit was the one to exceed it.
            FakeKinesis.reset!()
            laser = cc()
            FakeKinesis.setbits!(FakeKinesis.ENABLED) # output on: setpoints are sent at once
            setcurrent!(laser, 160.0)
            @test FakeKinesis.setpoints == [UInt16(23830)]
            encoded(l, code) = Float64(code) / l.max_setpoint * l.max_setcurrent
            @test encoded(laser, FakeKinesis.setpoints[end]) <= 160.0

            # The guarantee is stated in terms of the driver's own decode, so
            # check that this testset's `encoded` is that same arithmetic.
            @test encoded(laser, 12345) == TCube.setpoint_current(laser, 12345)

            for request in (0.0, 0.5, 1.0, 37.3, 99.9, 159.999, 160.0)
                @test encoded(laser, TCube.setpoint_code(laser, request)) <= request
            end
            @test TCube.setpoint_code(laser, 0.0) == 0x0000

            # Truncation alone did NOT deliver that: the scaling can round a
            # request one ulp below a code boundary up onto the boundary.
            just_under_9 = prevfloat(9.0 / 32767.0 * 220.0) # 0.06042664876247444
            @test floor(just_under_9 / laser.max_setcurrent * laser.max_setpoint) == 9.0
            @test encoded(laser, UInt16(9)) > just_under_9
            @test TCube.setpoint_code(laser, just_under_9) == UInt16(8)

            # Not one special case: sweep the predecessor of every code
            # boundary below the default 160 mA ceiling.
            boundary_neighbours = [prevfloat(Float64(k) / laser.max_setpoint * laser.max_setcurrent) for k in 1:23830]
            @test all(r -> encoded(laser, TCube.setpoint_code(laser, r)) <= r, boundary_neighbours)
            @test all(k -> TCube.setpoint_code(laser, boundary_neighbours[k]) == UInt16(k - 1), 1:23830)
            @test all(k -> TCube.setpoint_code(laser, Float64(k) / laser.max_setpoint * laser.max_setcurrent) == UInt16(k),
                (1, 9, 5957, 23830))

            # The bottom of the range commands nothing, and says so.
            one_code = laser.max_setcurrent / laser.max_setpoint
            @test TCube.setpoint_code(laser, prevfloat(one_code)) == 0x0000
            @test TCube.setpoint_code(laser, 0.001) == 0x0000
            FakeKinesis.reset!()
            FakeKinesis.setbits!(FakeKinesis.ENABLED)
            setcurrent!(laser, 0.001)
            @test FakeKinesis.setpoints == [UInt16(0)] # a ZERO SETPOINT is sent --
            @test laser.properties.is_on == false      # not an "off": is_on is untouched
            @test laser.drive_current == 0.001         # and the field keeps the request
            @test export_state(laser)[1]["drive_current"] == 0.001

            # Conversion parameters are validated before converting.
            FakeKinesis.reset!()
            @test_throws ArgumentError setcurrent!(cc(; max_setcurrent=0.0), 0.0)
            @test_throws ArgumentError setcurrent!(cc(; max_setcurrent=NaN), 80.0)
            @test_throws ArgumentError setcurrent!(cc(; max_setpoint=100000.0), 160.0)
            @test_throws ArgumentError setcurrent!(cc(; min_current=-10.0), -5.0)
            @test isempty(FakeKinesis.setpoints) # none of them reached the SDK

            offender(l, c) = try
                setcurrent!(l, c)
                ""
            catch e
                e.msg
            end
            @test occursin("max_setcurrent", offender(cc(; max_setcurrent=NaN), 80.0))
            @test occursin("max_setpoint", offender(cc(; max_setpoint=100000.0), 160.0))
            @test occursin("non-negative", offender(cc(; min_current=-10.0), -5.0))
        end

        @testset "tcube_refresh explains itself instead of firing" begin
            FakeKinesis.reset!()
            laser = cc()
            err = try
                tcube_refresh(laser)
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("90 mA", err.msg)       # says what it used to do ...
            @test occursin("setcurrent!", err.msg) # ... and what to call instead
            @test isempty(FakeKinesis.calls)       # and reaches no hardware
            @test :tcube_refresh in names(MicroscopeControl)
        end

        @testset "export_state" begin
            laser = cc(; daq_device="Dev2", ao_channel="Dev2/ao1", threshold_current=65.0)
            attrs, data, children = export_state(laser)
            @test attrs isa Dict{String,Any}
            @test attrs["regulation_mode"] == "ConstantCurrent"
            @test attrs["setpoint_unit"] == "mA"
            @test attrs["min_current_mA"] == 0.0
            @test attrs["max_current_mA"] == 160.0
            @test attrs["threshold_current_mA"] == 65.0
            @test isnan(attrs["controller_max_current"])
            @test isnan(attrs["drive_current"]) # nothing commanded yet
            @test attrs["daq_device"] == "Dev2"
            @test attrs["ao_channel"] == "Dev2/ao1"
            # 0.2.4's keys are kept next to the new ones.
            for k in ("min_current", "max_current", "power_unit", "power", "min_power", "max_power")
                @test haskey(attrs, k)
            end
            @test attrs["min_current"] == 0.0 && attrs["max_current"] == 160.0
            @test attrs["power_unit"] == "mA"
            @test attrs["max_power"] == 160.0
            # setcurrent! writes 0.2.4's deprecated figure to properties.power.
            FakeKinesis.reset!()
            lp = cc()
            initialize(lp)
            setcurrent!(lp, 80.0)
            @test lp.properties.power == TCube.legacy_power(lp, 80.0)
            @test export_state(lp)[1]["power"] == lp.properties.power
            @test !haskey(attrs, "wa_calibration_W_per_A") # open loop has no calibration
            @test data === nothing
            @test haskey(children, "daq")
            @test export_state(cc())[1]["daq_device"] == ""
            # The deprecated 2-argument forwarder still works.
            @test export_state(laser, nothing)[1]["serialNo"] == "00000000"

            FakeKinesis.reset!()
            pl = cp(; threshold_current=65.0)
            initialize(pl)
            setoutputpower!(pl, 50.0)
            a = export_state(pl)[1]
            @test a["regulation_mode"] == "ConstantPhotocurrent"
            @test a["setpoint_unit"] == "mW"
            @test a["power_reference"] == "laser output"
            @test a["min_output_power_mW"] == 1.0 && a["max_output_power_mW"] == 70.0
            @test a["wa_calibration_W_per_A"] == 224.2
            @test a["tia_range_A"] == 1e-3
            @test a["tec_stabilised"] == "unknown" # `missing` is not HDF5-safe
            @test a["max_current_clamp_mA"] == pl.pd.max_current_clamp
            @test a["output_power_requested_mW"] == 50.0
            @test a["photocurrent_requested_A"] == pl.pd.photocurrent_requested
            @test export_state(cp(; tec_stabilised=true))[1]["tec_stabilised"] == "true"
            # And it round-trips through HDF5.
            mktempdir() do dir
                path = joinpath(dir, "cp.h5")
                wait(save_h5(path, export_state(pl)))
                HDF5.h5open(path, "r") do f
                    @test HDF5.read_attribute(f["Main"], "regulation_mode") == "ConstantPhotocurrent"
                    @test HDF5.read_attribute(f["Main"], "tec_stabilised") == "unknown"
                end
            end
        end
    end

    # The simulated twin carries the physics the fake SDK cannot: a diode whose
    # light follows current above threshold, a photodiode whose responsivity
    # can drift, and a loop that raises current until the photocurrent matches
    # its setpoint or the clamp stops it. `true_output_power` is the oracle a
    # driver can never report.
    @testset "Simulated Diode Laser" begin
        SimDL = MicroscopeControl.HardwareImplementations.SimulatedDiodeLaser
        sim_cc(; kw...) = SimDiodeLaser(; mode=ConstantCurrent(), kw...)
        sim_cp(; kw...) = SimDiodeLaser(; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                                        tec_stabilised=missing,
                                        properties=LightSourceProperties("mW", 0.0, false, 1.0, 70.0), kw...)

        @test sim_cc() isa DiodeLaser
        @test_throws ArgumentError SimDiodeLaser()
        @test_throws ArgumentError SimDiodeLaser(; mode=ConstantPhotocurrent())

        @testset "1. the loop converges on the requested power" begin
            sim = sim_cp()
            initialize(sim)
            setoutputpower!(sim, 40.0)
            light_on(sim)
            @test indicated_output_power(sim) ≈ 40.0 rtol = 1e-3
            @test SimDL.true_output_power(sim) ≈ 40.0 rtol = 1e-3 # the calibration starts true
            @test measured_current(sim) > sim.threshold_current
            s = loop_status(sim)
            @test s.closed_loop && s.output_enabled && !s.saturated
            @test s.below_threshold === false
        end

        @testset "2. a blocked photodiode drives the current to the clamp" begin
            sim = sim_cp(; pd_blocked=true)
            initialize(sim)
            setoutputpower!(sim, 40.0)
            light_on(sim)
            @test measured_current(sim) == sim.pd.max_current_clamp
            @test loop_status(sim).saturated
            @test indicated_output_power(sim) ≈ 0.0 atol = 1e-9
        end

        @testset "3. responsivity drift: the number stays flat, the light does not" begin
            sim = sim_cp()
            initialize(sim)
            setoutputpower!(sim, 40.0)
            light_on(sim)
            before = SimDL.true_output_power(sim)
            sim.responsivity_drift = 0.15 # the photodiode warms up
            @test indicated_output_power(sim) ≈ 40.0 rtol = 1e-3 # what the driver reports
            @test abs(SimDL.true_output_power(sim) - before) / before > 0.1 # what the sample gets
        end

        @testset "4. each unit-true setter exists only in its own mode" begin
            c, p = sim_cc(), sim_cp()
            initialize(c); initialize(p)
            @test_throws "not implemented" setcurrent!(p, 80.0)
            @test_throws "not implemented" setoutputpower!(c, 10.0)
            @test_throws "setoutputpower!" setpower(p, 80.0)
            @test_deprecated setpower(c, 80.0)
            @test c.drive_current == 80.0
        end

        @testset "5. commands before initialize and after shutdown throw, state unchanged" begin
            for sim in (sim_cc(), sim_cp())
                @test_throws "not initialized" light_on(sim)
                @test_throws "not initialized" loop_status(sim)
                @test_throws "not initialized" setlevel!(sim, 0.5)
                @test isnan(sim.drive_current)
                initialize(sim)
                setlevel!(sim, 0.5)
                shutdown(sim)
                requested = sim.pd === nothing ? sim.drive_current : sim.pd.output_power_requested
                @test_throws "not initialized" setlevel!(sim, 0.9)
                @test_throws "not initialized" measured_current(sim)
                @test requested == (sim.pd === nothing ? sim.drive_current : sim.pd.output_power_requested)
            end
        end

        @testset "6. amplifier over/under range make setoutputpower! refuse" begin
            sim = sim_cp()
            initialize(sim)
            sim.tia_over_fault = true
            @test_throws "OVER" setoutputpower!(sim, 20.0)
            sim.tia_over_fault = false
            sim.tia_under_fault = true
            setoutputpower!(sim, 20.0) # under range with the output off is expected
            light_on(sim)
            @test_throws "UNDER" setoutputpower!(sim, 30.0)
            @test sim.pd.output_power_requested == 20.0
            # A moved DIP switch is refused at initialize.
            @test_throws "range" initialize(sim_cp(; tia_range_A=10e-3))
            @test_throws "interlock" initialize(sim_cp(; interlock=false))
        end

        # 7 (opening a panel issues nothing) is in test/gui.jl.

        @testset "8. setlevel! endpoints, linear in the regulated quantity" begin
            c = sim_cc(; min_current=70.0, max_current=150.0, threshold_current=65.0)
            initialize(c)
            setlevel!(c, 0.0)
            @test c.drive_current == 70.0
            light_on(c)
            @test SimDL.true_output_power(c) > 0 # the floor is above threshold, so 0 emits
            setlevel!(c, 1.0)
            @test c.drive_current == 150.0
            setlevel!(c, 0.5)
            @test c.drive_current ≈ 110.0

            p = sim_cp()
            initialize(p)
            setlevel!(p, 0.0)
            @test p.pd.output_power_requested == 1.0
            setlevel!(p, 1.0)
            @test p.pd.output_power_requested == 70.0
            setlevel!(p, 0.5)
            @test p.pd.output_power_requested ≈ 35.5
            light_on(p)
            @test indicated_output_power(p) ≈ 35.5 rtol = 1e-3
        end

        @testset "9. the same setlevel! sequence runs against both modes" begin
            # The property the one-line mode switch depends on: code written
            # against setlevel!, light_on, loop_status and export_state needs
            # no edit when the construction line changes mode.
            function sequence!(laser)
                initialize(laser)
                for f in (0.0, 0.3, 1.0, 0.6)
                    setlevel!(laser, f)
                end
                light_on(laser)
                s = loop_status(laser)
                attrs = export_state(laser)[1]
                light_off(laser)
                shutdown(laser)
                return s, attrs
            end
            for laser in (sim_cc(; min_current=70.0, max_current=150.0), sim_cp())
                s, attrs = sequence!(laser)
                @test s.output_enabled
                @test !s.saturated
                @test attrs["regulation_mode"] == string(nameof(typeof(regulation_mode(laser))))
            end
        end

        @testset "export_state matches the hardware driver's attribute names" begin
            hw = Set(keys(export_state(TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2,
                tia_range=1e-3, tec_stabilised=missing, properties=LightSourceProperties("mW", 0.0, false, 1.0, 70.0), max_current=160.0))[1]))
            simk = Set(keys(export_state(sim_cp())[1]))
            @test issubset(simk, hw)
            @test "power_reference" in simk && "wa_calibration_W_per_A" in simk
        end

        include("tcube_output_order.jl")
    end

    @testset "NIdaq digital output" begin
        # Digital scalar writes are PORT format: bit n is line n of the port,
        # even for a single-line task. Confirmed on hardware (NI-DAQmx 23.5,
        # USB-6008): a shutter on port0/line1 ignored 1 and responded to 2.
        # `do_port_word` is the whole of the fix and is testable without a DAQ.
        DAQ = MicroscopeControl.HardwareImplementations.NIDAQcard

        # A line task: the value is a level and lands on that line's bit.
        @test DAQ.do_port_word(["Dev1/port0/line0"], 1.0) === UInt32(1)
        @test DAQ.do_port_word(["Dev1/port0/line1"], 1.0) === UInt32(2)
        @test DAQ.do_port_word(["Dev1/port0/line3"], 1.0) === UInt32(8)
        @test DAQ.do_port_word(["Dev1/port1/line2"], 1.0) === UInt32(4)
        @test DAQ.do_port_word(["Dev1/port0/line7"], 1.0) === UInt32(128)
        # Zero clears that line, whichever line it is.
        @test DAQ.do_port_word(["Dev1/port0/line5"], 0.0) === UInt32(0)

        # The defect itself: before the fix every one of these was UInt32(1),
        # so only line0 could ever be driven.
        @test DAQ.do_port_word(["Dev1/port0/line1"], 1.0) != UInt32(1)

        # A pre-shifted port word on a line task is refused, because shifting
        # it again would drive a different line.
        @test_throws ErrorException DAQ.do_port_word(["Dev1/port0/line1"], 2.0)
        @test_throws ErrorException DAQ.do_port_word(["Dev1/port0/line3"], 8.0)

        # A port-wide task keeps the old pass-through: the value IS the word.
        @test DAQ.do_port_word(["Dev1/port0"], 8.0) === UInt32(8)
        @test DAQ.do_port_word(["Dev1/port1"], 0.0) === UInt32(0)

        # Several channels in one task is ambiguous and is refused.
        @test_throws ErrorException DAQ.do_port_word(
            ["Dev1/port0/line0", "Dev1/port0/line1"], 1.0)

        # A name that is neither a line nor a port is REFUSED, not assumed to
        # be a port. `channel_names` returns VIRTUAL names, which DAQmx lets
        # you assign independently of the physical line, so a renamed line task
        # would otherwise fall through to port semantics and reproduce the
        # original defect exactly.
        @test_throws ErrorException DAQ.do_port_word(["shutter"], 1.0)
        @test_throws ErrorException DAQ.do_port_word(["Dev1/myLine"], 1.0)
        # A line RANGE needs a grouping policy this driver does not have.
        @test_throws ErrorException DAQ.do_port_word(["Dev1/port0/line0:3"], 1.0)
        # A line with no port still reads as a line.
        @test DAQ.do_port_word(["Dev1/line5"], 1.0) === UInt32(32)
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
end  # lab_summary
