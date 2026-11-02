# Production drivers over a DAQ subtype. No NIdaq method is replaced here;
# discovery, task allocation and every voltage write stay inside this fake.
module DaqLightsTests
using MicroscopeControl, Test, GLMakie
const MC = MicroscopeControl
const LI = MC.HardwareInterfaces.LightSourceInterface

mutable struct RecordedTask
    id::Int
    kind::String
    channel::String
end
mutable struct RecordingDAQ <: DAQ
    unique_id::String
    lines::Dict{String,Float64}
    calls::Vector{Any}
    open_tasks::Set{Int}
    failures::Vector{Tuple{Symbol,String,Any,Union{Nothing,Float64}}}
    next_id::Int
    pause::Any
    export_hook::Any
    devices::Vector{String}
    reserved::Dict{String,Int}
    finalizer_fails::Bool
end
RecordingDAQ(; devices=["Fake1", "Fake2"]) = RecordingDAQ("recording DAQ", Dict(), [], Set(), [], 0, nothing, nothing, devices, Dict(), false)
function fail!(daq, stage, channel, error=ErrorException("$stage failed on $channel"); voltage=nothing)
    push!(daq.failures, (stage, channel, error, voltage))
    return error
end
function maybe_fail!(daq, stage, channel; voltage=nothing)
    index = findfirst(f -> f[1] == stage && f[2] == channel && (f[4] === nothing || f[4] == voltage), daq.failures)
    index === nothing || throw(splice!(daq.failures, index)[3])
end
function MC.showdevices(daq::RecordingDAQ)
    push!(daq.calls, (:devices,))
    return daq.devices
end
function MC.showchannels(daq::RecordingDAQ, kind::String, device::String)
    push!(daq.calls, (:channels, kind, device))
    maybe_fail!(daq, :discovery, kind)
    return kind == "AO" ? ["$device/ao$i" for i in 0:1] : ["$device/port0/line$i" for i in 0:11]
end
function MC.createtask(daq::RecordingDAQ, kind::String, channel::String; min_val=nothing, max_val=nothing)
    push!(daq.calls, (:create, kind, channel))
    haskey(daq.reserved, channel) && error("channel reserved: $channel")
    maybe_fail!(daq, :create, channel)
    daq.next_id += 1
    push!(daq.open_tasks, daq.next_id)
    task = RecordedTask(daq.next_id, kind, channel)
    finalizer(task) do t
        # After explicit clear fails, DAQmx.Task retries clear on GC.
        if t.id in daq.open_tasks && !daq.finalizer_fails
            push!(daq.calls, (:finalize, t.kind, t.channel))
            delete!(daq.open_tasks, t.id)
            get(daq.reserved, t.channel, 0) == t.id && delete!(daq.reserved, t.channel)
        end
    end
    return task
end
function MC.setvoltage(daq::RecordingDAQ, task::RecordedTask, voltage::Float64)
    @assert task.id in daq.open_tasks
    push!(daq.calls, (:write, task.kind, task.channel, voltage))
    daq.pause === nothing || daq.pause(task, voltage)
    # Model a write that reaches the line and then reports an error: a driver
    # cannot assume a failed call left the previous level in place.
    daq.lines[task.channel] = voltage
    maybe_fail!(daq, :write, task.channel; voltage)
    return 1
end
function MC.deletetask(daq::RecordingDAQ, task::RecordedTask)
    @assert task.id in daq.open_tasks
    push!(daq.calls, (:delete, task.kind, task.channel))
    try
        maybe_fail!(daq, :delete_reserved, task.channel)
    catch
        daq.reserved[task.channel] = task.id
        rethrow()
    end
    delete!(daq.open_tasks, task.id)
    # A cleanup error after the write still makes the command uncertain.
    maybe_fail!(daq, :delete, task.channel)
    return nothing
end
function MC.export_state(daq::RecordingDAQ)
    daq.export_hook === nothing || daq.export_hook()
    return Dict("unique_id" => daq.unique_id), nothing, Dict()
end

const AO = "Named/ao0"
const DO = "Named/port0/line7"
const TYPES = (CrystaLaser, DaqTrLight, VortranLaser)
# Replace only window display, so the real gui return path remains tested.
struct PanelScreen
    figure::Figure
end
const panels = Figure[]
const displayed = Ref{Union{Nothing,PanelScreen}}(nothing)
function LI._display_figure(fig, light::Union{SimLight,SimDiodeLaser,CrystaLaser,DaqTrLight,VortranLaser})
    push!(panels, fig)
    displayed[] = PanelScreen(fig)
    return displayed[]
end
panel_figure(result) = result isa PanelScreen ? result.figure : result
make_light(T, daq=RecordingDAQ(); kwargs...) = T === VortranLaser ?
    T(; daq, ao_channel=AO, do_channel=DO, kwargs...) : T(; daq, channel=AO, kwargs...)
enable_channel(T) = T === VortranLaser ? DO : AO
writes(daq) = filter(c -> first(c) == :write, daq.calls)
function caught(f)
    try
        f()
    catch e
        return e
    end
    return nothing
end

# An arbitrary LightSource, including interruptions, for best-effort teardown.
mutable struct TeardownLight <: LightSource
    unique_id::String
    failure::Any
    calls::Int
end
function MC.light_off(light::TeardownLight)
    light.calls += 1
    light.failure === nothing || throw(light.failure)
    return nothing
end

@testset "DAQ voltage lights" begin
    @testset "Constructors and named channels" begin
        for T in TYPES
            daq = RecordingDAQ()
            light = make_light(T, daq)
            @test light.daq === daq
            @test fieldtype(T, :daq) === DAQ
            @test isempty(daq.calls) # explicit names skip all discovery
            @test light.properties.power_unit == "V"
            @test (light.properties.min_power, light.properties.max_power) == (light.min_voltage, light.max_voltage)
            @test isnan(light.level_requested)
            properties = LightSourceProperties("mW", 45.0, false, 0.0, 100.0)
            light = @test_logs make_light(T; properties)
            @test light.properties === properties
            @test properties.power_unit == "mW"
            @test properties.power == 45.0 && properties.max_power == 100.0
            # Default DAQ construction with named channels is pure too.
            default_daq = T === VortranLaser ? T(; ao_channel=AO, do_channel=DO) : T(; channel=AO)
            @test default_daq.daq isa NIdaq
            @test hasmethod(T, Tuple{}) # downstream no-argument construction remains supported
        end
        for T in (CrystaLaser, DaqTrLight)
            @test isnan(make_light(T; min_voltage=1.2, max_voltage=2.0).level_requested)
            @test isnan(make_light(T; min_voltage=0.0, max_voltage=0.5).level_requested)
        end
        for T in TYPES
            daq = RecordingDAQ()
            light = T(; daq)
            device = T === DaqTrLight ? "Fake2" : "Fake1"
            @test daq.calls == [(:devices,), (:channels, "AO", device), (:channels, "DO", device)]
            if T === VortranLaser
                @test light.ao_channel == "$device/ao1"
                @test light.do_channel == "$device/port0/line11"
            else
                @test light.channel == "$device/ao0"
            end
        end
        daq = RecordingDAQ()
        v = VortranLaser(; daq, ao_channel=AO)
        @test v.ao_channel == AO && v.do_channel == "Fake1/port0/line11"
        @test daq.calls == [(:devices,), (:channels, "DO", "Fake1")]
        daq = RecordingDAQ()
        v = VortranLaser(; daq, do_channel=DO)
        @test v.ao_channel == "Fake1/ao1" && v.do_channel == DO
        @test daq.calls == [(:devices,), (:channels, "AO", "Fake1")]
        daq = RecordingDAQ()
        fail!(daq, :discovery, "DO")
        c = @test_logs (:warn, r"discovery failed") CrystaLaser(; daq)
        @test c.channel == "Fake1/ao0" && isempty(c.channelsDO)
    end

    @testset "Single-line requested level and on/off" begin
        for T in (CrystaLaser, DaqTrLight)
            daq = RecordingDAQ()
            light = make_light(T, daq)
            @test setpower(light, 2.5) === nothing
            @test isempty(daq.calls) && !light.properties.is_on
            @test light.level_requested == light.properties.power == 2.5
            light_on(light)
            @test light.properties.is_on && daq.lines[AO] == 2.5
            light_off(light)
            @test !light.properties.is_on && daq.lines[AO] == 0.0
            @test light.level_requested == 2.5
            light_on(light)
            @test light.properties.is_on && daq.lines[AO] == 1.0
            setpower(light, 2.0)
            @test daq.lines[AO] == light.level_requested == 2.0
            shutdown(light)
            @test !light.properties.is_on && daq.lines[AO] == 0.0 && light.level_requested == 2.0
            light_on(light)
            initialize(light)
            @test !light.properties.is_on && daq.lines[AO] == 0.0 && light.level_requested == 1.0
            fresh = make_light(T, daq)
            light_on(fresh)
            @test daq.lines[AO] == 1.0
            @test isempty(daq.open_tasks)
        end
    end

    @testset "Vortran level and enable are separate" begin
        daq = RecordingDAQ()
        light = make_light(VortranLaser, daq)
        initialize(light)
        @test writes(daq) == [(:write, "DO", DO, 0.0)]
        @test isnan(light.level_requested) && !haskey(daq.lines, AO)
        setpower(light, 2.5)
        @test daq.lines[AO] == 2.5 && !light.properties.is_on
        light_on(light)
        light_off(light)
        light_on(light)
        @test daq.lines[DO] == 1.0 && daq.lines[AO] == 2.5
        @test light.level_requested == 2.5
        initialize(light)
        @test !light.properties.is_on && daq.lines[DO] == 0.0 && daq.lines[AO] == 2.5
    end

    @testset "Validation and truthful voltage metadata" begin
        for T in TYPES
            daq = RecordingDAQ()
            light = make_light(T, daq)
            setpower(light, 2.5)
            # MicroscopeAdapt writes a percent here immediately after setpower.
            light.properties.power = 90.0
            light_on(light)
            @test daq.lines[AO] == 2.5
            light_off(light)
            light.properties.power = NaN
            light_on(light)
            expected_level = T === VortranLaser ? 2.5 : 1.0
            @test daq.lines[AO] == expected_level
            @test all(w -> w[4] != 90.0 && !isnan(w[4]), writes(daq))
            for on in (true, false)
                on || light_off(light)
                for bad in (NaN, Inf, -Inf, light.min_voltage - 0.01, light.max_voltage + 0.01)
                    before = (copy(daq.calls), copy(daq.lines), light.level_requested, light.properties.power, light.properties.is_on)
                    @test_throws ArgumentError setpower(light, bad)
                    @test isequal((daq.calls, daq.lines, light.level_requested, light.properties.power, light.properties.is_on), before)
                end
            end
            light.properties.min_power = -90.0
            light.properties.max_power = 90.0
            light.properties.power_unit = "%"
            attrs, data, children = export_state(light)
            @test attrs["power"] == attrs["power_requested"] == expected_level
            @test attrs["power_unit"] == "V"
            @test (attrs["min_power"], attrs["max_power"]) == (light.min_voltage, light.max_voltage)
            @test data === nothing && haskey(children, "daq")
            if T === VortranLaser
                @test attrs["ao_channel"] == AO && attrs["do_channel"] == DO
                @test haskey(attrs, "channelsAO") && haskey(attrs, "channelsDO")
            else
                @test attrs["channel"] == AO
                @test haskey(attrs, "channels_AO") && haskey(attrs, "channels_DO")
            end
        end
    end

    @testset "Failed off cannot claim darkness" begin
        for T in TYPES, stage in (:create, :write, :delete), command in (light_off, initialize, shutdown)
            daq = RecordingDAQ()
            light = make_light(T, daq)
            setpower(light, 2.5)
            light_on(light)
            fail!(daq, stage, enable_channel(T))
            @test caught(() -> command(light)) isa Exception
            @test light.properties.is_on
            @test isempty(daq.open_tasks) # also checks finally on failed setvoltage
        end
    end

    @testset "Uncertain enable or live level writes attempt to darken" begin
        for T in TYPES, stage in (:create, :write, :delete), command in (light_on, l -> setpower(l, 2.0)), darken_fails in (false, true)
            daq = RecordingDAQ()
            light = make_light(T, daq)
            setpower(light, 2.5)
            command === light_on || light_on(light)
            empty!(daq.calls)
            channel = command === light_on ? enable_channel(T) : AO
            original = fail!(daq, stage, channel)
            darken_fails && fail!(daq, :write, enable_channel(T), ErrorException("darken failed"); voltage=0.0)
            @test caught(() -> command(light)) === original
            @test light.properties.is_on == darken_fails
            @test light.level_requested == 2.5
            @test light.properties.power == 2.5
            @test last(writes(daq))[3:4] == (enable_channel(T), 0.0)
            @test isempty(daq.open_tasks)
        end
        # An off Vortran's failed level write never enables DO or claims a new request.
        daq = RecordingDAQ()
        light = make_light(VortranLaser, daq)
        original = fail!(daq, :write, AO)
        @test caught(() -> setpower(light, 2.0)) === original
        @test !light.properties.is_on && isnan(light.level_requested)
        @test !haskey(daq.lines, DO) && isempty(daq.open_tasks)
    end

    @testset "Vortran off fallback and independent shutdown attempts" begin
        for ao_fails in (false, true)
            daq = RecordingDAQ()
            light = make_light(VortranLaser, daq)
            setpower(light, 2.5)
            light_on(light)
            empty!(daq.calls)
            original = fail!(daq, :write, DO)
            ao_fails && fail!(daq, :write, AO)
            @test caught(() -> light_off(light)) === original
            @test light.properties.is_on
            @test light.level_requested == (ao_fails ? 2.5 : 0.0)
            @test writes(daq) == [(:write, "DO", DO, 0.0), (:write, "AO", AO, 0.0)]
        end
        for stage in (:create, :write, :delete), do_fails in (false, true), ao_fails in (false, true)
            daq = RecordingDAQ()
            light = make_light(VortranLaser, daq)
            setpower(light, 2.5)
            light_on(light)
            empty!(daq.calls)
            do_fails && fail!(daq, stage, DO)
            ao_fails && fail!(daq, stage, AO)
            e = caught(() -> shutdown(light))
            @test (e === nothing) == !(do_fails || ao_fails)
            @test light.properties.is_on == (do_fails || ao_fails)
            @test light.level_requested == (ao_fails ? 2.5 : 0.0)
            expected = Any[]
            !(stage === :create && do_fails) && push!(expected, (:write, "DO", DO, 0.0))
            !(stage === :create && ao_fails) && push!(expected, (:write, "AO", AO, 0.0))
            @test writes(daq) == expected
            if do_fails && ao_fails
                @test e isa ErrorException
                message = sprint(showerror, e)
                @test occursin("DO", message) && occursin("AO", message)
                @test occursin(DO, message) && occursin(AO, message)
            end
            @test isempty(daq.open_tasks)
        end
    end

    @testset "Missing channels throw, including off setpower" begin
        for T in TYPES, command in (l -> setpower(l, 2.5), light_on, light_off, initialize, shutdown)
            daq = RecordingDAQ(; devices=String[])
            light = @test_logs (:warn, r"not available") T(; daq, unique_id="missing light")
            e = caught(() -> command(light))
            @test e isa Exception
            @test occursin("missing light", sprint(showerror, e))
            @test isempty(writes(daq)) && isempty(daq.open_tasks)
        end
        daq = RecordingDAQ()
        no_ao = VortranLaser(; daq, ao_channel="", do_channel=DO, unique_id="no AO")
        @test_throws r"no AO.*missing ao_channel" setpower(no_ao, 2.5)
        no_do = VortranLaser(; daq, ao_channel=AO, do_channel="", unique_id="no DO")
        for command in (light_on, light_off, initialize, shutdown)
            @test_throws r"no DO.*missing do_channel" command(no_do)
        end
        @test !haskey(daq.lines, "")
    end

    @testset "Setpower and switch-off serialize their writes and records" begin
        for T in TYPES, off_first in (false, true)
            daq = RecordingDAQ()
            light = make_light(T, daq)
            setpower(light, 2.5)
            light_on(light)
            entered, release = Channel{Nothing}(1), Channel{Nothing}(1)
            target = off_first ? 0.0 : 2.0
            channel = off_first ? enable_channel(T) : AO
            daq.pause = function (task, voltage)
                if task.channel == channel && voltage == target
                    put!(entered, nothing)
                    timedwait(() -> isready(release), 10.0; pollint=0.001) === :ok || error("fake write release timed out")
                    take!(release)
                end
            end
            first_task = @async off_first ? light_off(light) : setpower(light, 2.0)
            @test timedwait(() -> isready(entered), 10.0; pollint=0.001) === :ok
            second_task = @async off_first ? setpower(light, 2.0) : light_off(light)
            yield()
            @test !istaskdone(second_task)
            put!(release, nothing)
            @test timedwait(() -> istaskdone(first_task) && istaskdone(second_task), 10.0; pollint=0.001) === :ok
            @test !istaskfailed(first_task) && !istaskfailed(second_task)
            @test !light.properties.is_on
            @test daq.lines[enable_channel(T)] == 0.0
            @test isempty(daq.open_tasks)
        end
    end

    @testset "lights_off preserves and displays every named failure" begin
        @test Base.ispublic(MC, :LightsOffError) && !Base.isexported(MC, :LightsOffError)
        @test Base.ispublic(LI, :LightsOffError) && !Base.isexported(LI, :LightsOffError)
        @test MC.LightsOffError === LI.LightsOffError
        for interrupt in (false, true), varargs in (false, true)
            first = TeardownLight("first", nothing, 0)
            failure = interrupt ? InterruptException() : ErrorException("transport failed")
            middle = TeardownLight("middle", failure, 0)
            other_error = ErrorException("another failure\nwith detail")
            other = TeardownLight("other", other_error, 0)
            last = TeardownLight("last", nothing, 0)
            lights = [first, middle, other, last]
            e = caught(() -> varargs ? lights_off(lights...) : lights_off(lights))
            @test e isa MC.LightsOffError
            @test all(l -> l.calls == 1, lights)
            @test e.failures == ["middle" => failure, "other" => other_error]
            lines = split(sprint(showerror, e), '\n')
            @test length(lines) == 2
            @test occursin("middle", lines[1]) && occursin("other", lines[2])
        end
        light = SimLight()
        light_on(light)
        @test lights_off(light) === nothing
        @test !light.properties.is_on
        @test lights_off(()) === nothing && lights_off() === nothing
        # A failed real driver in the middle does not strand either neighboring driver.
        daq = RecordingDAQ()
        a = CrystaLaser(; daq, channel="a")
        b = VortranLaser(; daq, ao_channel="b-AO", do_channel="b-DO", unique_id="488 middle")
        c = DaqTrLight(; daq, channel="c")
        foreach(light_on, (a, b, c))
        fail!(daq, :write, "b-DO")
        e = caught(() -> lights_off((a, b, c)))
        @test e isa MC.LightsOffError
        @test !a.properties.is_on && b.properties.is_on && !c.properties.is_on
        @test daq.lines["a"] == daq.lines["c"] == 0.0
        @test occursin("488 middle", sprint(showerror, e))
    end

    @testset "Generic panels reuse the bounded setpoint and output controls" begin
        sim_nan = SimLight(properties=LightSourceProperties("mW", NaN, false, 0.0, 100.0))
        sim_outside = SimLight(properties=LightSourceProperties("mW", 150.0, false, 0.0, 100.0))
        for light in (sim_nan, sim_outside, make_light(CrystaLaser), make_light(VortranLaser))
            if !(light isa SimLight)
                light.properties.power = 90.0 # the slider must use level_requested
            end
            before = export_state(light)[1]
            fig = panel_figure(gui(light))
            try
                @test isequal(export_state(light)[1], before)
                daq = light isa SimLight ? nothing : light.daq
                @test daq === nothing || isempty(daq.calls)
                slider = only(filter(x -> x isa Slider, fig.content))
                textbox = only(filter(x -> x isa Textbox, fig.content))
                toggle = only(filter(x -> x isa Toggle, fig.content))
                settings = LI._power_settings(light)
                @test first(slider.range[]) == settings.lo && last(slider.range[]) == settings.hi
                expected = isfinite(settings.requested) && settings.lo <= settings.requested <= settings.hi ? settings.requested : settings.lo
                @test slider.value[] ≈ expected atol=0.1
                @test !textbox.validator[]("NaN") && !textbox.validator[](string(settings.hi + 1))
                @test !textbox.validator[](string(settings.lo - 1))
                @test textbox.validator[](string(settings.hi))
                # stored_string is the existing panel seam, fired by a validated submission.
                textbox.stored_string[] = string(settings.hi)
                @test slider.value[] == settings.hi
                if daq === nothing
                    @test light.properties.power == settings.hi
                elseif light isa VortranLaser
                    @test length(writes(daq)) == 1
                else
                    @test isempty(writes(daq)) # a level change while off cannot emit
                end
                toggle.active[] = true
                @test light.properties.is_on
                if daq !== nothing
                    empty!(daq.calls)
                    textbox.stored_string[] = string(settings.lo)
                    @test length(writes(daq)) == 1 # textbox must not command twice
                    fail!(daq, :write, enable_channel(typeof(light)))
                    @test caught(() -> (toggle.active[] = false)) === nothing
                    @test light.properties.is_on && toggle.active[] # failed off is corrected, with no re-enable
                    labels = filter(x -> x isa Label, fig.content)
                    @test any(l -> occursin("refused", l.text[]), labels)
                    @test any(l -> l.text[] == "output on", labels)
                    # After failed off, single-line changes stage; Vortran still writes AO.
                    fail!(daq, :write, AO)
                    @test caught(() -> set_close_to!(slider, settings.hi)) === nothing
                    @test light.properties.is_on == toggle.active[] == !(light isa VortranLaser)
                    @test any(l -> l.text[] == (light isa VortranLaser ? "output off" : "output on"), labels)
                end
            finally
                fig.scene.events.window_open[] = false
                GLMakie.closeall()
            end
        end
    end
end
@testset "DAQ panel and staging behavior" begin
    @testset "every textbox submission commands exactly once" begin
        for light in (make_light(VortranLaser), SimDiodeLaser())
            light isa SimDiodeLaser && initialize(light)
            fig = Figure()
            commands = Float64[]
            refuse = Ref(false)
            message = LI._attach_setpoint!(fig, light, 0.0:0.1:5.0, 0.0,
                x -> (push!(commands, x); refuse[] && error("retry this level")), () -> "requested")
            slider = only(filter(x -> x isa Slider, fig.content))
            textbox = only(filter(x -> x isa Textbox, fig.content))
            # The displayed bottom is not yet a known AO request on Vortran.
            textbox.stored_string[] = "0"
            @test commands == [0.0]
            textbox.stored_string[] = "0"
            @test commands == [0.0, 0.0]
            textbox.stored_string[] = "2"
            @test commands == [0.0, 0.0, 2.0] # an ordinary entry still commands once
            refuse[] = true
            @test caught(() -> (textbox.stored_string[] = "3")) === nothing
            @test commands == [0.0, 0.0, 2.0, 3.0]
            @test occursin("refused", message.text[])
            refuse[] = false
            textbox.stored_string[] = "3"
            @test commands == [0.0, 0.0, 2.0, 3.0, 3.0]
            @test message.text[] == ""
            @test slider.value[] == 3.0
        end
        daq = RecordingDAQ()
        light = make_light(VortranLaser, daq)
        daq.lines[AO] = 4.0 # prior process's line value, unknown to this object
        initialize(light)
        fig = panel_figure(gui(light))
        textbox = only(filter(x -> x isa Textbox, fig.content))
        empty!(daq.calls)
        textbox.stored_string[] = "0"
        @test writes(daq) == [(:write, "AO", AO, 0.0)]
        @test daq.lines[AO] == light.level_requested == 0.0
    end

    @testset "single-line staged requests and legacy enabling" begin
        for T in (CrystaLaser, DaqTrLight)
            daq = RecordingDAQ()
            light = make_light(T, daq)
            @test !light.level_staged
            setpower(light, 2.5)
            @test light.level_staged && isempty(writes(daq))
            light_on(light)
            @test daq.lines[AO] == light.level_requested == 2.5
            @test !light.level_staged
            light_off(light)
            @test export_state(light)[1]["power_requested"] == 2.5
            light_on(light)
            @test daq.lines[AO] == light.level_requested == light.properties.power == 1.0
            @test !light.level_staged
            setpower(light, 2.5) # live changes do not stage the next enable
            @test !light.level_staged
            light_off(light)
            @test export_state(light)[1]["power_requested"] == 2.5
            light_on(light)
            @test daq.lines[AO] == light.level_requested == light.properties.power == 1.0
            fresh = make_light(T, daq)
            light_on(fresh)
            @test daq.lines[AO] == 1.0
            light_off(light)
            setpower(light, 2.0)
            light_off(light)
            @test light.level_staged && light.level_requested == 2.0
            light_on(light)
            @test daq.lines[AO] == 2.0 && !light.level_staged
            # Failed enables must retain both the pending request and its flag.
            for stage in (:create, :write, :delete), darken_fails in (false, true)
                light_off(light)
                setpower(light, 2.5)
                original = fail!(daq, stage, AO)
                darken_fails && fail!(daq, :write, AO; voltage=0.0)
                @test caught(() -> light_on(light)) === original
                @test light.level_staged && light.level_requested == 2.5
                @test light.properties.is_on == darken_fails
                light_on(light)
                @test daq.lines[AO] == 2.5 && !light.level_staged
            end
            # An uncertain enable is not permission for a subsequent level write.
            light_off(light)
            setpower(light, 2.0)
            original = fail!(daq, :write, AO)
            fail!(daq, :write, AO; voltage=0.0)
            @test caught(() -> light_on(light)) === original
            @test light.properties.is_on && light.level_staged
            empty!(daq.failures)
            empty!(daq.calls)
            setpower(light, 2.5)
            @test light.properties.is_on && light.level_staged && isempty(writes(daq))
            light_off(light)
            light_on(light)
            @test daq.lines[AO] == 2.5
            # The default itself must be recorded, including when clamped.
            for (lo, hi, expected) in ((1.2, 2.0, 1.2), (0.0, 0.5, 0.5))
                c = make_light(T, daq; min_voltage=lo, max_voltage=hi)
                light_on(c)
                @test daq.lines[AO] == c.level_requested == c.properties.power == expected
            end
        end
    end

    @testset "requested label refreshes after output commands" begin
        for T in (CrystaLaser, DaqTrLight)
            light = make_light(T)
            light_on(light)
            setpower(light, 2.5)
            light_off(light)
            fig = panel_figure(gui(light))
            labels = filter(x -> x isa Label, fig.content)
            requested = only(filter(l -> startswith(l.text[], "requested:"), labels))
            @test requested.text[] == "requested: 2.5 V"
            toggle = only(filter(x -> x isa Toggle, fig.content))
            toggle.active[] = true
            @test light.level_requested == 1.0
            @test requested.text[] == "requested: 1.0 V"
        end
    end

    @testset "a waiting child export cannot block lights_off" begin
        for T in TYPES
            daq = RecordingDAQ()
            light = make_light(T, daq)
            light_on(light)
            neighbor = make_light(DaqTrLight, RecordingDAQ())
            light_on(neighbor)
            entered, release = Channel{Nothing}(1), Channel{Nothing}(1)
            daq.export_hook = function ()
                put!(entered, nothing)
                timedwait(() -> isready(release), 5.0; pollint=0.001) === :ok || error("export release timed out")
                take!(release)
            end
            exporting = @async export_state(light)
            @test timedwait(() -> isready(entered), 5.0; pollint=0.001) === :ok
            stopping = @async lights_off(light, neighbor)
            try
                @test timedwait(() -> istaskdone(stopping), 0.5; pollint=0.001) === :ok
                @test !light.properties.is_on && !neighbor.properties.is_on
                @test daq.lines[enable_channel(T)] == 0.0
            finally
                put!(release, nothing)
                @test timedwait(() -> istaskdone(exporting) && istaskdone(stopping), 5.0; pollint=0.001) === :ok
            end
            @test !istaskfailed(exporting) && !istaskfailed(stopping)
            daq.export_hook = nothing
        end
    end

    @testset "generic gui returns its display result" begin
        for light in (SimLight(), make_light(CrystaLaser), make_light(VortranLaser))
            result = gui(light)
            @test result === displayed[]
            @test result isa PanelScreen
            @test panel_figure(result) isa Figure
        end
        # The DiodeLaser panels keep returning the figure, not the display result.
        laser = SimDiodeLaser()
        result = gui(laser)
        @test result === displayed[].figure
        @test result isa Figure
    end

    @testset "caller display properties are preserved" begin
        for T in TYPES, unit in ("%", "mW", "V")
            properties = LightSourceProperties(unit, 45.0, false, -10.0, 100.0)
            before = (properties.power_unit, properties.power, properties.is_on, properties.min_power, properties.max_power)
            light = @test_logs min_level=Base.CoreLogging.Warn make_light(T; properties)
            @test light.properties === properties
            @test (properties.power_unit, properties.power, properties.is_on, properties.min_power, properties.max_power) == before
            setpower(light, 2.5)
            @test properties.power == (unit == "V" ? 2.5 : 45.0)
            light_on(light)
            setpower(light, 2.0)
            @test properties.power == (unit == "V" ? 2.0 : 45.0)
            @test properties.power_unit == unit && properties.min_power == -10.0 && properties.max_power == 100.0
            settings = LI._power_settings(light)
            @test settings.unit == "V" && settings.lo == light.min_voltage && settings.hi == light.max_voltage
            attrs = export_state(light)[1]
            @test attrs["power_requested"] == 2.0 && attrs["power_unit"] == "V"
            @test all(w -> w[4] != 45.0, writes(light.daq))
        end
    end

    @testset "the textbox follows the slider without a second command" begin
        daq = RecordingDAQ()
        light = make_light(VortranLaser, daq)
        fig = panel_figure(gui(light))
        slider = only(filter(x -> x isa Slider, fig.content))
        textbox = only(filter(x -> x isa Textbox, fig.content))
        textbox.stored_string[] = "1"
        empty!(daq.calls)
        set_close_to!(slider, 2.0)
        @test textbox.displayed_string[] == "2.0"
        @test writes(daq) == [(:write, "AO", AO, 2.0)]
    end

    @testset "GUI fields describe the field-specific camera menus" begin
        text = read(joinpath(pkgdir(MC), "skills", "mc-api-map", "references", "gui-fields.md"), String)
        @test !occursin("outside its scope", text)
        @test occursin("capture_mode", text) && occursin("trigger_mode", text)
        @test occursin("selected field", text)
    end
end

# The failure model from the review's p6/p7 probes. Unlike RecordingDAQ, it
# omits call logs so exhaustive walks do not allocate a trace at every step.
struct WalkTask
    id::Int
    channel::String
end
mutable struct WalkDAQ <: DAQ
    unique_id::String
    lines::Dict{String,Float64}
    reserved::Dict{String,Int}
    mode::Symbol
    persistent::Bool
    fired::Bool
    next_id::Int
end
WalkDAQ() = WalkDAQ("walk DAQ", Dict(), Dict(), :none, false, false, 0)
want(d::WalkDAQ, mode) = d.mode == mode && (d.persistent || !d.fired)
function MC.createtask(d::WalkDAQ, kind::String, channel::String; kwargs...)
    haskey(d.reserved, channel) && error("channel reserved")
    if want(d, :create)
        d.fired = true
        error("create failed")
    end
    d.next_id += 1
    return WalkTask(d.next_id, channel)
end
function MC.setvoltage(d::WalkDAQ, t::WalkTask, v::Float64)
    if want(d, :write_before)
        d.fired = true
        error("write failed before changing line")
    end
    d.lines[t.channel] = v
    if want(d, :write_after)
        d.fired = true
        error("write failed after changing line")
    end
    return 1
end
function MC.deletetask(d::WalkDAQ, t::WalkTask)
    if want(d, :delete_freed)
        d.fired = true
        error("delete failed with channel freed")
    end
    if want(d, :delete_reserved)
        d.fired = true
        d.reserved[t.channel] = t.id
        error("delete failed with channel reserved")
    end
    return nothing
end
const WALK_COMMANDS = (
    (:initialize, initialize), (:light_on, light_on), (:light_off, light_off),
    (:setpower_2_5, l -> setpower(l, 2.5)), (:setpower_1_5, l -> setpower(l, 1.5)),
    (:shutdown, shutdown), (:gc, l -> empty!(l.daq.reserved)))
const WALK_MODES = ((:none, false), (:create, false), (:create, true),
    (:write_before, false), (:write_before, true), (:write_after, false),
    (:write_after, true), (:delete_freed, false), (:delete_reserved, false))
emitting(l) = get(l.daq.lines, enable_channel(typeof(l)), 0.0) > 0
function walk_invariants(T, start_lit, sequence)
    d = WalkDAQ()
    light = make_light(T, d)
    if start_lit
        d.lines[AO] = 2.5
        T === VortranLaser && (d.lines[DO] = 1.0)
    end
    off_attempted = false
    violations = [0, 0]
    for option in sequence
        ci, mi = mod1(option, length(WALK_COMMANDS)), (option - 1) ÷ length(WALK_COMMANDS) + 1
        name, command = WALK_COMMANDS[ci]
        d.mode, d.persistent = WALK_MODES[mi]
        d.fired = false
        was_emitting = emitting(light)
        try
            command(light)
        catch e
            e isa ErrorException || rethrow() # only the fake's injected failures
        end
        off_attempted |= name in (:initialize, :light_off, :shutdown)
        # Like p6/p7, I1 starts after the first off attempt. A newly
        # constructed driver cannot know a line left high by another process.
        violations[1] += off_attempted && emitting(light) && !light.properties.is_on
        violations[2] += !was_emitting && emitting(light) && name != :light_on
    end
    return violations
end
function check_walks(; full=false)
    n = length(WALK_COMMANDS) * length(WALK_MODES)
    totals = [0, 0]
    first_failure = nothing
    count = 0
    for T in TYPES, start_lit in (false, true)
        sequences = full ? ((a,b,c) for a in 1:n for b in 1:n for c in 1:n) :
            ((a,b) for a in 1:n for b in 1:n)
        for sequence in sequences
            v = walk_invariants(T, start_lit, sequence)
            totals .+= v
            any(!iszero, v) && first_failure === nothing && (first_failure = (T, start_lit, sequence, v))
            count += 1
        end
        if !full
            # Fixed, evenly spread sample of 4096 distinct three-step walks.
            # 7919 is coprime to 63^3, so no duplicates occur in this prefix.
            for i in 0:4095
                k = mod(i * 7919, n^3)
                sequence = (mod(k,n)+1, mod(k÷n,n)+1, k÷n^2+1)
                v = walk_invariants(T, start_lit, sequence)
                totals .+= v
                any(!iszero, v) && first_failure === nothing && (first_failure = (T, start_lit, sequence, v))
                count += 1
            end
        end
    end
    return (; totals, first_failure, count)
end

@testset "Emission invariants across commands and failures" begin
    # All 1,500,282 three-step walks passed in 43.87 s on Julia 1.13.
    # Keep all two-step walks plus the fixed sample by default (brief's 30 s
    # budget); set MC_FULL_LIGHT_WALKS=true to repeat the exhaustive check.
    full = get(ENV, "MC_FULL_LIGHT_WALKS", "false") == "true"
    result = nothing
    elapsed = @elapsed result = check_walks(; full)
    @info "DAQ failure walks" full seconds=round(elapsed; digits=2) walks=result.count first_failure=result.first_failure
    @test result.totals[1] == 0 # I1: never claim off after an uncertain off
    @test result.totals[2] == 0 # I2: only light_on can make a dark light emit
end

@testset "Unknown levels and lifecycle staging" begin
    for T in TYPES
        light = make_light(T)
        @test isnan(export_state(light)[1]["power_requested"])
        T === VortranLaser && continue
        light_on(light)
        @test export_state(light)[1]["power_requested"] == 1.0
        for lifecycle in (initialize, shutdown), failing in (false, true)
            light_off(light)
            setpower(light, 2.7785)
            failing && fail!(light.daq, :create, AO)
            caught(() -> lifecycle(light))
            @test !light.level_staged
            light_on(light)
            @test light.daq.lines[AO] == 1.0
        end
        light_off(light)
        setpower(light, 2.7785)
        shutdown(light)
        initialize(light)
        light_on(light)
        @test light.daq.lines[AO] == 1.0
    end
end

@testset "Off attempts revoke level-write permission" begin
    for T in (CrystaLaser, DaqTrLight), off in (initialize, light_off, shutdown)
        daq = RecordingDAQ()
        light = make_light(T, daq)
        # Off failed before touching a dark line. The report is uncertain,
        # but setpower must not turn that uncertainty into an enable.
        fail!(daq, :create, AO)
        @test caught(() -> off(light)) isa ErrorException
        @test light.properties.is_on
        empty!(daq.calls)
        setpower(light, 2.5)
        @test isempty(writes(daq)) && light.level_staged
        @test get(daq.lines, AO, 0.0) == 0.0
        @test hasproperty(light, :line_enabled) && !light.line_enabled
        light_on(light)
        @test hasproperty(light, :line_enabled) && light.line_enabled
        fail!(daq, :write, AO)
        @test caught(() -> setpower(light, 2.0)) isa ErrorException
        @test hasproperty(light, :line_enabled) && !light.line_enabled
    end
end

@testset "Output status polls the driver without commanding" begin
    for light in (make_light(CrystaLaser), make_light(DaqTrLight), make_light(VortranLaser), SimDiodeLaser())
        light isa SimDiodeLaser && initialize(light)
        fig = light isa SimDiodeLaser ? gui(light) : LI._light_panel(light)
        try
            toggle = first(filter(x -> x isa Toggle, fig.content))
            status = only(filter(x -> x isa Label && x.text[] == "output off", fig.content))
            light isa SimDiodeLaser || @test isempty(light.daq.calls)
            light_on(light) # another caller, outside the panel
            before = light isa SimDiodeLaser ? light.drive_current : copy(light.daq.calls)
            sleep(0.65)
            @test status.text[] == "output on"
            @test toggle.active[]
            @test isequal(light isa SimDiodeLaser ? light.drive_current : light.daq.calls, before)
            fig.scene.events.window_open[] = false
            light_off(light)
            before = light isa SimDiodeLaser ? light.drive_current : copy(light.daq.calls)
            sleep(0.65)
            @test status.text[] == "output on" && toggle.active[] # polling has stopped
            @test isequal(light isa SimDiodeLaser ? light.drive_current : light.daq.calls, before)
        finally
            fig.scene.events.window_open[] = false
        end
    end
end

@testset "Reserved deletion: GC, off, and process restart recovery" begin
    for T in TYPES, gc_succeeds in (false, true)
        daq = RecordingDAQ()
        light = make_light(T, daq)
        daq.lines[enable_channel(T)] = 1.0 # left high by a previous process
        # Keep the failed task live, unlike the usual freed-delete failure.
        daq.finalizer_fails = !gc_succeeds
        fail!(daq, :delete_reserved, enable_channel(T))
        @test caught(() -> light_off(light)) isa ErrorException
        @test light.properties.is_on
        @test !isempty(daq.open_tasks) && haskey(daq.reserved, enable_channel(T))
        @test caught(() -> light_off(light)) isa ErrorException
        GC.gc()
        err = caught(() -> light_off(light))
        @test gc_succeeds ? err === nothing : err isa ErrorException
        @test light.properties.is_on == !gc_succeeds
        # Restart releases old task resources. A new driver still initializes
        # the same physical line to zero; it does not trust object defaults.
        restarted_daq = RecordingDAQ()
        restarted_daq.lines = daq.lines
        restarted_daq.lines[enable_channel(T)] = 1.0
        restarted = make_light(T, restarted_daq)
        initialize(restarted)
        @test restarted_daq.lines[enable_channel(T)] == 0.0
        @test !restarted.properties.is_on
    end
end
for fig in panels
    fig.scene.events.window_open[] = false
end

end # module
