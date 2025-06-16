# main.jl
using Serialization
using Printf

"""
    run_with_serialization(timeout_s::Real) -> (result::Dict, success::Bool)

Spawns `worker.jl` in a subprocess, passing it a temp‐file path.
Waits up to `timeout_s` seconds (covering Julia startup + your work).
On success: reads & returns the deserialized Dict, then deletes the file.
On timeout or failure: kills the process, deletes any stale file, and returns `(nothing,false)`.
"""
function run_with_serialization(timeout_s::Real)
    outfile = tempname() * ".bin"
    script  = abspath("dev/blocking_timeout/worker.jl")
    
    # Don't use pipeline - it can create zombie processes
    proc = run(`julia --startup-file=no $script $outfile`, wait=false)
    
    deadline = time() + timeout_s
    while process_running(proc) && time() < deadline
        sleep(0.01)
    end
    
    if process_running(proc)
        # Force kill on Windows
        if Sys.iswindows()
            # First try Julia's SIGKILL
            try
                kill(proc, Base.SIGKILL)
                sleep(0.1)  # Give it a moment
            catch
            end
            
            # If still running, use OS-level kill
            if process_running(proc)
                try
                    run(`taskkill /F /PID $(getpid(proc))`)
                catch
                end
            end
        else
            kill(proc)
        end
        
        # Don't wait after force kill - it might hang
        isfile(outfile) && rm(outfile; force=true)
        return nothing, false
    else
        # Process finished normally
        wait(proc)
        if isfile(outfile)
            result = open(deserialize, outfile, "r")
            rm(outfile; force=true)
            return result, true
        else
            return nothing, false
        end
    end
end



"""
    display_metrics(res::Dict, tic_spawn::Real)

Given the worker’s `res` Dict (with keys
  :script_start, :work_elapsed, :serialize_elapsed
) and the `tic_spawn` timestamp from before you spawned it,
this will print a formatted timing summary to the REPL.

Example:
```julia
# after `res, ok = run_with_serialization(TIMEOUT)`:
if ok
    display_metrics(res, tic_spawn)
end
```
"""
function display_metrics(res::Dict, tic_spawn::Real)
    # compute each metric
    spawn_overhead    = res[:script_start]    - tic_spawn
    work_elapsed      = res[:work_elapsed]
    serialize_elapsed = res[:serialize_elapsed]

    # print table
    println("\n=== Timing Summary ===")
    println(rpad("Stage",  20), " | ", "Seconds")
    println(repeat('-', 32))
    @printf("%-20s | %8.6f\n", "Spawn Overhead",    spawn_overhead)
    @printf("%-20s | %8.6f\n", "Work Elapsed",      work_elapsed)
    @printf("%-20s | %8.6f\n", "Serialize Elapsed", serialize_elapsed)
end


# ==== Usage Example ====
const TIMEOUT2 = 4.0  # seconds
const TIMEOUT1 = 7.0  # seconds


tic_spawn = time()
res, ok = run_with_serialization(TIMEOUT2)

if ok
    display_metrics(res, tic_spawn)
else
    println("✗ timed out or no output after $(TIMEOUT2) s")
end
