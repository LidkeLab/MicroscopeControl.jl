# Thorlabs LCC1620(/M) liquid crystal attenuator — driver notes

Official user guide (specifications, figures, timing tables, mechanical
drawing): Thorlabs CTN002190-D02,
<https://media.thorlabs.com/globalassets/items/l/lc/lcc/lcc1620_m/ctn002190-d02.pdf>.
Refer to it for anything not covered here; the earlier restatement of the
manual was removed from this repo.

Facts the driver depends on (from the manual):

- The EXT. INPUT (SMC) takes 0–5 V. In ATTENUATOR mode it is summed with the
  front potentiometer, so the pot must be fully clockwise for the external
  voltage to span the full range.
- 0 V is maximum transmission; transmission falls monotonically with voltage
  and is saturated dark by about 3 V, so the useful calibration range is
  0–2.5 V. Transmission is wavelength dependent.
- Switching is step-and-settle: opening takes about 5 ms, closing under
  1 ms, and contrast degrades when modulated above a few tens of Hz.

# This rig & the `LCC1620` driver

## Rig settings

- Mode switch: **ATTENUATOR**. Potentiometer: **fully clockwise** — the EXT
  INPUT is summed with the pot (see the manual, Ch. 5), so anything less silently compresses
  the achievable range. If the range looks wrong, check the pot before
  suspecting the DAQ.
- The **12 V supply must be connected** (auto-powers, no switch) — EXT INPUT
  alone does nothing on an unpowered unit.

## Wiring

The attenuators are driven by a **Triggerscope V4** (16-bit DACs, serial
control), not the NIDAQ card:

```
Triggerscope V4                       LCC1620/M
---------------                       ---------
DAC 1 (SMA) ── coax ───────────────►  LCA 1 EXT. INPUT (SMC)
DAC 2 (SMA) ── coax ───────────────►  LCA 2 EXT. INPUT (SMC)
```

- One DAC channel per attenuator; both `LCC1620` instances **share one
  `Triggerscope4` object** (one serial port) with different `dac_channel`
  values.
- `initialize(att)` sets the channel's DAC range to **ZEROTOFIVE**, so the
  full 16-bit resolution (65536 steps ≈ 76 µV/step) covers the LC's 0–5 V
  input. The 25 kΩ input impedance is an easy load for the DAC.
- The Triggerscope end is SMA; the LCC1620 end is SMC (small-thread coax,
  not SMA) — use an SMA↔SMC cable/adapter.
- The photodiode for calibration sweeps still reads through the **NIDAQ AI**
  (the Triggerscope has no analog inputs — its inputs are TTL triggers).

## Driver implications

- **0 V = maximum transmission, rising voltage = darker** (manual Fig. 7). So
  `shutdown`, which drives to `min_voltage` (0 V), leaves the attenuator
  **fully transmitting**, not blocked. A beam-blocked shutdown would mean
  driving to 5 V instead — a deliberate change, not the default. `shutdown`
  also leaves the shared Triggerscope serial port **open** (the other LCA may
  still be using it) — close the scope separately when done with all
  channels.
- Each `setdrivevoltage` is a serial command round-trip
  (write + response, paced by the scope's `compause`, 0.1 s each by
  default ⇒ ~0.2 s per set). Fine for step-and-settle attenuation; not a
  modulation path — for hardware-timed sequences use the Triggerscope's
  PROG_DAC/ARM sequence mode instead.
- The curve is **saturated dark by ~3 V** (manual Fig. 6/7: the 3 V and 5 V curves
  overlap at ≈0 %). Concentrate `set_calibration!` sweep points in
  **0–2.5 V**; the upper half of the range carries no information. The curve
  is monotonic, so `settransmission`'s LUT-inversion requirement is naturally
  satisfied.
- Transmission is wavelength dependent — calibrate at the working wavelength.
- **Step-and-settle, not modulation**: total open ≈ 5.5 ms vs close ≈ 0.4 ms
  at 25 °C (manual timing table), and contrast degrades above ~40–60 Hz (manual Fig. 8).
  Allow **≥ 5–10 ms** after a voltage step before trusting a photodiode
  reading; the bench `run_test!` script's 0.1 s holds are comfortably safe.
