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

## Where a laser's numbers live

This driver ships **no** laser's numbers: no serial, no W/A factor, no threshold, no
ceiling, no analogue output. Each is a property of one diode, one controller and one rig's
wiring, so it belongs in the rig's own code, next to the line that constructs the laser,
with the record of how it was measured (the table of step 5, the date, who measured it).
The driver takes everything as constructor keywords and refuses to guess what it was not
given (`max_current`, and in closed loop `wa_calibration`, `tia_range`, `tec_stabilised`
and `properties`). The same code drives any number of TCube lasers, each with its own
serial, mode, calibration and (optional) modulation output.

Constructing a laser once it is calibrated (the numbers are placeholders):

```julia
using MicroscopeControl

laser = TCubeLaser("<serial>";
    mode              = ConstantPhotocurrent(),
    wa_calibration    = 200.0,     # W/A, step 3
    tia_range         = 1e-3,      # A, the rear-panel DIP switch (step 1)
    tec_stabilised    = missing,   # true / false once known; `missing` is honest until then
    threshold_current = 60.0,      # mA, step 2
    # ref_current_mA = 80.0, ref_photocurrent_A = <measured>,  # step 3b; without it light_on warns
    max_current       = 120.0,     # mA, your diode's rating: programmed into the controller as the loop's clamp
    properties        = LightSourceProperties("mW", 0.0, false, 0.0, 50.0))  # [0, 50] mW: max_power at or below your diode's rating

initialize(laser)            # checks key, interlock and the DIP switch; programs the clamp; never emits
setoutputpower!(laser, 20.0) # mW at the laser output
light_on(laser)
loop_status(laser)           # photocurrent, drive current, saturated / TIA flags
```

## Controller facts (TLD001)

Seen on a TLD001 in 2026-09-28/29 (kept from a session diary cut from this file); they
are the controller model's behaviour, not one rig's numbers. Facts the driver's docstrings
already state are marked with where.

- A plain `LD_SetMaxCurrentDigPot` is ignored: adjust mode (`LD_EnableMaxCurrentAdjust`) and a pause before leaving it are needed, 2026-09-28 (driver: `set_digpot!`, `CLAMP_WAIT_S`).
- The header's potentiometer scale (`position * 220 / 255` mA) is wrong for this unit: position 204 gave 160.74 mA and 194 gave 152.43 mA, 2026-09-28; the manual gives about 0.7 mA per step (p.28, p.38); position 203 read 159.9 mA, and the limit readback is stable across fresh reads, 2026-09-29. The limit readback is what the driver trusts; `DIGPOT_STEP_ESTIMATE_mA` keeps the header's 220/255 mA, the larger step, only to choose the next position, so moves approach `max_current` from below.
- The potentiometer position does not survive a controller power cycle, 2026-09-29; `initialize` re-programs it every time and power-mode `light_on` re-checks it.
- The controller ignores a setpoint sent while its output is off and then runs on a stale stored setpoint (the diode went to its current limit); the setpoint read-back is stale with the output off (65530), 2026-09-28 (driver: `send_setpoint`).
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
   an old factor over.
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
factor must be measured again afterwards** (record which gain a factor belongs
to). The manuals are Thorlabs 17874-D03 (Kinesis) and 17874-D01 (APT).

A "ceiling" in the photocurrent near 100 µA that the gain does not explain can be
the setpoint-jump lock (see "Controller facts" above), not the photodiode channel.

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
laser = TCubeLaser("<serial>"; mode = ConstantCurrent(), min_current = 0.0, max_current = 120.0)  # max_current: your diode's rating
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
otherwise).

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
switch moves. A reference read on another day than the W/A factor, or after the gain was
re-optimised, is not a reference for that factor.

### 4. Build the laser in closed loop

Construct `TCubeLaser(...; mode = ConstantPhotocurrent(), ...)` with the three
numbers, as in the example above, choosing `properties.min_power` above the
power at threshold and `max_power` at or below the highest power you verified.
`initialize` checks that the controller reports the `tia_range` you stated.

### 5. Verify

In closed loop, command a set of powers across `[min_power, max_power]` with
`setoutputpower!`, and read the power meter at each. Record the table, with the
date, beside the rig code that constructs the laser. Agreement within a few percent means the factor
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
from a fixed reflection) for 20 minutes from a cold start in closed loop.
Set `tec_stabilised` from what you find.

## What the controller's own W/A setting does

`initialize` writes `wa_calibration` to the controller with
`LD_SetWACalibFactor`, so the front-panel display agrees with the driver. That
setting scales the **display** only; the loop regulates photocurrent regardless,
and this driver does its own conversion.

## External modulation (MOD IN from a DAQ)

The fast way to change the power during an acquisition. `setoutputpower!` sends a setpoint
over USB and then waits `lock_check_s` to verify the loop (over a second on the TLD001 tested).
The TLD001 also adds the voltage on its rear SMA **MOD IN** to the software setpoint
(manual section 5.5), and a DAQ analog output can drive it in one write:

```julia
TC = MicroscopeControl.HardwareImplementations.TCubeLaserControl
enable_modulation!(laser; ao_channel = "<device>/ao<n>")  # your wiring; 0 V, then source = software + external
setoutputpower!(laser, 1.0); light_on(laser)   # the slow, verified base setpoint, once
setmodulation!(laser, 20.0)                     # + 20 mW: one DAQ write, ~0.5 ms
setmodulation!(laser, 0.0)                      # back to the base
light_off(laser)                                # writes 0 V first
disable_modulation!(laser)                      # restores the previous control source
```

**What the driver supports, per laser** (each `TCubeLaser` is opened by its own serial and
holds its own mode, calibration, clamp and modulation state; nothing is shared between
lasers except the analogue-output guard below):

| | without MOD IN | with MOD IN |
|---|---|---|
| closed loop (`ConstantPhotocurrent`, mW) | `setoutputpower!` | `setoutputpower!` + `setmodulation!` (verified on hardware) |
| open loop (`ConstantCurrent`, mA) | `setcurrent!` (verified on hardware 2026-10-13) | **refused** by `enable_modulation!` (see below) |

- **The output is the caller's to name.** There is no default: `ao_channel = "<device>/ao<n>"`
  for an NI-DAQmx channel, or `writer`, `v_range` and `output_id` for anything else (below).
  Which output is wired to which controller is the rig's wiring, kept in the rig's code.
- **Open loop + MOD IN is refused.** On a TLD001 tested 2026-10-13 the input scaled as
  expected when it acted (within 1.5 % of the controller's limit / 10 V), but it acted only
  after the control source was set **while the output was on**. Any `setcurrent!` or off/on
  disarmed it again. After re-arming, the first voltage change was sometimes ignored and
  later ones counted from it, leaving the current several mA off what the driver would record.
  A driver cannot promise a current under those rules, so it refuses rather than guess.
- **Several lasers.** Each laser object claims its analogue output (the DAQ channel, or the
  `output_id` passed with a `writer`); a second one asking for an output that is held is
  refused until the first releases it (`disable_modulation!`/`shutdown`), also when both
  objects are for the same serial. Releasing deletes the DAQ task (a writer's own `close=`
  runs), on disable, on shutdown and on a failed enable. A laser that never calls
  `enable_modulation!` never touches a DAQ.
- **One setpoint change at a time.** The slow calls (`setoutputpower!`, `setcurrent!`,
  `light_on`, `light_off`, `shutdown`, `initialize`, enable/disable) hold a per-laser lock
  and wait for each other. `setmodulation!` does not wait: while any of them runs it refuses
  at once and writes nothing, so a level is never checked against a setpoint that is about
  to change (the race the PR #83 review reproduced: 25 + 5 mW held against a 28 mW ceiling).
  Set the base before a fast run and only modulate during it; when free, `setmodulation!`
  adds well under 0.1 ms to the output's own write.
- **Failures.** `light_on` re-checks the recorded request and request + modulation against
  the current ceiling before the enable. If writing 0 V fails while the restored control
  source still includes the external input, `disable_modulation!` keeps modulation enabled
  (a stale voltage may still add) and a retry finishes. A writer that throws gets 0 V written
  and the level recorded as 0.
- **Any analogue output.** `enable_modulation!(laser; writer = v -> ..., v_range = (lo, hi),
  output_id = "...")` drives MOD IN from anything that can set a voltage (a Triggerscope DAC,
  another card). Mind the range: 10 V is the photodiode's full scale (`tia_range x
  wa_calibration`, often far above the diode's rating); the driver refuses totals above
  `properties.max_power`, and the controller's current clamp is the hardware backstop.
- **Scale.** 0-10 V = 0 to full scale: the photodiode's full-scale power (`tia_range x
  wa_calibration`, so `modulation_scale` mW per volt) in closed loop, the controller's current
  limit in open loop. It adds to the setpoint; a negative voltage subtracts. The driver refuses
  a setpoint + modulation above `properties.max_power` (or the current ceiling) or below 0,
  and a voltage outside the output's range. Measured on a TLD001 in closed loop: within 0.4 %
  of `modulation_scale`.
- **Control source.** The input is ignored unless the controller's control source includes
  the external flag (2); a cube can come up with 5 (software + front potentiometer) and ignore
  it. `enable_modulation!` sets 3 (software + external; the potentiometer's own offset left
  out), not persisted, and `disable_modulation!`/`shutdown` restore what it read. A TLD001
  read back 1 after 2 or 3 although the input worked, so the read-back cannot confirm the flag.
- **What "off" means.** The modulation only adds to a running setpoint, and a 0-5 V output
  cannot subtract, so the low level is the base setpoint plus the output's 0 V offset (a
  fraction of a mW on the NI USB DAQ tested). For a truly dark "off", set the base to **0 mW**
  (`properties.min_power` must allow 0) or use a ±10 V output with a negative voltage. Tested
  on a TLD001 (2026-10-13): a 0 mW base with the output on is dark (diode current ≈ 0 mA, no
  current-limit bit), 15 jumps up from 0 V never locked high, and on a camera at 200 Hz a
  +20 mW pulse from it landed within one 5 ms frame even after 2 s dark (the first ON frames a
  few % above the settled level). A base just below threshold is nearly as dark; above
  threshold the "off" leaks the base power. The controller's own photodiode and current
  READINGS lag the light by a few hundred ms: time the light on a detector, not on them.
- **Speed.** One write (about 0.5 ms on an NI USB DAQ, software-timed). The light takes about 2 ms to settle
  (10-90 %, measured on a camera at 200, 500 and 800 Hz on 2026-10-14, base 0 mW: one transition frame then full
  level at 200 Hz, 1-2 frames at 500-800 Hz; OFF dark at every rate). Earlier, on a camera at
  200 Hz a step landed within one 5 ms frame: one transition frame per edge, the next frame at
  full level, no overshoot (the manual gives 20 kHz full-depth bandwidth).
- **One setpoint register (TLD001, 2026-10-13).** The controller does not keep "software
  setpoint" and "external input" apart: it has ONE setpoint register. A USB setpoint write
  sets that register outright, and a later MOD IN change adds only its DIFFERENCE;
  `LD_GetLaserSetPoint` reads the sum. Measured: on at 10 mW, +5 mW -> register and light 15;
  a USB write of 12 mW with the +5 still applied -> 12 (the modulation absorbed); then 0 V ->
  7 mW, not 12. So `setoutputpower!`, `setcurrent!` and `light_on` send request + modulation
  level whenever modulation is enabled, and `check_lock` checks that total. With that, the same
  sequence reads 15 / 17 / 12 mW on hardware. Driving MOD IN from other code (a raw DAQ task
  the driver does not know about) still breaks this: the next USB write absorbs it.
- **Safety.** Every switch-off path writes 0 V before it disables the output.
