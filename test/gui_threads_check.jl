# Run by gui.jl in a `julia -t 2,1` subprocess, so the default suite exercises it: the camera display's frame reader
# must run on its own thread. A reader whose `getlastframe` blocks in a foreign call stands in for a DCAM frame wait; a
# ticker stands in for the render side. Every wait here has a deadline, so a regression fails the test and cannot hang it.
#
# Threads: `-t 2,1` is two default threads and one interactive thread (Julia 1.9 and later; see the manual's section on
# threadpools). With an interactive pool the main task runs on the interactive thread (documented for 1.11 as well as 1.12
# and later; not run on 1.11 by the authors). The ticker is spawned in the interactive pool too, and `Threads.@spawn` in
# `run_live_loop` puts the reader in the default pool, so the reader never shares a thread with the ticker or with the
# display callback, which runs on the main task. A reader that shared the main thread (an `@async` instead of
# `Threads.@spawn`) would stop the ticker and fail the checks below, on every version.
using MicroscopeControl, Test

const CI = MicroscopeControl.HardwareInterfaces.CameraInterface
const READS = 4
const READ_S = 0.3
const DEADLINE_S = 30.0

mutable struct BlockingCamera <: MicroscopeControl.Camera
    is_running::Int
    reads::Int
    reader_threads::Vector{Int}
end

function MicroscopeControl.getlastframe(camera::BlockingCamera)
    camera.reads += 1
    push!(camera.reader_threads, Threads.threadid())
    @static if Sys.iswindows()
        ccall((:Sleep, "kernel32"), stdcall, Cvoid, (UInt32,), round(UInt32, 1000 * READ_S))
    else
        ccall(:usleep, Cint, (Cuint,), round(Cuint, 1_000_000 * READ_S))
    end
    camera.reads >= READS && (camera.is_running = 0)
    return ones(UInt16, 2, 2)
end

@testset "the frame reader runs off the render thread" begin
    @test Threads.nthreads(:default) >= 2 && Threads.nthreads(:interactive) >= 1
    camera = BlockingCamera(1, 0, Int[])
    shown = Ref(0)
    ticks = Ref(0)
    stop = Threads.Atomic{Bool}(false)
    ticker_thread = Ref(0)
    ticker = Threads.@spawn :interactive begin
        ticker_thread[] = Threads.threadid()
        while !stop[]
            ticks[] += 1
            sleep(0.01)
        end
    end
    show_thread = Ref(0)
    reader, display_task, _ = CI.run_live_loop(camera; fps = 200) do _
        shown[] += 1
        show_thread[] = Threads.threadid()
    end
    @test timedwait(() -> istaskdone(reader) && istaskdone(display_task), DEADLINE_S; pollint = 0.01) === :ok
    stop[] = true
    @test timedwait(() -> istaskdone(ticker), DEADLINE_S; pollint = 0.01) === :ok
    @test shown[] == READS
    @test Threads.threadpool(ticker_thread[]) === :interactive
    @test all(t -> Threads.threadpool(t) === :default, camera.reader_threads)   # the reader is off the interactive thread
    @test ticker_thread[] ∉ camera.reader_threads
    @test show_thread[] ∉ camera.reader_threads              # the display callback's thread is not the reader's
    # Over READS x READ_S = 1.2 s of blocked reads the ticker runs about 100 times, unless the reads block its thread.
    @info "render-side ticks during blocking reads" ticks = ticks[] reader_threads = camera.reader_threads ticker_thread = ticker_thread[]
    @test ticks[] >= 40
end
