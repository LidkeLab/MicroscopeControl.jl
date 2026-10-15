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
            @test iFRF < findfirst(==("PI_IsControllerReady"), F.calls)
            @test findlast(==("PI_IsControllerReady"), F.calls) < findfirst(==("PI_qFRF"), F.calls)
            @test stage.range_x == (0.0, 25.0)
            @test stage.range_y == (0.0, 25.0)
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

        @testset "failed close keeps the id; a retry reclaims it" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_FRF")
            F.close_leaves_open[] = true
            stage = PIStage()
            @test_throws ErrorException initialize(stage)
            @test !stage.connectionstatus
            @test stage.id == 5
            F.close_leaves_open[] = false
            delete!(F.failing, "PI_FRF")
            push!(F.connect_ids, 6)
            empty!(F.calls)
            initialize(stage)
            @test stage.connectionstatus
            @test stage.id == 6
            @test findfirst(==("PI_CloseConnection"), F.calls) < findfirst(==("PI_EnumerateUSB"), F.calls)
        end

        @testset "reclaim fails: no reconnect" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_FRF")
            F.close_leaves_open[] = true
            stage = PIStage()
            @test_throws ErrorException initialize(stage)
            @test stage.id == 5
            empty!(F.calls)
            initialize(stage)
            @test !stage.connectionstatus
            @test stage.id == 5
            @test ncalls("PI_EnumerateUSB") == 0
        end

        @testset "controller-ready query fails" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_IsControllerReady")
            stage = PIStage()
            @test_throws "PI_IsControllerReady failed" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
            @test stage.id == -1
        end

        @testset "nothing enumerated" begin
            F.reset!()
            F.enum_count[] = 0
            stage = PIStage()
            @test initialize(stage) === nothing
            @test !stage.connectionstatus
            @test stage.id == -1
            @test ncalls("PI_ConnectUSB") == 0
        end

        @testset "connect fails" begin
            F.reset!()
            push!(F.connect_ids, -1)
            stage = PIStage()
            @test initialize(stage) === nothing
            @test !stage.connectionstatus
            @test stage.id == -1
            @test ncalls("PI_SVO") == 0
        end

        @testset "range read fails" begin
            for op in ("PI_qTMN", "PI_qTMX")
                F.reset!()
                push!(F.connect_ids, 5)
                F.fail!(op)
                stage = PIStage()
                @test_throws "travel range unknown" initialize(stage)
                @test ncalls("PI_CloseConnection") == 1
                @test !stage.connectionstatus
            end
        end

        @testset "velocity set fails" begin
            for op in ("PI_VEL", "PI_qVEL")
                F.reset!()
                push!(F.connect_ids, 5)
                F.fail!(op)
                stage = PIStage()
                @test_throws "velocity not set" initialize(stage)
                @test ncalls("PI_CloseConnection") == 1
                @test !stage.connectionstatus
            end
        end

        @testset "motion stops after polls" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.moving_polls[] = 2
            stage = PIStage()
            initialize(stage)
            @test stage.connectionstatus
            @test ncalls("PI_IsMoving") == 3
        end

        @testset "motion never stops" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.moving_polls[] = typemax(Int)
            stage = PIStage()
            @test_throws "still moving" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
        end

        @testset "IsMoving query fails" begin
            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_IsMoving")
            stage = PIStage()
            @test_throws "PI_IsMoving failed" initialize(stage)
            @test ncalls("PI_CloseConnection") == 1
            @test !stage.connectionstatus
        end

        @testset "GUI guard" begin
            G = MicroscopeControl.gui_initialize
            F.reset!()
            push!(F.connect_ids, 5)
            stage = PIStage()
            @test G(stage, "stage") === true

            F.reset!()
            F.enum_count[] = 0
            stage = PIStage()
            @test G(stage, "stage") === false

            F.reset!()
            push!(F.connect_ids, 5)
            F.fail!("PI_FRF")
            stage = PIStage()
            r = @test_logs (:error, r"Failed to initialize the stage") match_mode=:any G(stage, "stage")
            @test r === false
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
