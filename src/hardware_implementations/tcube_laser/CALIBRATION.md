# Calibrating a TCube laser for closed loop (power mode)

A `TCubeLaser{ConstantPhotocurrent}` is commanded in **mW at the laser output**
with `setoutputpower!`. The controller cannot measure optical power: in closed
loop it holds the **monitor photodiode current** constant, and the driver turns
your mW into a photocurrent setpoint through two numbers you must supply:

| Number | Keyword | What it is | Where it comes from |
|---|---|---|---|
| W/A factor | `wa_calibration` | optical power at the laser output per amp of monitor photocurrent | measured with a power meter (this document) |
| TIA range | `tia_range` | full scale of the photodiode amplifier, in A: `10e-6`, `100e-6`, `1e-3` or `10e-3` | the rear-panel DIP switch on the TLD001; `initialize` refuses to start if the controller reports a different one |

The conversion both ways is

    photocurrent_A = power_mW / 1000 / wa_calibration
    setpoint_word  = photocurrent_A / tia_range * 32767        (rounded down)
    power_mW       = reading_word / 32767 * tia_range * wa_calibration * 1000

Two more numbers are declared at construction and come from the same bench
session: `threshold_current` (mA, where the diode starts lasing) and
`properties.min_power` / `max_power` (mW, the range `setoutputpower!` accepts
and the endpoints of `setlevel!` and the panel slider).

## The 642 nm rig's current calibration

| | |
|---|---|
| Controller | Thorlabs TLD001, serial `64849775` |
| TIA range | 1 mA (`tia_range = 1e-3`) |
| W/A factor | **224.2** W/A |
| Measurement plane | power meter **before the fibre** (coupling efficiency drifts, so the meter is never read after it) |
| Measured by | Ali Kazemi Nasaban Shotorban, recorded in `helpers.jl`, Oct 2024 |
| Threshold | ~65 mA |

Verification, in closed loop with those two factors: power commanded through
the formula above versus power measured before the fibre, in mW. Single
readings, no repeats or statistics:

| commanded | measured |
|---:|---:|
| 0.0 | < 0.001 |
| 10.0 | 9.31 |
| 20.0 | 19.11 |
| 30.0 | 29.11 |
| 40.0 | 39.06 |
| 50.0 | 48.97 |
| 60.0 | 59.22 |
| 70.0 | 69.65 |
| 80.0 | 79.50 |

Measured power sits 0.35–1.03 mW below the command at every point: within
1.5 % from 60 mW up, 2–4.5 % at 20–50 mW, and 7 % at 10 mW. The offset is not
modelled by the driver.

Constructing the laser with it:

```julia
using MicroscopeControl

laser = TCubeLaser("64849775";
    mode              = ConstantPhotocurrent(),
    wa_calibration    = 224.2,     # W/A, this document
    tia_range         = 1e-3,      # A, the rear-panel DIP switch
    tec_stabilised    = missing,   # true / false once known; `missing` is honest until then
    threshold_current = 65.0,      # mA
    max_current       = 160.0,     # mA: programmed into the controller as the loop's clamp
    properties        = LightSourceProperties("mW", 0.0, false, 1.0, 70.0))  # [1 mW, 70 mW]

initialize(laser)            # checks key, interlock and the DIP switch; programs the clamp; never emits
setoutputpower!(laser, 20.0) # mW at the laser output
light_on(laser)
loop_status(laser)           # photocurrent, drive current, saturated / TIA flags
```

## Hardware check, 2026-09-28 (642 nm rig, this driver)

Power meter before the fibre, read by Ali Kazemi Nasaban Shotorban; 30 s (open
loop) or 20 s (closed loop) per point.

Open loop (`ConstantCurrent`), setpoint sent after the output is enabled:

| setpoint | front display | measured | photodiode x 224.2 W/A |
|---:|---:|---:|---:|
| 70 mA | 70.0 | 1.687 mW | 2.2 mW |
| 90 mA | 90.0 | 20.67 mW | 21.4 mW |
| 110 mA | 110.0 | 39.42 mW | over range (`0x8000`) |

Threshold about 68 mA, slope about 0.94 mW/mA.

Closed loop (`ConstantPhotocurrent`, 224.2 W/A, 1 mA range):

| requested | measured | photodiode held at | drive current |
|---:|---:|---:|---:|
| 1 mW | 0.561 mW | 4.46 µA (= setpoint) | 68.5 mA |
| 2 mW | 1.554 mW | 8.91 µA (= setpoint) | 69.8 mA |
| 3 mW | 2.543 mW | 13.37 µA (= setpoint) | 70.7 mA |
| 5 mW | 4.517 mW | 22.28 µA (= setpoint) | 72.8 mA |
| 5 mW (first attempt) | 21.43 mW | 98.09 µA (stuck) | 90.8 mA |
| 10 mW | 21.42 mW | 98.09 µA (stuck) | 90.8 mA |

Where the loop regulated, measured = requested - 0.46 mW with a slope of 0.99:
**the 224.2 W/A calibration still holds.** The 5 and 10 mW failures were
diagnosed the next day (below): not the photodiode channel, but a **jump of
the setpoint from 0**, which locks the loop at ~21 mW (~90 mA, photocurrent
pinned near 98 µA) whatever the request. The Kinesis application at 10 mW
gave 9.30 mW / 77.9 mA / 44.56 µA, i.e. exactly the driver's setpoint; the
difference was only how the setpoint is reached.

### 2026-09-29: the ramp, and closed loop verified to 40 mW

Re-checked after the manual's PD range / gain procedure (1 mA range confirmed
"In Range"; 386 µA at the 160 mA limit in Kinesis; gain re-optimised). The
driver now **ramps** upward closed-loop steps ([`RAMP_STEP_mW`] = 3 mW every
[`RAMP_STEP_S`] = 10 ms, i.e. 40 mW in about 0.2 s):

| requested | reached by | measured | drive current |
|---:|---|---:|---:|
| 10 mW | jump from 0 (before the fix) | 21.38 mW | 90.4 mA |
| 10 mW | 1 mW steps, 2 s apart | 9.31 mW | 77 mA |
| 10 mW | 1 mW steps, 50 / 20 / 10 / 5 ms apart | 9.29 / 9.31 / 9.30 / 9.31 mW | 77.7 mA |
| 20 mW | 1 mW steps, 50 ms | 19.04 mW | 88.2 mA |
| 40 mW | 1 mW steps, 50 ms | 38.79 mW | 109.1 mA |
| 40 mW | **3 mW steps, 10 ms (shipped default)** | **38.74 mW** | 109.3 mA |
| 70 mW | 3 mW steps, 10 ms (0.38 s) | 68.59 mW | 141.4 mA |
| 10 mW | jump from 0, later the same night, 4 runs | 9.30 / 9.31 / 9.30 / 9.31 mW | 77.6-78.0 mA |

Open loop the same day: 110 mA -> 39.43 mW, 130 mA -> 57.71 mW.

How the Kinesis application reaches a power setpoint was not determined (the C
API has only `LD_SetLaserSetPoint`; the APT protocol document could not be
fetched and the application was not traced with a USB capture). The ramp's
time is almost all USB round trips, about 15 ms per write, so 5 ms pauses were
no faster than 10 ms; a USB trace of Kinesis (Wireshark + USBPcap while it
sets 10 mW) is the way to find out whether a single write can work.

Two practical notes from the session: the controller must be **power-cycled
when switching between the Kinesis application and this driver**, in either
direction (`LD_Open` error 2, or "load device failed" in Kinesis, until then);
and the max-current potentiometer position does not survive a power cycle
(`initialize` re-programs it every time).

Measured power is requested x 0.97 - ~0.3 mW over 1-70 mW (the loop holds the
photocurrent exactly; the meter reads a little under 224.2 W/A's prediction).
Closed loop is therefore verified over the rig's range, and
`properties.max_power = 70.0` is supported. Note that 70 mW needs ~141 mA,
above the 132 mA the rig had used as its working ceiling; the clamp at
`max_current` (160 mA) is the hard limit.

**The lock is intermittent, and its cause is not known.** The jump from 0 to
10 mW failed 3 times out of 3 on 09-28/29 (before and after the gain
re-optimisation, before and after a power cycle), then, later on 09-29 after a
Kinesis CONST P session at 10 mW with the W/A factor persisted, worked 4 times
out of 4, and then also at 40 mW (controller readings identical to the ramped
run) and 70 mW (68.5 mW measured). Ramped runs have never failed (10 of 10,
10-70 mW). **The jump is the shipped default** (one write, ~10 ms) because it
is the fastest and was reliable when last tested; the ramp is kept in the
driver as a recorded, verified fallback: set `RAMP_STEP_mW[] = 3.0` and
`RAMP_STEP_S[] = 0.01` (40 mW in 0.22 s, 70 mW in 0.38 s). If the lock recurs
the symptom is unmistakable, ~90 mA and ~21 mW whatever the request; switch
the ramp on and report the run.

Found on the same day, and fixed in the driver: the controller ignores a
setpoint sent while its output is off (it then runs on a stale stored setpoint,
which on this rig drove the diode to its ~160 mA limit, 85-88 mW), so the
driver only sends setpoints with the output on.

## The photodiode range (DIP switch) and the TIA gain

The photodiode signal goes through a transimpedance amplifier (TIA) whose range
-- 10 µA, 100 µA, 1 mA or 10 mA full scale -- is selected **only by the
rear-panel DIP switches**; software can read it (status bits `0x10`-`0x80`,
`loop_status(laser).tia_range_A`) but not set it. A separate TIA **gain**
calibration (`LD_FindTIAGain` in the Kinesis API) trims the amplifier on the
selected range.

The procedure, from the TLD001 Kinesis user manual (section "Photodiode Current
(IPD) Range", the front-panel set-up pages, and the software "Photodiode Tab";
read on ManualsLib, manual 1891386, pages 18, 27, 28 and 46, 2026-09-28):

1. **Start on the 10 mA range**: "Initially always set the PD RANGE switches to
   the 10 mA range (all switches must be in the upwards, ON position)."
2. **The laser must be on** -- "otherwise the photocurrent will be zero". Run it
   at the highest current you intend to use, so the range covers your top power.
3. **Step the switches down, one range at a time**, "from a higher range towards
   the lower ranges, i.e. in the 10 mA -> 1 mA -> 100 uA -> 10 uA order", and
   watch the indication:
   - front panel, Photodiode Range parameter (reached with DISPLAY from the Max
     Laser Current parameter): **`Pdr H`** = over range, **`Pdr -`** = range OK,
     **`Pdr L`** = under range;
   - or in the Kinesis software, Settings > **Photodiode** tab, with "Enable
     Photodiode TIA Range Adjustment" ticked: adjust until the green **In Range**
     LED is lit.
   Stop on the most sensitive range that still shows OK.
4. **Then optimise the photodiode (TIA) gain** -- "an automated process performed
   internally by the unit", only after the range is set: front panel, next
   parameter after the range (DISPLAY), press **MODE** (the display shows `Pd oP`
   with a flashing dot, then the photocurrent); or **Optimize Amplifier Gain** on
   the Kinesis Photodiode tab. "Persist Settings to Hardware" saves it. This
   driver does not do either (the API call is `LD_FindTIAGain`).
5. **Re-measure the W/A factor on that range** (steps 3 and 5 of the procedure
   below). A W/A factor belongs to one range and one gain setting; do not carry
   224.2 over.
6. Construct the laser with `tia_range` set to the range you chose;
   `initialize` refuses if the controller reports a different one.

Why the gain step matters here (Kinesis user guide 17874-D03, §3.3.8): in
closed loop the setpoint comes from a DAC, and "to enable the full range of the
DAC to be used, the photodiode current readings must be 'normalized', so that
the full range (i.e. maximum photocurrent) corresponds to the DAC full range.
The 'optimize current gain' button carries out this normalization." And from
the PC tutorial: "The photodiode range adjustment should be performed at maximum
laser drive current." So the reading's full scale is set by the gain
optimisation, done with the diode at its current limit. A reading that clips at
~10 % of full scale (as on 2026-09-28) points to a gain that no longer matches
the range and diode -- for example one optimised on another range or at another
current limit. **Re-optimising the gain changes the counts per mW, so the W/A
factor must be measured again afterwards**; 224.2 belongs to the gain the
controller had in 2024, which the 1-5 mW closed-loop points of 2026-09-28 still
matched. The manuals are on the lab share: `Z:\Computers and Software\isos and
Install Files\ThorLabs\TLD001 Laser Diode Driver\` (17874-d03.pdf = Kinesis,
17874-d01.pdf = APT).

Done on the 642 nm rig on 2026-09-28: the 1 mA range showed "In Range" with
386 µA at the 160 mA limit (10 mA showed 383 µA, i.e. under range), and the
gain was re-optimised and persisted. It did not change the light (110 mA gave
39.43 mW before and after); the ~98 µA "ceiling" seen that day turned out to
be the setpoint-jump lock described above, not the photodiode channel.

## When to recalibrate

The numbers belong to **this photodiode, this TIA range and this measurement
plane**. Recalibrate when any of these changes:

- the DIP switch is moved (`initialize` will refuse until `tia_range` matches;
  measure the W/A factor again on the new range rather than assuming it carries over);
- the diode, its mount or the photodiode is replaced or realigned;
- the plane you want to quote power at changes;
- the verification (step 5) drifts by more than you can accept.

It is also worth re-running step 5 every few months: it takes minutes and tells
you whether the old factor still holds.

## Procedure

**Safety first.** Every step below emits. Follow the rig's laser rules, keep the
beam off the sample (park the SLM or close the shutters), and put the power
meter head **before the fibre coupler**, at the plane you will quote power at.
Let the laser warm up for about 15 minutes at a mid current before measuring:
the photodiode's responsivity changes with temperature.

All of steps 1–3 run in **open loop** (`ConstantCurrent`), where you command
the current and read the photocurrent, so nothing depends on a calibration you
do not have yet.

```julia
using MicroscopeControl
laser = TCubeLaser("64849775"; mode = ConstantCurrent(), min_current = 0.0, max_current = 132.0)
initialize(laser)
```

### 1. Choose the TIA range

The range must put the photocurrent well inside full scale at the highest power
you will use: not over range, and not so low that it is a few counts.

1. Set the DIP switch to the least sensitive range (10 mA) and power-cycle the
   controller if the manual asks for it.
2. Run the laser at the top of its operating range and read
   `s = loop_status(laser)`. Look at `s.tia_range_A`, `s.photocurrent_A`,
   `s.tia_over` and `s.tia_under`.
3. Step to the next more sensitive range (10 mA → 1 mA → 100 µA → 10 µA) until
   the reading is between roughly 30 % and 90 % of full scale with neither flag
   set. Use that range.

```julia
setcurrent!(laser, 130.0); light_on(laser); sleep(1.0)
s = loop_status(laser)
(s.tia_range_A, s.photocurrent_A / s.tia_range_A, s.tia_over, s.tia_under)
light_off(laser)
```

### 2. Measure the threshold current

Sweep the drive current across and above the threshold, read the power meter at
each point, and fit a straight line to the points clearly above threshold. The
threshold is where that line crosses zero power. Choose `min_current` (open
loop) and `min_power` (closed loop) a little **above** threshold: at exactly the
threshold the diode is at the knee and emits almost nothing, and a `min_power`
the diode cannot reach makes the loop drive the current to the clamp.

### 3. Measure the W/A factor

At several currents above threshold, record the power meter and the photocurrent
together. W/A is the slope of power (W) against photocurrent (A); fit it through
the origin, since zero light should give zero photocurrent.

```julia
using Statistics
rows = NamedTuple[]
light_on(laser)
for I in 70.0:10.0:130.0
    setcurrent!(laser, I)
    sleep(1.0)                                   # settle; the readings are polled every 50 ms
    s = loop_status(laser)
    (s.tia_over || s.tia_under) && @warn "TIA flag set at $I mA: change the range (step 1)"
    print("I = $I mA, photocurrent = $(round(s.photocurrent_A * 1e6; digits=2)) µA.  Power meter (mW): ")
    P = parse(Float64, readline())
    push!(rows, (I_mA = I, I_pd_A = s.photocurrent_A, P_mW = P))
end
light_off(laser)

x = [r.I_pd_A for r in rows]
y = [r.P_mW / 1000 for r in rows]                # W
wa_calibration = sum(x .* y) / sum(x .^ 2)       # least squares through the origin, W/A

# threshold from the same data: power vs drive current, points above threshold
Is = [r.I_mA for r in rows]; Ps = [r.P_mW for r in rows]
slope = sum((Is .- mean(Is)) .* (Ps .- mean(Ps))) / sum((Is .- mean(Is)) .^ 2)
threshold_current = mean(Is) - mean(Ps) / slope

shutdown(laser)
```

Check the residuals: if power against photocurrent is not a straight line, the
range is wrong (step 1) or the photodiode is saturating.

### 4. Build the laser in closed loop

Construct `TCubeLaser(...; mode = ConstantPhotocurrent(), ...)` with the three
numbers, as in the example above, choosing `properties.min_power` above the
power at threshold and `max_power` at or below the highest power you verified.
`initialize` checks that the controller reports the `tia_range` you stated.

### 5. Verify

In closed loop, command a set of powers across `[min_power, max_power]` with
`setoutputpower!`, and read the power meter at each. Record the table beside
this document's, with the date. Agreement within a few percent means the factor
holds; a constant offset is expected, a slope error means the factor is wrong.

Watch `loop_status` while you do it: `saturated` means the loop hit the current
clamp (blocked or misaligned photodiode, or a power the diode cannot make), and
a drive current creeping up at a fixed setpoint means the photodiode or the
diode is changing.

### 6. Optional: how much does the light drift?

Closed loop holds the **photocurrent**, not the light. Without a
temperature-stabilised mount the photodiode's responsivity drifts with
temperature, so the delivered power can drift while every number the driver
reports stays flat. To measure how much, log the power meter (or a camera signal
from a fixed reflection) for 20 minutes from a cold start in closed loop. The
rig probe in MicroscopeAdapt, `dev/test_tcube_power.jl` (`:drift_log` and
`:closed_loop_trial` steps), automates this and the clamp and scan checks.
Set `tec_stabilised` from what you find.

## What the controller's own W/A setting does

`initialize` writes `wa_calibration` to the controller with
`LD_SetWACalibFactor`, so the front-panel display agrees with the driver. That
setting scales the **display** only; the loop regulates photocurrent regardless,
and this driver does its own conversion.
