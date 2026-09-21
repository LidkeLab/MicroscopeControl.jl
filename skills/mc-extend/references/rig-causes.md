# Rig causes that look like driver defects

Companion to `mc-extend` (MicroscopeControl.jl v0.2.0). Rule these out before reporting or rewriting anything; all rows traced from the driver source, the PI row confirmed on rigs.

## Symptoms and their non-driver causes

Rule these out before writing a report. All three were reported from Windows rigs
and each looks like a broken `ccall`.

| Observed symptom | Possible causes | How to tell |
|---|---|---|
| `initialize(stage::PIStage)` logs `@error` ("No PI C-867 found ..." or "PI_ConnectUSB failed ...") and returns; `stage.connectionstatus` stays `false`. It does **not** throw. | Controller absent or unpowered; USB enumeration; **or** held by another process (a second Julia session with an initialized stage, PIMikroMove, an open COM port). None of these is established by the error alone. | Check `stage.connectionstatus` after every `initialize`. Close PIMikroMove and every other Julia; check Task Manager for stray `julia.exe`. If it then connects, it was contention, not the driver. |
| `MLSLM` SDK calls do nothing useful | The board is claimed by another process (vendor GUI or a dead Julia), or the SDK never found it. | `MLSLM()` is pure: its `n_boards_found` field is a **default of 0** and is never updated, so it diagnoses nothing. The only board count is what `initializesdk()` prints to stdout from `Create_SDK`. Read that output; if it reports 0 boards with the board powered, close the vendor GUI and every other Julia, then reboot if a dead process still holds it. |
| Serial device times out, returns garbage, or "port busy" | Wrong COM assignment (Windows renumbers COM ports when USB topology changes), or the port is open elsewhere. Applies only to the **Triggerscope** (`Triggerscope4`, default `portname="COM3"`) and, through it, `LCC1620`. | Device Manager: match the port to the device. From Julia, `MicroscopeControl.HardwareImplementations.Triggerscope.LibSerialPort.list_ports()`. One `Triggerscope4` per physical port, shared by its dependents (`mc-system-design`). |
| A DAQ-backed light (`CrystaLaser`, `VortranLaser`, `DaqTrLight`) `@warn`s at construction ("No NI-DAQ devices found ..." or "Failed to initialize NI-DAQ ..."), then `initialize` returns normally (Vortran's may `@warn` "insufficient DO channels for initialization") and `setpower`/`light_on` `@warn` about missing channels and do nothing, or only some calls work | These devices are **not** serial. They drive NI-DAQ AO/DO channels through an `NIdaq` built in their constructor, which picks `devs[1]` (Crysta, Vortran) or `devs[device_index]` (DaqTrLight, default 2). Discovery runs AO then DO inside one `try`, so it can **partially** succeed: AO channels kept, DO empty. Causes: wrong device index, missing NI-DAQmx runtime, card not enumerated, or a DO-less card. | Inspect `light.channelsAO` and `light.channelsDO` right after construction; `NIDAQcard.showdevices(NIdaq())` from Julia; compare with NI MAX. Fix the index or the runtime, not the driver. |
| `TCubeLaser` does not respond | Kinesis serial number wrong or the device is open in the Kinesis GUI. It is addressed by `serialNo` (Thorlabs Kinesis), plus an `NIdaq` AO channel for modulation. | Match `serialNo` to the Kinesis GUI's device list; close that GUI. |
| A method "does nothing" or throws `not implemented for <Type>` | It is a contract stub, not a defect in a `ccall`. | `which(f, Tuple{typeof(dev)}).sig` names `AbstractInstrument` or the interface type. See `mc-api-map`. Still worth reporting, as a missing method, not a wrong one. |

A defect is what remains after these: a wrong argument type or size in a
`ccall`/`@ccall`, a wrong constant, a return value read from the wrong place, a
released buffer, an off-by-one in a frame index. v0.1.1's `PI_SVO` fix is a model
case: the flags were packed as `UInt8` instead of 32-bit `BOOL`, so axis 2's servo
read garbage and every move was refused.

## Verifying before you report

Run the suspect call in a fresh session with nothing else attached to the device,
under the pinned tag, and paste the exact output. If the failure needs the GUI,
say so; most `ccall` defects reproduce from the REPL. The Sim devices cannot
reproduce hardware defects, so a report needs the rig; note in the report that the
simulated path (if any) behaves correctly, which localizes the defect to the
`ccall` layer.
