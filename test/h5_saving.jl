@testset "S6/S7: cached driver exports and HDF5 round trips (no SDK)" begin
    ML = MicroscopeControl.HardwareImplementations.Meadowlark
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    slm = MLSLM(width=4, height=3, pixelsize=2.0, wavelength=0.5,
        pupil=ML.Pupil(1, 2, 3, 4), phase=fill(1.0, 3, 4), offset=fill(2.0, 3, 4),
        sequence=ML.Sequence(phase=fill(3.0, 3, 4, 2), offset=fill(4.0, 3, 4, 2)))
    # Positional construction bypasses SDK initialization; the keyword camera constructors open hardware.
    cam = CSC.ThorCamCSCCamera(C_NULL, 3_000_000, Cint(1000), UInt8[0x31], Cint(5),
        CameraFormat(8, 6, 1, 0, "CMOS"), Cint(2), Cint(0), Cint(1), Cint(30),
        CameraROI(3, 2, 4, 3), 3, CSC.SEQUENCE, CSC.SOFTWARE_TRIGGER, Cint(9), Cint(7), 0)
    dcam = DC.DCAM4Camera("fake", CameraFormat(8, 6, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        CameraROI(2, 1, 4, 3), DC.SINGLE_FRAME, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2,
        DC.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 3, 4), NaN, 0)

    a, data, children = export_state(slm)
    @test a["width"] == 4 && a["height"] == 3
    @test a["pixelsize"] == 2.0 && a["wavelength"] == 0.5
    @test (a["pupil_x_center"], a["pupil_y_center"], a["pupil_x_radius"], a["pupil_y_radius"]) == (1, 2, 3, 4)
    @test a["bit_depth"] == 12 && a["n_boards_found"] == 0 && a["constructed_ok"] == 1
    @test a["is_nematic_type"] == a["ram_write_enable"] == a["use_gpu"] == 1
    @test a["max_transient_frames"] == 10
    @test all(v -> v isa Number, values(a))
    @test data === nothing
    @test isempty(children)

    a, data, children = export_state(cam)
    @test a["unique_id"] isa String
    @test a["unique_id"] == "1" && cam.unique_id == UInt8[0x31]
    cam.unique_id = UInt8[0x31, 0x00, 0x00]
    @test export_state(cam)[1]["unique_id"] == "1" # SDK name buffer may be NUL padded
    @test cam.unique_id == UInt8[0x31, 0x00, 0x00]
    @test a["camera_format_x_pixels"] == 8 && a["camera_format_y_pixels"] == 6
    @test a["roi_origin"] == 1
    @test (a["roi_x"], a["roi_y"], a["roi_width"], a["roi_height"]) == (3, 2, 4, 3)
    @test a["exposure_time"] == 3_000_000 && a["exposure_time_unit"] == "us"
    @test a["poll_timeout_ms"] == 1000
    @test a["capture_mode"] == Int(CSC.SEQUENCE) && a["trigger_mode"] == Int(CSC.SOFTWARE_TRIGGER)
    @test a["sequence_length"] == 3 && a["last_error"] == 9
    @test a["is_running"] == 0 && a["camera_state"] == 7
    @test data === nothing && isempty(children)

    a = export_state(dcam)[1]
    @test a["roi_origin"] == 0
    @test (a["roi_x"], a["roi_y"], a["roi_width"], a["roi_height"]) == (2, 1, 4, 3)

    mktempdir() do dir
        for (name, device) in (("slm", slm), ("csc", cam), ("dcam", dcam))
            path = joinpath(dir, name * ".h5")
            state = export_state(device)
            wait(save_h5(path, state))
            HDF5.h5open(path) do file
                group = file["Main"]
                @test isempty(keys(group)) # attributes only: no data or child groups
                @test Set(keys(HDF5.attrs(group))) == Set(keys(state[1]))
                for (key, value) in state[1]
                    @test HDF5.read_attribute(group, key) == value
                end
            end
        end
    end
end

@testset "r7b: HDF5 saves follow symlinks" begin
    if Sys.isunix()
        mktempdir() do dir
            targetdir = mkdir(joinpath(dir, "data"))
            linkdir = mkdir(joinpath(dir, "links"))
            target = joinpath(targetdir, "frames.h5")
            link = joinpath(linkdir, "frames.h5")
            state(value) = (Dict("run" => value), fill(UInt16(value), 3, 4), Dict())
            wait(save_h5(target, state(1)))
            symlink(joinpath("..", "data", "frames.h5"), link)
            @test_logs wait(save_h5(link, state(2)))
            @test islink(link)
            @test HDF5.h5read(target, "Main/data") == fill(UInt16(2), 3, 4)
            @test HDF5.h5read(link, "Main/data") == fill(UInt16(2), 3, 4)
            @test readdir(targetdir) == ["frames.h5"]
            @test readdir(linkdir) == ["frames.h5"]

            # A missing target is a valid symlink destination; direct HDF5 creates that target too.
            dangling = joinpath(linkdir, "new.h5")
            symlink(joinpath("..", "data", "new.h5"), dangling)
            wait(save_h5(dangling, state(3)))
            @test islink(dangling)
            @test isfile(joinpath(targetdir, "new.h5"))
        end
    end
end

@testset "r7e: HDF5 follows directory symlinks before parent traversal" begin
    if Sys.isunix()
        mktempdir() do dir
            work = mkdir(joinpath(dir, "work"))
            data = mkdir(joinpath(dir, "data"))
            run = mkdir(joinpath(data, "run"))
            link = joinpath(work, "link")
            symlink(run, link)
            state(value) = (Dict("run" => value), fill(UInt16(value), 3, 4), Dict())
            requested = joinpath(link, "..", "frames.h5")
            target = joinpath(data, "frames.h5")

            wait(save_h5(requested, state(1)))
            @test isfile(target)
            @test !ispath(joinpath(work, "frames.h5"))
            # Also cover a file that already exists when the destination is resolved.
            save_attributes_and_data(target, "Main", state(9)...)
            @test_logs wait(save_h5(requested, state(2)))
            @test HDF5.h5read(target, "Main/data") == fill(UInt16(2), 3, 4)
            @test islink(link)

            # Pass a relative path unchanged to HDF5, including link/...
            cd(work) do
                wait(save_h5(joinpath("link", "..", "relative.h5"), state(3)))
            end
            @test isfile(joinpath(data, "relative.h5"))
            @test !ispath(joinpath(work, "relative.h5"))

            # A file symlink can itself name a target containing directory-link/...
            filelink = joinpath(work, "file-link.h5")
            symlink(joinpath("link", "..", "file-target.h5"), filelink)
            wait(save_h5(filelink, state(4)))
            @test islink(filelink)
            @test isfile(joinpath(data, "file-target.h5"))
            @test !ispath(joinpath(work, "file-target.h5"))
        end
    end
end

@testset "S2/r7e: snapshot and in-place overwrite" begin
    mktempdir() do dir
        filename = joinpath(dir, "frames.h5")
        frame = fill(UInt16(111), 4, 3)
        childframe = copy(frame)
        attributes = Dict("run" => 1)
        childattrs = Dict("child" => 2)
        state = (attributes, frame, Dict("camera" => (childattrs, childframe, Dict())))
        task = save_h5(filename, state)
        @test task isa Task
        frame .= 999
        childframe .= 888
        attributes["run"] = 3
        childattrs["child"] = 4
        wait(task)
        @test HDF5.h5read(filename, "Main/data") == fill(UInt16(111), 4, 3)
        @test HDF5.h5read(filename, "Main/camera/data") == fill(UInt16(111), 4, 3)
        HDF5.h5open(filename) do f
            @test HDF5.read_attribute(f["Main"], "run") == 1
            @test HDF5.read_attribute(f["Main/camera"], "child") == 2
        end
        inode = stat(filename).inode
        @test_logs wait(save_h5(filename, state))
        @test stat(filename).inode == inode
        @test HDF5.h5read(filename, "Main/data") == frame
        fresh = joinpath(dir, "fresh.h5")
        wait(save_h5(fresh, state))
        @test isfile(fresh)
        # Keep the original overwrite behavior if a target appears before the task runs.
        race = joinpath(dir, "race.h5")
        task = save_h5(race, state)
        write(race, "earlier data")
        @test_logs wait(task)
        @test HDF5.h5read(race, "Main/data") == frame
        @test readdir(dir) == ["frames.h5", "fresh.h5", "race.h5"]
    end
end

@testset "r7f: relative paths are anchored when save_h5 is called" begin
    mktempdir() do dir
        first = mkdir(joinpath(dir, "first"))
        second = mkdir(joinpath(dir, "second"))
        state = (Dict("run" => 1), fill(UInt16(42), 3, 4), Dict())
        task = cd(first) do
            save_h5("frames.h5", state)
        end
        cd(second) do
            @test_logs wait(task)
        end
        @test !ispath(joinpath(second, "frames.h5"))
        @test HDF5.h5read(joinpath(first, "frames.h5"), "Main/data") == state[2]
    end
end

@testset "r7e: real filesystem write failures log and invalidate incomplete saves" begin
    # Linux RLIMIT_FSIZE gives real EFBIG failures on ordinary numeric data.
    # Keep the resource limit and SIGXFSZ handler in a child, with no devices.
    if Sys.islinux()
        mktempdir() do dir
            script = """
                using MicroscopeControl, Test
                const HDF5 = MicroscopeControl.HDF5
                @testset "EFBIG cleanup, with and without wait" begin
                    small = (Dict("run" => 1), zeros(UInt16, 3, 4), Dict())
                    large = (Dict("run" => 2), fill(UInt16(42), 256, 256), Dict())
                    existing = joinpath(ARGS[1], "existing.h5")
                    alias = joinpath(ARGS[1], "alias.h5")
                    fresh = joinpath(ARGS[1], "new.h5")
                    link = joinpath(ARGS[1], "link.h5")
                    target = joinpath(ARGS[1], "target.h5")
                    unwaited = joinpath(ARGS[1], "unwaited.h5")
                    save_attributes_and_data(existing, "Main", small...)
                    chmod(existing, 0o640)
                    hardlink(existing, alias)
                    symlink("target.h5", link)
                    original = stat(existing)
                    # RLIMIT_FSIZE=1, SIGXFSZ=25, SIG_IGN=(void*)1 on Linux.
                    ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 25, Ptr{Cvoid}(UInt(1)))
                    limits = UInt64[16384, typemax(UInt64)]
                    @test ccall(:setrlimit, Cint, (Cint, Ptr{UInt64}), 1, limits) == 0
                    for path in (existing, fresh, link)
                        @test_logs (:error, "Failed to save to HDF5 file") begin
                            @test_throws TaskFailedException wait(save_h5(path, large))
                        end
                    end
                    @test filesize(existing) == filesize(alias) == 0
                    @test stat(existing).inode == stat(alias).inode == original.inode
                    @test stat(existing).uid == original.uid && stat(existing).gid == original.gid
                    @test filemode(existing) == original.mode
                    @test !HDF5.ishdf5(existing)
                    @test !ispath(fresh)
                    @test islink(link) && readlink(link) == "target.h5"
                    @test !ispath(target) && !ispath(link)
                    # The caller does not wait: the task itself must log its failure.
                    @test_logs (:error, "Failed to save to HDF5 file") begin
                        task = save_h5(unwaited, large)
                        @test timedwait(() -> istaskdone(task), 10.0; pollint=0.005) === :ok
                        @test istaskfailed(task)
                    end
                    @test !ispath(unwaited)
                    @test readdir(ARGS[1]) == ["alias.h5", "existing.h5", "link.h5"]
                end
                """
            output = IOBuffer()
            project = dirname(Base.active_project())
            process = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --project=$project -e $script $dir`),
                                   stdout=output, stderr=output))
            success(process) || @error "HDF5 write-failure child failed" output=String(take!(output))
            @test success(process)
            @test filesize(joinpath(dir, "existing.h5")) == filesize(joinpath(dir, "alias.h5")) == 0
            @test islink(joinpath(dir, "link.h5")) && !ispath(joinpath(dir, "target.h5"))
            @test readdir(dir) == ["alias.h5", "existing.h5", "link.h5"]
        end
    else
        @test_skip false # RLIMIT_FSIZE and the signal constants above are Linux-specific.
    end
end

@testset "r7e: cleanup failures are logged without hiding the write error" begin
    if Sys.isunix() && ccall(:geteuid, Cuint, ()) != 0
        mktempdir() do dir
            path = joinpath(dir, "readonly.h5")
            state = (Dict("run" => 1), fill(UInt16(42), 3, 4), Dict())
            save_attributes_and_data(path, "Main", state...)
            original = read(path)
            chmod(path, 0o400) # Both the HDF5 open and subsequent truncation really fail.
            try
                logs, task = Test.collect_test_logs() do
                    task = save_h5(path, state)
                    @test_throws TaskFailedException wait(task)
                    task
                end
                @test [log.message for log in logs] == ["Failed to save to HDF5 file",
                    "Failed to clean up HDF5 file after save failure"]
                if length(logs) == 2
                    original_error = logs[1].kwargs[:exception]
                    cleanup_error = logs[2].kwargs[:exception]
                    @test original_error isa HDF5.API.H5Error
                    @test cleanup_error isa Base.IOError || cleanup_error isa SystemError
                    @test last(Base.current_exceptions(task)).exception === original_error
                end
                @test read(path) == original
            finally
                chmod(path, 0o600)
            end
        end
    else
        @test_skip false # Permission failures must be exercised as a non-root Unix user.
    end
end

# Pause after real HDF5 writes, while its file is open, to deliver a real task
# interrupt. The numeric attributes and arrays remain ordinary valid state.
module H5InterruptRecorder
using MicroscopeControl
const entered = Channel{Nothing}(1)
const resume = Channel{Nothing}(1)
const continued = Ref(false)
function MicroscopeControl.save_group_recursive(parent, group::String,
        attributes::Dict{String,Int32}, data, children)
    result = invoke(MicroscopeControl.save_group_recursive,
        Tuple{Any,String,Dict,Any,Any}, parent, group, attributes, data, children)
    if get(attributes, "pause_for_interrupt", 0) == 1
        put!(entered, nothing)
        take!(resume)
        continued[] = true
    end
    result
end
end

@testset "r7e: interrupts log, clean up, and propagate" begin
    mktempdir() do dir
        for existed in (false, true)
            path = joinpath(dir, existed ? "existing.h5" : "new.h5")
            if existed
                save_attributes_and_data(path, "Main", Dict("run" => 1), zeros(UInt16, 3, 4), Dict())
            end
            interrupted = InterruptException()
            H5InterruptRecorder.continued[] = false
            logs, task = Test.collect_test_logs() do
                state = (Dict("pause_for_interrupt" => Int32(1)), fill(UInt16(42), 3, 4), Dict())
                task = save_h5(path, state)
                ready = timedwait(() -> isready(H5InterruptRecorder.entered), 10.0; pollint=0.005)
                @test ready === :ok
                ready === :ok || error("HDF5 write did not reach the interrupt barrier")
                take!(H5InterruptRecorder.entered)
                schedule(task, interrupted; error=true)
                @test_throws TaskFailedException wait(task)
                task
            end
            @test [log.message for log in logs] == ["Failed to save to HDF5 file"]
            @test last(Base.current_exceptions(task)).exception === interrupted
            @test !H5InterruptRecorder.continued[]
            @test existed ? filesize(path) == 0 : !ispath(path)
        end
        @test readdir(dir) == ["existing.h5"]
    end
end


@testset "r7f: changing directory during a failed relative save cleans only its own target" begin
    if Sys.islinux()
        mktempdir() do dir
            script = """
                using MicroscopeControl, Test
                const entered = Channel{Nothing}(1)
                const resume = Channel{Nothing}(1)
                # HDF5 has already opened the real file. Pause before the large write
                # so another task can change cwd, then let RLIMIT_FSIZE cause EFBIG.
                function MicroscopeControl.save_group_recursive(parent, group::String,
                        attributes::Dict{String,Int16}, data, children)
                    put!(entered, nothing)
                    take!(resume)
                    invoke(MicroscopeControl.save_group_recursive,
                        Tuple{Any,String,Dict,Any,Any}, parent, group, attributes, data, children)
                end
                @testset "Relative save cleanup after cwd changes" begin
                    own = mkdir(joinpath(ARGS[1], "own"))
                    other = mkdir(joinpath(ARGS[1], "other"))
                    small = (Dict("run" => 1), zeros(UInt16, 3, 4), Dict())
                    large = (Dict("run" => Int16(2)), fill(UInt16(42), 256, 256), Dict())
                    ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 25, Ptr{Cvoid}(UInt(1)))
                    limits = UInt64[16384, typemax(UInt64)]
                    @test ccall(:setrlimit, Cint, (Cint, Ptr{UInt64}), 1, limits) == 0
                    for existed in (true, false)
                        name = existed ? "existing.h5" : "new.h5"
                        target = joinpath(own, name)
                        unrelated = joinpath(other, name)
                        existed && save_attributes_and_data(target, "Main", small...)
                        save_attributes_and_data(unrelated, "Main", small...)
                        original = read(unrelated)
                        @test_logs (:error, "Failed to save to HDF5 file") begin
                            cd(own) do
                                task = save_h5(name, large)
                                ready = timedwait(() -> isready(entered), 10.0; pollint=0.005)
                                @test ready === :ok
                                ready === :ok || error("HDF5 did not open the relative destination")
                                take!(entered)
                                cd(other) do
                                    put!(resume, nothing)
                                    @test_throws TaskFailedException wait(task)
                                end
                            end
                        end
                        @test existed ? filesize(target) == 0 : !ispath(target)
                        @test read(unrelated) == original
                    end
                end
                """
            output = IOBuffer()
            project = dirname(Base.active_project())
            process = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --project=$project -e $script $dir`),
                                   stdout=output, stderr=output))
            success(process) || @error "HDF5 relative-cleanup child failed" output=String(take!(output))
            @test success(process)
        end
    else
        @test_skip false # Real EFBIG uses Linux resource-limit and signal constants.
    end
end


@testset "r7g: save paths resolve the parent once and keep the leaf" begin
    anchor = MicroscopeControl.anchor_h5_path
    mktempdir() do dir
        ordinary = mkdir(joinpath(dir, "ordinary"))
        cd(ordinary) do
            expected = joinpath(realpath(ordinary), "frames.h5")
            @test anchor("frames.h5") == expected
            @test anchor(joinpath(ordinary, "frames.h5")) == expected
            # Missing parent directories are real filesystem failures. Preserve
            # the requested spelling, including .., for the HDF5 writer to handle.
            missing = joinpath("missing", "..", "frames.h5")
            # Windows resolves `..` in the path text before looking at the disk, so there the missing directory
            # cancels out and the parent resolves; POSIX looks each component up, so it fails and the path stays.
            @test anchor(missing) == (Sys.iswindows() ? expected : missing)
            absolute_missing = joinpath(ordinary, "missing", "frames.h5")
            @test anchor(absolute_missing) == absolute_missing

            if Sys.iswindows()
                drive, tail = splitdrive(realpath(ordinary))
                if length(drive) == 2 && endswith(drive, ":")
                    # Both forms refer to existing directories on this drive;
                    # the anchored result must carry the fully resolved drive.
                    @test anchor(joinpath(tail, "frames.h5")) == expected
                    @test anchor(drive * "frames.h5") == expected
                end
            end
        end
        if Sys.isunix()
            work = mkdir(joinpath(dir, "work"))
            data = mkdir(joinpath(dir, "data"))
            run = mkdir(joinpath(data, "run"))
            other = mkdir(joinpath(dir, "other"))
            other_run = mkdir(joinpath(other, "run"))
            link = joinpath(work, "link")
            symlink(run, link)
            cd(work) do
                requested = joinpath("link", "..", "frames.h5")
                target = joinpath(realpath(data), "frames.h5")
                @test anchor(requested) == target
                @test anchor(joinpath(work, requested)) == target

                # Resolve only the parent: a symlink leaf stays for HDF5 and
                # the existing failure cleanup to follow at write time.
                leaf = joinpath(work, "leaf.h5")
                symlink(joinpath(data, "not-created.h5"), leaf)
                @test anchor("leaf.h5") == joinpath(realpath(work), "leaf.h5")
                @test islink(leaf)

                state = (Dict("run" => 1), fill(UInt16(42), 3, 4), Dict())
                task = save_h5(requested, state)
                # The task must use the parent's call-time resolution even if
                # another caller retargets that directory link before it writes.
                rm(link)
                symlink(other_run, link)
                @test_logs wait(task)
                @test isfile(target)
                @test HDF5.h5read(target, "Main/data") == state[2]
                @test !ispath(joinpath(other, "frames.h5"))
            end
        end
        if Sys.isunix() && ccall(:geteuid, Cuint, ()) != 0
            # A working directory whose ancestor is not searchable: realpath
            # fails, and a relative save must still work as it did before.
            locked = mkdir(joinpath(dir, "locked"))
            inner = mkdir(joinpath(locked, "run"))
            chmod(inner, 0o700)
            cd(inner) do
                chmod(locked, 0o600)
                try
                    @test anchor("frames.h5") == "frames.h5"
                    state = (Dict("run" => 1), fill(UInt16(42), 3, 4), Dict())
                    @test_logs wait(save_h5("frames.h5", state))
                    @test isfile("frames.h5")
                    @test HDF5.h5read("frames.h5", "Main/data") == state[2]
                finally
                    chmod(locked, 0o700)
                end
            end
        end
    end
end

# An attribute value HDF5 cannot store (a mutable struct). A caller's `export_state` could return one; HDF5.jl throws
# after the file exists and the data are written, so it injects a failed save on every platform, Windows included,
# where the file-size-limit tests above are skipped.
mutable struct H5UnwritableAttribute
    x::Vector{Int}
end

@testset "save_h5 removes or empties a partial file after a failed write, on every platform" begin
    mktempdir() do dir
        bad = (Dict{String,Any}("bad" => H5UnwritableAttribute([1])), fill(UInt16(7), 3, 4), Dict{String,Any}())
        good = (Dict{String,Any}("run" => 1), fill(UInt16(42), 3, 4), Dict{String,Any}())
        failed_save(path) = @test_logs (:error, r"Failed to save to HDF5 file") match_mode = :any begin
            @test_throws TaskFailedException wait(save_h5(path, bad))
        end

        # A file the save created is removed.
        fresh = joinpath(dir, "fresh.h5")
        failed_save(fresh)
        @test !ispath(fresh)

        # An existing file is emptied in place (the HDF5 handle must be closed first, which Windows enforces).
        existing = joinpath(dir, "existing.h5")
        wait(save_h5(existing, good))
        @test filesize(existing) > 0
        failed_save(existing)
        @test isfile(existing)
        @test filesize(existing) == 0

        # Through a symlink to a new target: the target is removed and the link kept. Making a symlink can need a
        # privilege on Windows; skip only if the platform refuses.
        target = joinpath(dir, "target.h5")
        link = joinpath(dir, "link.h5")
        made = try
            symlink(target, link)
            true
        catch
            false
        end
        if made
            failed_save(link)
            @test islink(link)
            @test !ispath(target)
        else
            @test_skip false
        end
    end
end
