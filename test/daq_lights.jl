# Production drivers over a DAQ subtype. No NIdaq method is replaced here;
# discovery, task allocation and every voltage write stay inside this fake.
module DaqLightsTests
using MicroscopeControl, Test, GLMakie
const MC = MicroscopeControl
const LI = MC.HardwareInterfaces.LightSourceInterface

struct RecordedTask
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
    devices::Vector{String}
end
RecordingDAQ(; devices=["Fake1", "Fake2"]) = RecordingDAQ("recording DAQ", Dict(), [], Set(), [], 0, nothing, devices)
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
    maybe_fail!(daq, :create, channel)
    daq.next_id += 1
    push!(daq.open_tasks, daq.next_id)
    return RecordedTask(daq.next_id, kind, channel)
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
    delete!(daq.open_tasks, task.id)
    # A cleanup error after the write still makes the command uncertain.
    maybe_fail!(daq, :delete, task.channel)
    return nothing
end
MC.export_state(daq::RecordingDAQ) = (Dict("unique_id" => daq.unique_id), nothing, Dict())

const AO = "Named/ao0"
const DO = "Named/port0/line7"
const TYPES = (CrystaLaser, DaqTrLight, VortranLaser)
# Existing panel seam: build the real controls and callbacks without opening
# a display window. This affects only the concrete types exercised here.
LI._show_panel(fig, light::Union{SimLight,CrystaLaser,VortranLaser}) = fig
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
            @test T === VortranLaser ? isnan(light.level_requested) : light.level_requested == 1.0
            properties = LightSourceProperties("mW", 45.0, false, 0.0, 100.0)
            @test_logs (:warn, r"changed to V") make_light(T; properties)
            light = make_light(T; properties)
            @test light.properties === properties
            @test properties.power_unit == "V"
            # Default DAQ construction with named channels is pure too.
            default_daq = T === VortranLaser ? T(; ao_channel=AO, do_channel=DO) : T(; channel=AO)
            @test default_daq.daq isa NIdaq
            @test hasmethod(T, Tuple{}) # downstream no-argument construction remains supported
        end
        for T in (CrystaLaser, DaqTrLight)
            @test make_light(T; min_voltage=1.2, max_voltage=2.0).level_requested == 1.2
            @test make_light(T; min_voltage=0.0, max_voltage=0.5).level_requested == 0.5
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
            @test light.properties.is_on && daq.lines[AO] == 2.5
            setpower(light, 2.0)
            @test daq.lines[AO] == light.level_requested == 2.0
            shutdown(light)
            @test !light.properties.is_on && daq.lines[AO] == 0.0 && light.level_requested == 2.0
            light_on(light)
            initialize(light)
            @test !light.properties.is_on && daq.lines[AO] == 0.0 && light.level_requested == 2.0
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
            @test daq.lines[AO] == 2.5
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
            @test attrs["power"] == attrs["power_requested"] == 2.5
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

    @testset "Failed off and initialize retain the enable state" begin
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
            @test light.properties.is_on == do_fails
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
            fig = gui(light)
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
                    # A failed live setpower darkens; the toggle must follow that too.
                    fail!(daq, :write, AO)
                    @test caught(() -> set_close_to!(slider, settings.hi)) === nothing
                    @test !light.properties.is_on && !toggle.active[]
                    @test any(l -> l.text[] == "output off", labels)
                end
            finally
                GLMakie.closeall()
            end
        end
    end
end
end # module
