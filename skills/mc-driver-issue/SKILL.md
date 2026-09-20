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

| Symptom | Actual cause | How to tell |
|---|---|---|
| `initialize` on a PI stage throws "held by another process", or `PI_ConnectUSB` returns a negative id | The controller is held by another process: a second Julia session with an initialized stage, PIMikroMove, or an open COM port. Since v0.1.1 `initialize` fails loudly on this instead of continuing with a bad handle. | Close PIMikroMove and every other Julia REPL; check Task Manager for stray `julia.exe`. If it then works, it was never the driver. |
| `MLSLM()` comes back with `n_boards_found == 0` or `constructed_ok == false` although the board is powered | The Meadowlark board is claimed by another process (the vendor GUI, or a previous Julia session that never released it). | Close the vendor GUI and every other Julia; if a dead process still holds it, a reboot releases the board. |
| Serial device (`Triggerscope4`, `CrystaLaser`, `VortranLaser`) times out, returns garbage, or "port busy" | Wrong COM assignment, or the port is open elsewhere. `Triggerscope4()` defaults to `portname="COM3"`; Windows reassigns COM numbers when USB topology changes. | Device Manager: match the port to the device. From Julia, `MicroscopeControl.HardwareImplementations.Triggerscope.LibSerialPort.list_ports()`. One `Triggerscope4` per physical port, shared by its dependents (see `mc-wire-device`). |
| A method "does nothing" or throws `not implemented for <Type>` | It is a contract stub, not a defect in a `ccall`. | `which(f, Tuple{typeof(dev)}).sig` names `AbstractInstrument` or the interface type. See `mc-api-map`. This is still worth reporting, as a missing method, not a wrong one. |

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

You own neither the function nor the type. The method is installed globally the
moment your package loads, so every caller in the session, including the package's
own GUI, `initialize` and any other downstream code, silently gets your behaviour
with no indication in a stack trace that it left upstream code. It is invisible in
`Manifest.toml`. When the pinned tag moves and upstream ships its own fix, the two
methods either collide (a method overwrite warning at load, yours wins because it
loaded later) or diverge silently. `which(MicroscopeControl.servo, Tuple{PIStage,Bool,Bool})`
pointing at a file in your repo is the diagnostic.

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
