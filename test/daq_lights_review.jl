# Review regressions: each testset is exercised against the pre-fix code too.
@testset "DAQ light review regressions" begin
    @testset "Finding 2: every textbox submission commands exactly once" begin
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

    @testset "Finding 3: single-line staged requests and legacy enabling" begin
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
            for off in (light_off, shutdown, initialize)
                off(light)
                @test light.level_staged && light.level_requested == 2.0
            end
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
            # The default itself must be recorded, including when clamped.
            for (lo, hi, expected) in ((1.2, 2.0, 1.2), (0.0, 0.5, 0.5))
                c = make_light(T, daq; min_voltage=lo, max_voltage=hi)
                light_on(c)
                @test daq.lines[AO] == c.level_requested == c.properties.power == expected
            end
        end
    end

    @testset "Finding 3: requested label refreshes after output commands" begin
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

    @testset "Finding 4: a waiting child export cannot block lights_off" begin
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

    @testset "Finding 5: generic gui returns its display result" begin
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

    @testset "Finding 6: caller display properties are preserved" begin
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

    @testset "Finding 7: the textbox follows the slider without a second command" begin
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

    @testset "Finding 8: GUI fields describe the field-specific camera menus" begin
        text = read(joinpath(pkgdir(MC), "skills", "mc-api-map", "references", "gui-fields.md"), String)
        @test !occursin("outside its scope", text)
        @test occursin("capture_mode", text) && occursin("trigger_mode", text)
        @test occursin("selected field", text)
    end
end
