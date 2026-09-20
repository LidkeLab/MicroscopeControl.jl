---
name: mc-driver-issue
description: What to do when a MicroscopeControl.jl driver misbehaves on hardware -- rule out rig causes, report upstream with a reproducible template against the pinned tag, and work around locally without type piracy; activates for "driver bug", "SDK", "ccall", "report", or "not working on hardware".
---

# mc-driver-issue

Driver code lives upstream in `LidkeLab/MicroscopeControl.jl`. A downstream rig
repo composes devices; it does not carry driver fixes. When a driver is wrong the
fix belongs upstream, and the local workaround must be obviously temporary and
must not change the package's own behaviour from outside.

## What bites first: it is usually not the driver

Rule these out before writing a report. All three were reported from Windows rigs
and each looks like a broken `ccall`.

| Observed symptom | Possible causes | How to tell |
|---|---|---|
| `initialize(stage::PIStage)` logs `@error` ("No PI C-867 found ..." or "PI_ConnectUSB failed ...") and returns; `stage.connectionstatus` stays `false`. It does **not** throw. | Controller absent or unpowered; USB enumeration; **or** held by another process (a second Julia session with an initialized stage, PIMikroMove, an open COM port). None of these is established by the error alone. | Check `stage.connectionstatus` after every `initialize`. Close PIMikroMove and every other Julia; check Task Manager for stray `julia.exe`. If it then connects, it was contention, not the driver. |
| `MLSLM` SDK calls do nothing useful | The board is claimed by another process (vendor GUI or a dead Julia), or the SDK never found it. | `MLSLM()` is pure: its `n_boards_found` field is a **default of 0** and is never updated, so it diagnoses nothing. The only board count is what `initializesdk()` prints to stdout from `Create_SDK`. Read that output; if it reports 0 boards with the board powered, close the vendor GUI and every other Julia, then reboot if a dead process still holds it. |
| Serial device times out, returns garbage, or "port busy" | Wrong COM assignment (Windows renumbers COM ports when USB topology changes), or the port is open elsewhere. Applies only to the **Triggerscope** (`Triggerscope4`, default `portname="COM3"`) and, through it, `LCC1620`. | Device Manager: match the port to the device. From Julia, `MicroscopeControl.HardwareImplementations.Triggerscope.LibSerialPort.list_ports()`. One `Triggerscope4` per physical port, shared by its dependents (`mc-wire-device`). |
| A DAQ-backed light (`CrystaLaser`, `VortranLaser`, `DaqTrLight`) `@warn`s at construction ("No NI-DAQ devices found ..." or "Failed to initialize NI-DAQ ..."), then `initialize` succeeds and `setpower`/`light_on` `@warn` "no AO channels" and do nothing, or only some calls work | These devices are **not** serial. They drive NI-DAQ AO/DO channels through an `NIdaq` built in their constructor, which picks `devs[1]` (Crysta, Vortran) or `devs[device_index]` (DaqTrLight, default 2). Discovery runs AO then DO inside one `try`, so it can **partially** succeed: AO channels kept, DO empty. Causes: wrong device index, missing NI-DAQmx runtime, card not enumerated, or a DO-less card. | Inspect `light.channelsAO` and `light.channelsDO` right after construction; `NIDAQcard.showdevices(NIdaq())` from Julia; compare with NI MAX. Fix the index or the runtime, not the driver. |
| `TCubeLaser` does not respond | Kinesis serial number wrong or the device is open in the Kinesis GUI. It is addressed by `serialNo` (Thorlabs Kinesis), plus an `NIdaq` AO channel for modulation. | Match `serialNo` to the Kinesis GUI's device list; close that GUI. |
| A method "does nothing" or throws `not implemented for <Type>` | It is a contract stub, not a defect in a `ccall`. | `which(f, Tuple{typeof(dev)}).sig` names `AbstractInstrument` or the interface type. See `mc-api-map`. Still worth reporting, as a missing method, not a wrong one. |

A defect is what remains after these: a wrong argument type or size in a
`ccall`/`@ccall`, a wrong constant, a return value read from the wrong place, a
released buffer, an off-by-one in a frame index. v0.1.1's `PI_SVO` fix is a model
case: the flags were packed as `UInt8` instead of 32-bit `BOOL`, so axis 2's servo
read garbage and every move was refused.

## Report against the pinned tag

The downstream repo pins a tag (`Pkg.add(url=..., rev="v0.2.0")`). The fix ships as
a new tag, so the report has to say which one you were on, or nobody can reproduce
it or tell you which tag closes it. Get it from the environment, not from memory:

```julia
using MicroscopeControl
pkgversion(MicroscopeControl)      # v"0.2.0"
VERSION                            # Julia
Sys.KERNEL, Sys.MACHINE            # OS
```

Template (fill every line; omit nothing marked required):

```markdown
**Device**: <driver type, e.g. `PIStage`> / <model and controller, e.g. PI C-867 with M-686 stage>
**MicroscopeControl.jl tag**: v0.2.0            (required: `pkgversion(MicroscopeControl)`)
**Julia**: 1.13.0 / **OS**: Windows 11 22H2       (required)
**SDK / DLL**: <name and version, e.g. PI_GCS2_DLL_x64 3.x>

**Call path**: `servo(stage, true, true)` -> `PI.servo` -> `PI_SVO`
**ccall involved** (paste from the driver file and line, e.g. `pi_stage/config_methods.jl:104`):
    @ccall gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, Cint[xtoggle, ytoggle]::Ptr{Cint})::Cint

**Observed**: <exact error text or wrong value; include `stage.last_error` / `cam.last_error` if set>
**Expected**: <per SDK manual, cite section>
**Reproduce**: <minimal sequence from `initialize` to the failure>
**Ruled out**: other process holding the device (Y/N, how), COM assignment (Y/N), fresh Julia session (Y/N)
**Local workaround in use**: <link to your wrapper, or "none">
```

File it:

```bash
gh issue create --repo LidkeLab/MicroscopeControl.jl \
  --title "PIStage: <one-line symptom> (v0.2.0, Windows)" \
  --body-file report.md
```

Keep the title to driver type, symptom, tag and OS. If you have already found the
fix, say so in the body and offer a PR; upstream tags every merge to `main`, so a
merged fix is pinnable the same day.

## Working around it locally

There are two honest workarounds and one that looks honest and is not.

**Fine: re-bind the C call in your own code.** Copy the `ccall` into your package
under your own name, with the corrected signature, and call your function from your
instrument code. Nothing in MicroscopeControl.jl changes.

```julia
# in your rig package; RIG-LOCAL WORKAROUND for MicroscopeControl.jl issue #NN,
# remove when pinned tag >= the fixing release
const PI = MicroscopeControl.HardwareImplementations.PI      # PI.gcs2path is the DLL path constant
function rig_servo_on(stage::PIStage, x::Bool, y::Bool)
    @ccall PI.gcs2path.PI_SVO(stage.id::Cint, "1 2"::Ptr{UInt8}, Cint[x, y]::Ptr{Cint})::Cint
end
```

That is the corrected `PI_SVO` binding as it now stands in
`pi_stage/config_methods.jl` (`stage.id::Cint` is the controller handle); it was
not executed here because it needs the PI DLL. Take the real constant, field and
argument types from the driver file the issue names, and keep the `@ccall` beside
a comment with the issue number and the tag that fixes it.

**Fine: a local fork pinned by rev.** Fork upstream, apply the fix on a branch, and
point the rig's pin at it:

```julia
Pkg.add(url="https://github.com/<you>/MicroscopeControl.jl.git", rev="fix-pi-svo")
```

The `Manifest.toml` then records the fork and the commit, so the deviation is visible
to anyone who reads the environment, and returning to upstream is one `Pkg.add` with
the new tag. Open the upstream PR from the same branch.

**Not fine: defining a method on a MicroscopeControl generic for a MicroscopeControl
type from your package.** This is type piracy:

```julia
# DO NOT DO THIS in a downstream package
function MicroscopeControl.servo(stage::PIStage, x::Bool, y::Bool)
    ...
end
```

You own neither the function nor the type. The method is installed the moment your
package loads, and every caller that dispatches **through the generic
`MicroscopeControl.servo`** gets your behaviour: the package GUI, other downstream
code, `MicroscopeControl.servo(stage, ...)` from the REPL. Callers that bypass the
generic are *not* affected, which is the second trap: PI's own `initialize_original`
calls PI's private `servo` directly, so your override changes what the GUI does and
leaves `initialize` on the old code. The rig is then in a state no single file
describes. The deviation is invisible in `Manifest.toml`; it is visible in a stack
trace or `which(...)` as a method whose file is in your repo, if someone thinks to
look. When the pinned tag moves and upstream ships its own fix, the two methods
either collide (a method-overwrite warning at load, yours wins because it loaded
later) or diverge silently.

Extending a generic on **your own** type (`MC.initialize(::Rig)`, `MC.export_state(::Rig)`)
is the intended pattern and is not piracy; the rule is about types you did not define.

## Making the workaround obviously temporary

- Prefix the function name (`rig_`), put all workarounds in one file
  (`src/workarounds.jl`), and head each with the issue URL and the tag that fixes it.
- Add a test that fails once the fix lands, so the workaround gets removed:

  ```julia
  @test pkgversion(MicroscopeControl) < v"0.2.1"   # drop rig_servo_on when this fails
  ```

- When you move the pin, delete the workaround and rerun `install_skills()` so the
  API map matches the new tag.

## Verifying before you report

Run the suspect call in a fresh session with nothing else attached to the device,
under the pinned tag, and paste the exact output. If the failure needs the GUI,
say so; most `ccall` defects reproduce from the REPL. The Sim devices cannot
reproduce hardware defects, so a report needs the rig; note in the report that the
simulated path (if any) behaves correctly, which localizes the defect to the
`ccall` layer.
