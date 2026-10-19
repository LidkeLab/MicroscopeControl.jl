const SPEED_RATE = 10_000.0   # speed.jl acquisition rate
function edges(tr)
    lo = quantile(tr, 0.05); hi = quantile(tr, 0.95); mid = (lo + hi) / 2
    up = [i for i in 2:length(tr) if tr[i-1] < mid <= tr[i]]; dn = [i for i in 2:length(tr) if tr[i-1] >= mid > tr[i]]
    (lo, hi, up, dn)
end
function crossing(tr, i0, lev, dir)  # first index from i0 back/forward where it crosses lev, linear interp
    i = i0
    if dir > 0
        while i > 2 && tr[i-1] >= lev; i -= 1; end      # walk back to where it was below
        while i < length(tr) && tr[i] < lev; i += 1; end
    else
        while i > 2 && tr[i-1] <= lev; i -= 1; end
        while i < length(tr) && tr[i] > lev; i += 1; end
    end
    i <= 1 && return NaN
    (i - 1) + (lev - tr[i-1]) / (tr[i] - tr[i-1])
end
function step_metrics(tr, e, dir)
    pre = mean(tr[max(1, e - 150):max(1, e - 50)]); post = mean(tr[min(end, e + 200):min(end, e + 400)])
    Δ = post - pre
    t10 = crossing(tr, e, pre + 0.1Δ, dir); t90 = crossing(tr, e, pre + 0.9Δ, dir)
    pk = dir > 0 ? maximum(tr[e:min(end, e + 200)]) : minimum(tr[e:min(end, e + 200)])
    # time to settle within 2 % of the step
    k = findlast(i -> abs(tr[i] - post) > 0.02 * abs(Δ), e:min(length(tr), e + 400))
    (pre = pre, post = post, rise_ms = (t90 - t10) / SPEED_RATE * 1e3, over = (pk - post) / Δ, settle_ms = k === nothing ? 0.0 : k / SPEED_RATE * 1e3)
end
