# Calibrating a TCube laser for closed loop (power mode)

A `TCubeLaser{ConstantPhotocurrent}` is commanded in **mW at the laser output**
with `setoutputpower!`. The controller cannot measure optical power: in closed
loop it holds the **monitor photodiode current** constant, and the driver turns
your mW into a photocurrent setpoint through two numbers you must supply:

| Number | Keyword | What it is | Where it comes from |
|---|---|---|---|
| W/A factor | `wa_calibration` | optical power at the laser output per amp of monitor photocurrent | measured with a power meter (this document) |
| Calibration reference | `ref_current_mA`, `ref_photocurrent_A` | an open-loop current and the photocurrent in A read at it, re-checked at the first `light_on` after every `initialize` | measured with the W/A factor (step 3b) |
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
| Calibration reference | none recorded yet (see step 3b) |

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

laser = TCubeLaser("00000000";
    mode              = ConstantPhotocurrent(),
    wa_calibration    = 224.2,     # W/A, this document
    tia_range         = 1e-3,      # A, the rear-panel DIP switch
    tec_stabilised    = missing,   # true / false once known; `missing` is honest until then
    threshold_current = 65.0,      # mA
    # ref_current_mA = 90.0, ref_photocurrent_A = <measured>,  # step 3b; without it light_on warns
    max_current       = 150.0,     # mA, your diode's rating: programmed into the controller as the loop's clamp
    properties        = LightSourceProperties("mW", 0.0, false, 1.0, 70.0))  # [1 mW, 70 mW]: the 70 is max_power, your diode's rating

initialize(laser)            # checks key, interlock and the DIP switch; programs the clamp; never emits
setoutputpower!(laser, 20.0) # mW at the laser output
light_on(laser)
loop_status(laser)           # photocurrent, drive current, saturated / TIA flags
```

## Controller facts (TLD001)

Kept from the session diary cut from this file (2026-09-28/29, the 642 nm
rig's TLD001, serial `64849775`). Facts the driver's docstrings already state
are marked with where.

- A plain `LD_SetMaxCurrentDigPot` is ignored: adjust mode (`LD_EnableMaxCurrentAdjust`) and a pause before leaving it are needed, 2026-09-28 (driver: `set_digpot!`, `CLAMP_WAIT_S`).
- The header's potentiometer scale (`position * 220 / 255` mA) is wrong for this unit: position 204 gave 160.74 mA and 194 gave 152.43 mA, 2026-09-28; the manual gives about 0.7 mA per step (p.28, p.38); position 203 read 159.9 mA, and the limit readback is stable across fresh reads, 2026-09-29. The limit readback is what the driver trusts; `DIGPOT_STEP_ESTIMATE_mA` keeps the header's 220/255 mA, the larger step, only to choose the next position, so moves approach `max_current` from below.
- The potentiometer position does not survive a controller power cycle, 2026-09-29; `initialize` re-programs it every time and power-mode `light_on` re-checks it.
- The controller ignores a setpoint sent while its output is off and then runs on a stale stored setpoint (on this rig the diode went to its ~160 mA limit); the setpoint read-back is stale with the output off (65530), 2026-09-28 (driver: `send_setpoint`).
- The photodiode UNDER-range flag was set at 1 mW (4.5 uA on the 1 mA range) while the loop regulated correctly, 2026-09-29; the driver warns and does not refuse.
- The photocurrent reading is signed and `0x8000` means over range (seen at 110 mA open loop on the 1 mA range), 2026-09-28 (driver: `measured_photocurrent`).
- The controller answers one request behind: the first `LD_RequestStatusBits` after an enable returned the pre-enable bits even 0.5 s later; readings behave the same, 2026-09-29 (driver: `request_twice`).
- With no light the photocurrent reads raw 65532, i.e. -4 signed, 2026-09-29.
- A setpoint jumped up from 0 can lock the loop at ~90 mA / ~21 mW / ~98 uA whatever is requested: 3 of 3 at 10 mW, then 4 of 4 without the lock after a Kinesis CONST P session; stepped setpoints never failed (10 of 10), 2026-09-28/29 (driver: `PhotodiodeLoop`'s `ramp_step_mW` field, `check_lock`).
- One USB write takes about 15 ms, so ramp pauses below ~10 ms do not go faster, 2026-09-29.
- The controller must be power-cycled when switching between the Kinesis application and this driver, in either direction (`LD_Open` error 2, or "load device failed" in Kinesis, until then), 2026-09-29. Recorded only here.
- How the Kinesis application reaches a power setpoint was not determined (the C API has only `LD_SetLaserSetPoint`); a USB trace (Wireshark + USBPcap while it sets 10 mW) would show whether a single write can work.


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
be the setpoint-jump lock (see "Controller facts" above), not the photodiode channel.

## When to recalibrate

The numbers belong to **this photodiode, this TIA range and this measurement
plane**. Recalibrate when any of these changes:

- the DIP switch is moved (`initialize` will refuse until `tia_range` matches;
  measure the W/A factor again on the new range rather than assuming it carries over);
- the diode, its mount or the photodiode is replaced or realigned;
- the plane you want to quote power at changes;
- the verification (step 5) drifts by more than you can accept;
- record a new calibration reference whenever the W/A factor is re-measured.

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
# the laser stays on: record the calibration reference (3b) before light_off and shutdown

x = [r.I_pd_A for r in rows]
y = [r.P_mW / 1000 for r in rows]                # W
wa_calibration = sum(x .* y) / sum(x .^ 2)       # least squares through the origin, W/A

# threshold from the same data: power vs drive current, points above threshold
Is = [r.I_mA for r in rows]; Ps = [r.P_mW for r in rows]
slope = sum((Is .- mean(Is)) .* (Ps .- mean(Ps))) / sum((Is .- mean(Is)) .^ 2)
threshold_current = mean(Is) - mean(Ps) / slope
```

Check the residuals: if power against photocurrent is not a straight line, the
range is wrong (step 1) or the photodiode is saturating.

Step 3b belongs to this step and runs now, with the laser still on. Only then switch it
off, with `light_off(laser)` and `shutdown(laser)`.

### 3b. Record the calibration reference

Do this inside step 3, with the laser still on, on the same range and gain as the W/A
factor; the block below ends step 3 with `light_off(laser)` and `shutdown(laser)`. Pick one
current from the sweep at least 20 mA above threshold and at most the power-mode
`max_current`, whose indicated power is at most `max_power` (the constructor refuses
otherwise). On the 642 nm rig that is 90 mA (about 99 uA, about 22 mW at 224.2 W/A).

```julia
TCube = MicroscopeControl.HardwareImplementations.TCubeLaserControl
setcurrent!(laser, 90.0); sleep(1.0)
ref_photocurrent_A = TCube.photocurrent_from_raw(laser, TCube.read_photocurrent_word(laser), 1e-3)  # decode with the tia_range the power-mode config will state
light_off(laser); shutdown(laser)                # the end of step 3: the laser is off
```

Then pass `ref_current_mA = 90.0, ref_photocurrent_A = ref_photocurrent_A` when you build
the power-mode laser (step 4). The first `light_on` after every `initialize` then drives the
diode in open loop at `ref_current_mA`, reads the photodiode, and refuses unless the reading
is within a factor `ref_ratio` (default 1.5) of `ref_photocurrent_A`, in either direction; the
output is off after the check. A range the reading does not follow, or a `tia_range`
relabelled with W/A kept, fails that check. Re-measure W/A and the reference whenever the
switch moves.

`[limitation]` the 642 nm rig's words of 2026-09-29 (375 / 1802 / 6172 at 70 / 80 / 110 mA)
are **not** a reference for its W/A factor. That factor dates from Oct 2024, and the gain was
re-optimised on 2026-09-28 (see above). Record the reference at the next W/A verification.

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
