Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
Main.TM.RUN_NAME[] = "modscale"
include(joinpath(@__DIR__, "tcube_run.jl"))
