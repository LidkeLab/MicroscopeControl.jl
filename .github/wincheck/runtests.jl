# Windows subset runner for the PR 94 check (admiral, 2026-11-03): the four test files that exercise
# save_h5's cleanup and path anchoring, the CSC timeouts, the stage exports and the DCAM read-backs,
# with the fakes they need, in the same order as test/runtests.jl. Copied over test/runtests.jl of the
# checked-out target commit by .github/workflows/WindowsCheck.yml; the target's src and test files are
# used unchanged.
using MicroscopeControl
using Test

const HDF5 = MicroscopeControl.HDF5

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
