# Generic runner: re-include lib, then run dev/tcube_modin/<RUN>.jl inside TM with a log.
# Called from dev/output/repl/run_<name>.jl, which sets TM.RUN_NAME[].
let T = Main.TM, run = Main.TM.RUN_NAME[]
    T.log_open(run)
    try
        Base.include(T, joinpath(@__DIR__, "..", "..", "tcube_modin", run * ".jl"))
    catch e
        T.say("RUN FAILED: ", sprint(showerror, e)); rethrow()
    finally
        T.log_close()
    end
end
