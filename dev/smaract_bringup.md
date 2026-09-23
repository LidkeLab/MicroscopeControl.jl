# SmarAct MCS2 bring-up

Steps to get the SmarAct stage running from Julia on this rig. Written
2026-09-23 against branch `smaract`.

## What is on this machine

Verified by enumerating USB devices and searching the filesystem:

| | |
|---|---|
| Controller | `MCS2-00025165`, seen as `USB\VID_0403&PID_6014` |
| Link | FTDI USB-serial, driver `FTDIBUS` 2.12.36.20, `ftd2xx.dll` present |
| Channels | 2 |
| SmarAct SDK | **not installed** — `SmarActCTL.dll` is absent |
| Julia | 1.11.6 |

The controller is connected and Windows sees it. The SDK is the only thing
missing.

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

> **Warning — this script moves the stage.** At top level it runs:
>
> | Line | Action |
> |---|---|
> | 261 | `reference_all` — homes every channel |
> | **374** | **`find_xy_travel_range` — drives X and Y into both hard end stops, 70 mm overshoot** |
> | 410 | moves to (100 µm, −50 µm) |
>
> Line 374 will drive anything mounted on the stage into whatever is in its
> path. Before running: clear the stage of optics and samples, **or comment out
> line 374**. The end-stop scan only needs to be done once, to learn the
> physical range.

```bash
julia --project dev/test_smaract_dll.jl
```

Expected output: library version, `Devices found: usb:sn:MCS2-00025165`, serial
number, channel count, and positioner type per channel. That alone confirms
Steps 1–3 worked; it is a reasonable place to stop on the first pass.

## Step 5 — Driver test

`dev/test_smaract_stage.jl:2` hardcodes `C:\Users\nanol\.julia\dev\MicroscopeControl.jl`,
which is the Clemson rig's path and does not exist here. Change it to:

```julia
Pkg.activate(raw"C:\Users\MahsaHabibi\Documents\julia repos\MicroscopeControl.jl")
```

Rather than running the script straight through (its last line opens the GUI),
work in the REPL:

```julia
using MicroscopeControl
stage = MCS2Stage(stagelabel="SmarAct MCS2", n_channels=3, channel_ids=Int32[0,1,2])
initialize(stage)
```

`initialize!` does **not** move the stage. It opens the device, reads the real
channel count, sets closed-loop frequency / hold time / velocity / acceleration,
and reads travel limits.

This rig has 2 channels and the constructor defaults to 3, so expect:

```
┌ Warning: Device has 2 channels; stage configured for 3. Truncating.
```

That is normal, not an error. Channels with no sensor log
`no positioner detected` and are marked N/C.

Then check readback before commanding anything:

```julia
getposition(stage)
move(stage, [10.0, 0.0, 0.0])   # small 10 µm move on X only
getposition(stage)
```

## Step 6 — GUI

```julia
MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)
```

`gui` is ambiguous at the top level because each hardware interface defines its
own, hence the qualified call.

Note that `test_smaract_stage.jl:15-16` sets `range_x`/`range_y` to ±20 mm.
Those are **software limits only** and do not reflect actual hardware travel —
set them to the real range measured in Step 4 before relying on the GUI bounds.

## Notes

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
