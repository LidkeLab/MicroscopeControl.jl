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
        @test FK.first_index("dcambuf_copyframe") === nothing
    end

    @testset "X3: getdata superseded during a status read that ends the poll reads no frame" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_STABLE   # not BUSY, so this one read ends the poll
        FK.frames_transferred[] = 2
        cam = fake_camera(DC.SEQUENCE)
        FK.on_status[] = () -> (cam.capture_generation += 1)   # a newer capture replaces it during that read
        @test_logs (:warn, r"replaced by a newer one") @test CameraInterface.getdata(cam) === nothing
        @test FK.first_index("dcamcap_transferinfo") === nothing && FK.first_index("dcambuf_copyframe") === nothing
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

    @testset "A: getlastframe with no live view still waits and reads, as on 0.2.6" begin
        FK.reset!()
        cam = fake_camera(DC.SEQUENCE)    # a sequence that ended: is_running is false, its buffer still holds the frames
        @test !cam.is_running
        @test CameraInterface.getlastframe(cam) == zeros(UInt16, 2, 2)
        @test FK.first_index("dcamwait_open") !== nothing
        @test isempty(cam.waits) && isempty(FK.open_waits)
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
        @test FK.first_index("dcambuf_copyframe") === nothing
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
        @test FK.first_index("dcambuf_copyframe") === nothing
        @test cam.last_error == DC.DCAMERR_SUCCESS
        @test isempty(cam.waits)
    end

    @testset "B: capture superseded during its wait reads nothing and stops nothing" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_READY
        cam = fake_camera(DC.LIVE)
        FK.after_wait[] = () -> (cam.capture_generation += 1)
        @test_logs (:warn, r"capture found its capture stopped or replaced") @test CameraInterface.capture(cam) === nothing
        @test FK.first_index("dcambuf_copyframe") === nothing
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
        DC.DCAM_API_USERS[] = 0                              # the cameras made positionally above each adopted a count
        c1 = DC.DCAM4Camera(0)
        c2 = DC.DCAM4Camera(1)
        @test FK.inits[] == 1 && DC.DCAM_API_USERS[] == 2    # the keyword constructor counts once, not twice
        @test c1.camera_handle != c2.camera_handle
        @test DC.shutdown(c1) === DC.DCAMERR_SUCCESS         # another holder keeps the API up: the 0.2.6 success code
        @test FK.uninits[] == 0 && FK.api_up[] && DC.DCAM_API_USERS[] == 1
        @test CameraInterface.capture(c2) == zeros(UInt16, 2, 2)     # the other camera still captures
        @test DC.shutdown(c1) === DC.DCAMERR_SUCCESS         # twice is safe: no second close, no second count given back
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
            @test DC.showdevicelist() === DC.DCAMERR_SUCCESS   # another holder keeps the API up
        end
        @test FK.inits[] == inits && FK.uninits[] == 0 && DC.DCAM_API_USERS[] == 1
        # The last shutdown uninitializes, and returns the library's code for it, as on 0.2.6.
        FK.codes["dcamapi_uninit"] = DC.DCAMERR_NOTREADY
        quiet() do
            @test DC.shutdown(c2) == DC.DCAMERR_NOTREADY
        end
        delete!(FK.codes, "dcamapi_uninit")
        @test FK.uninits[] == 1 && !FK.api_up[] && DC.DCAM_API_USERS[] == 0
        @test DC.shutdown(c2) === DC.DCAMERR_SUCCESS && FK.uninits[] == 1
        # With no camera, showdevicelist initializes and uninitializes around itself, and a failed init takes no count.
        redirect_stdout(devnull) do
            @test DC.showdevicelist() === DC.DCAMERR_SUCCESS   # 0.2.6 returned the uninitialize code
            FK.codes["dcamapi_uninit"] = DC.DCAMERR_NOTREADY
            quiet() do
                @test DC.showdevicelist() == DC.DCAMERR_NOTREADY
            end
            delete!(FK.codes, "dcamapi_uninit")
        end
        @test FK.inits[] == 3 && FK.uninits[] == 3 && DC.DCAM_API_USERS[] == 0
        FK.codes["dcamapi_init"] = DC.DCAMERR_NOTREADY
        quiet() do
            @test_throws r"dcamapi_init failed" DC.DCAM4Camera(0)
        end
        @test DC.DCAM_API_USERS[] == 0 && FK.uninits[] == 4  # the failed init is followed by an uninit, as it always was
    end

    handle_camera(mode, h = 0x200) = DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), Ptr{Cvoid}(UInt(h)), 0.01, 10.0,
        DC.CameraROI(0, 0, 1, 1), mode, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2, DC.DCAMERR_SUCCESS,
        false, 0, zeros(UInt16, 1, 1), NaN, 0)

    @testset "Round 2 item 9: a positionally built camera uninitializes the API it was built around" begin
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()                                    # the caller's own initialization
        cam = handle_camera(DC.LIVE)
        @test DC.DCAM_API_USERS[] == 1 && FK.uninits[] == 0
        @test DC.shutdown(cam) === DC.DCAMERR_SUCCESS
        @test FK.uninits[] == 1 && !FK.api_up[] && FK.closed == [Ptr{Cvoid}(UInt(0x200))]
    end

    @testset "Round 2 item 1: overlapping starts leave the SDK mode and capture_mode in agreement" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3                               # the drain lasts, so both starts are inside it together
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = live_camera()
        seen = Tuple{Bool,Bool}[]                            # at each SDK start: (it is the live start, the camera says LIVE)
        FK.on_start[] = m -> push!(seen, (m == Int32(DC.DCAMCAP_START_SEQUENCE), cam.capture_mode == DC.LIVE))
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            l = @async CameraInterface.live(cam)
            q = @async CameraInterface.sequence(cam, 2)
            @test finished(l) && finished(q) && finished(waiter)
        end
        @test length(seen) == 2
        @test all(p -> p[1] == p[2], seen)                   # no start ran with the other's mode published
        @test cam.is_running && cam.draining == 0 && isempty(cam.waits)
    end

    @testset "Round 2 item 2: a stale cleanup aborts nobody's wait" begin
        FK.reset!()
        FK.wait_mode[] = :block
        cam = fake_camera(DC.LIVE)
        cap = @async CameraInterface.capture(cam)
        @test in_wait()
        DC.stop_and_release!(cam; current = () -> false)
        @test FK.first_index("dcamwait_abort") === nothing
        FK.ready_now[] = true                                # the frame arrives
        @test finished(cap)
        @test fetch(cap) == zeros(UInt16, 2, 2)
    end

    @testset "Round 2 item 3: a drain that ends leaves no wait handle open" begin
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        FK.wait_mode[] = :block
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = handle_camera(DC.LIVE)
        cam.is_running = true
        FK.on_wait_close[] = () -> sleep(0.2)                # the waiter is slow to close its handle
        waiter = @async CameraInterface.getlastframe(cam)
        @test in_wait()
        FK.ready_now[] = true
        @test timedwait(() -> "dcamwait_event_end" in FK.calls, 10.0; pollint = 0.002) === :ok
        CameraInterface.abort(cam)
        DC.shutdown(cam)
        @test finished(waiter)
        @test isempty(FK.violations)                         # the device was never closed with a wait handle open
        @test FK.last_index("dcamwait_close") < FK.first_index("dcamdev_close") < FK.first_index("dcamapi_uninit")
    end

    @testset "Round 2 item 4: an exception after the wait registers leaves nothing registered or open" begin
        FK.reset!()
        cam = live_camera()
        FK.on_wait_enter[] = () -> throw(InterruptException())
        @test_throws InterruptException CameraInterface.getlastframe(cam)
        @test isempty(cam.waits) && isempty(FK.open_waits)
        quiet() do
            @test_throws InterruptException CameraInterface.capture(fake_camera(DC.LIVE))
        end
        @test isempty(FK.open_waits)
        FK.on_wait_enter[] = () -> nothing
        # An abort afterwards does not hang on a handle nobody will end.
        @test finished(@async CameraInterface.abort(cam))
    end

    @testset "Round 2 item 5: shutdown is one coordinated operation" begin
        # Two shutdowns at once: the second neither closes the device nor gives the API count back, and does not
        # return before the first has finished.
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        FK.on_dev_close[] = () -> sleep(0.2)
        done = Symbol[]
        s1 = @async (DC.shutdown(cam); push!(done, :first))
        @test timedwait(() -> "dcamdev_close" in FK.calls, 10.0; pollint = 0.002) === :ok
        s2 = @async (r = DC.shutdown(cam); push!(done, :second); r)
        @test finished(s1) && finished(s2)
        @test done == [:first, :second] && fetch(s2) === DC.DCAMERR_SUCCESS
        @test length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        @test FK.first_index("dcamdev_close_end") < FK.first_index("dcamapi_uninit")

        # A second shutdown that arrives while the first is still joining a frame wait (the lock is free then) waits too.
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        cam.is_running = true
        done = Symbol[]
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            s1 = @async (DC.shutdown(cam); push!(done, :first))
            @test timedwait(() -> cam.closing == 1 && cam.draining == 1, 10.0; pollint = 0.002) === :ok
            s2 = @async (DC.shutdown(cam); push!(done, :second))
            @test finished(s1) && finished(s2) && finished(waiter)
        end
        @test done == [:first, :second]
        @test length(FK.closed) == 1 && FK.uninits[] == 1 && isempty(FK.violations)

        # Shutdown during a capture: the wait is aborted and joined, nothing is read from the closed device, and every
        # later call fails cleanly with no DCAM call.
        FK.reset!()
        FK.wait_mode[] = :block
        DC.DCAM_API_USERS[] = 0
        c = DC.DCAM4Camera(0)
        quiet() do
            cap = @async CameraInterface.capture(c)
            @test in_wait()
            DC.shutdown(c)
            @test finished(cap) && fetch(cap) === nothing
            @test FK.first_index("dcamwait_abort") < FK.first_index("dcamdev_close") < FK.first_index("dcamapi_uninit")
            @test FK.last_index("dcambuf_copyframe") === nothing && isempty(FK.violations)
            @test c.camera_handle == C_NULL && !c.is_running
            n = length(FK.calls)
            @test CameraInterface.getlastframe(c) === nothing
            @test CameraInterface.getdata(c) === nothing
            @test_throws r"shut down" CameraInterface.capture(c)
            CameraInterface.live(c); @test c.last_error == DC.DCAMERR_INVALIDHANDLE
            c.last_error = DC.DCAMERR_SUCCESS
            CameraInterface.sequence(c, 2); @test c.last_error == DC.DCAMERR_INVALIDHANDLE
            CameraInterface.abort(c)
            @test length(FK.calls) == n                      # no DCAM call on the closed handle
        end
    end

    @testset "Round 2 item 7: LIVE getdata reads only while its capture is current" begin
        FK.reset!()
        cam = fake_camera(DC.LIVE)
        quiet() do
            @test DC.read_live_frame(cam, () -> false) === nothing
        end
        @test FK.first_index("dcambuf_copyframe") === nothing
        @test DC.read_live_frame(cam, () -> true) == zeros(UInt16, 2, 2)
    end

    @testset "Round 2 item 8: a stop that fails during a capture leaves a leftover the next call cleans up" begin
        for next in (cam -> CameraInterface.abort(cam), cam -> (FK.wait_mode[] = :ready; CameraInterface.capture(cam)))
            FK.reset!()
            FK.wait_mode[] = :block
            cam = fake_camera(DC.LIVE)
            quiet() do
                cap = @async CameraInterface.capture(cam)
                @test in_wait()
                FK.status[] = DC.DCAMCAP_STATUS_BUSY
                FK.codes["dcamcap_stop"] = DC.DCAMERR_NOTREADY
                gen = cam.capture_generation
                CameraInterface.abort(cam)
                @test finished(cap) && fetch(cap) === nothing
                @test cam.last_error == DC.DCAMERR_NOTREADY && cam.capture_generation == gen
                delete!(FK.codes, "dcamcap_stop")
                stops = count(==("dcamcap_stop"), FK.calls)
                releases = count(==("dcambuf_release"), FK.calls)
                next(cam)
                @test count(==("dcamcap_stop"), FK.calls) >= stops + 1     # the leftover is stopped and released (a capture also cleans up after itself)
                @test count(==("dcambuf_release"), FK.calls) >= releases + 1
            end
        end
    end

    @testset "Round 3 item 2: a loop of captures cannot keep a drain from ending" begin
        FK.reset!()
        FK.wait_mode[] = :block
        cam = fake_camera(DC.LIVE)
        stop = Ref(false)
        quiet() do
            looper = @async while !stop[]
                try
                    CameraInterface.capture(cam)
                catch
                end
            end
            @test in_wait()
            stopper = @async CameraInterface.abort(cam)
            @test finished(stopper)                          # without the fix, each abort meets a new wait, for ever
            stop[] = true
            FK.ready_now[] = true
            @test finished(looper)
        end
        @test cam.draining == 0 && isempty(cam.waits)
    end

    @testset "Round 3 item 3: getdata resolves a cache miss under the lock and calls DCAM on no closed handle" begin
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.SEQUENCE)                     # readout_s is NaN: the poll's timeout needs a camera read
        @test isnan(cam.readout_s)
        gen = cam.capture_generation
        DC.shutdown(cam)
        n = length(FK.calls)
        quiet() do
            @test DC.sequence_timeout_ms(cam, 2, () -> cam.capture_generation == gen) === nothing
        end
        @test length(FK.calls) == n                          # no readout read on the closed handle
        FK.reset!()
        cam = fake_camera(DC.SEQUENCE)
        @test DC.sequence_timeout_ms(cam, 2, () -> true) isa Int32 && FK.first_index("dcamprop_getvalue") !== nothing
    end

    @testset "Round 3 item 4: an interrupted shutdown leaves the camera open, and the next one finishes it" begin
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        cam.is_running = true
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            s1 = @async DC.shutdown(cam)
            @test timedwait(() -> cam.closing == 1 && cam.draining == 1, 10.0; pollint = 0.002) === :ok
            s2 = @async DC.shutdown(cam)                     # waits for the first
            schedule(s1, InterruptException(); error = true)
            @test finished(s1) && finished(s2) && finished(waiter)
            @test istaskfailed(s1) && !istaskfailed(s2)      # the second did not report the first's success: it shut the camera down
        end
        @test cam.closing == 2 && length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        # Interrupted with nothing waiting to take over: the camera is open again, and a later shutdown finishes it.
        FK.reset!()
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        cam.is_running = true
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            s1 = @async DC.shutdown(cam)
            @test timedwait(() -> cam.closing == 1 && cam.draining == 1, 10.0; pollint = 0.002) === :ok
            schedule(s1, InterruptException(); error = true)
            @test finished(s1) && istaskfailed(s1) && finished(waiter)
            @test cam.closing == 0 && cam.camera_handle != C_NULL && isempty(FK.closed) && FK.uninits[] == 0
            @test DC.shutdown(cam) === DC.DCAMERR_SUCCESS
        end
        @test cam.closing == 2 && length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        @test DC.shutdown(cam) === DC.DCAMERR_SUCCESS && FK.uninits[] == 1
    end

    @testset "Round 3 item 6: a stale poll never overwrites the newer capture's last_error" begin
        FK.reset!()
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam = fake_camera(DC.SEQUENCE)
        polls = Ref(0)
        quiet() do
            # current while it reads the status, replaced by the time it reaches its deadline
            @test DC.wait_not_busy(cam, 0, "test"; current = () -> (polls[] += 1) <= 1) === false
        end
        @test cam.last_error == DC.DCAMERR_SUCCESS
        quiet() do
            @test DC.wait_not_busy(cam, 0, "test") === false          # a current one still records its timeout
        end
        @test cam.last_error == DC.DCAMERR_TIMEOUT
    end

    @testset "Round 3 item 7: a failed positional assembly leaks no API count" begin
        DC.DCAM_API_USERS[] = 0
        @test_throws Exception DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
            DC.CameraROI(0, 0, 1, 1), DC.LIVE, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2, DC.DCAMERR_SUCCESS,
            false, 0, "not an array", NaN, 0)
        @test DC.DCAM_API_USERS[] == 0
    end

    @testset "Round 4 item 1: an interrupted shutdown resumes without repeating a native step" begin
        interrupt() = throw(InterruptException())
        # A camera that is the only API holder, its device open, and a first shutdown that is interrupted at `arm`.
        function interrupted_shutdown(arm)
            FK.reset!()
            DC.DCAM_API_USERS[] = 0
            DC.dcamapi_init()
            cam = handle_camera(DC.LIVE)
            arm()
            quiet() do
                @test_throws InterruptException DC.shutdown(cam)
            end
            return cam
        end
        retry(cam) = quiet() do
            DC.shutdown(cam)
        end
        done(cam) = DC.shutdown(cam) === DC.DCAMERR_SUCCESS && length(FK.closed) <= 1 && FK.uninits[] <= 1

        # Interrupted before the close was entered (the trace lock wait): begun but unknown, so it is not repeated.
        cam = interrupted_shutdown(() -> FK.before_dev_close[] = () -> (FK.before_dev_close[] = () -> nothing; interrupt()))
        @test cam.close_step == 1 && cam.api_held
        @test_logs (:error, r"device close was interrupted") match_mode = :any DC.shutdown(cam)
        @test isempty(FK.closed) && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0 && cam.closing == 2
        @test done(cam)

        # Interrupted after the close returned, before it was recorded: closed once, not twice.
        cam = interrupted_shutdown(() -> FK.after_dev_close[] = () -> (FK.after_dev_close[] = () -> nothing; interrupt()))
        @test cam.close_step == 1 && cam.camera_handle != C_NULL
        @test_logs (:error, r"device close was interrupted") match_mode = :any DC.shutdown(cam)
        @test length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        @test done(cam)

        # Interrupted while waiting for the API lock: nothing was given back, and the retry gives it back.
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        lock(DC.DCAM_API_LOCK)
        s1 = @async DC.shutdown(cam)
        @test timedwait(() -> !isempty(FK.closed) && istaskstarted(s1), 10.0; pollint = 0.002) === :ok
        yield()
        schedule(s1, InterruptException(); error = true)
        unlock(DC.DCAM_API_LOCK)
        quiet() do
            @test finished(s1) && istaskfailed(s1)
        end
        @test cam.api_held && DC.DCAM_API_USERS[] == 1 && cam.close_step == 2 && FK.uninits[] == 0   # untouched
        retry(cam)
        @test length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
        @test done(cam)

        # Interrupted between the decrement and dcamapi_uninit: begun, unknown, not repeated.
        cam = interrupted_shutdown(() -> FK.before_uninit[] = () -> (FK.before_uninit[] = () -> nothing; interrupt()))
        @test cam.api_step == 1 && !cam.api_held && DC.DCAM_API_USERS[] == 0
        @test_logs (:error, r"dcamapi_uninit was interrupted") match_mode = :any DC.shutdown(cam)
        @test length(FK.closed) == 1 && FK.uninits[] == 0 && cam.api_step == 2
        @test done(cam)

        # A concurrent shutdown that was waiting for the interrupted one resumes it instead of reporting success.
        FK.reset!()
        FK.on_dev_close[] = () -> nothing
        DC.DCAM_API_USERS[] = 0
        DC.dcamapi_init()
        cam = handle_camera(DC.LIVE)
        FK.wait_mode[] = :block
        FK.entry_delay[] = 0.3
        FK.status[] = DC.DCAMCAP_STATUS_BUSY
        cam.is_running = true
        quiet() do
            waiter = @async CameraInterface.getlastframe(cam)
            @test in_wait()
            FK.after_dev_close[] = () -> (FK.after_dev_close[] = () -> nothing; interrupt())
            s1 = @async DC.shutdown(cam)
            @test timedwait(() -> cam.closing == 1 && cam.draining == 1, 10.0; pollint = 0.002) === :ok
            s2 = @async DC.shutdown(cam)
            @test finished(s1) && finished(s2) && finished(waiter)
            @test istaskfailed(s1) && !istaskfailed(s2)
        end
        @test length(FK.closed) == 1 && FK.uninits[] == 1 && DC.DCAM_API_USERS[] == 0
    end

    @testset "property setters and getters make no DCAM call after shutdown" begin
        FK.reset!()
        DC.DCAM_API_USERS[] = 0
        c = DC.DCAM4Camera(0)
        DC.shutdown(c)
        n = length(FK.calls)
        refusal(f) = begin
            c.last_error = DC.DCAMERR_SUCCESS
            @test_logs (:error, r"refused: the camera has been shut down") match_mode = :any f()
            @test c.last_error == DC.DCAMERR_INVALIDHANDLE
        end
        refusal(() -> DC.setexposuretime!(c))
        refusal(() -> DC.setexposuretime!(c, 0.02))
        refusal(() -> DC.setroi!(c))
        refusal(() -> DC.setroi!(c, DC.CameraROI(0, 0, 4, 4)))
        refusal(() -> DC.setvalue(c, DC.DCAM_IDPROP_EXPOSURETIME, 0.01))
        refusal(() -> DC.settriggermode!(c))
        refusal(() -> DC.showproperties(c))
        refusal(() -> @test DC.readout_time(c) == DC.READOUT_FALLBACK_S)
        @test isnan(c.readout_s)
        @test length(FK.calls) == n
    end
end

