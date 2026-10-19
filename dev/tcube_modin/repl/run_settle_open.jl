Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
@eval Main.TM SETTLE_CFG = [(:open, 80.0, 81.0, 5.0)]
Main.TM.RUN_NAME[] = "settle"
include(joinpath(@__DIR__, "tcube_run.jl"))
