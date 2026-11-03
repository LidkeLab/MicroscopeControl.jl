@testset "M4: DCAM exposure and ROI read-back failures (p4)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    F = Main.FakeDCAM
    camera() = DC.DCAM4Camera("fake", CameraFormat(8, 6, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        CameraROI(0, 0, 4, 4), DC.SINGLE_FRAME, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2,
        DC.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 4, 4), NaN, 0)

    # DCAMERR_TIMEOUT is a documented SDK error; getvalue leaves its initialized output at zero.
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
    F.reset!()
end

@testset "r7b: installed skills describe DCAM read-back exceptions" begin
    # The documented behavior must agree with the documented DCAMERR_TIMEOUT input above.
    mktempdir() do dir
        MicroscopeControl.install_skills(dir; quiet=true)
        acquire = read(joinpath(dir, ".claude", "skills", "mc-acquire", "SKILL.md"), String)
        testing = read(joinpath(dir, ".claude", "skills", "mc-testing", "SKILL.md"), String)
        capture_table = split(split(acquire, "| Driver | `capture` on SDK failure |"; limit=2)[2], "\n\n"; limit=2)[1]
        @test occursin(r"\| `DCAM4Camera` \|[^\n]*exposure/ROI read-backs[^\n]*throw", capture_table)
        @test occursin("DCAM4 exposure/ROI read-backs throw", testing)
    end
end


@testset "r7f: normal DCAM construction checks every initial property read" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    F = Main.FakeDCAM
    # TIMEOUT is a documented DCAMERR. The fake reproduces the SDK wrapper's
    # untouched zero output on failure, through the ordinary public constructor.
    for (property, message) in ((DC.DCAM_IDPROP_EXPOSURETIME, "exposure read-back failed"),
            (DC.DCAM_IDPROP_IMAGE_WIDTH, "image width read-back failed"),
            (DC.DCAM_IDPROP_IMAGE_HEIGHT, "image height read-back failed")), shared in (false, true)
        F.reset!()
        F.device_count[] = 2
        DC.DCAM_API_USERS[] = 0
        F.values[Int32(DC.DCAM_IDPROP_EXPOSURETIME)] = 0.025
        healthy = shared ? DC.DCAM4Camera(1) : nothing
        built = nothing
        try
            F.read_codes[Int32(property)] = DC.DCAMERR_TIMEOUT
            @test_throws message (built = DC.DCAM4Camera(0))
            @test built === nothing
            @test F.closed == [Ptr{Cvoid}(UInt(0x100))]
            @test DC.DCAM_API_USERS[] == (shared ? 1 : 0)
            @test F.uninits[] == (shared ? 0 : 1)
            @test F.api_up[] == shared
        finally
            empty!(F.read_codes)
            built === nothing || shutdown(built)
            healthy === nothing || shutdown(healthy)
        end
        @test DC.DCAM_API_USERS[] == 0
    end
    F.reset!()
    DC.DCAM_API_USERS[] = 0
    F.values[Int32(DC.DCAM_IDPROP_EXPOSURETIME)] = 0.025
    cam = DC.DCAM4Camera(0)
    try
        @test cam.exposure_time == 0.025
        @test (cam.camera_format.x_pixels, cam.camera_format.y_pixels) == (2, 2)
        @test cam.last_error == DC.DCAMERR_SUCCESS
        @test initialize(cam) === nothing
    finally
        shutdown(cam)
        F.reset!()
    end
end
