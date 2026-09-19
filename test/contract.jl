using InteractiveUtils

# Dummy Stage with no methods of its own, used to check that the interface
# fallbacks throw instead of silently returning `nothing`. Must live at file
# top level: `include` evaluates each form here at module scope regardless of
# the `@testset` block it is textually nested in, but `struct` still requires
# that top-level scope (not the local scope a testset body runs in).
# `dimensions` defaults to 1 so the no-arg form still exercises the plain
# `getposition` stub; passing 4 explicitly exercises `gui`'s own
# dimension-dispatch fallback (see "Stub throws" below).
struct _ContractDummyStage <: MicroscopeControl.Stage
    dimensions::Int
end
_ContractDummyStage() = _ContractDummyStage(1)

# Dummy AbstractInstrument with no methods of its own, used to check the
# generic `gui` fallback in isolation. `_ContractDummyStage` can't be used for
# this: `gui(::Stage)` has a real dimension-dispatch body that fails on
# `stage.dimensions` before ever reaching the `AbstractInstrument` stub.
struct _ContractDummyInstrument <: MicroscopeControl.AbstractInstrument end

# true iff the most specific method for these argument types is defined on T itself
function has_specific_method(f, T, argtypes...)
    sig = Tuple{T, argtypes...}
    hasmethod(f, sig) || return false
    m = which(f, sig)
    return m.sig.parameters[2] === T
end

@testset "Interface Contract" begin
    MC = MicroscopeControl

    @testset "No ambiguous top-level exports" begin
        ambiguous = [n for n in names(MC) if !isdefined(MC, n)]
        if !isempty(ambiguous)
            @info "Ambiguous/undefined exported names" ambiguous
        end
        @test isempty(ambiguous)
    end

    # `gui` is architecturally different from initialize/shutdown/export_state:
    # every interface (Stage, Camera, LightSource, DAQ, Attenuator, TRIG) has its
    # own real, functional `gui(::<Interface>)` in its `gui.jl` (e.g.
    # stage_interface/gui.jl dispatches by `stage.dimensions` to genuine
    # GLMakie-building code for every stage; camera_interface/gui.jl similarly
    # builds a real control figure) -- it is the *intended*, shared
    # implementation, not a vacuous stand-in for a missing device-specific one.
    # So "T implements gui" means "dispatch does not land on the universal
    # AbstractInstrument stub", not "gui is defined on T's own leaf type".
    # SLM has no interface-level `gui.jl` at all, so this still correctly
    # excludes a device with no gui support whatsoever.
    function has_working_gui(T)
        sig = Tuple{T}
        hasmethod(MC.gui, sig) || return false
        m = which(MC.gui, sig)
        return m.sig.parameters[2] !== MC.AbstractInstrument
    end

    # Devices that do not yet implement the full AbstractInstrument contract.
    # SLM and TRIG are declared as their own abstract hierarchies
    # (`abstract type SLM end`, `abstract type TRIG end` in
    # slm_interface/interface_types.jl and triggerscope_interface/interface_types.jl)
    # rather than `<: AbstractInstrument`, so their devices never get the shared
    # fallbacks by construction -- any method they do have had to be written
    # directly against the concrete device. Hierarchy fix (making SLM/TRIG
    # `<: AbstractInstrument`) is a follow-up, not addressed here.
    # MLSLM has no initialize/shutdown/export_state/gui methods of its own at all.
    # Triggerscope4 defines initialize/shutdown itself, gets gui from the shared
    # `gui(::TRIG)`, but has no export_state.
    # NIdaq and ThorCamCSCCamera each lack one lifecycle method (pre-existing,
    # not touched by this naming/dispatch-only PR); TCubeLaser's export_state
    # takes an extra unused positional argument, so the 1-arg contract call
    # never reaches it and falls through to the (now-throwing) instrument-level
    # stub. All are pre-existing gaps, listed here rather than papered over.
    no_core_methods = Set([:MLSLM])
    no_initialize = Set([:NIdaq, :ThorCamCSCCamera])
    no_shutdown = Set([:NIdaq])
    no_export_state = Set([:MLSLM, :Triggerscope4, :ThorCamCSCCamera, :TCubeLaser])

    interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG)

    @testset "Core AbstractInstrument contract" begin
        for iface in interfaces
            for T in subtypes(iface)
                nameof(T) === :StageFormat && continue # not a device, a config format
                nameof(T) === :_ContractDummyStage && continue # test fixture, not a device
                nameof(T) in no_core_methods && continue
                nameof(T) in no_initialize || @test has_specific_method(MC.initialize, T)
                nameof(T) in no_shutdown || @test has_specific_method(MC.shutdown, T)
                @test has_working_gui(T)
                nameof(T) in no_export_state && continue
                @test has_specific_method(MC.export_state, T)
            end
        end
    end

    @testset "Stage contract" begin
        for T in subtypes(MC.Stage)
            (nameof(T) === :StageFormat || nameof(T) === :_ContractDummyStage) && continue
            @test has_specific_method(MC.getposition, T)
            # Arity varies by dimensionality (1D stages take just `x`, 2D take
            # `x,y`, only 3D matches the fallback's `x,y,z`), so check dispatch
            # across all `move` methods rather than a single fixed signature.
            @test any(m -> m.sig.parameters[2] === T, methods(MC.move))
        end
    end

    @testset "Camera contract" begin
        for T in subtypes(MC.Camera)
            for f in (MC.capture, MC.getdata, MC.getlastframe, MC.abort, MC.live, MC.sequence)
                @test has_specific_method(f, T)
            end
        end
    end

    @testset "LightSource contract" begin
        for T in subtypes(MC.LightSource)
            @test has_specific_method(MC.setpower, T, Float64)
            # `light_on`'s own docstring and every driver implement the 1-arg
            # `light_on(::T)` form, but the interface stub in
            # lightsource_interface/interface_functions.jl is declared with a
            # second `ipower::Float64` argument that no driver actually takes.
            # `MC.light_on(light, power)` therefore throws for every
            # LightSource today -- a pre-existing interface/driver arity
            # mismatch, not something to paper over with a fake 2-arg wrapper.
            # Tracked as broken rather than skipped so a real fix flips it.
            @test_broken has_specific_method(MC.light_on, T, Float64)
            @test has_specific_method(MC.light_on, T) # the arity drivers actually implement
            @test has_specific_method(MC.light_off, T)
        end
    end

    @testset "Stub throws" begin
        @test_throws "not implemented" MC.getposition(_ContractDummyStage())
        @test_throws "not implemented" MC.gui(_ContractDummyInstrument())
        @test_throws "not implemented" MC.gui(_ContractDummyStage(4))
    end
end
