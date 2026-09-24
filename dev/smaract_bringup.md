# SmarAct MCS2 bring-up

Steps to get the SmarAct stage running from Julia on this rig. Written
2026-09-23 against branch `smaract`.

## What is on this machine

Verified by enumerating USB devices and searching the filesystem:

| | |
|---|---|
| Controller | `MCS2-00025165`, seen as `USB\VID_0403&PID_6014` |
| Link | FTDI USB-serial, driver `FTDIBUS` 2.12.36.20, `ftd2xx.dll` present |
| Bus modules | 1 (Stick-Slip-Piezo-Driver, sensor module present) |
| Channels | 3 available; **2 populated** — X = 0, Y = 1, channel 2 empty |
| Positioners | `CT001/AT001` (type 300) on channels 0 and 1 |
| Hand Control Module | present — it can move the stage independently of your code |
| SmarAct SDK | `SmarActCTL.dll` 1.5.16.153011 in `C:\Windows\System32` |
| Julia | 1.11.6 |

Confirmed on 2026-09-23 by running both the smoke test and the driver.

The controller reports **3 channels**, so `MCS2Stage`'s default
`n_channels = 3` matches and the truncation warning below does **not** appear.
Only two of those channels have a positioner attached, so `initialize!` logs:

```
[ Info: Channel 2: no positioner detected — skipping motion setup. (Shown as N/C in GUI.)
```

That is correct, not a fault. Note the two different sensor bits: the smoke
test prints `Sensor Module present: yes` from the **module**-level
`MOD_STATE_BIT_SM_PRESENT`, once for the whole module, while `initialize!`
tests the **per-channel** `CH_STATE_BIT_SENSOR_PRESENT`. The smoke test also
prints `Positioner Type: CT001/AT001` for all three channels, but that is a
*configured* property, not a detection — it says nothing about whether
anything is plugged in. Channel 2 is genuinely empty.

### Travel range — provisional, and NOT from the end-stop scan

The working window lives in **`dev/smaract_rig_config.jl`**, which all three
SmarAct dev scripts include. Currently:

| Axis | Channel | Safe window |
|---|---|---|
| X | 0 | −215.0 … +171.0 µm |
| Y | 1 | −249.0 … +162.0 µm |

Both are well under 0.5 mm — nothing like the ±20 mm that earlier revisions
wrote into the software limits.

**Do not use the end-stop scan to set these.** It was tried, and the stop is
not at a repeatable position:

| | X negative | X positive |
|---|---|---|
| 2026-09-23 scan | −261.2 µm | +186.6 µm |
| 2026-09-24, first stop | −225.8 µm | +181.7 µm |
| 2026-09-24, after repeats | −244.2 µm | +223.1 µm |

Driven into the stop, the stick-slip actuator forces its way further each
attempt — 41 µm of creep on the positive side. Every one of those moves set
`MOVEMENT_FAILED` alongside `END_STOP_REACHED`, meaning the closed loop gave up
rather than arriving anywhere. The scan measures how hard the actuator was
pushed, not where the stage ends.

So the window above is derived defensively: X from the *earliest* stop actually
observed, inset 10 µm; Y from its scan figures corrected by the discrepancy X
showed, then inset 10 µm. **These are provisional.** Replace them with the
vendor travel spec from
`D:\Positioners\OperationParameters\Operation_Parameters_101-110-002740.pdf`
— the reasoning is written out at the top of `smaract_rig_config.jl`.

## Step 1 — Install the SmarAct MCS2 SDK

Run **`D:\MCS2\MCS2_Installer_2.2.15.exe`** ("MCS2 Software", SmarAct GmbH,
v2.2.15). This is the package that ships `SmarActCTL.dll`, and it is the only
installer required.

Do **not** run `D:\Drivers\CDM21228_Setup.exe`. That is FTDI CDM 2.12.28; the
driver already bound to the controller is 2.12.36.20, so it would be a
downgrade. The clean `MCS2-00025165` enumeration confirms the current driver
works.

Optional, not needed by the Julia driver:

| Installer | What it is | Verdict |
|---|---|---|
| `D:\PTC\PTC_Installer_2.1.20.exe` | Precision Tool Commander, SmarAct's own GUI | Worth installing — see below |
| `D:\Drivers\LVRTE2018_f2Patchstd.exe` | LabVIEW Runtime 2018 (350 MB) | Only a prerequisite for PTC; install **before** PTC |
| `D:\MCS2\MCS2_HSDR_Installer_2.1.8.exe` | High-speed data recording add-on | Skip |
| `*_Linux.tgz` | Linux builds | Skip |

PTC is useful as an *independent* check: if PTC can see and jog the stage but
Julia cannot, the problem is in the Julia layer, not the hardware or the SDK.
That distinction saves a lot of time on a first connection.

## Step 2 — Confirm where the DLL landed

```bash
ls "C:/Windows/System32/SmarActCTL.dll"
```

The driver on this branch loads the DLL by **absolute path**, so if the
installer puts it elsewhere (e.g. `C:\SmarAct\MCS2\SDK\bin\`), update both
hardcoded paths rather than copying the DLL around:

- `src/hardware_implementations/smaract_stage/MCS2Stage_module.jl:7`
- `dev/test_smaract_dll.jl:8`

## Step 3 — Julia environment

```bash
cd "C:/Users/MahsaHabibi/Documents/julia repos/MicroscopeControl.jl"
git checkout smaract
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Step 4 — SDK smoke test

`dev/test_smaract_dll.jl` verifies the DLL and enumerates the controller
without loading the package.

> **Warning — this script moves the stage.** At top level it references both
> axes (`reference_all`) and then moves to (100 µm, −50 µm).
>
> The end-stop scan — `find_xy_travel_range`, which drives X and Y into both
> hard stops with 70 mm of overshoot — is now behind `RUN_ENDSTOP_SCAN`,
> default `false`. It has already been run once and its results are recorded
> above and baked into the script as `MEASURED_RANGE_PM`. Set it to `true` only
> to remeasure after a mechanical change, and clear the stage of optics and
> samples first.

```bash
julia --project dev/test_smaract_dll.jl
```

Expected output: library version, `Devices found: usb:sn:MCS2-00025165`, serial
number, channel count, and positioner type per channel. That alone confirms
Steps 1–3 worked; it is a reasonable place to stop on the first pass.

**Drive frequency.** The script used to force `MAX_CL_FREQUENCY` to 18.5 kHz on
every channel, with a comment claiming that is the vendor default. It is not
the default for this rig's positioners: CT001/AT001 report **5 kHz**, so the
override drove them at 3.7× their rated step rate. That is audible as a whine
and is needless wear. Both the script and `initialize!` now read
`SA_CTL_PKEY_DEFAULT_MAX_CL_FREQUENCY` per channel and use that value.

## Step 5 — Driver test

`dev/test_smaract_stage.jl` used to hardcode
`C:\Users\nanol\.julia\dev\MicroscopeControl.jl`, the Clemson rig's path. It now
activates the repo relative to its own location, so it works on any checkout.
It also no longer opens the GUI on its own — that is left to the caller, so the
limits can be checked first.

Run it, or work in the REPL:

```julia
using MicroscopeControl
stage = MCS2Stage(stagelabel="SmarAct MCS2", n_channels=3, channel_ids=Int32[0,1,2])
initialize(stage)
```

`initialize!` does **not** move the stage. It opens the device, reads the real
channel count, sets closed-loop frequency / hold time / velocity / acceleration,
and reads travel limits.

All 3 channels are present here, so the truncation warning does not appear. On a
rig with fewer channels than configured you would see
`Device has N channels; stage configured for 3. Truncating.` — normal, not an
error. Channels with no sensor log `no positioner detected` and are marked N/C.

**Check `stage.is_referenced` before commanding an absolute move.**
`initialize!` never references, and MCS2 referencing is lost on a controller
power cycle. An unreferenced channel reports positions against an arbitrary
zero, so an absolute move made on that assumption can drive straight into an end
stop. `find_reference!` (`helper_smaract.jl`) homes a channel, and now verifies
the `IS_REFERENCED` bit afterwards rather than assuming success.

Then check readback before commanding anything:

```julia
getposition(stage)
move(stage, [10.0, 0.0, 0.0])   # small 10 µm move on X only
getposition(stage)
```

## Step 6 — Motion characterisation

`dev/test_smaract_motion.jl` measures what the stage actually does, rather than
just that it moves:

```bash
julia --project dev/test_smaract_motion.jl            # all three
julia --project dev/test_smaract_motion.jl small      # or name the ones you want
```

| Test | What it measures |
|---|---|
| `long` | Accuracy across the full travel, forward and reverse, plus hysteresis at each point |
| `small` | Minimum incremental motion — achieved/commanded ratio from 50 nm to 5 µm |
| `combined` | A fine step taken immediately after a long traverse, and bidirectional repeatability at one target |

Every target is clamped into the controller's software limits with a 5 µm
standoff, so it cannot command an end stop; it refuses to run against an
unreferenced channel, and it returns the stage to where it started.

`small` is the one that tells you the resolution floor. The ratio column sits
near 1.00 until the commanded step drops below what a stick-slip actuator can
reliably produce, then collapses or scatters. Where that happens sets the
smallest useful step for acquisition.

## Step 7 — GUI

```julia
MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)
```

`gui` is ambiguous at the top level because each hardware interface defines its
own, hence the qualified call.

`test_smaract_stage.jl` used to set `range_x`/`range_y` to ±20 mm — 44× the real
travel, so the GUI offered sliders that could command a move well past an end
stop. They are now set from the measured range with a 5 µm standoff:
X `(-256.2, 181.6)`, Y `(-289.5, 172.3)` µm. These remain **software limits
only**; re-derive them if the range is ever remeasured.

## Notes

**Range limits are volatile, and nothing sets them automatically.** The
controller forgets `RANGE_LIMIT_MIN/MAX` on a power cycle, and `initialize!`
only *reads* them — so whatever the last session left in the controller bounds
every move of the next one, the GUI's included. They also are not validated
against the positioner: ±20 mm on a 0.45 mm stage is accepted in silence. Write
them each session with `M.set_range_limits!(stage, i, lo_pm, hi_pm)`; both
`dev/test_smaract_stage.jl` and `dev/test_smaract_motion.jl` now do this at
startup from the shared window. Never derive a motion range from
`stage.min_pm` / `max_pm` without checking them against the known travel first.

**Only one connection at a time.** The MCS2 permits a single open connection.
A REPL or script that called `initialize` and never called `shutdown` still
holds the device, and the next attempt reports:

```
No SmarAct MCS2 devices found.  Check USB/Ethernet connection.
```

— which reads like a cabling fault but usually is not. Close the other Julia
session, or call `shutdown(stage)` in it, then retry. `dev/test_smaract_motion.jl`
shuts the device down in a `finally`, so an interrupted run does not leak the
handle; a REPL session will unless you close it explicitly.

**Position drift between sessions.** The smoke test left the stage at
(100.000, −50.001) µm; the driver read (99.756, −50.348) µm on the next
connect — about 0.24 µm on X and 0.35 µm on Y. Both scripts call
`SA_CTL_Stop` at the end, which ends the position hold, so the positioner
relaxes once nothing is holding it. This is what `HOLD_TIME_INFINITE` in
`initialize!` is there to prevent *while connected*; it does not survive a
stop or a disconnect. Sub-µm, and expected — not a fault. It does mean a
position read at the start of a session is not the position you left.

**Two drivers exist for this hardware.** This branch uses `smaract_stage`, the
one merged into `main`. A second, independent implementation, `smaract_mcs2`,
is parked unmerged on GitHub at `origin/add-smaract-mcs2-stage`. It defaults to
`dimensions = 2, channels = [0, 1]` — matching this rig without truncation —
targets the SOM-MS-8070 XY stage by name, loads the DLL by name rather than
absolute path, and carries 36 hardware-free tests. It also has explicit
`findreference` / `calibrate` / `moverelative` / `moveaxis` calls and settable
range limits. To try it:

```bash
git checkout -b smaract-mcs2 origin/add-smaract-mcs2-stage
```

The two cannot be loaded at once — both export `MCS2Stage`.

**Pre-existing test failure.** `julia --project -e 'using Pkg; Pkg.test()'`
reports 773 passed, 1 failed, 1 errored, 8 broken. The failure is
`test/skills.jl` "path containment: symlink and traversal refusal", a Windows
symlink-permission issue unrelated to SmarAct. It fails identically on a clean
`main`.

**Positioner documentation** is on the SmarAct media:
`D:\Positioners\OperationParameters\Operation_Parameters_101-110-002740.pdf`
gives the real travel range for these positioners — a safer source than
discovering it by driving into the end stops.
