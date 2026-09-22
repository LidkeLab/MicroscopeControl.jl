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
                GLMakie.closeall()
            catch
                threw = true
            end
            @test_broken !threw
            # Whether or not it throws, no hardware call happens before the
            # `stagelabel` field access, so state must still be unchanged.
            @test state_snapshot(stage) == before
        end
    end
end
