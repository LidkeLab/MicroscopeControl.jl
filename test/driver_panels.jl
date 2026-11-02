using GLMakie

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

module StagePanelTests
using MicroscopeControl, Test, GLMakie
const SI = MicroscopeControl.HardwareInterfaces.StageInterface
const F = Main.FakePIStage
# Pure field-only stage: constructing it never initializes a vendor SDK.
mutable struct PanelStage <: Stage
    stagelabel::String
    dimensions::Int
    connectionstatus::Bool
    range_x::Tuple{Float64,Float64}
    range_y::Tuple{Float64,Float64}
    range_z::Tuple{Float64,Float64}
end
SI._show_stage_panel(fig, ::Union{PanelStage,PIStage}) = fig

@testset "Stage steps accept only finite positive numbers" begin
    for dimensions in 1:3
        stage = PanelStage("test stage", dimensions, false, (0.,25.), (0.,25.), (0.,25.))
        fig = gui(stage)
        boxes = filter(x -> x isa Textbox && x.placeholder[] == "0.1", fig.content)
        @test length(boxes) == dimensions
        for box in boxes
            # Makie treats a Type validator as tryparse, so exercise the same
            # rule without a display or a keyboard event.
            valid(s) = box.validator[] isa Type ? tryparse(box.validator[], s) !== nothing : box.validator[](s)
            @test !valid("NaN")
            @test !valid("-1")
            @test !valid("0")
            @test valid("0.1")
        end
    end
end

@testset "Refused PI panel moves preserve targets without escaping callbacks" begin
    F.reset!()
    stage = PIStage(connectionstatus=true)
    fig = gui(stage)
    target = only(filter(x -> x isa Textbox && x.placeholder[] == "Enter (X,Y)", fig.content))
    target_label = only(filter(x -> x isa Label && startswith(x.text[], "( "), fig.content))
    # Establish a displayed target through a successful move before refusing.
    target.stored_string[] = "12.5,12.5"
    old_label = target_label.text[]
    F.fail!("PI_MOV")
    actions = Function[() -> (target.stored_string[] = "20,21")]
    for label in ("<", ">", "^", "v")
        button = only(filter(x -> x isa Button && x.label[] == label, fig.content))
        push!(actions, () -> (button.clicks[] += 1))
    end
    for action in actions
        @test_logs (:error, r"Stage move refused") action()
        @test (stage.targ_x, stage.targ_y) == (12.5,12.5)
        @test target_label.text[] == old_label
    end
    F.reset!()
end
end
