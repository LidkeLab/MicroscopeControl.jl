# The lab test record (admiral decision 0009). `record_tests.jl` runs `Pkg.test()` with
# LAB_TEST_SUMMARY=<path> and reads the result from that file, one entry per test group of
# test/test_groups.toml. Until this package adopts the lab's group layout (decision 0008),
# the whole suite is the one group Core, and this wrapper is the only record-specific code.

using Test, TOML

"""
    lab_summary(f, group)

Run `f()`, the package's top-level `@testset`, and when LAB_TEST_SUMMARY is set write its
counts there as `group`. A failing suite still writes its summary and then rethrows, so
`Pkg.test()` fails exactly as it did without the wrapper.
"""
function lab_summary(f, group::AbstractString)
    t0 = time()
    counts, failure = try
        ts = f()
        c = Test.get_test_counts(ts)
        (pass = c.passes + c.cumulative_passes, fail = 0, error = 0,
            broken = c.broken + c.cumulative_broken), nothing
    catch e
        e isa Test.TestSetException || rethrow()
        (pass = e.pass, fail = e.fail, error = e.error, broken = e.broken), e
    end
    path = get(ENV, "LAB_TEST_SUMMARY", "")
    if !isempty(path)
        result = Dict{String, Any}(
            "ran" => true, "passed" => counts.fail + counts.error == 0, "pass" => counts.pass,
            "fail" => counts.fail, "error" => counts.error, "broken" => counts.broken,
            "seconds" => round(time() - t0; digits = 1))
        open(path, "w") do io
            TOML.print(io, Dict("julia" => string(VERSION),
                "host" => first(split(gethostname(), '.')),
                "groups" => Dict(group => result)); sorted = true)
        end
    end
    failure === nothing || throw(failure)
    return nothing
end
