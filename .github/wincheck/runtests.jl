# Windows subset runner for the PR 94 check (admiral, 2026-11-03): the four test files that exercise
# save_h5's cleanup and path anchoring, the CSC timeouts, the stage exports and the DCAM read-backs,
# with the fakes they need, in the same order as test/runtests.jl. Copied over test/runtests.jl of the
# checked-out target commit by .github/workflows/WindowsCheck.yml; the target's src and test files are
# used unchanged.
using MicroscopeControl
using Test

const HDF5 = MicroscopeControl.HDF5

# Diagnostic, before the tests: a failed save through a symlink to a new target, with every step printed and the
# logs shown, to see which cleanup branch runs on Windows and why the target can remain.
mutable struct DiagUnwritable
    x::Vector{Int}
end
let dir = mktempdir()
    target = joinpath(dir, "target.h5")
    link = joinpath(dir, "link.h5")
    symlink(target, link)
    println("DIAG islink(link)=", islink(link), " ispath(link)=", ispath(link), " ispath(target)=", ispath(target))
    println("DIAG readlink(link)=", repr(readlink(link)))
    path = MicroscopeControl.anchor_h5_path(link)
    println("DIAG anchored=", repr(path), " ispath(anchored)=", ispath(path), " islink(anchored)=", islink(path))
    bad = (Dict{String,Any}("bad" => DiagUnwritable([1])), fill(UInt16(7), 3, 4), Dict{String,Any}())
    t = save_h5(link, bad)
    try
        wait(t)
    catch e
        println("DIAG save threw ", typeof(e))
    end
    println("DIAG after: islink(link)=", islink(link), " ispath(link)=", ispath(link), " ispath(target)=", ispath(target),
        " size(target)=", isfile(target) ? filesize(target) : -1)
    try
        println("DIAG realpath(link)=", repr(realpath(link)))
    catch e
        println("DIAG realpath(link) threw ", sprint(showerror, e))
    end
    try
        rm(target)
        println("DIAG manual rm(target) ok; ispath(target)=", ispath(target))
    catch e
        println("DIAG manual rm(target) threw ", sprint(showerror, e))
    end
end

include("pi_n472_fake_sdk.jl")
include("pi_stage_fake_sdk.jl")

@testset "Windows subset" begin
    include("h5_saving.jl")
    include("dcam4_fake_sdk.jl")
    include("dcam4_fake_paths.jl")
    include("driver_readback.jl")
    include("csc_failures.jl")
    include("mcl_stage.jl")
    include("stage_exports.jl")
end
