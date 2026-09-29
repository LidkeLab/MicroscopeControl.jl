@testset "PI N472 (no hardware)" begin
    N = MicroscopeControl.HardwareImplementations.PI_N472
    F = Main.FakeGCS2
    quiet(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())
    setup_ops = ["PI_RON", "PI_qRON", "PI_POS", "PI_SVO", "PI_qSVO", "PI_qTMN", "PI_qTMX", "PI_VEL", "PI_qVEL"]

    @testset "_cstring stops at the first NUL" begin
        buf = zeros(UInt8, 32)
        buf[1:14] .= codeunits("PI C-885 SN 42")
        buf[20] = UInt8('x')   # stale bytes past the terminator are ignored
        @test N._cstring(buf) == "PI C-885 SN 42"
        @test N._cstring(codeunits("abc") |> collect) == "abc"
        @test N._cstring(UInt8[0x00]) == ""
    end

    @testset "first description is passed as a String" begin
        F.reset!()
        F.enum_bytes[] = UInt8[codeunits("d1\nd2")..., 0x00, codeunits("junk")...]
        F.enum_count[] = 2
        stage = N472()
        quiet(() -> initialize(stage))
        @test F.lastarg["PI_ConnectUSB"] isa String
        @test F.lastarg["PI_ConnectUSB"] == "d1"
        @test stage.connectionstatus == true
        @test stage.id == 0
    end

    @testset "description is stripped" begin
        F.reset!()
        F.enum_bytes[] = UInt8[codeunits("  d1\r\n")..., 0x00]
        quiet(() -> initialize(N472()))
        @test F.lastarg["PI_ConnectUSB"] == "d1"
    end

    @testset "failed connect leaves the object retryable" begin
        F.reset!()
        append!(F.connect_ids, [-1, 0])
        stage = N472()
        @test_logs (:error, r"PI_ConnectUSB failed") match_mode=:any initialize(stage)
        @test stage.connectionstatus == false
        @test stage.id == -1
        @test !any(op -> op in setup_ops, F.calls)
        quiet(() -> initialize(stage))
        @test stage.connectionstatus == true
        @test stage.id == 0
    end

    @testset "no controller found" begin
        F.reset!()
        F.enum_count[] = 0
        stage = N472()
        @test_logs (:error, r"No PI C-885 found") match_mode=:any initialize(stage)
        @test stage.connectionstatus == false
        @test !("PI_ConnectUSB" in F.calls)
        @test_logs (:error, r"No PI C-885 found") match_mode=:any initialize(stage)
    end

    @testset "stopmotion sends one axes string" begin
        F.reset!()
        stage = N472()
        quiet(() -> initialize(stage))
        quiet(() -> stopmotion(stage))
        @test F.lastarg["PI_HLT"] == "1 3 5"
    end

    @testset "shutdown closes only its own connection" begin
        F.reset!()
        A = N472(); B = N472()
        quiet(() -> initialize(A))
        quiet(() -> shutdown(A))
        append!(F.connect_ids, [0, 0])
        quiet(() -> initialize(B))
        @test 0 in F.open_ids
        quiet(() -> shutdown(A))
        @test 0 in F.open_ids
        @test count(==("PI_CloseConnection"), F.calls) == 1
        @test A.id == -1
    end

    @testset "a fresh object holds no connection" begin
        F.reset!()
        @test N472().id == -1
        B = N472()
        quiet(() -> initialize(B))
        @test 0 in F.open_ids
        quiet(() -> shutdown(N472()))
        @test 0 in F.open_ids
        @test !("PI_CloseConnection" in F.calls)
    end

    @testset "a failing setup step closes the connection: $op" for op in setup_ops
        F.reset!()
        F.error_code[] = 7
        push!(F.failing, op)
        stage = N472()
        err = try
            quiet(() -> initialize(stage))
            nothing
        catch e
            e
        end
        @test err isa ErrorException
        @test occursin("GCS error 7", err.msg)
        @test !(0 in F.open_ids)
        @test stage.connectionstatus == false
        @test stage.id == -1
        empty!(F.failing)
        F.error_code[] = 0
        quiet(() -> initialize(stage))
        @test stage.connectionstatus == true
    end
end
