using GLMakie

# A 1D panel fixture: SimStage1d has no stagelabel and cannot open the shared panel yet.
Base.@kwdef mutable struct _PanelStage1D <: Stage
    stagelabel::String = "Panel test"
    dimensions::Int = 1
    connectionstatus::Bool = true
    real_x::Float64 = 5.0
    targ_x::Float64 = 5.0
    range_x::Tuple{Float64,Float64} = (0.0, 10.0)
    refuse::Bool = false
end
function MicroscopeControl.move(s::_PanelStage1D, x::Float64)
    s.refuse && error("fixture refused move")
    s.targ_x = x
end
MicroscopeControl.home(s::_PanelStage1D) = MicroscopeControl.move(s, 0.0)

@testset "S3: camera menus select their own field (p3)" begin
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    camera = SimCamera()
    figure = Figure()
    for (i, field) in enumerate((:capture_mode, :trigger_mode))
        options = [(string(m), m) for m in instances(typeof(getfield(camera, field)))]
        menu = CI.create_menu(figure, 1, i, options, string(getfield(camera, field)), camera, field)
        other = field == :capture_mode ? :trigger_mode : :capture_mode
        before = getfield(camera, other)
        menu.selection[] = last(options)[2]
        @test getfield(camera, field) == last(options)[2]
        @test getfield(camera, other) == before
    end
    GLMakie.closeall()
end

@testset "S4: stage step validation without a window" begin
    SI = MicroscopeControl.HardwareInterfaces.StageInterface
    for text in ("NaN", "Inf", "-Inf", "0", "-0.1", "bad")
        @test !SI.valid_step(text)
    end
    @test SI.valid_step("0.1")
    for step in (NaN, Inf, -Inf, 0.0, -100.0), direction in (-1, 1)
        @test_throws ArgumentError SI.step_target(5.0, step, direction, (0.0, 10.0))
    end
    for (target, step, direction) in ((0.0, 1.0, -1), (10.0, 1.0, 1), (20.0, 1.0, -1),
                                    (-20.0, 1.0, 1), (NaN, 1.0, 1), (floatmax(Float64), floatmax(Float64), 1))
        @test_throws ArgumentError SI.step_target(target, step, direction, (0.0, 10.0))
    end
    @test SI.step_target(5.0, 5.0, -1, (0.0, 10.0)) == 0.0
    @test SI.step_target(5.0, 5.0, 1, (0.0, 10.0)) == 10.0
end

@testset "Stage panel callbacks catch refusals and display accepted targets" begin
    SI = MicroscopeControl.HardwareInterfaces.StageInterface
    F = Main.FakePIStage
    F.reset!()
    MCL = MicroscopeControl.HardwareImplementations.MadCityLabs
    stages = (_PanelStage1D(), PIStage(connectionstatus=true), MCL.MCLStage(connectionstatus=true, targ_x=5.0, targ_y=5.0, targ_z=5.0))
    for stage in stages
        try
            gui(stage)
            figure = GLMakie.Makie.current_figure()
            boxes = filter(x -> x isa Textbox, figure.content)
            steps = filter(x -> x.placeholder[] == "0.1", boxes)
            @test length(steps) == stage.dimensions
            for step in steps, text in ("NaN", "-100", "0", "Inf")
                @test !step.validator[](text)
                @test_logs (:error, "Stage panel command failed") (step.stored_string[] = text)
            end
            targetbox = only(filter(x -> startswith(x.placeholder[], "Enter"), boxes))
            before = ntuple(i -> getfield(stage, (:targ_x, :targ_y, :targ_z)[i]), stage.dimensions)
            if stage isa _PanelStage1D
                stage.refuse = true
            elseif stage isa PIStage
                F.fail!("PI_MOV")
            else
                FakeMCL.write_codes[1] = Cint(-5)
            end
            text = join(fill("6.0", stage.dimensions), ",")
            @test_logs (:error, "Stage panel command failed") match_mode=:any (targetbox.stored_string[] = text)
            after = ntuple(i -> getfield(stage, (:targ_x, :targ_y, :targ_z)[i]), stage.dimensions)
            @test after == before
            # Every arrow and home callback is guarded too.
            arrows = filter(x -> x isa Button && x.label[] in ("<----", "---->", "<", ">", "^", "v", "Home"), figure.content)
            for button in arrows
                @test_logs (:error, "Stage panel command failed") match_mode=:any (button.clicks[] += 1)
            end
            after = ntuple(i -> getfield(stage, (:targ_x, :targ_y, :targ_z)[i]), stage.dimensions)
            @test after == before
            if stage isa MCL.MCLStage
                query = only(filter(x -> x isa Button && x.label[] == "Query Position", figure.content))
                initialize_button = only(filter(x -> x isa Button && x.label[] == "Initialize", figure.content))
                old_position = FakeMCL.positions[1]
                FakeMCL.positions[1] = -5.0
                try
                    @test_logs (:error, "Stage panel command failed") match_mode=:any (query.clicks[] += 1)
                    @test_logs (:error, "Failed to initialize the stage") match_mode=:any (initialize_button.clicks[] += 1)
                    @test (stage.targ_x, stage.targ_y, stage.targ_z) == before
                finally
                    FakeMCL.positions[1] = old_position
                end
                old_range = FakeMCL.ranges[1]
                FakeMCL.ranges[1] = -8.0
                try
                    @test_logs (:error, "Failed to initialize the stage") match_mode=:any (initialize_button.clicks[] += 1)
                finally
                    FakeMCL.ranges[1] = old_range
                end
            end
        finally
            F.reset!()
            FakeMCL.write_codes[1] = Cint(0)
            GLMakie.closeall()
        end
    end
end

@testset "MCL partial move refreshes displayed targets" begin
    SI = MicroscopeControl.HardwareInterfaces.StageInterface
    MCL = MicroscopeControl.HardwareImplementations.MadCityLabs
    # Partial success: X accepted, Y refused; display X's new target and preserve Y and Z.
    stage = MCL.MCLStage(targ_x=1.0, targ_y=2.0, targ_z=3.0)
    targets = (Observable(1.0), Observable(2.0), Observable(3.0))
    positions = (Observable(0.0), Observable(0.0), Observable(0.0))
    click = Observable(0)
    SI.on_stage(click, stage, targets, positions) do _
        SI.panel_move!(stage, 11.0, 22.0, 33.0)
    end
    FakeMCL.write_codes[2] = Cint(-5)
    @test_logs (:error, "Stage panel command failed") match_mode=:any (click[] += 1)
    @test map(x -> x[], targets) == (11.0, 2.0, 3.0)
    FakeMCL.write_codes[2] = Cint(0)
end

@testset "Camera panel callbacks contain failed DCAM setup" begin
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    F = Main.FakeDCAM
    cam = DC.DCAM4Camera("fake", CameraFormat(8, 6, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        CameraROI(0, 0, 4, 4), DC.SINGLE_FRAME, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2,
        DC.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 4, 4), NaN, 0)
    for property in (DC.DCAM_IDPROP_EXPOSURETIME, DC.DCAM_IDPROP_SUBARRAYHSIZE),
        action in (CI.start_capture, CI.start_live, CI.start_sequence)
        F.reset!()
        F.read_codes[Int32(property)] = DC.DCAMERR_TIMEOUT
        figure = Figure()
        button = CI.create_button(figure, 1, 1, "test", action, cam)
        @test_logs (:error, "Camera panel command failed") match_mode=:any (button.clicks[] += 1)
        @test cam.last_error == DC.DCAMERR_TIMEOUT
        @test !cam.is_running
        @test !("dcamcap_start" in F.calls)
    end
    F.reset!()
    GLMakie.closeall()
end
