Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
Main.TM.RUN_NAME[] = "xpd_cal"
include(joinpath(@__DIR__, "tcube_run.jl"))
