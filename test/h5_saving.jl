@testset "S2: save_h5 snapshot and publication (p2)" begin
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
        original = read(filename)
        bad = (Dict("nothing_attr" => nothing), frame, Dict())
        @test_logs (:error, r"Failed to save") @test_throws TaskFailedException wait(save_h5(filename, bad))
        @test read(filename) == original
        @test readdir(dir) == ["frames.h5"]
        @test_logs (:error, r"Failed to save") @test_throws TaskFailedException wait(save_h5(joinpath(dir, "bad.h5"), bad))
        @test readdir(dir) == ["frames.h5"]
        @test_throws ArgumentError save_h5(filename, state; overwrite=false)
        @test read(filename) == original
        @test readdir(dir) == ["frames.h5"]
        @test_logs (:warn, r"Replacing existing HDF5 file") wait(save_h5(filename, state))
        @test HDF5.h5read(filename, "Main/data") == frame
        fresh = joinpath(dir, "fresh.h5")
        wait(save_h5(fresh, state; overwrite=false))
        @test isfile(fresh)
        # A competing writer wins after the call but before the task runs: never clobber it.
        race = joinpath(dir, "race.h5")
        task = save_h5(race, state; overwrite=false)
        write(race, "earlier data")
        @test_throws TaskFailedException wait(task)
        @test read(race, String) == "earlier data"
        # Rename failure also cleans up (a directory cannot be replaced by a file).
        targetdir = mkdir(joinpath(dir, "destination"))
        write(joinpath(targetdir, "earlier"), "intact")
        @test_logs (:warn, r"Replacing existing HDF5 file") @test_throws TaskFailedException wait(save_h5(targetdir, state))
        @test read(joinpath(targetdir, "earlier"), String) == "intact"
        @test sort(readdir(dir)) == ["destination", "frames.h5", "fresh.h5", "race.h5"]
    end
end

@testset "S6: MLSLM export and HDF5 round trip" begin
    ML = MicroscopeControl.HardwareImplementations.Meadowlark
    slm = MLSLM(width=4, height=3, phase=fill(1.0, 3, 4), offset=fill(2.0, 3, 4),
                sequence=ML.Sequence(phase=fill(3.0, 3, 4, 2), offset=fill(4.0, 3, 4, 2)))
    a, data, children = export_state(slm)
    @test a["width"] == 4 && a["height"] == 3
    @test data == fill(1.0, 3, 4)
    @test children["offset"][2] == fill(2.0, 3, 4)
    @test children["sequence"][1]["num_frames"] == 2
    mktempdir() do dir
        path = joinpath(dir, "slm.h5")
        wait(save_h5(path, export_state(slm)))
        @test HDF5.h5read(path, "Main/data") == data
        @test HDF5.h5read(path, "Main/sequence/data") == slm.sequence.phase
        @test HDF5.h5read(path, "Main/sequence/offset/data") == slm.sequence.offset
    end
end
