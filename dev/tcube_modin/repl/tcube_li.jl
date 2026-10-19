# Step 1b on the NEW laser 64865766: open-loop L-I curve, PD only.
Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))   # pick up lib edits
let T = Main.TM
    T.SER[] = "64865766"
    T.log_open("li_curve")
    try
        Base.include(T, joinpath(@__DIR__, "..", "..", "tcube_modin", "li_curve.jl"))
    finally
        T.log_close()
    end
end
