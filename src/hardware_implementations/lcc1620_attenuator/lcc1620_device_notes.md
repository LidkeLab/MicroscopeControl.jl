# Thorlabs LCC1620(/M) Liquid Crystal Shutter — Manual Reference

Complete technical content of the official Thorlabs user guide
(**CTN002190-D02, Rev D, January 8, 2020**), restated chapter by chapter for
this repo, with a rig/driver appendix at the end. Original PDF (graphs and
mechanical drawings in full fidelity):
<https://media.thorlabs.com/globalassets/items/l/lc/lcc/lcc1620_m/ctn002190-d02.pdf>

---

## Ch. 1 — Warning symbols

Standard IEC symbol legend used on the device and in the manual: DC, AC,
DC+AC, earth ground, protective conductor, frame/chassis terminal,
equipotentiality, supply on/off, bi-stable push control in/out positions, and
caution triangles for electric shock, hot surface, general danger, laser
radiation, and spinning blades.

## Ch. 2 — Safety

- **Do not open the housing.** No user-serviceable parts; service only by
  trained personnel.
- Safety statements and technical data apply only when the unit is operated
  correctly.
- FCC Part 15 compliance: may not cause harmful interference and must accept
  any interference received.
- **Laser radiation warning — avoid exposure to the beam.**

## Ch. 3 — Product overview

The LCC1620 is a precision, high-speed shutter intended as a laser switch. It
consists of three parts in one housing: a **liquid crystal (LC) cell**, an
**electronic control unit**, and the mechanical housing.

The LC cell sits between two protective glass plates and **two polarizers
whose transmission axes are crossed**. A line on the front of the housing
marks the shutter's transmission axis; linearly polarized input light must be
aligned to this mark. When powered, the drive voltage controls the LC cell:
at full drive the cell rotates the input polarization by **90°**, aligning it
with the output polarizer so the light passes with little attenuation. At
intermediate drive the rotation is partial, so the device also works as a
**variable attenuator**, not just an on/off shutter. The drive level is set
by the top potentiometer (shutter mode: on/off; attenuator mode: output power
level).

## Ch. 4 — Setup

**4.1 Mounting and alignment.** Input must be linearly polarized and aligned
to the front-face line; a polarizer or wave plate upstream can set this. Two
8-32 (M4 on the /M version) post-mounting holes, typical thread depth 4.5 mm,
are offset by 90° so the housing can be posted with either a vertical or
horizontal polarization axis. Four 4-40 holes on the front make it compatible
with Thorlabs 30 mm cage systems, in either orientation.

**4.2 Power supply.** Operates from **12 VDC**; the supply is included.

**4.3 Powering on.** The unit powers on as soon as the supply is connected —
**there is no power switch**.

**4.4 Beam centering.** For best performance, center the beam in the input
aperture (face is marked "MAX BEAM 20mm").

## Ch. 5 — Operation

- Ensure the beam is linearly polarized, aligned to the front marking, at
  normal incidence, and centered through the LC cell.
- Connect the power supply.
- A top slide switch selects one of two modes:
  - **SHUTTER mode** — the potentiometer simply blocks or transmits the beam.
    Fully counterclockwise = shutter off (**red LED**); turning the knob
    eventually switches it on (**green LED**).
  - **ATTENUATOR mode** — the potentiometer is a variable attenuator:
    clockwise = more transmitted power. The **green LED is always lit** in
    this mode.
- **External control** ("EXT. INPUT" SMC connector, 0–5 V DC signal):
  - In SHUTTER mode the potentiometer must be **fully clockwise** for the
    external signal to control the shutter.
  - In ATTENUATOR mode the external input **adds an offset to the
    potentiometer setting**: pot fully counterclockwise → no effect; the
    effect grows as the pot is turned clockwise and is **full only with the
    pot fully clockwise**.
  - Manual's explicit note: in ATTENUATOR mode with the pot not fully
    clockwise, the external voltage **cannot reach full transmission** — it
    only spans from off up to the attenuation level the pot allows.

## Ch. 6 — Specifications and graphs

| Item | LCC1620(/M) |
|---|---|
| Operating wavelength range | 420 – 700 nm |
| Transmission (avg) | > 60 % |
| Contrast ratio (CR; avg)¹ | > 8000:1 |
| Laser damage threshold — CW | 1 W/cm² (532 nm, Ø0.471 mm) |
| Laser damage threshold — pulsed | 0.4 J/cm² (532 nm, 10 ns, 10 Hz, Ø0.750 mm) |
| Clear aperture | Ø20 mm |
| Surface quality | 40-20 scratch-dig |
| Max incidence angle | ±5° |
| Switching speed (shutter mode, typ.)² | opening 5 ms / closing 1 ms |
| Wavefront distortion | ≤ λ/4 @ 633 nm |
| External input | SMC connector, 0 – 5 V, 25 kΩ input impedance |
| Power adapter | 12 VDC / 1.25 A, with power cord |
| AC power requirements | 110 – 240 VAC, 47 – 63 Hz, 0.4 A |
| Mounting | two 8-32 (M4) post holes · 30 mm cage compatible · Ø1" lens tube compatible |
| Operating temperature | 15 °C to 60 °C |
| Dimensions | 60 mm × 60 mm × 27 mm |

¹ Average CR is specified over the operating wavelength range.
² Shutter mode with a 0–5 V TTL input on the EXT port. Opening time: input
falls to 10 % → transmission rises to 90 % of total. Closing time: input
rises to 90 % → transmission falls to 10 %.

### Figure 5 — Transmission and contrast ratio vs wavelength

Transmission (linear scale) and CR (log scale) from 400–800 nm. Transmission
climbs steeply from ~5 % at 400 nm to ~80 % near 500 nm, then declines gently
to ~65 % at 700 nm and ~52–57 % at 750–800 nm. CR exceeds 10⁴ across roughly
450–650 nm, stays near 10⁴ to ~680 nm, then collapses above 700 nm to about
5:1 at 800 nm.

### Figure 6 — Transmission spectra at fixed external voltages

Curves at 0, 0.5, 1, 1.5, 2, 2.5, 3, and 5 V over 350–800 nm. All curves cut
on near 400 nm. Peak transmission (~450–520 nm): ≈78 % at 0 V, ≈70 % at
0.5 V, ≈53 % at 1 V, ≈33 % at 1.5 V, ≈18 % at 2 V, ≈8 % at 2.5 V, and ≈0 %
at 3 V and 5 V (the two overlap). All curves rise again above ~750 nm where
the polarizers lose contrast.

### Figure 7 — Transmission vs external voltage ("attenuator mode")

Transmission vs 0–5 V attenuation voltage at 500, 550, 600, 650, 700, and
750 nm. Monotonic S-shaped decrease: at 0 V transmission is ≈80 % (500 nm)
down to ≈53 % (750 nm); the steepest slope is around 0.5–1.5 V; all
wavelengths converge below ~5 % by 2.5–3 V and stay essentially flat (0–3 %)
to 5 V. Note: all curves taken with linearly polarized light aligned to the
front-surface transmission axis; CR plots use a log₁₀ scale.

### Figure 8 — Normalized contrast ratio vs frequency

Modulating the shutter degrades contrast with frequency: normalized CR ≈ 1.0
up to ~40 Hz, ~0.8 at 100 Hz, ~0.5 at ~140 Hz, falling to ~0.28 at 200 Hz.

### Figure 9 — Switching-time stability

Over six weeks of monitoring, rise (opening) switching time stays ~5.2–6.0 ms
and fall (closing) time stays ~0.3–0.4 ms — both essentially flat over time.

### Shutter timing specifications (typ., vs temperature)

Points A–F refer to the manual's timing diagram: the external 0→5 V
modulation pulse (10 %/90 % levels) and the shutter's optical response.

| Key | Description | 25 °C | 40 °C | 60 °C |
|---|---|---|---|---|
| A→B | input rising edge @90 % → shutter starts closing (down to 90 %) | 0.065 ms | 0.061 ms | 0.052 ms |
| B→C | falling edge, 90 % → 10 % | 0.346 ms | 0.344 ms | 0.342 ms |
| A→C | input rising edge @90 % → shutter down to 10 % (**total close**) | 0.416 ms | 0.404 ms | 0.392 ms |
| D→E | input falling edge @10 % → shutter starts opening (up to 10 %) | 2.23 ms | 1.89 ms | 1.73 ms |
| E→F | rising edge, 10 % → 90 % | 3.24 ms | 2.71 ms | 2.61 ms |
| D→F | input falling edge @10 % → shutter up to 90 % (**total open**) | 5.47 ms | 4.60 ms | 4.34 ms |

(Voltage applied = shutter **closes**; voltage removed = shutter **opens** —
opening is the slow LC-relaxation direction, ~10× slower than closing, and
both speed up slightly with temperature.)

## Ch. 7 — Mechanical drawing

All shutter models share the same housing; the /M version has M4 tapped holes
instead of 8-32. Key dimensions:

- Housing: 2.36" (60.0 mm) square × 1.06" (27.0 mm) deep; 3.14" (79.7 mm)
  overall height including the knob.
- Clear aperture: Ø0.79" (20.0 mm), centered 1.18" (30.0 mm) from the edges.
- Internal **SM1 (1.035"-40) threads, 0.16" deep**, on both faces.
- Four **4-40 tapped holes** (30 mm cage system) on both front and back faces.
- **8-32 (M4) post-mounting holes** on the bottom and side, 0.53" (13.5 mm)
  from the face, 1.18" (30.0 mm) from the edge — the 90° offset pair.
- Side panel carries the 12 VDC power jack.

## Ch. 8 — Maintenance and troubleshooting

No maintenance required under normal operation; no serviceable parts — do not
open the unit; contact Thorlabs technical support for problems.

| Problem | Solution |
|---|---|
| No output power | Remove the caps. SHUTTER mode: adjust the knob until the LED is green. ATTENUATOR mode: turn the knob clockwise until the LED is green. |
| Output power can't be attenuated | Ensure the device is powered on; switch to ATTENUATOR mode; adjust the knob until the LED is green. |
| Output is unstable | When using EXT INPUT to control the output, ensure the control voltage itself is stable. |

## Ch. 9–11 — Certification, regulatory, contacts

- **CE certified** (EMC 2004/108/EC & LVD 2006/95/EC; EN 61326-1:2013,
  EN 61010-1:2010) — covers LCC1620, LCC1620/M, LCC1621, LCC1621/M.
- **WEEE**: EU end-of-life units can be returned to Thorlabs for disposal at
  no charge; do not discard in general waste.
- Contacts: <https://www.thorlabs.com/contact> (offices worldwide;
  techsupport@thorlabs.com).

---

# Appendix — this rig & the `LCC1620` driver

Everything below is ours, not Thorlabs'.

## Rig settings

- Mode switch: **ATTENUATOR**. Potentiometer: **fully clockwise** — the EXT
  INPUT is summed with the pot (Ch. 5), so anything less silently compresses
  the achievable range. If the range looks wrong, check the pot before
  suspecting the DAQ.
- The **12 V supply must be connected** (auto-powers, no switch) — EXT INPUT
  alone does nothing on an unpowered unit.

## Wiring

```
NI USB-6008 (Dev2)                    LCC1620/M
------------------                    ---------
AO 0  (pin 14) ── signal ──────────►  EXT. INPUT (SMC center)
GND   (pin 13) ── return ──────────►  EXT. INPUT (SMC shell)
```

- One AO channel per attenuator; the second unit goes on AO 1 (pin 15) /
  GND (pin 16). The 25 kΩ input impedance is an easy load for the USB-6008.
- SMC is the small-thread coax connector (not SMA).

## Driver implications

- **0 V = maximum transmission, rising voltage = darker** (Fig. 7). So
  `shutdown`, which drives to `min_voltage` (0 V), leaves the attenuator
  **fully transmitting**, not blocked. A beam-blocked shutdown would mean
  driving to 5 V instead — a deliberate change, not the default.
- The curve is **saturated dark by ~3 V** (Fig. 6/7: the 3 V and 5 V curves
  overlap at ≈0 %). Concentrate `set_calibration!` sweep points in
  **0–2.5 V**; the upper half of the range carries no information. The curve
  is monotonic, so `settransmission`'s LUT-inversion requirement is naturally
  satisfied.
- Transmission is wavelength dependent — calibrate at the working wavelength.
- **Step-and-settle, not modulation**: total open ≈ 5.5 ms vs close ≈ 0.4 ms
  at 25 °C (timing table), and contrast degrades above ~40–60 Hz (Fig. 8).
  Allow **≥ 5–10 ms** after a voltage step before trusting a photodiode
  reading; the bench `run_test!` script's 0.1 s holds are comfortably safe.
