Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
@eval Main.TM SETTLE_CFG = [(:closed, 800, 900, 300), (:closed, 2000, 2100, 300)]
Main.TM.RUN_NAME[] = "settle"
include(joinpath(@__DIR__, "tcube_run.jl"))
