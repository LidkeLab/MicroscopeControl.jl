# Offline: window means around the MOD step (lost vs applied), external PD.
using HDF5, Statistics, Printf
f = ARGS[1]; rate = 2000.0
ms(a, b, tr, m) = mean(tr[clamp(m + round(Int, a * rate / 1000), 1, end):clamp(m + round(Int, b * rate / 1000), 1, end)])
h5open(f) do h
    lp = read(h, "loop"); base = read(h, "base"); usb = read(h, "usb"); da = read(h, "d_actual"); iw = read(h, "i_write"); im = read(h, "i_mod"); fr = read(h, "frac")
    bstr(b) = isinteger(b) && lp[1] == 1 ? string(Int(b)) : string(b)
    ks = ["trace_$(lp[r] == 1 ? "closed" : "open")_$(bstr(base[r]))_$(count(==(base[r]), base[1:r]))" for r in eachindex(base)]
    println("loop base usb d frac | ext PD mean in windows rel. to the MOD step (ms): [-50,-5] [2,20] [20,100] [100,300] [300,600] [1000,2000] [end]")
    for (k, key) in enumerate(ks)
        tr = read(h, key); m = round(Int, im[k]); w = round(Int, iw[k])
        @printf("%s %5.0f %6.1f %.2f %5.2f | %.3f %.3f %.3f %.3f %.3f %.3f %.3f   (write->step lvl %.3f)\n", lp[k] == 1 ? "C" : "O", base[k], usb[k], da[k], fr[k],
            ms(-50, -5, tr, m), ms(2, 20, tr, m), ms(20, 100, tr, m), ms(100, 300, tr, m), ms(300, 600, tr, m), ms(1000, 2000, tr, m), mean(tr[end-300:end]),
            m - w > 40 ? mean(tr[w+20:m-2]) : NaN)
    end
end
