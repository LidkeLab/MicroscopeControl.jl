using MicroscopeControl
using Test

const HDF5 = MicroscopeControl.HDF5

# Replaces the TCube laser's Kinesis wrappers with a recorder, so the driver's
# own `initialize`/`setpower`/`shutdown` can be run without a controller. Must
# be included at top level, before the testsets. See the file for the seam.
include("tcube_fake_sdk.jl")

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
    # answers: see CHANGELOG 0.3.0, hardware verification NOT DONE.
    @testset "TCube Laser (no hardware)" begin
        TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl

        @testset "Constructor defaults" begin
            laser = TCubeLaser("00000000")
            # 60.0 mA used to be the default floor: not a floor at all, since
            # it is a *lower* bound, so it only rejected safe small currents.
            @test laser.min_current == 0.0
            @test laser.max_current == 160.0
            # `initialize` records the controller's limit here, not over the
            # caller's `max_current`; NaN means "not read yet".
            @test isnan(laser.controller_max_current)
            # setpower takes mA and now says so.
            @test laser.properties.power_unit == "mA"
            @test laser.daq_device === nothing
            @test laser.ao_channel === nothing
        end

        @testset "Current validation" begin
            laser = TCubeLaser("00000000")

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
            floored = TCubeLaser("00000000"; min_current=20.0)
            @test_throws ArgumentError TCube.check_current(floored, 10.0)

            # Above the setpoint DAC's full scale is rejected as out of range
            # rather than dying in `UInt16(...)` with an InexactError.
            wide = TCubeLaser("00000000"; max_current=400.0)
            @test TCube.effective_max_current(wide) == wide.max_setcurrent
            @test_throws ArgumentError TCube.check_current(wide, 300.0)
        end

        @testset "Caller ceiling survives the controller's limit" begin
            # The 1b-bis regression: `initialize` used to assign the
            # controller's limit straight over `max_current`, so a rig that
            # asked for 80 mA on a weak diode silently got the controller's
            # 160-220 mA, and `setpower` then validated against the
            # controller. `record_controller_limit!` is the field-writing half
            # of `initialize` with the SDK read removed.
            laser = TCubeLaser("00000000"; max_current=80.0)
            raw = UInt16(round(160.0 / laser.max_setcurrent * laser.max_setpoint))
            TCube.record_controller_limit!(laser, raw)

            @test laser.max_current == 80.0 # untouched
            # rtol, not the default: the raw reading is a UInt16 setpoint, so
            # 160.0 mA round-trips as 160.003 mA.
            @test laser.controller_max_current ≈ 160.0 rtol = 1e-3 # recorded separately
            @test TCube.effective_max_current(laser) == 80.0
            @test_throws ArgumentError TCube.check_current(laser, 100.0)

            # ... and the controller wins when it is the stricter of the two.
            strict = TCubeLaser("00000000"; max_current=200.0)
            TCube.record_controller_limit!(strict, UInt16(round(120.0 / strict.max_setcurrent * strict.max_setpoint)))
            @test TCube.effective_max_current(strict) ≈ 120.0 rtol = 1e-3
            @test_throws ArgumentError TCube.check_current(strict, 150.0)
        end

        @testset "setpower rejects before touching the SDK" begin
            # Ordering, not just rejection. `setpower`'s first statement is
            # the range check, so an out-of-range request must fail with the
            # check's own `ArgumentError`. Under the old code the check was an
            # `@error` log and execution continued, so the exception *type* is
            # what distinguishes "refused" from "attempted".
            #
            # 200.0 mA is the case that matters and the reason it is here
            # rather than 500.0 alone: it is over the 160 mA ceiling but under
            # `max_setcurrent`, so it converts to a valid `UInt16` setpoint and
            # the old code carried it all the way into the
            # `LD_SetLaserSetPoint` ccall (executed against the pre-fix driver:
            # `ErrorException`, "could not load library ...LaserDiode.dll" --
            # on a Windows rig that call would have driven 200 mA into the
            # diode). 500.0 and -5.0 happen to die earlier, in `UInt16(...)`
            # with an `InexactError`, which is a crash rather than a refusal.
            FakeKinesis.reset!()
            laser = TCubeLaser("00000000")
            @test_throws ArgumentError setpower(laser, 200.0)
            @test_throws ArgumentError setpower(laser, 500.0)
            @test_throws ArgumentError setpower(laser, -5.0)
            # A refused request must not be recorded as the laser's state.
            # The old code wrote it before the call: `setpower(laser, 200.0)`
            # left `properties.power == 125.0` (executed).
            @test laser.properties.power == 0.0
            # And "before touching the SDK" is now an observation rather than
            # an inference: the fake records every setpoint it is handed.
            @test isempty(FakeKinesis.setpoints)
            @test isempty(FakeKinesis.calls)
        end

        @testset "initialize keeps the caller's ceiling (fake SDK)" begin
            # The regression this driver was fixed for lives inside
            # `initialize`, so this runs the real `initialize` against the fake
            # Kinesis SDK. Restoring the old `light.max_current = ...`
            # assignment must fail this testset; testing
            # `record_controller_limit!` alone did not, which is why this
            # exists.
            FakeKinesis.reset!() # controller reports a 160 mA limit
            laser = TCubeLaser("00000000"; max_current=80.0)
            initialize(laser)

            @test FakeKinesis.calls == ["TLI_BuildDeviceList", "TLI_GetDeviceListSize",
                "LD_Open", "LD_SetOpenLoopMode", "LD_RequestReadings",
                "LD_GetLaserDiodeMaxCurrentLimit"]
            @test laser.max_current == 80.0 # survived initialize
            @test laser.controller_max_current ≈ 160.0 rtol = 1e-3
            @test TCube.effective_max_current(laser) == 80.0

            # The consequence, which is the point: a post-initialize request
            # between the caller's ceiling and the controller's is refused, and
            # nothing reaches the SDK.
            empty!(FakeKinesis.setpoints)
            @test_throws ArgumentError setpower(laser, 100.0)
            @test isempty(FakeKinesis.setpoints)
            # ... while one under the caller's ceiling is sent. The exact code
            # matters, not just that a call happened: sending code 0 for this
            # accepted request passed every assertion here until the setpoint
            # itself was pinned. 40 mA is floor(40/220*32767) = 5957, which
            # decodes to 39.9957 mA -- at or below the request, as always.
            setpower(laser, 40.0)
            @test FakeKinesis.setpoints == [UInt16(5957)]
            @test Float64(5957) / laser.max_setpoint * laser.max_setcurrent <= 40.0
            @test laser.properties.power == 40.0

            # A second initialize, with a different controller reading. One
            # fixture does not establish that the reading is what determines
            # the stored limit: replacing the recording with a constant 160.0
            # while still calling the SDK passed everything above. This limit
            # is also *below* the caller's ceiling, so the `min` in
            # `effective_max_current` is exercised in the other direction too.
            FakeKinesis.reset!(limit_raw=8936) # 8936/32767*220 = 59.997 mA
            weak = TCubeLaser("00000000"; max_current=80.0)
            initialize(weak)
            @test weak.controller_max_current ≈ 60.0 rtol = 1e-3
            @test weak.max_current == 80.0 # still the caller's
            @test TCube.effective_max_current(weak) == weak.controller_max_current # controller is stricter now
            @test_throws ArgumentError setpower(weak, 70.0) # between the two ceilings
            @test isempty(FakeKinesis.setpoints)
        end

        @testset "a failed initialize closes the connection (fake SDK)" begin
            # A controller left open refuses the next LD_Open, so a failure
            # after the open must not leak the handle -- and the error the
            # caller sees must be the one that stopped initialization.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_SetOpenLoopMode", 3)
            laser = TCubeLaser("00000000")
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
                "LD_Open", "LD_SetOpenLoopMode", "LD_Close"]
            @test isnan(laser.controller_max_current) # nothing recorded

            # A failure at the open itself has no handle to close.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_Open", 2)
            @test_throws ErrorException initialize(TCubeLaser("00000000"))
            @test "LD_Close" ∉ FakeKinesis.calls

            # A close that *throws* must not displace the error that stopped
            # initialization. This is the case the cleanup's inner try/catch
            # exists for, and the only failure `LD_Close` can express: the
            # binding returns void, so there is no status code to fail with.
            # Until the fake could raise, deleting that handler -- letting the
            # close error propagate in place of the real one -- failed nothing.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_SetOpenLoopMode", 3)
            FakeKinesis.throw!("LD_Close", "fake close explosion")
            both = TCubeLaser("00000000")
            # The close failure is reported, hence the expected @error record.
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
                "LD_Open", "LD_SetOpenLoopMode", "LD_Close"] # and the close was still attempted
            @test isnan(both.controller_max_current)
        end

        @testset "shutdown closes the connection either way (fake SDK)" begin
            # `shutdown` runs against the recorder like the rest of the
            # lifecycle; nothing invoked it until this testset, so the
            # commentary above was ahead of the tests.
            FakeKinesis.reset!()
            laser = TCubeLaser("00000000")
            laser.properties.is_on = true
            shutdown(laser)
            @test FakeKinesis.calls == ["LD_DisableOutput", "LD_Close"]
            @test laser.properties.is_on == false

            # A failed disable throws -- and the handle is closed anyway,
            # because leaving it open would block the reconnection a caller
            # needs in order to retry that disable.
            FakeKinesis.reset!()
            FakeKinesis.fail!("LD_DisableOutput", 5)
            stuck = TCubeLaser("00000000")
            stuck.properties.is_on = true
            err = try
                shutdown(stuck)
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("LD_DisableOutput", err.msg)
            @test FakeKinesis.calls == ["LD_DisableOutput", "LD_Close"] # closed regardless
            # The disable failed, so the output is not recorded as off: the
            # field follows the call, not the request.
            @test stuck.properties.is_on == true
        end

        @testset "Setpoint encoding" begin
            # The ceiling has to hold at the wire, not just in the check.
            # Rounding put the 160 mA ceiling at code 23831 = 160.00305 mA on
            # the driver's own scale, so the one request sitting exactly on the
            # enforced limit was the one to exceed it.
            FakeKinesis.reset!()
            laser = TCubeLaser("00000000")
            setpower(laser, 160.0)
            @test FakeKinesis.setpoints == [UInt16(23830)]
            encoded(l, code) = Float64(code) / l.max_setpoint * l.max_setcurrent
            @test encoded(laser, FakeKinesis.setpoints[end]) <= 160.0

            # The guarantee is stated in terms of the driver's own decode, so
            # check that this testset's `encoded` is that same arithmetic
            # before using it to check the guarantee.
            @test encoded(laser, 12345) == TCube.setpoint_current(laser, 12345)

            # The commanded current never decodes above the requested one, at
            # any setpoint.
            for request in (0.0, 0.5, 1.0, 37.3, 99.9, 159.999, 160.0)
                @test encoded(laser, TCube.setpoint_code(laser, request)) <= request
            end
            @test TCube.setpoint_code(laser, 0.0) == 0x0000

            # Truncation alone did NOT deliver that, which is why the encoder
            # corrects downward afterwards. `current / max_setcurrent *
            # max_setpoint` can round a request one ulp below a code boundary
            # up onto the boundary itself, leaving `floor` nothing to cut. The
            # first such request in the default range:
            just_under_9 = prevfloat(9.0 / 32767.0 * 220.0) # 0.06042664876247444
            @test floor(just_under_9 / laser.max_setcurrent * laser.max_setpoint) == 9.0 # what floor alone gives
            @test encoded(laser, UInt16(9)) > just_under_9                               # and it is over the request
            @test TCube.setpoint_code(laser, just_under_9) == UInt16(8)                  # so the encoder steps down

            # Not one special case: 1794 of these exist below the default 160
            # mA ceiling. Sweep the predecessor of every code boundary in it.
            boundary_neighbours = [prevfloat(Float64(k) / laser.max_setpoint * laser.max_setcurrent) for k in 1:23830]
            @test all(r -> encoded(laser, TCube.setpoint_code(laser, r)) <= r, boundary_neighbours)
            # The correction is a step of exactly one code, and only when it is
            # needed: the boundary itself still encodes to its own code.
            @test all(k -> TCube.setpoint_code(laser, boundary_neighbours[k]) == UInt16(k - 1), 1:23830)
            @test all(k -> TCube.setpoint_code(laser, Float64(k) / laser.max_setpoint * laser.max_setcurrent) == UInt16(k),
                (1, 9, 5957, 23830))

            # The bottom of the range commands nothing, and says so. A positive
            # request under one code (220/32767 = 0.006714 mA here) rounds down
            # to code 0 -- rounding it up would command more than was asked for
            # -- but `properties.power` still records the request, so the field
            # is what the caller asked for and not what went to the wire.
            one_code = laser.max_setcurrent / laser.max_setpoint
            @test TCube.setpoint_code(laser, prevfloat(one_code)) == 0x0000
            @test TCube.setpoint_code(laser, 0.001) == 0x0000
            FakeKinesis.reset!()
            setpower(laser, 0.001)
            @test FakeKinesis.setpoints == [UInt16(0)] # the diode is commanded off
            @test laser.properties.power == 0.001      # while the field keeps the request

            # Conversion parameters are validated before converting. Each of
            # these passes check_current and used to die in `UInt16(...)` with
            # an InexactError.
            empty!(FakeKinesis.setpoints)
            @test_throws ArgumentError setpower(TCubeLaser("00000000"; max_setcurrent=0.0), 0.0)
            @test_throws ArgumentError setpower(TCubeLaser("00000000"; max_setcurrent=NaN), 80.0)
            @test_throws ArgumentError setpower(TCubeLaser("00000000"; max_setpoint=100000.0), 160.0)
            @test_throws ArgumentError setpower(TCubeLaser("00000000"; min_current=-10.0), -5.0)
            @test isempty(FakeKinesis.setpoints) # none of them reached the SDK

            # The message has to name the field at fault.
            offender(l, c) = try
                setpower(l, c)
                ""
            catch e
                e.msg
            end
            @test occursin("max_setcurrent", offender(TCubeLaser("00000000"; max_setcurrent=NaN), 80.0))
            @test occursin("max_setpoint", offender(TCubeLaser("00000000"; max_setpoint=100000.0), 160.0))
            @test occursin("non-negative", offender(TCubeLaser("00000000"; min_current=-10.0), -5.0))
        end

        @testset "Properties must be labelled mA" begin
            # The default is "mA", but the label is the caller's to pass, and a
            # caller passing "mW" got the accepted *current* stored under a
            # milliwatt name -- into export_state and the HDF5 attributes with
            # it. That is exactly the silent break the 0.3.0 bump announces, so
            # the constructor refuses it.
            mW = LightSourceProperties("mW", 0.0, false, 0.0, 100.0)
            @test_throws ArgumentError TCubeLaser("00000000"; properties=mW)
            err = try
                TCubeLaser("00000000"; properties=mW)
            catch e
                e
            end
            @test occursin("mW", err.msg)
            @test occursin("current", err.msg)

            # Properties that are labelled correctly are kept as given.
            ok = TCubeLaser("00000000"; properties=LightSourceProperties("mA", 0.0, false, 0.0, 220.0))
            @test ok.properties.max_power == 220.0
            @test export_state(ok)[1]["power_unit"] == "mA" # the checks refuse, they do not block

            # The constructor is the earliest check, not a barrier. Three ways
            # around it, each of which used to put a current of 40.0 into
            # exported metadata under a "mW" label. The invariant is therefore
            # enforced at the use boundary (`setpower`) and the export boundary
            # (`export_state`) as well.
            #
            # 1. `properties` is mutable and reachable through the device.
            FakeKinesis.reset!()
            mutated = TCubeLaser("00000000")
            mutated.properties.power_unit = "mW"
            @test_throws ArgumentError setpower(mutated, 40.0)
            @test isempty(FakeKinesis.setpoints) # nothing commanded under a false label
            @test_throws ArgumentError export_state(mutated)

            # 2. ... and through a reference the caller kept after passing it.
            kept = LightSourceProperties("mA", 0.0, false, 0.0, 100.0)
            aliased = TCubeLaser("00000000"; properties=kept)
            kept.power_unit = "mW"
            @test aliased.properties.power_unit == "mW" # same object, not a copy
            @test_throws ArgumentError setpower(aliased, 40.0)
            @test_throws ArgumentError export_state(aliased)

            # 3. The struct's auto-generated positional constructor never runs
            # the keyword constructor's check at all.
            t = TCubeLaser("00000000")
            positional = TCubeLaser(t.unique_id, LightSourceProperties("mW", 0.0, false, 0.0, 100.0),
                t.laser_color, t.min_current, t.max_current, t.controller_max_current,
                t.max_setcurrent, t.max_setpoint, t.serialNo, t.task_mod, t.daq,
                t.daq_device, t.ao_channel)
            @test positional.properties.power_unit == "mW" # constructed, not refused
            @test_throws ArgumentError setpower(positional, 40.0)
            @test_throws ArgumentError export_state(positional)

            @test isempty(FakeKinesis.setpoints) # none of the three reached the SDK
        end

        @testset "export_state" begin
            laser = TCubeLaser("00000000"; daq_device="Dev2", ao_channel="Dev2/ao1")
            attrs, data, children = export_state(laser) # 1-arg: used to throw
            @test attrs isa Dict{String,Any}
            @test attrs["power_unit"] == "mA"
            @test attrs["min_current"] == 0.0
            @test attrs["max_current"] == 160.0
            @test isnan(attrs["controller_max_current"])
            @test attrs["daq_device"] == "Dev2"
            @test attrs["ao_channel"] == "Dev2/ao1"
            @test data === nothing
            @test haskey(children, "daq")
            # `nothing` is not writable as an HDF5 attribute; unset must be "".
            @test export_state(TCubeLaser("00000000"))[1]["daq_device"] == ""
        end
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
