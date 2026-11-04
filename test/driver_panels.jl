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
    target.stored_string[] = "10,11"
    old_label = target_label.text[]
    F.fail!("PI_MOV")
    actions = Function[() -> (target.stored_string[] = "20,21")]
    for label in ("<", ">", "^", "v", "Home")
        button = only(filter(x -> x isa Button && x.label[] == label, fig.content))
        push!(actions, () -> (button.clicks[] += 1))
    end
    for action in actions
        @test_logs (:error, r"Stage move refused") action()
        @test (stage.targ_x, stage.targ_y) == (10.0,11.0)
        @test target_label.text[] == old_label
    end
    F.reset!()
    home_button = only(filter(x -> x isa Button && x.label[] == "Home", fig.content))
    home_button.clicks[] += 1
    @test (stage.targ_x, stage.targ_y) == (12.5,12.5)
    @test last(F.moves) == ("1 2", [12.5,12.5])
    @test target_label.text[] == "( 12.5, 12.5 )"
    F.reset!()
end
end

module LightPanelTaskTests
using MicroscopeControl, Test, GLMakie
const LI = MicroscopeControl.HardwareInterfaces.LightSourceInterface

# Record the thread that reads the driver's cached report; fail one poll on
# demand. Commands stay inside this fake and never reach a hardware driver.
mutable struct PollProbeLight <: LightSource
    unique_id::String
    properties::LightSourceProperties
    read_threads::Vector{Int}
    fail_next::Bool
    commands::Vector{Tuple{Symbol,Int}}
end
PollProbeLight() = PollProbeLight("poll probe", LightSourceProperties("V", 0., false, 0., 5.), Int[], false, [])
function Base.getproperty(light::PollProbeLight, name::Symbol)
    if name === :properties
        push!(getfield(light, :read_threads), Threads.threadid())
        if getfield(light, :fail_next)
            setfield!(light, :fail_next, false)
            error("injected status refresh failure")
        end
    end
    return getfield(light, name)
end
function MicroscopeControl.light_on(light::PollProbeLight)
    push!(light.commands, (:on, Threads.threadid()))
    getfield(light, :properties).is_on = true
end
function MicroscopeControl.light_off(light::PollProbeLight)
    push!(light.commands, (:off, Threads.threadid()))
    getfield(light, :properties).is_on = false
end

function poll_scenario()
    owner = Threads.threadid()
    fig = Figure()
    light = PollProbeLight()
    message = Label(fig[1,1], "")
    controls = LI._attach_output_toggle!(fig, 2, light, message)
    poll_task = get(controls, :poll_task, nothing)
    try
        empty!(light.read_threads)
        getfield(light, :properties).is_on = true # another caller's change
        light.fail_next = true
        refreshed = timedwait(() -> controls.status[] == "output on", 3.0; pollint=0.01)
        poll_threads = copy(light.read_threads)
        poll_commands = copy(light.commands)
        sticky = poll_task isa Task && poll_task.sticky
        controls.toggle.active[] = false
        commands = copy(light.commands)
        fig.scene.events.window_open[] = false
        ended = poll_task isa Task ? timedwait(() -> istaskdone(poll_task), 1.5; pollint=0.01) : :missing
        nreads = length(light.read_threads)
        getfield(light, :properties).is_on = true
        sleep(0.65)
        return (; owner, sticky, refreshed, poll_threads, poll_commands, commands,
            ended, stopped=length(light.read_threads) == nreads,
            failed=poll_task isa Task && istaskfailed(poll_task))
    finally
        fig.scene.events.window_open[] = false
    end
end

@testset "Output polling stays on the panel thread and survives a refresh error" begin
    logger = Test.TestLogger()
    result = Base.CoreLogging.with_logger(logger) do
        # This caller starts nonsticky on a worker, reproducing the review's
        # Timer migration case. The panel's @async poll must stay with it.
        fetch(Threads.@spawn poll_scenario())
    end
    @test result.sticky
    @test result.refreshed === :ok
    @test !isempty(result.poll_threads) && all(==(result.owner), result.poll_threads)
    @test isempty(result.poll_commands)
    @test result.commands == [(:off, result.owner)]
    @test result.ended === :ok && !result.failed
    @test result.stopped
    @test length(logger.logs) == 1 && occursin("status refresh failed", string(only(logger.logs).message))
end

struct DisplayProbeDiode <: DiodeLaser
    unique_id::String
    properties::LightSourceProperties
end
const display_failure = ErrorException("injected panel display failure")
# Replace the native display only; both real _show_panel paths and the shared
# display cleanup still run, including the diode's distinct return behavior.
LI._display_figure(fig, ::Union{PollProbeLight,DisplayProbeDiode}) = throw(display_failure)

@testset "Failed generic and diode displays stop output polling" begin
    for light in (PollProbeLight(), DisplayProbeDiode("display probe", LightSourceProperties("V", 0., false, 0., 5.))),
        initially_open in (false, true)
        fig = Figure()
        message = Label(fig[1,1], "")
        controls = LI._attach_output_toggle!(fig, 2, light, message)
        try
            initially_open && (fig.scene.events.window_open[] = true)
            err = try
                LI._show_panel(fig, light)
                nothing
            catch e
                e
            end
            @test err === display_failure
            @test !fig.scene.events.window_open[]
            @test hasproperty(controls, :poll_task)
            if hasproperty(controls, :poll_task)
                @test timedwait(() -> istaskdone(controls.poll_task), 1.5; pollint=0.01) === :ok
                @test !istaskfailed(controls.poll_task)
            end
        finally
            fig.scene.events.window_open[] = false
        end
    end
end
end
