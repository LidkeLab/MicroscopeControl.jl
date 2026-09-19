using InteractiveUtils

# Dummy Stage with no methods of its own, used to check that the interface
# fallbacks throw instead of silently returning `nothing`. Must live at file
# top level: `include` evaluates each form here at module scope regardless of
# the `@testset` block it is textually nested in, but `struct` still requires
# that top-level scope (not the local scope a testset body runs in).
struct _ContractDummyStage <: MicroscopeControl.Stage end

@testset "Interface Contract" begin
    MC = MicroscopeControl

    @testset "No ambiguous top-level exports" begin
        ambiguous = [n for n in names(MC) if !isdefined(MC, n)]
        if !isempty(ambiguous)
            @info "Ambiguous/undefined exported names" ambiguous
        end
        @test isempty(ambiguous)
    end

    # Devices that do not yet implement the full AbstractInstrument contract.
    # Not addressed here: this PR is a naming/dispatch fix, not a driver
    # behavior change. MLSLM has no initialize/shutdown/export_state/gui
    # methods at all; Triggerscope4 has no export_state.
    no_core_methods = Set([:MLSLM])
    no_export_state = Set([:MLSLM, :Triggerscope4])

    interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG)

    @testset "Core AbstractInstrument contract" begin
        for iface in interfaces
            for T in subtypes(iface)
                nameof(T) === :StageFormat && continue # not a device, a config format
                nameof(T) in no_core_methods && continue
                @test hasmethod(MC.initialize, Tuple{T})
                @test hasmethod(MC.shutdown, Tuple{T})
                @test hasmethod(MC.gui, Tuple{T})
                nameof(T) in no_export_state && continue
                @test hasmethod(MC.export_state, Tuple{T})
            end
        end
    end

    @testset "Stage contract" begin
        for T in subtypes(MC.Stage)
            nameof(T) === :StageFormat && continue
            @test hasmethod(MC.move, Tuple{T,Float64,Float64,Float64})
            @test hasmethod(MC.getposition, Tuple{T})
        end
    end

    @testset "Camera contract" begin
        for T in subtypes(MC.Camera)
            for f in (MC.capture, MC.getdata, MC.getlastframe, MC.abort, MC.live, MC.sequence)
                @test hasmethod(f, Tuple{T})
            end
        end
    end

    @testset "LightSource contract" begin
        for T in subtypes(MC.LightSource)
            @test hasmethod(MC.setpower, Tuple{T,Float64})
            @test hasmethod(MC.light_on, Tuple{T,Float64})
            @test hasmethod(MC.light_off, Tuple{T})
        end
    end

    @testset "Stub throws" begin
        @test_throws ErrorException MC.getposition(_ContractDummyStage())
        @test_throws ErrorException MC.gui(_ContractDummyStage())
    end
end
