using GLMakie

# Regression tests for the lightsource_interface/gui.jl fix (CHANGELOG 0.2.1):
# constructing a device's control panel must not command the hardware. A
# `lift` evaluates immediately when it is created, so wiring a side effect
# (setpower, light_on/light_off, move, ...) to a widget's observable with
# `lift` instead of `on` used to push the widget's initial value to the
# device the instant the panel opened. `gui(::SimLight)` is the direct
# regression test: it must leave `properties.power` and `properties.is_on`
# untouched.
#
# `export_state` is used as a generic, per-device snapshot of observable
# state (attributes + data) rather than hand-listing fields, so this test
# doesn't need to know each device's field names.
function state_snapshot(device)
    attrs, data, _ = export_state(device)
    return (attrs, data)
end

# A state snapshot cannot, by itself, tell a real fix from a broken one:
# `SimLight()` starts at power `0.0` and off, which is exactly what the
# widgets now initialise from, so reverting both callbacks in
# `lightsource_interface/gui.jl` back to `lift` would re-issue
# `setpower(light, 0.0)` and `light_off(light)` while every state
# assertion below still passes. `RecordingLight` instead logs every
# `setpower`/`light_on`/`light_off` call it receives, so the test can
# assert directly that construction issues zero commands, regardless of
# what the starting state is.
mutable struct RecordingLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
    log::Vector{Symbol}
end
RecordingLight(properties::LightSourceProperties) =
    RecordingLight("RecordingLight", properties, Symbol[])

MicroscopeControl.setpower(light::RecordingLight, ::Float64) = (push!(light.log, :setpower); nothing)
MicroscopeControl.light_on(light::RecordingLight) = (push!(light.log, :light_on); nothing)
MicroscopeControl.light_off(light::RecordingLight) = (push!(light.log, :light_off); nothing)

# A camera whose frame reads follow a script: `nothing` (a timeout, a refused read) or a frame, one per call. The
# loop needs only `is_running` and `getlastframe`; it stops being "running" once the script is used up.
mutable struct ScriptedCamera <: MicroscopeControl.Camera
    is_running::Int
    script::Vector{Any}
    reads::Int
end
ScriptedCamera(script...) = ScriptedCamera(1, collect(Any, script), 0)
function MicroscopeControl.getlastframe(camera::ScriptedCamera)
    camera.reads += 1
    frame = camera.script[camera.reads]
    camera.reads == length(camera.script) && (camera.is_running = 0)
    return frame
end

# End a child process in bounded time: SIGTERM, a grace period, then SIGKILL, then a bounded wait. A child stuck in exit
# cleanup can survive SIGTERM, and an unbounded `wait` would then hang the suite. Returns whether the process is gone.
function terminate_process!(proc; grace = 5.0, final = 10.0)
    process_running(proc) && kill(proc, Base.SIGTERM)
    timedwait(() -> !process_running(proc), grace; pollint = 0.05) === :ok && return true
    process_running(proc) && kill(proc, Base.SIGKILL)
    return timedwait(() -> !process_running(proc), final; pollint = 0.05) === :ok
end

@testset "GUI panels" begin
    @testset "Simulated Camera" begin
        cam = SimCamera()
        before = state_snapshot(cam)
        gui(cam)
        GLMakie.closeall()
        @test state_snapshot(cam) == before
    end

    @testset "Camera live display" begin
        CI = MicroscopeControl.HardwareInterfaces.CameraInterface
        quiet(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())
        ended(tasks...) = timedwait(() -> all(istaskdone, tasks), 10.0; pollint = 0.005) === :ok

        # The frame loop: the blocking read on its own task, the display callback on this thread's.
        cam = SimCamera(exposure_time = 0.001, roi = CameraROI(0, 0, 8, 4))
        live(cam)
        shown = Matrix{UInt16}[]
        show_tids = Int[]
        reader, display_task, _ = CI.run_live_loop(cam; fps = 200) do frame
            push!(shown, frame)
            push!(show_tids, Threads.threadid())
        end
        @test timedwait(() -> length(shown) >= 3, 10.0; pollint = 0.005) === :ok
        @test size(first(shown)) == (4, 8)
        abort(cam)
        @test ended(reader, display_task)
        @test all(==(Threads.threadid()), show_tids)   # `@async` runs on the thread that made it: only it updates Observables

        # A nothing frame does not end the loop, and a display callback that throws does not either.
        frame = ones(UInt16, 2, 2)
        shown = Matrix{UInt16}[]
        scripted = ScriptedCamera(nothing, nothing, frame, frame, nothing, frame)
        quiet() do
            reader, display_task, _ = CI.run_live_loop(scripted; fps = 500) do f
                push!(shown, f)
                length(shown) == 1 && error("the display failed on the first frame")
            end
            @test ended(reader, display_task)
            @test !istaskfailed(reader) && !istaskfailed(display_task)
        end
        @test scripted.reads == 6
        @test length(shown) == 3

        # `stop` ends the reader without `abort`.
        cam = SimCamera(exposure_time = 0.001, roi = CameraROI(0, 0, 8, 4))
        live(cam)
        reader, display_task, stop = CI.run_live_loop(_ -> nothing, cam; fps = 200)
        stop[] = true
        @test ended(reader, display_task)
        @test cam.is_running == 1
        abort(cam)

        # The reader runs on its own thread: a read that blocks in a foreign call must not stop the render side. That
        # needs a second thread, so it runs in a `julia -t 2,1` subprocess (see the file), where `Pkg.test()` and CI
        # exercise it. The child's waits have deadlines; the parent kills it after 60 s and fails.
        check = joinpath(@__DIR__, "gui_threads_check.jl")
        outfile = tempname()
        proc = run(pipeline(ignorestatus(`$(Base.julia_cmd()) -t 2,1 --project=$(Base.active_project()) $check`); stdout = outfile, stderr = outfile); wait = false)
        finished_in_time = timedwait(() -> !process_running(proc), 60.0; pollint = 0.1) === :ok
        finished_in_time || terminate_process!(proc)
        ok = finished_in_time && !process_running(proc) && success(proc)
        ok || print(read(outfile, String))
        rm(outfile; force = true)
        @test finished_in_time
        @test ok

        # The escalation itself: a child that ignores SIGTERM is still ended, in bounded time.
        if Sys.islinux()
            stubborn = run(`bash -c 'trap "" TERM; while true; do sleep 0.2; done'`; wait = false)
            sleep(0.5)
            t0 = time()
            @test terminate_process!(stubborn; grace = 1.0, final = 10.0)
            @test !process_running(stubborn) && time() - t0 < 8
        end

        # The whole display, on the simulated camera: it runs, and closing the window stops the camera and the loop.
        cam = SimCamera(exposure_time = 0.001, roi = CameraROI(0, 0, 64, 48))
        task = quiet(() -> CI.start_live(cam))
        @test cam.is_running == 1
        sleep(0.2)
        GLMakie.closeall()
        @test timedwait(() -> cam.is_running == 0 && istaskdone(task), 10.0; pollint = 0.01) === :ok
    end

    @testset "Simulated Light Source" begin
        light = SimLight()
        before = state_snapshot(light)
        gui(light)
        GLMakie.closeall()
        @test state_snapshot(light) == before
        # Belt-and-suspenders check naming the exact fields item 1 was about.
        @test light.properties.power == before[1]["power"]
        @test light.properties.is_on == before[1]["is_on"]

        # Command-based check, using starting states a snapshot can't
        # probe: on at construction; stored power off the slider's
        # `min_power:0.1:max_power` grid; stored power outside
        # `min_power..max_power` entirely. Each must still issue zero
        # commands when the panel is merely constructed.
        cases = (
            on_at_start = LightSourceProperties("mW", 0.0, true, 0.0, 100.0),
            off_grid_power = LightSourceProperties("mW", 33.33, false, 0.0, 100.0),
            out_of_range_power = LightSourceProperties("mW", 150.0, false, 0.0, 100.0),
        )
        for (name, properties) in pairs(cases)
            rec = RecordingLight(properties)
            gui(rec)
            GLMakie.closeall()
            @test isempty(rec.log)
        end
    end

    @testset "Simulated Stage" begin
        # gui(::Stage) currently throws for every Sim stage: the shared
        # stage_interface/gui.jl panel reads `stage.stagelabel`, but
        # SimStage1d/2d/3d carry `label`. That mismatch is item 4 on the
        # downstream's priority list and is out of scope for this PR. Marked
        # `@test_broken` (rather than silently skipped) so this flips to a
        # failure -- telling us to update the test -- once item 4 fixes it.
        for ctor in (SimStage3d, SimStage2d, SimStage1d)
            stage = ctor()
            before = state_snapshot(stage)
            threw = false
            try
                gui(stage)
            catch e
                # Restrict to the known `stagelabel`/`label` mismatch so an
                # unrelated failure isn't silently accepted as this expected
                # `@test_broken`. No pattern match on the message can do this
                # safely: `var"stagelabel "` and
                # `var"stagelabel`, available fields:extra"` are both legal
                # Julia field names, and each defeats a boundary built from a
                # character class or from the surrounding message text. So
                # compare the exception's own fields where they exist. Julia
                # 1.12+ raises a structured `FieldError`; 1.11 has no such type
                # and raises a plain `ErrorException`, where exact message
                # equality is the tightest check available.
                is_expected = @static if isdefined(Core, :FieldError)
                    e isa Core.FieldError &&
                        e.type === typeof(stage) && e.field === :stagelabel
                else
                    e isa ErrorException &&
                        e.msg == "type $(nameof(typeof(stage))) has no field stagelabel"
                end
                is_expected || rethrow()
                threw = true
            finally
                GLMakie.closeall()
            end
            @test_broken !threw
            # Whether or not it throws, no hardware call happens before the
            # `stagelabel` field access, so state must still be unchanged.
            @test state_snapshot(stage) == before
        end
    end

    # The DiodeLaser panels extend the no-commands-on-open rule to reads: a
    # panel must issue neither a command nor a poll until the user asks.
    # `SimDiodeLaser` logs reads as well as commands, and the fake Kinesis SDK
    # records every call, so both halves are assertable on both.
    @testset "Diode laser panels issue nothing on open" begin
        cp_props() = LightSourceProperties("mW", 0.0, false, 1.0, 70.0)
        sims = (SimDiodeLaser(; mode=ConstantCurrent(), min_current=70.0, max_current=150.0),
                SimDiodeLaser(; mode=ConstantPhotocurrent(), max_current=160.0, wa_calibration=224.2, tia_range=1e-3,
                              tec_stabilised=missing, properties=cp_props()))
        for sim in sims
            initialize(sim)
            empty!(sim.log)
            before = state_snapshot(sim)
            gui(sim)
            GLMakie.closeall()
            @test isempty(sim.log)
            @test isequal(state_snapshot(sim), before)
        end

        FakeKinesis.reset!()
        for laser in (TCubeLaser("00000000"; mode=ConstantCurrent()),
                      TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2,
                                 tia_range=1e-3, tec_stabilised=missing, properties=cp_props(), max_current=160.0,
                                 lock_check_s=0.1))
            gui(laser)
            GLMakie.closeall()
        end
        @test isempty(FakeKinesis.calls)
    end

    # The beam-steering panel wires its sliders with `on`, so opening it writes nothing;
    # moving a slider writes both axes, and Zero writes 0 V without the sliders' grid-rounded
    # values following it out.
    @testset "Beam steering panel" begin
        b = RecordingBackend()
        galvo = Galvo(b; xlimits = (-2.0, 2.0), ylimits = (-1.0, 3.0))
        eod = EOD(RecordingBackend(); max_crystal_volts = 150.0)
        for dev in (galvo, eod)
            initialize(dev)
            setvoltage(dev, 0.5, 0.25)
        end
        n = length(b.writes)
        fig = gui(galvo)
        @test length(b.writes) == n
        @test occursin("crystal", MicroscopeControl.HardwareInterfaces.BeamSteeringInterface.panel_readout(eod))
        gui(eod)

        sliders = [c for c in fig.content if c isa Slider]
        @test length(sliders) == 2
        set_close_to!(sliders[1], 1.0)
        @test length(b.writes) == n + 1
        @test b.writes[end][1] ≈ 1.0 atol = 0.01
        buttons = [c for c in fig.content if c isa Button]
        buttons[1].clicks[] += 1
        @test b.writes[end] == (0.0, 0.0)
        @test getvoltage(galvo) == (0.0, 0.0)
        GLMakie.closeall()
    end

    # The toggle's label follows the driver's `is_on`, not the click: a
    # `light_off` that fails leaves the diode on, and the panel must say so.
    @testset "Output toggle reports the driver's state, not the click" begin
        FakeKinesis.reset!()
        laser = TCubeLaser("00000000"; mode=ConstantCurrent())
        initialize(laser)
        light_on(laser)
        fig = Figure()
        message = Label(fig[1, 1], "")
        toggle, status = MicroscopeControl.LightSourceInterface._attach_output_toggle!(fig, 2, laser, message)
        @test toggle.active[] && status[] == "output on"
        FakeKinesis.fail!("LD_DisableOutput")
        toggle.active[] = false
        @test laser.properties.is_on
        @test status[] == "output on"
        @test toggle.active[]
        @test startswith(message.text[], "refused")
        # A command that works is followed by the label.
        delete!(FakeKinesis.status, "LD_DisableOutput")
        toggle.active[] = false
        @test !laser.properties.is_on && status[] == "output off" && !toggle.active[]
        GLMakie.closeall()
    end
end
