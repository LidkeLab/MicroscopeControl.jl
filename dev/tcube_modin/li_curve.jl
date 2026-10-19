# Step 1b: open-loop L-I curve in photocurrent units (monitor PD only).
# Source 1 (software only) so the front potentiometer adds nothing; up and down sweeps.
isdefined(@__MODULE__, :SER) || include("lib.jl")   # standalone, or included into TM

up = vcat(0.0, 10.0:10.0:40.0, 45.0:1.0:85.0, 87.0:2.0:CAP_OPEN_mA)
currents = vcat(up, reverse(up)[2:end])
rows = NamedTuple[]
LI_FITMIN = 50   # PD words: fit only clearly above threshold (this PD gives ~200 words at 90 mA)

with_session() do
    ld_openloop(); sleep(0.2)
    decode_status(status_fresh()).closed && error("still closed loop")
    ld_setsrc(1); sleep(0.2)
    ld_enable(); ld_setsp_raw(0)            # the stored setpoint is stale: zero it at once
    sleep(1.0)
    for (i, I) in enumerate(currents)
        ol_set(I)
        s = settled(settle = 1.2, n = 8)
        push!(rows, (i = i, set_mA = I, sp_word = s.sp, pd_word = s.pd, pd_sd = s.pd_sd, cur_mA = s.cur, cur_sd = s.cur_sd,
                     status = Int(s.status), limit = s.limit, tia_over = s.tia_over, tia_under = s.tia_under))
        say(@sprintf("%3d  set %6.1f mA  read %7.2f mA  PD %8.1f (sd %5.1f)  st 0x%04x%s%s%s\n", i, I, s.cur, s.pd, s.pd_sd, s.status,
                s.limit ? " LIMIT" : "", s.tia_over ? " OVER" : "", s.tia_under ? " under" : ""))
    end
end

d = columns(rows)
# Fit: straight line through the points clearly above threshold (PD > LI_FITMIN words), up sweep only
n_up = length(up)
x = [r.cur_mA for r in rows[1:n_up] if r.pd_word > LI_FITMIN && !r.tia_over]
y = [r.pd_word for r in rows[1:n_up] if r.pd_word > LI_FITMIN && !r.tia_over]
xm, ym = mean(x), mean(y)
slope = sum((x .- xm) .* (y .- ym)) / sum((x .- xm) .^ 2)
thr = xm - ym / slope
res = y .- (ym .+ slope .* (x .- xm))
r2 = 1 - sum(res .^ 2) / sum((y .- ym) .^ 2)
say(@sprintf("
fit (up sweep, PD>%d): slope %.3f words/mA, threshold %.2f mA, R2 %.5f, max |resid| %.1f words", LI_FITMIN, slope, thr, r2, maximum(abs.(res))))
xd = [r.cur_mA for r in rows[n_up+1:end] if r.pd_word > LI_FITMIN]; yd = [r.pd_word for r in rows[n_up+1:end] if r.pd_word > LI_FITMIN]
sd_ = sum((xd .- mean(xd)) .* (yd .- mean(yd))) / sum((xd .- mean(xd)) .^ 2)
say(@sprintf("fit (down sweep):          slope %.2f words/mA, threshold %.2f mA\n", sd_, mean(xd) - mean(yd) / sd_))
h5save("li_curve", d; attrs = Dict{String,Any}("slope_words_per_mA" => slope, "threshold_mA" => thr, "r2" => r2,
    "slope_down" => sd_, "threshold_down_mA" => mean(xd) - mean(yd) / sd_, "control_source_during" => 1,
    "note" => "open loop, source 1, settle 1.2 s, 8 samples; PD word signed, scale = reported TIA range"))
