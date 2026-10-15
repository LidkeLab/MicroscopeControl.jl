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
        # N3: one warning, and last_error left as it was.
        @test_logs (:warn, r"replaced by a newer one") @test CameraInterface.getdata(cam) === nothing
        @test cam.last_error == DC.DCAMERR_SUCCESS
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
        FK.frames_transferred[] = 2   # all transferred: only the failed read itself can stop the frame reads
        cam = fake_camera(DC.SEQUENCE)
        @test CameraInterface.getdata(cam) === nothing
        @test cam.last_error == DC.DCAMERR_NOTREADY
        @test FK.first_index("dcambuf_getframe_err") === nothing
    end

    @testset "X3: getdata superseded during a status read that ends the poll reads no frame" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_STABLE   # not BUSY, so this one read ends the poll
        FK.frames_transferred[] = 2
        cam = fake_camera(DC.SEQUENCE)
        FK.on_status[] = () -> (cam.capture_generation += 1)   # a newer capture replaces it during that read
        @test_logs (:warn, r"replaced by a newer one") @test CameraInterface.getdata(cam) === nothing
        @test FK.first_index("dcamcap_transferinfo") === nothing && FK.first_index("dcambuf_getframe_err") === nothing
        @test FK.first_index("dcamcap_stop") === nothing && FK.first_index("dcambuf_release") === nothing
    end

    @testset "X1: a live view started during getdata's cleanup keeps its buffer" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_READY   # a single frame captured, its buffer still attached
        cam = fake_camera(DC.SINGLE_FRAME)
        live_task = Ref{Task}()
        # A single frame is read with no poll, so the first status read is the cleanup's. It starts a live
        # view on another task and yields once, so that task runs as far as it can before the cleanup reads on.
        FK.on_status[] = function ()
            FK.on_status[] = () -> nothing
            live_task[] = @async CameraInterface.live(cam)
            yield()
            istaskdone(live_task[]) && (FK.status[] = DC.DCAMCAP_STATUS_BUSY)   # the live view started, and runs
        end
        # No log output: a log write could yield inside the live start and hide the race.
        Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
            CameraInterface.getdata(cam)
        end
        wait(live_task[])
        start = FK.last_index("dcamcap_start")
        @test start !== nothing
        @test FK.last_index("dcambuf_release") < start
        @test something(FK.last_index("dcamcap_stop"), 0) < start
        @test cam.is_running
    end

    # ---- The 0.2.7 camera release: frame waits are joined by a stop, and the API is reference-counted ----

    quiet(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())   # a refused or aborted call logs; not what these check
    finished(t; secs = 10.0) = timedwait(() -> istaskdone(t), secs; pollint = 0.005) === :ok
    live_camera() = (cam = fake_camera(DC.LIVE); cam.is_running = true; cam)
    in_wait(n = 1) = timedwait(() -> FK.in_wait[] == n, 10.0; pollint = 0.002) === :ok

    @testset "A: getlastframe refuses with nothing running" begin
        FK.reset!()
        cam = fake_camera(DC.LIVE)
        quiet() do
            @test CameraInterface.getlastframe(cam) === nothing
        end
        @test FK.first_index("dcamwait_open") === nothing
        @test isempty(cam.waits)
    end

    @testset "A: getlastframe reads under the lock and unregisters" begin
        FK.reset!()
        cam = live_camera()
        @test CameraInterface.getlastframe(cam) == zeros(UInt16, 2, 2)
        @test isempty(cam.waits) && cam.draining == 0
        @test FK.last_index("dcamwait_close") !== nothing
    end

    @testset "A: a stop aborts the frame wait and joins it before the capture is stopped" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            CameraInterface.abort(cam)
            @test fetch(waiter) === nothing
        end
        @test isempty(FK.violations)            # no stop or release ran with a wait inside the library
        @test FK.timeouts[] == 0                # it ended at the abort, not at its own timeout
        @test FK.first_index("dcamwait_abort") < FK.first_index("dcamcap_stop")
        @test FK.first_index("dcambuf_getframe_err") === nothing
        @test cam.last_error == DC.DCAMERR_SUCCESS && !cam.is_running
        @test isempty(cam.waits) && cam.draining == 0
    end

    @testset "A: an abort that reached the wait before it entered the library is repeated" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.15                 # the first abort lands before the wait can hear it
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            CameraInterface.abort(cam)
            @test fetch(waiter) === nothing
        end
        @test FK.timeouts[] == 0
        @test count(==("dcamwait_abort"), FK.calls) >= 2
        @test isempty(FK.violations)
    end

    @testset "A: no new frame wait registers while a stop joins the old ones" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            stopper = @async CameraInterface.abort(cam)
            @test timedwait(() -> cam.draining == 1, 10.0; pollint = 0.002) === :ok
            @test CameraInterface.getlastframe(cam) === nothing     # refused, with no wait opened
            @test count(==("dcamwait_open"), FK.calls) == 1
            @test finished(stopper) && finished(waiter)
        end
        @test cam.draining == 0 && isempty(cam.waits)
    end

    @testset "A: two stops, a start and a waiter at once do not deadlock" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            s1 = @async CameraInterface.abort(cam)
            s2 = @async CameraInterface.abort(cam)
            starter = @async CameraInterface.live(cam)      # its own abort joins the waiter at reentrant depth 2
            @test finished(s1) && finished(s2) && finished(starter) && finished(waiter)
        end
        @test isempty(FK.violations) && FK.timeouts[] == 0
        @test cam.is_running && cam.draining == 0 && isempty(cam.waits)
        @test FK.first_index("dcamwait_abort") < FK.last_index("dcamcap_start")
    end

    @testset "A: getlastframe called by a lock holder delays a stop by at most its own timeout" begin
        FK.reset!()
        FK.wait_mode[] = :ready
        cam = live_camera()
        @test (@lock cam.acquisition_lock CameraInterface.getlastframe(cam)) == zeros(UInt16, 2, 2)
        FK.reset!()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        quiet() do
            holder = @async @lock cam.acquisition_lock CameraInterface.getlastframe(cam)
            @test in_wait()
            stopper = @async CameraInterface.abort(cam)      # cannot take the lock until the holder's wait times out
            @test finished(holder) && finished(stopper)
            @test fetch(holder) === nothing
        end
        @test FK.timeouts[] == 1
        @test isempty(FK.violations) && !cam.is_running
    end

    @testset "A: a cleanup whose capture was replaced during the join stops nothing" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3                  # the join lasts long enough for a start to land in it
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        cam.capture_mode = DC.SINGLE_FRAME      # getdata reads the newest frame, then cleans up
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            replacer = @async (sleep(0.1); cam.capture_generation += 1)   # another task's start, during the join
            @test CameraInterface.getdata(cam) isa Matrix
            @test finished(replacer) && finished(waiter)
        end
        @test FK.first_index("dcamcap_stop") === nothing && FK.first_index("dcambuf_release") === nothing
        @test cam.is_running
    end

    @testset "A: getlastframe reads nothing once its capture was replaced" begin
        FK.reset!()
        cam = live_camera()
        FK.after_wait[] = () -> (cam.capture_generation += 1)   # a newer start, while this wait was in the library
        quiet() do
            @test CameraInterface.getlastframe(cam) === nothing
        end
        @test FK.first_index("dcambuf_getframe_err") === nothing
        @test cam.last_error == DC.DCAMERR_SUCCESS
        @test isempty(cam.waits)
    end

    @testset "B: capture superseded during its wait reads nothing and stops nothing" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_READY
        cam = fake_camera(DC.LIVE)
        FK.after_wait[] = () -> (cam.capture_generation += 1)
        @test_logs (:warn, r"capture found its capture stopped or replaced") @test CameraInterface.capture(cam) === nothing
        @test FK.first_index("dcambuf_getframe_err") === nothing
        @test count(==("dcambuf_release"), FK.calls) == 1        # the leftover cleanup before the start, and no more
        @test FK.first_index("dcamcap_stop") === nothing
        @test cam.last_error == DC.DCAMERR_SUCCESS
        @test isempty(cam.waits)
        # Control: a capture nobody replaced reads its frame and cleans up.
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_READY
        cam = fake_camera(DC.LIVE)
        @test CameraInterface.capture(cam) == zeros(UInt16, 2, 2)
        @test count(==("dcambuf_release"), FK.calls) == 2
    end

    @testset "B: a live view started during a capture's wait is not stopped by the capture" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = fake_camera(DC.LIVE)
        quiet() do
            cap = @async CameraInterface.capture(cam)
            @test in_wait()
            starter = @async CameraInterface.live(cam)
            @test finished(starter) && finished(cap)
            @test fetch(cap) === nothing
        end
        @test cam.is_running
        @test FK.last_index("dcamcap_stop") < FK.last_index("dcamcap_start")
        @test FK.last_index("dcambuf_release") < FK.last_index("dcamcap_start")
        @test isempty(FK.violations) && FK.timeouts[] == 0
        @test isempty(cam.waits)
    end

    @testset "C: a failed stop leaves the capture owned, and still aborts the waits" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        FK.codes["dcamcap_stop"] = DC.DCAMERR_NOTREADY
        cam = fake_camera(DC.LIVE)
        cam.is_running = true
        gen = cam.capture_generation
        DC.stop_and_release!(cam)
        @test cam.capture_generation == gen && cam.is_running && cam.last_error == DC.DCAMERR_NOTREADY
        # The waits are still aborted and joined before the failed stop.
        FK.reset!()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        FK.codes["dcamcap_stop"] = DC.DCAMERR_NOTREADY
        cam = live_camera()
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            DC.stop_and_release!(cam)
            @test fetch(waiter) === nothing
        end
        @test FK.first_index("dcamwait_abort") < FK.first_index("dcamcap_stop") && FK.timeouts[] == 0
        @test cam.is_running && cam.capture_generation == 0
        # A success moves the generation on, as before.
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        DC.stop_and_release!(cam)
        @test cam.capture_generation == 1 && !cam.is_running
    end

    @testset "C: the sequence poller still owns a capture whose stop failed" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = fake_camera(DC.SEQUENCE)
        quiet() do
            CameraInterface.sequence(cam, 2)
            @test cam.is_running
            gen = cam.capture_generation
            FK.codes["dcamcap_stop"] = DC.DCAMERR_NOTREADY
            CameraInterface.abort(cam)                       # the stop fails: the capture is still running
            @test cam.capture_generation == gen && cam.is_running
            delete!(FK.codes, "dcamcap_stop")
            FK.status[] = DC.DCAMCAP_STATUS_STABLE           # it ends on its own; its poller, still current, says so
            @test timedwait(() -> !cam.is_running, 10.0; pollint = 0.005) === :ok
        end
    end

    @testset "D: two cameras share the API; one shutdown leaves the other working" begin
        FK.reset!()
        FK.api_down_code[] = DC.DCAMERR_NOTREADY             # every call fails once the API is uninitialized
        @test DC.DCAM_API_USERS[] == 0
        c1 = DC.DCAM4Camera(0)
        c2 = DC.DCAM4Camera(1)
        @test FK.inits[] == 1 && DC.DCAM_API_USERS[] == 2
        @test c1.camera_handle != c2.camera_handle
        DC.shutdown(c1)
        @test FK.uninits[] == 0 && FK.api_up[] && DC.DCAM_API_USERS[] == 1
        @test CameraInterface.capture(c2) == zeros(UInt16, 2, 2)     # the other camera still captures
        DC.shutdown(c1)                                      # twice is safe: no second close, no second count given back
        @test FK.uninits[] == 0 && length(FK.closed) == 1 && DC.DCAM_API_USERS[] == 1
        # A constructor that fails after its own init gives back only its own count.
        FK.codes["dcamdev_open"] = DC.DCAMERR_NOTREADY
        @test_throws r"dcamdev_open failed" quiet(() -> DC.DCAM4Camera(2))
        delete!(FK.codes, "dcamdev_open")
        @test FK.uninits[] == 0 && FK.api_up[] && DC.DCAM_API_USERS[] == 1
        @test CameraInterface.capture(c2) == zeros(UInt16, 2, 2)
        # showdevicelist borrows a count rather than initializing and uninitializing under a live camera.
        inits = FK.inits[]
        redirect_stdout(devnull) do
            DC.showdevicelist()
        end
        @test FK.inits[] == inits && FK.uninits[] == 0 && DC.DCAM_API_USERS[] == 1
        DC.shutdown(c2)
        @test FK.uninits[] == 1 && !FK.api_up[] && DC.DCAM_API_USERS[] == 0
        DC.shutdown(c2)
        @test FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        # With no camera, showdevicelist initializes and uninitializes around itself, and a failed init takes no count.
        redirect_stdout(devnull) do
            DC.showdevicelist()
        end
        @test FK.inits[] == 2 && FK.uninits[] == 2 && DC.DCAM_API_USERS[] == 0
        FK.codes["dcamapi_init"] = DC.DCAMERR_NOTREADY
        quiet() do
            @test_throws r"dcamapi_init failed" DC.DCAM4Camera(0)
        end
        @test DC.DCAM_API_USERS[] == 0 && FK.uninits[] == 3  # the failed init is followed by an uninit, as it always was
    end
end
