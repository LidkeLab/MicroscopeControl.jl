Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
Main.TM.RUN_NAME[] = "range_check"
include(joinpath(@__DIR__, "tcube_run.jl"))
