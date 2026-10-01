# The DCAM library is absent on the machines that run this suite, so this file tests only what
# runs without it. The capture error paths, getdata's poll and stop_and_release! call the DCAM
# library first and cannot run without a swappable-library fake (a follow-up). The refusal and the
# cache are tested because they come before any library call.

# State for the qsort BEGIN-before-call test. The comparator runs inside the traced C call, so it must
# not throw (an exception through C frames is undefined): it records what it saw and the test checks after.
const QSORT_TRACE_PATH = Ref("")
const QSORT_SAW_BEGIN = Ref(false)
function qsort_cmp(a::Ptr{Cint}, b::Ptr{Cint})::Cint
    try
        QSORT_SAW_BEGIN[] |= occursin(r"BEGIN qsort id=", read(QSORT_TRACE_PATH[], String))
    catch
    end
    return Cint(sign(unsafe_load(a) - unsafe_load(b)))
end

@testset "DCAM4 (no library)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    CameraInterface = MicroscopeControl.HardwareInterfaces.CameraInterface

    # A camera built with no library call, through the positional constructor.
    fake_camera() = DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        DC.CameraROI(0, 0, 1, 1), DC.LIVE, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 10, DC.DCAMERR_SUCCESS,
        false, 0, zeros(UInt16, 1, 1), NaN, 0)

    @testset "a superseded wait touches nothing, before any library call" begin
        cam = fake_camera()
        cam.last_error = DC.DCAMERR_SUCCESS
        @test DC.wait_not_busy(cam, 1000, "test"; current = () -> false) == false
        @test cam.last_error == DC.DCAMERR_SUCCESS
    end

    @testset "capture_timeout_ms" begin
        @test DC.capture_timeout_ms(0.0125, 0.043) == 1111
        @test DC.capture_timeout_ms(0.25, 0.25) == 2000
        @test DC.capture_timeout_ms(0, 0) == 1000
        @test DC.capture_timeout_ms(0.25, 0.25) isa Int32
        @test_throws ErrorException DC.capture_timeout_ms(NaN, 0)
        @test_throws ErrorException DC.capture_timeout_ms(Inf, 0)
        @test_throws ErrorException DC.capture_timeout_ms(-0.001, 0)
        @test_throws ErrorException DC.capture_timeout_ms(0, -1)
        @test_throws ErrorException DC.capture_timeout_ms(0, NaN)
        @test_throws ErrorException DC.capture_timeout_ms(1e7, 0)
    end

    @testset "wait parameter struct" begin
        @test DC.DCAMWAIT_START(Int32(2), Int32(1000)).size == 16
        @test DC.DCAMWAIT_START(Int32(2), Int32(1000)).size == sizeof(DC.DCAMWAIT_START)
    end

    @testset "an unbounded wait is refused before any library call" begin
        @test_throws r"bounded" DC.dcamwait_event(C_NULL, Int32(2), Int32(-1))
        @test_throws r"bounded" DC.dcamwait_event(C_NULL, Int32(2), reinterpret(Int32, 0x80000000))
    end

    @testset "capture refuses while running, before any library call" begin
        cam = fake_camera()
        cam.is_running = true
        cam.capture_mode = DC.LIVE
        @test_throws r"Stop the live view or sequence first" CameraInterface.capture(cam)
        @test cam.capture_mode == DC.LIVE
        @test cam.is_running
    end

    @testset "cached readout time" begin
        cam = fake_camera()
        cam.readout_s = 0.043
        @test DC.cached_readout_time(cam) == 0.043
    end

    @testset "@dcamcall trace" begin
        # The macro is named by its full path: it must resolve while the file is parsed, before DC exists.
        # libc stands in for the DCAM library: the macro takes the same syntax as @ccall.
        f(s) = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall strlen(s::Cstring)::Csize_t
        g(x) = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall abs(x::Cint)::Cint
        DC.dcam_trace!(nothing)
        @test f("hello") == 5
        @test g(Cint(-3)) == 3

        n = Ref(0)
        h() = MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall abs((n[] += 1; Cint(-7))::Cint)::Cint
        @test h() == 7
        @test n[] == 1

        path = tempname()
        DC.dcam_trace!(path)
        @test f("hello") == 5
        @test h() == 7
        @test n[] == 2
        DC.dcam_trace_note("marker")
        lines = filter(l -> !occursin(r"NOTE  (heartbeat|trace o)", l), readlines(path))   # read while the file is still open: every line is flushed
        DC.dcam_trace!(nothing)
        @test length(lines) == 5
        @test occursin(r"tid=\d+ BEGIN strlen id=\d+ args=\(String\)", lines[1])
        @test occursin(r"tid=\d+ END strlen id=\d+ elapsed_ms=[\d.]+ ret=5 gc_ms=[\d.]+ sp_total_ms=[\d.]+ sp_max_ms=[\d.]+", lines[2])
        @test occursin(r"BEGIN strlen id=\d+ args=\(String\) gc_ms=[\d.]+ sp_total_ms=[\d.]+ sp_max_ms=[\d.]+", lines[1])
        @test occursin(r"BEGIN abs id=\d+ args=\(-7\)", lines[3])
        @test occursin("NOTE  marker", lines[5])

        # Calls are numbered: BEGIN and END share an id, ids increase, and a throw is logged under its BEGIN's id.
        path2 = tempname()
        DC.dcam_trace!(path2)
        @test f("hello") == 5
        @test f("hi") == 2
        @test_throws ArgumentError f("a\0b")
        l2 = readlines(path2)
        @test occursin(r"NOTE  trace on pid=\d+ julia=\S+ threads=interactive:\d+,default:\d+", l2[1])
        DC.dcam_trace!(nothing)
        ids(kind) = [parse(Int, m[1]) for m in match.(Regex(kind * " strlen id=(\\d+)"), l2) if m !== nothing]
        @test length(ids("BEGIN")) == 3
        @test ids("END") == ids("BEGIN")[1:2]
        @test issorted(ids("BEGIN"); lt = <=)
        @test ids("THROW") == ids("BEGIN")[3:3]
        @test any(l -> occursin(r"THROW strlen id=\d+ elapsed_ms=[\d.]+ err=ArgumentError: ", l), l2)
        @test endswith(readlines(path2)[end], "NOTE  trace off")
        rm(path2)

        # BEGIN is on disk before the library call runs: the comparator, called from inside qsort, sees it.
        qpath = tempname()
        QSORT_TRACE_PATH[] = qpath
        QSORT_SAW_BEGIN[] = false
        cmp = @cfunction(qsort_cmp, Cint, (Ptr{Cint}, Ptr{Cint}))
        arr = Cint[3, 1, 2]
        DC.dcam_trace!(qpath)
        GC.@preserve arr MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall qsort(pointer(arr)::Ptr{Cint}, length(arr)::Csize_t, sizeof(Cint)::Csize_t, cmp::Ptr{Cvoid})::Cvoid
        ql = readlines(qpath)
        DC.dcam_trace!(nothing)
        @test QSORT_SAW_BEGIN[]
        @test arr == Cint[1, 2, 3]
        @test any(l -> occursin(r"END qsort id=\d+ ", l), ql)
        rm(qpath)

        # A heartbeat runs while tracing is on, and stops (task done, file quiet) when it is off.
        hbpath = tempname()
        hbre = r"NOTE  heartbeat gc_ms=[\d.]+ sp_total_ms=[\d.]+ sp_max_ms=[\d.]+"
        DC.dcam_trace!(hbpath)
        hb1 = DC.HEARTBEAT[][1]
        t_end = time() + 5
        while time() < t_end && !any(l -> occursin(hbre, l), readlines(hbpath))
            sleep(0.1)
        end
        @test any(l -> occursin(hbre, l), readlines(hbpath))
        DC.dcam_trace!(nothing)
        timedwait(() -> istaskdone(hb1), 2.0)
        @test istaskdone(hb1)
        @test DC.HEARTBEAT[] === nothing
        sz = filesize(hbpath)
        sleep(1.5)
        @test filesize(hbpath) == sz

        # Re-enabling to a second path starts exactly one new heartbeat; the first file stays quiet.
        hbpath2 = tempname()
        DC.dcam_trace!(hbpath2)
        hb2 = DC.HEARTBEAT[][1]
        @test hb2 !== hb1
        DC.dcam_trace!(nothing)
        timedwait(() -> istaskdone(hb2), 2.0)
        @test istaskdone(hb2)
        @test filesize(hbpath) == sz
        rm(hbpath); rm(hbpath2)

        # A heartbeat stuck behind a hung call must not block dcam_trace!: it no longer waits on it.
        stuckpath = tempname()
        DC.dcam_trace!(stuckpath)
        realhb = DC.HEARTBEAT[]
        ev = Base.Event()
        stuck = Threads.@spawn wait(ev)
        DC.HEARTBEAT[] = (stuck, Threads.Atomic{Bool}(false))
        t = @async DC.dcam_trace!(nothing)
        @test timedwait(() -> istaskdone(t), 3.0) === :ok
        notify(ev)
        wait(stuck)
        realhb[2][] = true   # the replaced entry no longer reaches the real heartbeat
        @test timedwait(() -> istaskdone(realhb[1]), 3.0) === :ok
        rm(stuckpath)

        # The blocker's test: the heartbeat keeps writing during a long ccall made from this task. It needs a
        # thread that is not this task's: on 1.12+ the main task is on the interactive thread, so one default
        # thread is enough; before that the default pool must have two.
        if Threads.threadpool() !== :default || Threads.nthreads(:default) >= 2
            bpath = tempname()
            DC.dcam_trace!(bpath)
            timedwait(() -> any(l -> occursin("NOTE  heartbeat", l), readlines(bpath)), 3.0)
            MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall usleep(2_500_000::Cuint)::Cint
            bl = readlines(bpath)
            DC.dcam_trace!(nothing)
            ib = findfirst(l -> occursin(r"BEGIN usleep id=\d+", l), bl)
            bid = match(r"BEGIN usleep id=(\d+)", bl[ib])[1]
            ie = findfirst(l -> occursin("END usleep id=$bid ", l), bl)
            @test count(l -> occursin("NOTE  heartbeat", l), bl[ib:ie]) >= 2
            rm(bpath)
        else
            # a single thread cannot run the heartbeat during a ccall from the only thread
            @test_skip false
        end

        # A failed trace write turns tracing off with one warning; the call itself still runs.
        # (writing to a closed IOStream does not throw, so /dev/full stands in for a full disk)
        # The heartbeat's first line or the call's BEGIN fails first, depending on threads: one warning either way.
        if Sys.islinux()   # /dev/full is Linux-only
            r = @test_logs (:warn, r"tracing is now off") begin
                DC.dcam_trace!("/dev/full")
                v = f("hello")
                wait(DC.HEARTBEAT[][1])
                v
            end
            @test r == 5
            @test !DC.TRACE_ON[]
            @test (@test_logs f("hello")) == 5
            DC.dcam_trace!(nothing)
        end

        # The catch in the traced branch must not bind the caller's `err` (the DCAM call sites all have one).
        function caller_err()
            err = :untouched
            try
                MicroscopeControl.HardwareImplementations.DCAM4.@dcamcall strlen("a\0b"::Cstring)::Csize_t
            catch
            end
            return err
        end
        errpath = tempname()
        DC.dcam_trace!(errpath)
        @test caller_err() === :untouched
        DC.dcam_trace!(nothing)
        rm(errpath)

        # A Ref to a struct logs its Int32 fields, so a wait's timeout shows.
        @test occursin("DCAMWAIT_START{size=16,eventhappened=0,eventmask=2,timeout=1000}", DC.trace_arg(Ref(DC.DCAMWAIT_START(Int32(2), Int32(1000)))))

        @test DC.trace_arg(Ptr{Cvoid}(UInt(0x10))) == "0x10"

        # Off again: nothing is written.
        size0 = filesize(path)
        @test f("hello") == 5
        @test filesize(path) == size0
        rm(path)
    end
end
