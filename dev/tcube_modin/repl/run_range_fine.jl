Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
@eval Main.TM RC_I_OVERRIDE = [0.0, 80.0, 100.0, 110.0, 118.0, 120.0, 125.0, 130.0, 140.0, 145.0]
Main.TM.RUN_NAME[] = "range_check"
include(joinpath(@__DIR__, "tcube_run.jl"))
