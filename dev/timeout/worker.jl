# worker.jl
using Serialization
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

scope4 = Triggerscope4()
initialize(scope4)

outfile = ARGS[1]

# 1) record script start
script_start = time()

# 2) do your work
progdac(scope4, 1, 1, 1.0)
work_end     = time()
work_elapsed = work_end - script_start

# 3) build result without file timings
res = Dict(
    :script_start => script_start,
    :work_elapsed => work_elapsed,
    :payload      => rand(3)
)

# 4) serialize into memory & measure that
buf = IOBuffer()
t0 = time()
serialize(buf, res)
serialize_elapsed = time() - t0

# 5) annotate timing into the same dict
res[:serialize_elapsed] = serialize_elapsed

# 6) now write the **final** dict out exactly once
open(outfile, "w") do io
    serialize(io, res)
end
