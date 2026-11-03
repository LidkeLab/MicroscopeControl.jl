# Included after the PI, N472 and MCL recorders: all reads stay inside the fakes.
# SmarAct uses its scalar property seam, never the vendor DLL.
module FakeStageExport
const smaract_positions = Int64[1_000_000, 2_000_000, 3_000_000]
const smaract_reads = Int32[]
const smaract_fail_axis = Ref(Int32(-1))
end

@eval MicroscopeControl.HardwareImplementations.MCS2Stage_mod begin
    function _get_i64(stage::MCS2Stage, ch::Int32, pkey)
        pkey == SA_CTL_PKEY_POSITION || error("Unexpected SmarAct property read")
        push!(Main.FakeStageExport.smaract_reads, ch)
        ch == Main.FakeStageExport.smaract_fail_axis[] && error("SmarAct position read failed")
        return Main.FakeStageExport.smaract_positions[ch + 1]
    end
end

@testset "Stage export reads the position at save time without motion" begin
    PI = MicroscopeControl.HardwareImplementations.PI
    N = MicroscopeControl.HardwareImplementations.PI_N472
    MCL = MicroscopeControl.HardwareImplementations.MadCityLabs
    SA = MicroscopeControl.HardwareImplementations.MCS2Stage_mod

    # Valid measured positions differ from both the last-read cache and targets.
    # PI values reproduce the lab's 12.5,12.5 cache while the stage is elsewhere.
    FakePIStage.reset!()
    FakePIStage.position .= [6.2, 19.4]
    pi = PI.PIStage(connectionstatus=true, x=12.5, y=12.5, targ_x=6.0, targ_y=19.0)
    FakeGCS2.reset!()
    FakeGCS2.position .= [4.0, 5.0, 6.0]
    n = N.N472(connectionstatus=true, pos=[1.0, 2.0, 3.0])
    mcl = MCL.MCLStage(connectionstatus=true, real_x=1.0, real_y=2.0, real_z=3.0)
    sa = SA.MCS2Stage(connectionstatus=true, pos_pm=Int64[7, 8, 9])
    function positions(stage, a)
        stage isa PI.PIStage && return (a["position_x"], a["position_y"])
        stage isa MCL.MCLStage && return (a["position_x"], a["position_y"], a["position_z"])
        stage isa N.N472 && return a["position"]
        return a["position_pm"]
    end

    for (stage, expected) in ((pi, (6.2, 19.4)), (n, [4.0, 5.0, 6.0]),
                              (mcl, (10.0, 20.0, 30.0)), (sa, copy(FakeStageExport.smaract_positions)))
        a = export_state(stage)[1]
        @test positions(stage, a) == expected
        @test get(a, "position_fresh", nothing) === true

        # A second export must read again, never reuse a previous successful snapshot.
        @test positions(stage, export_state(stage)[1]) == expected
        stage.connectionstatus = false
        @test_logs (:warn, r"Could not refresh stage position") begin
            fallback = export_state(stage)[1]
            @test positions(stage, fallback) == expected
            @test fallback["position_fresh"] === false
        end
        stage.connectionstatus = true
    end
    @test FakePIStage.calls == ["PI_qPOS", "PI_qPOS"]
    @test FakeGCS2.calls == ["PI_qPOS", "PI_qPOS"]
    @test FakeStageExport.smaract_reads == Int32[0, 1, 2, 0, 1, 2]

    # Documented GCS2 FALSE is a failed read; even a modified output buffer
    # must not corrupt the last-read values. Throwing reads use the same fallback.
    push!(FakePIStage.failing, "PI_qPOS")
    @test_logs (:warn, r"Could not refresh stage position") begin
        a = export_state(pi)[1]
        @test positions(pi, a) == (6.2, 19.4)
        @test a["position_fresh"] === false
    end
    empty!(FakePIStage.failing)
    FakePIStage.throw!("PI_qPOS")
    @test_logs (:warn, r"Could not refresh stage position") @test !export_state(pi)[1]["position_fresh"]
    FakePIStage.reset!()

    push!(FakeGCS2.failing, "PI_qPOS")
    FakeGCS2.position .= 99.0
    @test_logs (:warn, r"Could not refresh stage position") min_level=Base.CoreLogging.Warn begin
        a = export_state(n)[1]
        @test a["position"] == [4.0, 5.0, 6.0]
        @test n.pos == [4.0, 5.0, 6.0]
        @test a["position_fresh"] === false
    end
    FakeGCS2.reset!()

    # Madlib -5 is MCL_DEV_NOT_READY. Fail the second read after a changed X;
    # fallback exports the complete snapshot from before this attempt.
    FakeMCL.positions[1] = 15.0
    FakeMCL.positions[2] = -5.0
    @test_logs (:warn, r"Could not refresh stage position") min_level=Base.CoreLogging.Warn begin
        a = export_state(mcl)[1]
        @test positions(mcl, a) == (10.0, 20.0, 30.0)
        @test a["position_fresh"] === false
    end
    FakeMCL.positions[1] = 10.0
    FakeMCL.positions[2] = 20.0

    FakeStageExport.smaract_fail_axis[] = 1
    FakeStageExport.smaract_positions[1] = 9_000_000
    @test_logs (:warn, r"Could not refresh stage position") begin
        a = export_state(sa)[1]
        @test a["position_pm"] == Int64[1_000_000, 2_000_000, 3_000_000]
        @test a["position_um"] == [1.0, 2.0, 3.0]
        @test a["position_fresh"] === false
    end
    FakeStageExport.smaract_fail_axis[] = -1

    for stage in (SimStage1d(), SimStage2d(), SimStage3d())
        stage.targ_x = 7.0
        stage.dimensions >= 2 && (stage.targ_y = 8.0)
        stage.dimensions >= 3 && (stage.targ_z = 9.0)
        a = export_state(stage)[1]
        @test a["position_fresh"] === true
        @test a["position_x"] == 7.0
        stage.dimensions >= 2 && @test a["position_y"] == 8.0
        stage.dimensions >= 3 && @test a["position_z"] == 9.0
    end

    # The freshness flag and newly measured position survive the actual save path.
    pi.connectionstatus = true
    FakePIStage.position .= [3.5, 17.0]
    mktempdir() do dir
        path = joinpath(dir, "stage.h5")
        wait(save_h5(path, export_state(pi)))
        HDF5.h5open(path) do f
            @test HDF5.read_attribute(f["Main"], "position_x") == 3.5
            @test HDF5.read_attribute(f["Main"], "position_y") == 17.0
            @test HDF5.read_attribute(f["Main"], "position_fresh") == 1
        end
    end
    FakePIStage.reset!()
end

@testset "r7b: SmarAct freshness requires every exported channel" begin
    SA = MicroscopeControl.HardwareImplementations.MCS2Stage_mod
    F = Main.FakeStageExport
    F.smaract_positions .= Int64[1_000_000, 2_000_000, 3_000_000]
    F.smaract_fail_axis[] = -1
    for connected in ([false, false, false], [true, false, true])
        empty!(F.smaract_reads)
        previous = Int64[7_000_000, 8_000_000, 9_000_000]
        stage = SA.MCS2Stage(connectionstatus=true, connected=connected, pos_pm=copy(previous))
        a = @test_logs (:warn, r"Could not refresh stage position") min_level=Base.CoreLogging.Warn export_state(stage)[1]
        @test a["position_fresh"] === false
        @test a["position_pm"] == previous
        @test a["position_um"] == [7.0, 8.0, 9.0]
        @test F.smaract_reads == Int32[i - 1 for i in eachindex(connected) if connected[i]]
    end
end

