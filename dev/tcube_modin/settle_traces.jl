# Offline: for each settle trial, external-PD level before the write, just after the MOD step (max over 0-0.5 s),
# and at the end; what the trace does around the USB write itself.
using HDF5, Statistics, Printf
f = ARGS[1]; rate = 2000.0
h5open(f) do h
    lp = read(h, "loop"); base = read(h, "base"); usb = read(h, "usb"); d = read(h, "delay"); da = read(h, "d_actual")
    iw = read(h, "i_write"); im = read(h, "i_mod"); fr = read(h, "frac")
    for (k, b) in enumerate(base)
        name = "trace_$(lp[k] == 1 ? "closed" : "open")_$(b isa Integer || isinteger(b) && lp[k]==1 ? Int(b) : b)_"
        key = first(filter(n -> startswith(n, name) && endswith(n, "_$(count(==(b), base[1:k]))"), keys(h)))
        tr = read(h, key)
        w = round(Int, iw[k]); m = round(Int, im[k])
        pre = mean(tr[max(1, w - 300):w-5])                          # before the USB write
        postw = m > w + 40 ? mean(tr[m-40:m-2]) : NaN                # after the write, before the MOD step
        win = tr[m+1:min(end, m + 1000)]                             # 0.5 s after the MOD step
        peak = maximum(win); fin = mean(tr[end-500:end])
        @printf("%-7s base %6.0f usb %6.0f d %.2f frac %5.2f | pre %.3f afterwrite %.3f maxpost %.3f (+%.0f ms) end %.3f\n",
            lp[k] == 1 ? "closed" : "open", b, usb[k], da[k], fr[k], pre, postw, peak, (argmax(win)) / rate * 1e3, fin)
    end
end
