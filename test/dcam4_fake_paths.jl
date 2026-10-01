# The capture paths, against the fake SDK in `dcam4_fake_sdk.jl` (included just before this file, last in runtests.jl).
@testset "DCAM4 capture paths (fake SDK)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    CameraInterface = MicroscopeControl.HardwareInterfaces.CameraInterface
    FK = Main.FakeDCAM

    fake_camera(mode) = DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        DC.CameraROI(0, 0, 1, 1), mode, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2, DC.DCAMERR_SUCCESS,
        false, 0, zeros(UInt16, 1, 1), NaN, 0)

    @testset "B4: getdata superseded by a newer capture leaves its buffer alone" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = fake_camera(DC.SEQUENCE)
        FK.on_status[] = () -> (cam.capture_generation += 1)   # a live view replaces the capture mid-poll
        @test CameraInterface.getdata(cam) === nothing
        @test FK.first_index("dcamcap_stop") === nothing && FK.first_index("dcambuf_release") === nothing
        # Control: a current getdata still cleans up.
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_ERROR   # not BUSY, so the wait ends; ERROR is stopped and released
        FK.frames_transferred[] = 2
        cam = fake_camera(DC.SEQUENCE)
        @test size(CameraInterface.getdata(cam)) == (2, 2, 2)
        @test FK.first_index("dcamcap_stop") !== nothing && FK.first_index("dcambuf_release") !== nothing
    end

    @testset "S1: a failed stop or release is recorded and leaves is_running true" begin
        for failing in ("dcamcap_stop", "dcambuf_release")
            FK.reset!()
            FK.status[] = DC.DCAMCAP_STATUS_BUSY
            FK.codes[failing] = DC.DCAMERR_NOTREADY
            cam = fake_camera(DC.LIVE)
            cam.is_running = true
            DC.stop_and_release!(cam)
            @test cam.last_error == DC.DCAMERR_NOTREADY
            @test cam.is_running
        end
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = fake_camera(DC.LIVE)
        cam.is_running = true
        DC.stop_and_release!(cam)
        @test cam.last_error == DC.DCAMERR_SUCCESS && !cam.is_running
    end

    @testset "S2: a failed $what start frees its buffer" for (what, f, mode) in
            (("sequence", cam -> CameraInterface.sequence(cam, 2), DC.SEQUENCE), ("live", CameraInterface.live, DC.LIVE))
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_READY   # a buffer that never ran
        FK.codes["dcamcap_start"] = DC.DCAMERR_NOTREADY
        cam = fake_camera(mode)
        f(cam)
        @test FK.last_index("dcambuf_release") > FK.first_index("dcamcap_start")
        @test cam.last_error == DC.DCAMERR_NOTREADY
        @test !cam.is_running
    end

    @testset "S3: a failed transferinfo sets last_error and the sequence returns nothing" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_STABLE
        FK.codes["dcamcap_transferinfo"] = DC.DCAMERR_NOTREADY
        cam = fake_camera(DC.SEQUENCE)
        @test CameraInterface.getdata(cam) === nothing
        @test cam.last_error == DC.DCAMERR_NOTREADY
        @test FK.first_index("dcambuf_getframe_err") === nothing
    end
end
