# Run by gui.jl in a `julia -t 2` subprocess, so the default suite exercises it: the camera display's frame reader
# must run on its own thread. A reader whose `getlastframe` blocks in a foreign call stands in for a DCAM frame wait; a
# ticker on this task stands in for the render side. If the reader shares this thread (an `@async` instead of
# `Threads.@spawn`), the ticker stops for the whole of every read.
using MicroscopeControl, Test

const CI = MicroscopeControl.HardwareInterfaces.CameraInterface
const READS = 4
const READ_S = 0.3

mutable struct BlockingCamera <: MicroscopeControl.Camera
    is_running::Int
    reads::Int
end

function MicroscopeControl.getlastframe(camera::BlockingCamera)
    camera.reads += 1
    @static if Sys.iswindows()
        ccall((:Sleep, "kernel32"), stdcall, Cvoid, (UInt32,), round(UInt32, 1000 * READ_S))
    else
        ccall(:usleep, Cint, (Cuint,), round(Cuint, 1_000_000 * READ_S))
    end
    camera.reads >= READS && (camera.is_running = 0)
    return ones(UInt16, 2, 2)
end

@testset "the frame reader runs off the render thread" begin
    @test Threads.nthreads(:default) >= 2
    camera = BlockingCamera(1, 0)
    shown = Ref(0)
    ticks = Ref(0)
    finished = Ref(false)
    ticker = @async while !finished[]
        ticks[] += 1
        sleep(0.01)
    end
    reader, display_task, _ = CI.run_live_loop(_ -> shown[] += 1, camera; fps = 200)
    wait(reader); wait(display_task)
    finished[] = true
    wait(ticker)
    @test shown[] == READS
    # Over READS x READ_S = 1.2 s of blocked reads the ticker runs about 100 times, unless the reads block its thread.
    @info "render-side ticks during blocking reads" ticks = ticks[]
    @test ticks[] >= 40
end
