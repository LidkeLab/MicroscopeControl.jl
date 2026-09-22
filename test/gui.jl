using GLMakie

# Regression tests for the lightsource_interface/gui.jl fix (CHANGELOG 0.3.0):
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

@testset "GUI panels" begin
    @testset "Simulated Camera" begin
        cam = SimCamera()
        before = state_snapshot(cam)
        gui(cam)
        GLMakie.closeall()
        @test state_snapshot(cam) == before
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
end
