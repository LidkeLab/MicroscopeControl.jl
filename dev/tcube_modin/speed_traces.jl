# Offline step analysis from the traces themselves: edges found by mid-level crossings, 10-90 % by interpolation,
# overshoot vs the settled level after the edge. Latency is not measurable (host/DAQ clocks not shared).
using HDF5, Statistics, Printf
include(joinpath(@__DIR__, "speed_traces_lib.jl"))
f = ARGS[1]; rate = 10_000.0
h5open(f) do h
    names = sort(filter(n -> occursin(r"_\d+$", n) && !occursin("_sq", n), collect(keys(h))))
    groups = unique([replace(n, r"_\d+$" => "") for n in names])
    @printf("%-28s %4s %16s %8s %8s %8s | %8s %8s %8s\n", "case", "n", "low->high V", "rise ms", "over", "settle", "fall ms", "under", "settle")
    for g in groups
        U = []; D = []
        for n in filter(n -> replace(n, r"_\d+$" => "") == g, names)
            tr = read(h, n); lo, hi, up, dn = edges(tr)
            isempty(up) || push!(U, step_metrics(tr, up[1], 1)); isempty(dn) || push!(D, step_metrics(tr, dn[end], -1))
        end
        md(v, f) = isempty(v) ? NaN : median([f(x) for x in v])
        @printf("%-28s %4d %7.3f->%7.3f %8.2f %+8.2f %8.1f | %8.2f %+8.2f %8.1f\n", g, length(U), md(U, x -> x.pre), md(U, x -> x.post),
            md(U, x -> x.rise_ms), md(U, x -> x.over), md(U, x -> x.settle_ms), md(D, x -> x.rise_ms), md(D, x -> x.over), md(D, x -> x.settle_ms))
    end
end
