# Load the MOD IN experiment helpers into module TM (not Main), from the dev/tcube_modin env.
let p = joinpath(@__DIR__, "..", "..", "tcube_modin") |> normpath
    filter!(!=(p), LOAD_PATH); pushfirst!(LOAD_PATH, p)   # first: the workspace project lists DAQmx but is not instantiated
end
isdefined(Main, :TM) || @eval Main module TM end
Base.include(Main.TM, joinpath(@__DIR__, "..", "..", "tcube_modin", "lib.jl"))
# list every TCube LD on USB
let buf = zeros(UInt8, 1024)
    TM.ld_build(); sleep(0.2)
    ccall((:TLI_GetDeviceListExt, TM.DLL), Cshort, (Ptr{UInt8}, Cuint), buf, 1024)
    println("Kinesis devices: ", String(buf[1:findfirst(==(0x00), buf)-1]))
end
