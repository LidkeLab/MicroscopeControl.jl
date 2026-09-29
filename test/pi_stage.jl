# PIStage against the fake GCS2 library in `pi_stage_fake_sdk.jl`: initialize's
# ordering and cleanup, and shutdown's id handling. No hardware.
@testset "PI stage (fake GCS2)" begin
    PI = MicroscopeControl.HardwareImplementations.PI
    F = Main.FakePIStage
    ncalls(op) = count(==(op), F.calls)
    saved_timeout = PI.REFERENCE_TIMEOUT_S[]
    PI.REFERENCE_TIMEOUT_S[] = 0.3

    try
        @testset "never-initialized stage has no id" begin
            F.reset!()
            stage = PIStage()
            @test stage.id == -1
            shutdown(stage)
            @test ncalls("PI_CloseConnection") == 0
        end

        @testset "successful initialize" begin
            F.reset!()
            F.not_ready_polls[] = 2
            F.unreferenced_polls[] = 2
            push!(F.connect_ids, 5)
            stage = PIStage()
            seen = Ref{Any}(nothing)
            F.frf_hook[] = () -> (seen[] = stage.connectionstatus)
            initialize(stage)
            @test stage.connectionstatus
            @test stage.id == 5
            @test seen[] == false
            iFRF = findfirst(==("PI_FRF"), F.calls)
            iready = findfirst(==("PI_IsControllerReady"), F.calls)
            iq = findfirst(==("PI_qFRF"), F.calls)
            @test iFRF < iready < iq
            @test ncalls("PI_IsControllerReady") == 3
        end

        @testset "refused PI_FRF" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_FRF")
            stage = PIStage()
            @test_throws ErrorException initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
            @test stage.id == -1
        end

        @testset "controller never ready" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.not_ready_polls[] = typemax(Int)
            stage = PIStage()
            @test_throws "not ready" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
        end

        @testset "axes never referenced" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.unreferenced_polls[] = typemax(Int)
            stage = PIStage()
            @test_throws "not referenced" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
        end

        @testset "throw after the reference" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.throw!("PI_qTMN")
            stage = PIStage()
            @test_throws "PI_qTMN threw" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
        end

        @testset "failed close keeps the id; retry cannot report ready" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_FRF")
            F.close_leaves_open[] = true
            stage = PIStage()
            @test_throws ErrorException initialize(stage)
            @test !stage.connectionstatus
            @test stage.id == 5
            F.enum_count[] = 0
            initialize(stage)
            @test !stage.connectionstatus
        end

        @testset "shutdown after initialize" begin
            F.reset!()
            push!(F.connect_ids, 5)
            stage = PIStage()
            initialize(stage)
            shutdown(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
            @test stage.id == -1
            shutdown(stage)
            @test ncalls("PI_CloseConnection") == 1
        end
    finally
        PI.REFERENCE_TIMEOUT_S[] = saved_timeout
        F.reset!()
    end
end
