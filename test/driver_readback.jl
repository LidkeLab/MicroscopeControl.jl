@testset "M4: DCAM exposure and ROI read-back failures (p4)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    F = Main.FakeDCAM
    camera() = DC.DCAM4Camera("fake", CameraFormat(8, 6, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        CameraROI(0, 0, 4, 4), DC.SINGLE_FRAME, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2,
        DC.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 4, 4), NaN, 0)

    F.reset!()
    cam = camera()
    F.read_codes[Int32(DC.DCAM_IDPROP_EXPOSURETIME)] = DC.DCAMERR_TIMEOUT
    @test_throws "exposure read-back failed" DC.setexposuretime!(cam, 0.05)
    @test cam.exposure_time == 0.05
    @test cam.last_error == DC.DCAMERR_TIMEOUT
    @test export_state(cam)[1]["exposure_time"] == 0.05
    empty!(F.read_codes)
    @test DC.setexposuretime!(cam) == (DC.DCAMERR_SUCCESS, 0.05)
    @test F.values[Int32(DC.DCAM_IDPROP_EXPOSURETIME)] == 0.05

    properties = (DC.DCAM_IDPROP_EXPOSURETIME, DC.DCAM_IDPROP_SUBARRAYHPOS,
        DC.DCAM_IDPROP_SUBARRAYHSIZE, DC.DCAM_IDPROP_SUBARRAYVPOS, DC.DCAM_IDPROP_SUBARRAYVSIZE)
    for property in properties, start in (CI.capture, CI.live, c -> CI.sequence(c, 2))
        F.reset!()
        cam = camera()
        F.read_codes[Int32(property)] = DC.DCAMERR_TIMEOUT
        @test_throws "read-back failed" start(cam)
        @test cam.last_error == DC.DCAMERR_TIMEOUT
        @test (cam.roi.x_start, cam.roi.y_start, cam.roi.width, cam.roi.height) == (0, 0, 4, 4)
        @test !cam.is_running
        @test !("dcambuf_alloc" in F.calls)
        @test !("dcamcap_start" in F.calls)
        @test isempty(F.open_waits)
        # A different task can acquire the lock; same-task reentrance would hide a leaked hold.
        unlocked = @async begin
            got = trylock(cam.acquisition_lock)
            got && unlock(cam.acquisition_lock)
            got
        end
        @test fetch(unlocked)
    end
    for bad in (NaN, Inf, -1.0)
        F.reset!()
        cam = camera()
        # The write updates values, so test invalid read-back on ROI validation directly.
        @test_throws "read-back failed" DC.check_roi_read!(cam, DC.DCAMERR_SUCCESS, bad, "HPOS")
        @test cam.last_error == DC.DCAMERR_INVALIDVALUE
    end
    F.reset!()
    @test export_state(camera())[1]["roi_origin"] == 0
end
