# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows Julia's pre-1.0 versioning convention, described in
the README's Installation section: in `0.x.y`, `x` is the breaking component
and `y` is the non-breaking one (releases are tagged; between them `main` carries
the next version with `-DEV`).

## [0.2.6] - 2026-09-29

A non-breaking release in three parts. None of it has run on hardware yet; the rig
checks are listed in #74 and #75.

- **PI stage (#73).** `PIStage.initialize` checks every status return, bounds its
  wait for motion to stop, and reclaims its own earlier connection. The stage,
  Triggerscope and objective-positioner panels log a failed `initialize` instead of
  throwing.
- **TCube laser safety (#74).** Fixes from the 642 nm rig's controller facts. Fresh
  reads send their request twice, because the TLD001 answers one request behind.
  `check_lock` refuses in both directions. A refusal found while the diode is lit
  zeroes and disables it first. Power mode gains an optional calibration reference,
  which every power-mode rig should record. Several calls take longer (see Changed).
- **DCAM4 capture (#75).** Every frame wait is bounded and armed before the capture
  starts, and every exit cleans up. This fixes the quickbeam rig's full-frame
  `capture` hang. `capture` now refuses while a live view or sequence runs.

### Fixed


- `PIStage`: `shutdown` could close another object's connection. `id` defaulted to `0`, a valid GCS id, and was never reset; it now defaults to `-1` and `shutdown` resets it.
- `PIStage.initialize` reported the stage connected before it was: `connectionstatus` was set before the connect, and a failed close after a failed reference left it `true`, so a retry answered "already initialized". It is now set only after the whole sequence succeeds, and every step after the connect is inside the cleanup.
- `PIStage.initialize` ignored a FALSE from reading the travel range (`PI_qTMN`/`PI_qTMX`) or setting the velocity, and came up connected with an unset range. Each is now checked; a failure closes the connection and throws. A failed range query no longer writes an uninitialized buffer into `range_x`/`range_y`.
- `PIStage.initialize`'s wait for motion to stop after the reference move had no deadline and ignored `PI_IsMoving`'s return, so a failed query could spin forever. It now polls every 0.1 s, throws on a failed query, and gives up after `REFERENCE_TIMEOUT_S`.
- A `PIStage.initialize` retried after a failed close reported the controller held by another process. The stage now closes its own earlier connection first, and does not reconnect if that close fails too.
- The stage, Triggerscope and objective-positioner panels log a failed `initialize` instead of throwing out of the callback, through one helper, and a stage panel reads no position after an `initialize` that did not connect.
- `TCubeLaser`: every fresh read of the controller (the status word, the current limit, the
  potentiometer position, the W/A read-back, `initialize`'s limit read and `tcube_get_current`)
  now sends its request twice before reading. The 642 nm rig's TLD001 answers one request behind
  (2026-09-29), so a single request could let `light_on`'s current-limit gate pass a
  potentiometer raised since the previous read, and the enable then ran above `max_current`
  until the setpoint landed.
- `TCubeLaser` power mode: `check_lock` makes its own readings and status requests and refuses
  in both directions. Besides a photocurrent above `lock_ratio` times the request, it refuses when
  the controller reports its current limit reached (status bit `0x400`) or the photocurrent is
  below the request divided by `lock_ratio`; the output is then zeroed and disabled, as for a
  suspected lock. It used to read the polled cache and test only the high side, so a loop driven
  to the clamp -- by a request the clamp cannot reach, or by a photodiode giving fewer counts per
  mW than at calibration -- went unnoticed.
- `PhotodiodeLoop` refuses a `lock_check_s` below 0.1 s (`LOCK_CHECK_MIN_S`): 0 was accepted and
  disabled the lock check. A construction passing a smaller value now throws.
- `TCubeLaser`: `measured_current` (and so `loop_status`) accepts the raw reading -32768, which
  the Kinesis header defines as -220 mA, instead of throwing.
- `TCubeLaser`: any failure during the calibration-reference re-check (a mismatch, a mode refusal or a
  command error) latches until the next `initialize`, and the diode is not re-lit on every retried `light_on`.
- `TCubeLaser`: a safety check that refuses while the output may be on (the stored-limit
  check, and in power mode also a mode, TIA-range or clamp change, or an over-range photodiode) now zeroes and disables
  the output before it throws, instead of leaving the diode lit in the fault.
- `TCubeLaser` open-loop `initialize` confirms open loop with a fresh status read after
  `LD_SetOpenLoopMode`, and refuses if the controller stays in closed loop.
- `TCubeLaser` power mode: `check_lock` also runs the current-limit test (`0x400`) at a zero request.
- `TCubeLaser` power mode: `setoutputpower!` decides on fresh status and photocurrent reads, and
  `light_on` and `setoutputpower!` refuse a photodiode range that no longer matches `tia_range`.
- `TCubeLaser`: the header's potentiometer floor, 17.25 mA, no longer gates anything. Open-loop
  `initialize` lowers the potentiometer for any `max_current` below the controller's limit, and
  power-mode construction no longer refuses a `max_current` under 17.25 mA; the limit the
  controller reports decides (the 642 nm rig's unit reads 16.74 mA at the lowest position).
- `DCAM4Camera` `capture` could hang, or leave the camera unusable after a missed frame. Its frame wait is now
  bounded by 2 x (exposure + readout) + 1 s, with the readout read from the camera
  (`DCAM_IDPROP_TIMING_READOUTTIME`); the wait is armed before the capture starts; the wait's parameter struct
  carries its size (it was sent as 0); and every exit stops the capture, releases the buffer and closes the wait.
  A timeout or failed wait logs, sets `last_error` and throws a clear error (it threw a MethodError before).
  Reported from the quickbeam rig: full frame at 12.5 ms and at 100 ms, including the first capture in a fresh
  session.
- `DCAM4Camera` `getlastframe`: a timeout or failed wait no longer throws a MethodError. It logs, sets `last_error`
  and returns `nothing`, as the code intended. Its wait is bounded the same way, with the readout time read once per
  `live`, `sequence` or `capture` and cached. A frame that cannot be copied, here or in `capture`, sets `last_error`.
- `DCAM4Camera` `getdata` in SEQUENCE mode polls the capture status against a deadline of
  2 x N x (exposure + readout) + 1 s instead of waiting for the end-of-cycle event. A sequence that has already
  ended cannot be missed, a full-frame sequence of short exposures no longer times out, and an interrupt can land
  while it waits. A frame that cannot be read returns `nothing` with `last_error` set (it threw a MethodError).
  Every exit stops the capture and releases the buffer. A sequence that transferred fewer frames than requested (or
  never ran) returns `nothing` with `last_error` set to `DCAMERR_LOSTFRAME`. In LIVE mode `getdata` returns the
  newest frame at once and leaves the live view running; it used to clear `is_running` while the view ran on.
- `DCAM4Camera` `sequence`: the task that marks the sequence finished gives up at the same deadline and stops a
  capture stuck running, so `is_running` can no longer stay true forever. It acts only while its sequence is
  current, so it never stops or marks finished a newer live view or sequence, and a failed status read is retried
  until the deadline.
- `DCAM4Camera`: clearing a leftover capture handles every state (a capture in the ERROR state was neither stopped
  nor released), and `abort` now does exactly that.

### Changed

- `PIStage.initialize` waits for `PI_IsControllerReady` after the reference move, before polling `PI_qFRF`, as PI's samples do. Not yet run on hardware; needs a rig check on the C-867.
- `TCubeLaser` timings, against 0.2.5, at the default `lock_check_s` (0.2 s) and `REQUEST_WAIT_S`
  (0.1 s; a fresh read now sends its request twice, 0.2 s, where it was 0.1 s):
  - a power-mode `light_on` takes about 0.6 s longer (`require_clamp` two fresh reads, +0.2 s; `check_lock`
    adds its photocurrent and status reads, +0.4 s);
  - a power-mode `setoutputpower!` with the output on takes about 0.8 s longer for a request above zero
    and about 0.6 s for a zero request (`require_clamp` +0.2 s, the fresh photocurrent read +0.2 s,
    `check_lock` +0.4 s, or +0.2 s at zero); with the output off, about 0.2 s longer;
  - an open-loop `light_on` takes about 0.1 s longer (one fresh limit read), and a `setcurrent!` with
    the output off about 0.1 s longer (one fresh status read);
  - `initialize` takes about 0.8 s longer in power mode (eight fresh reads: status 2, potentiometer 2, limit 3,
    W/A 1, for one potentiometer setting; each further setting adds 0.2 s) and about 0.3 s in open loop
    (one limit read, more if the potentiometer is lowered, plus 0.2 s for the open-loop confirm);
  - the first power-mode `light_on` after `initialize` also runs the calibration-reference re-check:
    `REFERENCE_DWELL_S` (0.1 s), three fresh reads (0.6 s) and the setpoint confirm, about 0.7 s plus the confirm.
- `DCAM4Camera` `capture` refuses (throws "Stop the live view or sequence first") while a live view or sequence is
  running (`is_running`), instead of failing at the buffer allocation and returning `nothing`. It never releases a
  buffer another task may be waiting on. A leftover from an earlier call (a failed capture, or a sequence that
  ended and was never read) is stopped and released first.

### Added

- Fake-GCS2 tests for `PIStage` (`test/pi_stage_fake_sdk.jl`, `test/pi_stage.jl`): `initialize`'s ordering and cleanup and `shutdown`'s id handling, the range, velocity and motion-stop checks, the reclaim after a failed close, and the GUI guard, with no hardware.
- A calibration reference for power mode: `ref_current_mA`, `ref_photocurrent_A` and `ref_ratio`
  (default 1.5) on `PhotodiodeLoop`, `TCubeLaser` and `SimDiodeLaser` (which stores them and does
  not check). With a reference, the first power-mode `light_on` after each `initialize` runs the
  diode in open loop at `ref_current_mA` for `REFERENCE_DWELL_S` (0.1 s) before reading the photodiode,
  and refuses unless the photocurrent is within a factor `ref_ratio` of `ref_photocurrent_A`; the
  output is off after the check either way, and a mismatch refuses every later `light_on` until the
  next `initialize`. Without one, that `light_on` warns once that the check is skipped. See `CALIBRATION.md`.
  **Every rig that uses power mode should record one** (`ref_current_mA`, `ref_photocurrent_A`),
  with its next W/A measurement; `CALIBRATION.md` step 3b says how.

## [0.2.5] - 2026-09-29

A non-breaking release. It brings the TCube laser's closed-loop (power) mode and
the `DiodeLaser` interface (#66), the PI N-472 and PI stage fixes (#67, #64), and
the Kinesis boolean binding split (#70). Every 0.2.4 line keeps its meaning,
with one deliberate exception. An open-loop rig whose stored current limit is
above `max_current` is now refused at `light_on`: that includes a `max_current`
below about 17.25 mA, and a limit that could not be lowered (see below). An
open-loop TCube rig also sees new controller calls, listed under Changed, and
none of them has yet run on hardware.

**UPGRADE WARNING, as for 0.2.4.** Before repinning a rig to 0.2.5:
- check every `setpower`/`setcurrent!` value that precedes a `light_on`;
- set `max_current` to the diode's rating;
- set the current limit stored in the controller (with its front-panel encoder
  or by software) at or below that rating;
- run a hardware check of the new sequence.

**Deliberate safety change a rig may notice: `light_on` on an open-loop
`TCubeLaser` now REFUSES while the current limit stored in the controller (set
with its front-panel encoder or by software) is above `max_current`.** It reads
that limit fresh before every enable (Codex C1 and C4, from the post-merge review
of 0.2.4). Between an enable and the setpoint that follows it, the diode runs on
the controller's stored setpoint. The controller ignores setpoints while its
output is off, so software cannot clear that setpoint in advance, and the stored
limit is the only bound on that interval. `initialize` lowers the stored limit to
`max_current` when it can. When it cannot (a `max_current` below about 17.25 mA,
or a failed lowering), it warns, and `light_on` then refuses until the limit is
lowered. Closed loop already refused above its programmed clamp. Also from that
review:
- a failed enable is rolled back like a failed setpoint, with a zero and then
  the disable (C2);
- `properties.is_on` is recorded as true from the moment the enable is sent, so
  a failure during the setpoint never reports a lit diode as off (C3).
Not yet run on hardware.

**Hardware verification.** Closed loop was run on the 642 nm rig on #66's
original head. The review changes on top of it, the open-loop changes and the PI
changes are exercised only against fake controllers.

### Fixed
- **TCube laser: Kinesis boolean arguments are passed as four bytes.** Every
  Kinesis boolean was bound as a one-byte `Bool`. That is right for return
  values, but the headers declare arguments as a four-byte type, so the
  controller could read three bytes of whatever the register held. Arguments
  (`LD_EnableMaxCurrentAdjust`, `LD_EnableTIAGainAdjust`,
  `LD_EnableLastMsgTimer`) are now a zero-extended `Cuint` (`KBOOL_ARG`), and
  returns stay one byte (`KBOOL_RET`); the vendor facts are in
  `manuals/Thorlabs/TLD001/BINDING.md` (see CLAUDE.md, "Instrument
  documentation archive"). In this release `LD_EnableMaxCurrentAdjust` is
  called by the current-limit programming (#66); the other two are not called.
- **Diode laser panel: the output toggle's label follows the driver, not the
  click.** After a `light_on`/`light_off` that failed, the label and the toggle
  showed the requested state while the diode was in the other; both now show
  `properties.is_on`, and the toggle is put back without re-firing a command.
  Not yet run on hardware (#66).
- **PI stage: `initialize` no longer finishes on an unreferenced stage.** It
  ignored the return of the reference move (`PI_FRF`), so when the controller
  rejected it (GCS error 5, e.g. one axis's servo off) the later move to the
  centre was rejected too and the driver believed the stage was centred while
  the controller read about 0. It now checks `PI_FRF`, then polls `PI_qFRF`
  for up to 60 s until both axes report referenced; either failure throws
  with the `PI_GetError` code and closes the connection first, so a retried
  `initialize` starts clean. `referencemove`'s signature and return are
  unchanged. Reported by the MicroscopeAdapt rig; not yet run on hardware
  (#64).

PI N-472 actuator driver (`PI_N472`): initialize, shutdown and stop. The
lifecycle is covered by fake-GCS2 tests that run on every machine
(`test/pi_n472_fake_sdk.jl`). Hardware: not verified in this repository. The
author reports exercising initialize, `stopmotion` with no motion in
progress, shutdown, re-initialize and a refused second object on a C-885
(SN 124014300), with no motion commanded; stop during motion and the
connect-failure branch were not exercised on hardware.

- **A failed connect was silent and poisoned the object.** `connectionstatus`
  was set before `PI_ConnectUSB` was called and its `-1` return never checked,
  so every later GCS call failed quietly, "Stage initialized" was still logged,
  and a retry was refused as "already initialized". The flag is now set only
  after a successful connect; a failure logs the description and
  `PI_GetInitError()` and leaves the object retryable. The intermittent
  initialize seen on the rig is more likely another process holding the
  controller, made sticky by this bug, than anything in the connect string;
  that is not established, so do not treat it as fixed until the rig says so.
- **`shutdown` never cleared `connectionstatus`**, so re-initializing the same
  object in one session was always refused. It now clears the flag.
- **`shutdown` could close another object's connection.** `id` defaulted to
  `0`, a valid GCS ID, and `shutdown` never reset it, so a second `shutdown` on
  a closed object, or a `shutdown` on one never initialized, closed whichever
  controller then held ID 0. `id` now defaults to `-1` and `shutdown` resets it.
- **`stopmotion` could not reach the controller.** It passed `stage.axes`, a
  `Vector{String}`, where the DLL wants one space-separated `Ptr{Cchar}`
  string; the pointer handed over pointed at string references, not
  characters. It now joins the axes like every other call in the driver.
- **The connect string relied on an implementation detail.** `initialize`
  filtered every `0x00` out of the enumeration buffer and passed the bare
  `Vector{UInt8}`. On current Julia that happens to leave a zero just past the
  shrunk vector, so the DLL did see a terminated string, but by accident of
  `filter`'s implementation, and carrying the enumeration's trailing newline
  (and every further description when several controllers are attached). It
  now passes the first description, whitespace-stripped, as a `String`, which
  Julia always NUL-terminates at a `Ptr{Cchar}` boundary. The buffer grew from
  128 to 1024 bytes to match the C-867 driver.

### Changed (PI N-472)

Behaviour a rig pinned to an earlier tag will see from the PI N-472 driver,
each on its own:

- **`initialize(::N472)` now throws when a setup step fails.** After the
  connect, every step (reference mode, `PI_POS`, servos, travel range,
  velocity) is checked; a failure closes the connection, clears
  `connectionstatus` and `id`, and throws with the step and its GCS error
  code. Before, failures were ignored and "Stage initialized" was logged on a
  half-initialized stage. Enumeration and connect failures still log `@error`
  and return, as `initialize(::PIStage)` does. Not a break under this
  package's versioning rule: it changes behaviour only on a path that was
  already broken.
- **Re-initializing after `shutdown` now re-zeroes the frame.** A second
  `initialize` on the same object was refused and did nothing; it now runs the
  full sequence: reference mode off, `PI_POS` redefining the current position
  as `homepos`, servos on. A script that used shutdown-then-initialize as a
  reconnect now resets its coordinates to wherever the actuator sits.
- **With several C-885s attached, `initialize` connects to the first
  enumerated one.** There is no selection by serial number.
- **`N472()` defaults `id` to `-1`**, not `0`.
- **`setvel(::N472)` returns `FALSE` when `PI_VEL` fails.** It used to return
  only the status of the `PI_qVEL` read-back.

### Changed (release process)
- **`main` is the development branch**, carrying the next version with
  `-DEV`; every pull request goes into it. The `0.3rc1` release-candidate
  branch, which never released, is folded into `main` and retired, and CI's
  version check runs on every pull request again. A release branch is cut only
  for a safety backport (CLAUDE.md "Versioning").

### Laser diodes in two regulation modes (#66)

Laser diodes in two regulation modes, and closed loop (photodiode feedback,
"constant power") for the TCube. Implements the design plan
`dev/output/plan-laser-modes.md` (revision 3, on branch `fix/revert-cppbool`).

**Hardware verification: PARTIAL**, on the 642 nm rig's TLD001 (64849775),
2026-09-28, with a power meter before the fibre; the tables are in
`src/hardware_implementations/tcube_laser/CALIBRATION.md`.

- **Open loop: verified.** 70 / 90 / 110 mA gave 70.0 / 90.0 / 110.0 mA on the
  front display and 1.69 / 20.67 / 39.42 mW.
- **Closed loop: verified from 1 to 70 mW** (2026-09-28/29): 1, 2, 3, 5, 10,
  20, 40 and 70 mW gave 0.56, 1.55, 2.54, 4.52, 9.30, 19.04, 38.74 and
  68.59 mW, so the 224.2 W/A calibration holds. One controller behaviour had
  to be guarded against: **a setpoint jumped from 0 locked the loop** at
  ~21 mW / 90 mA whatever the request, 3 of 3 attempts at 10 mW, while the same
  target reached in steps regulated exactly, as the Kinesis application does.
  Later the same night the jump worked at 10 mW (4 of 4), 40 and 70 mW, so
  the lock is intermittent and its cause unknown. The single write is the
  default (fastest, ~10 ms); an optional ramp of upward closed-loop steps is
  kept in the driver as the verified fallback (`ramp_step_mW = 3.0`,
  `ramp_step_s = 0.01`, keywords of `TCubeLaser`: 40 mW in ~0.2 s, 70 mW in ~0.4 s; ramped runs never
  failed, 10 of 10). The photodiode's UNDER-range flag now warns instead of
  refusing (it was set at 1 mW while the loop regulated correctly).
- **Found on the rig and fixed before release**, none of which the fake SDK
  could have shown: the TLD001 **ignores setpoints sent while its output is
  off** (so the driver sends them right after enabling, and zeroes the setpoint
  before disabling); the setpoint read-back only refreshes while polling runs
  (so polling starts first); the photocurrent reading is signed, with `0x8000`
  meaning over range; a plain potentiometer write is ignored (adjust mode and a
  pause are needed); and the header's potentiometer-to-mA scale is wrong for this
  unit (so the clamp is the controller's own reported limit).

Per decision 0035 this is a **non-breaking** change: `mode` defaults to
`ConstantCurrent()`, so every existing construction line and `setpower` call
keeps meaning what it meant in 0.2.4, and closed loop is additive and opt-in
(`mode = ConstantPhotocurrent()`); the default will not change.
Not verified: the meaning of `LD_EnableMaxCurrentAdjust`'s second flag (always
passed `false`); and how the Kinesis application itself brings the loop up
(the C API offers only `LD_SetLaserSetPoint`; the protocol document could not
be fetched and the application was not traced), so whether a single write
could be made to work is unknown. The ramp's ~0.2 s to 40 mW is almost all
USB round trips (~15 ms per write), so the most a single write could save is
that 0.2 s. Also observed: the controller must be power-cycled when switching
between the Kinesis application and this driver, in either direction, or the
next open fails (error code 2 / "load device failed").

### Deprecated
Each of these still works and keeps its 0.2.4 meaning; each is removed at the
next breaking release.
- `setpower(laser, mA)` on a `ConstantCurrent` `DiodeLaser` forwards to
  `setcurrent!` and warns. The mode is fixed at construction, so a forwarded
  call can never change unit. On a `ConstantPhotocurrent` laser it throws.
- `properties.power` on a `TCubeLaser`: the uncalibrated `legacy_power` figure,
  written by an open-loop `setcurrent!` as 0.2.4's `setpower` wrote it, and
  still exported. Read `drive_current` instead.
- The 2-argument `export_state(::TCubeLaser, x)`, which forwards to the 1-argument
  method.

Recommended new forms (the `mode = ConstantCurrent()` line is optional, it is the
default):

```julia
# 0.2.4 line, still works
laser = TCubeLaser("00000000"; max_current = 150.0)   # your diode's rating
setpower(laser, 80.0)                     # mA, deprecated

# open loop, with the unit in the name
laser = TCubeLaser("00000000"; mode = ConstantCurrent(), max_current = 150.0)   # mode optional; max_current: your diode's rating
setcurrent!(laser, 80.0)                  # mA

# closed loop (calibration: src/hardware_implementations/tcube_laser/CALIBRATION.md)
laser = TCubeLaser("00000000"; mode = ConstantPhotocurrent(),
    wa_calibration = 224.2, tia_range = 1e-3, tec_stabilised = missing,
    threshold_current = 65.0,
    max_current = 150.0,                                                  # mA, your diode's rating
    properties = LightSourceProperties("mW", 0.0, false, 1.0, 70.0))     # 70.0 mW: your diode's rating
setoutputpower!(laser, 20.0)              # mW at the laser output

# either mode, when the unit does not matter: a fraction of the declared range
setlevel!(laser, 0.4)
```

### Added
- **`TCubeLaser` closed-loop loop-lock check and per-laser ramp keywords**
  (#66): `ramp_step_mW` (default `Inf`, one write), `ramp_step_s` (`0.01`),
  `lock_check_s` (`0.2`) and `lock_ratio` (`1.5`) are keywords of the
  `ConstantPhotocurrent` `TCubeLaser` constructor and fields of
  `PhotodiodeLoop`; they replace the `RAMP_STEP_mW` and `RAMP_STEP_S` globals,
  which were never released. After a setpoint the driver now compares the
  measured photocurrent with the request and, above `lock_ratio` times it,
  disables the output and throws "loop lock suspected". The ramp starts from
  what the driver knows the controller holds (0 in `light_on`, the previous
  request in `setoutputpower!`), not from the stale `LD_GetLaserSetPoint`.
  The threshold and wait are not yet run on hardware.
- **`DiodeLaser <: LightSource`**, for lasers on a controller that regulates
  something, and the mode types **`ConstantCurrent`** (the loop holds drive
  current) and **`ConstantPhotocurrent`** (the loop holds the monitor photodiode
  current). There is deliberately no `ConstantPower`: the loop does not hold
  optical power, and without a temperature-stabilised mount the delivered power
  drifts while the photocurrent is held. `regulation_mode(laser)` and
  `supported_modes(T)` report the mode. The voltage-modulated lights
  (`CrystaLaser`, `VortranLaser`, `DaqTrLight`) and `SimLight` are unchanged.
- **`TCubeLaser{M}`**: the driver is parametric in its mode, fixed at
  construction. **Closed loop** (`ConstantPhotocurrent`) takes the photodiode
  calibration as required keywords -- `wa_calibration` (W/A at the laser
  output), `tia_range` (the rear-panel DIP switch, A), `tec_stabilised` (`true`,
  `false` or `missing`) -- held in a new **`PhotodiodeLoop`**, and
  `properties.min_power`/`max_power` become the enforced mW bounds. A range the
  amplifier cannot reach, a TIA range the TLD001 does not have, or a ceiling
  below the potentiometer's lowest clamp is refused at construction.
  `max_current` has no default in closed loop: it is the clamp `initialize`
  programs and the only real protection there, so omitting it throws an
  `ArgumentError`. In open loop it still defaults to `160.0`.
- **Closed-loop `initialize`**, a protected sequence: require the key switch and
  interlock; require the controller's TIA range to match `tia_range` (a moved
  DIP switch is a silent factor-of-ten error otherwise); disable the output (the
  setpoint cannot be zeroed with the output off, so `light_on` sends the real one
  right after enabling); leave the max-current potentiometer at the highest
  position whose controller-reported limit is `<= max_current` -- the only real
  protection in closed loop, since a blocked photodiode drives the current
  straight to it; enter closed loop and verify the status bit; write the W/A
  factor to the controller's display and read it back. It never enables the
  output. `light_on` and `setoutputpower!` refuse until the clamp is verified.
- **`setcurrent!(laser, mA)`** (open loop) and **`setoutputpower!(laser, mW)`**
  (closed loop, mW at the laser output -- not at the sample; the driver holds no
  field describing the optics downstream). Both read their setpoint back and
  record the request only after the controller confirmed it.
  `pd.photocurrent_requested` holds the decoded setpoint the loop was actually
  given. `setoutputpower!` refuses when the amplifier is over range, or under
  range with the output on, or when the controller has left closed loop.
- **`setlevel!(laser, frac)`**: unit-free, `frac` in 0..1 of the declared range,
  linear in the regulated quantity; the same call works in both modes, so code
  written against it survives a mode switch. `frac = 0` is the bottom of the
  range, not off.
- **Readbacks**: `measured_current` (mA), `measured_photocurrent` (A),
  `indicated_output_power` (mW, closed loop; a conversion, not a measurement)
  and `loop_status`, one snapshot of the status word, both readings and the
  decoded flags, including `saturated` (at the current clamp) and
  `below_threshold` (`missing` when the threshold is unknown, never a silent
  pass). `initialize` starts Kinesis polling at 50 ms so these are cache reads.
  New field `threshold_current` (mA, declared by the rig).
- **Panels**: `gui(::DiodeLaser)` opens a current panel (slider in mA over the
  enforced range) or a power panel (slider in mW at the laser output, the range
  and the calibration basis shown). Opening issues no command and no read; the
  readout fills on Read or a Poll toggle that starts off. The textbox accepts
  only in-range values and turns red otherwise; an entry issues one command,
  not two; the display changes only after a command succeeded, and a refusal
  is shown in the panel instead of being thrown inside the event handler.
- **`SimDiodeLaser{M}`**, a simulated twin on the same abstract type, with a
  diode, photodiode and loop model, faults (blocked photodiode, responsivity
  drift, TIA flags, key/interlock) and a log of every command and read. It
  takes the same keywords with the same requirements as `TCubeLaser`, minus the
  serial (`mode` default and closed-loop required keywords included), and its
  default `properties` are labelled `"mA"`, so one construction line serves a rig
  and its twin.
- **`CALIBRATION.md`** in the TCube driver folder: how to choose the TIA range,
  measure the threshold and the W/A factor, build the laser in closed loop and
  verify it, and the 642 nm rig's current calibration (224.2 W/A on the 1 mA
  range, measured before the fibre, with its closed-loop verification table).

### Changed (TCube laser)
- **`TCubeLaser.initialize` starts background polling** (`LD_StartPolling`,
  every `POLL_INTERVAL_MS`); `shutdown` and a failed `initialize` stop it
  (`LD_StopPolling`). Not yet run on hardware; needs the 642 nm rig check.
- **`TCubeLaser.initialize` now zeroes and disables the output** in both modes,
  before the mode command, so it never sends a mode command with the diode lit
  and `properties.is_on` is false afterwards. Not yet run on hardware; needs the
  642 nm rig check.
- **Open loop: `initialize` may lower the controller's max-current
  potentiometer** when its limit is above `max_current`, and never raises it, by
  construction (the search's upper bound is the starting position). Not yet run
  on hardware; needs the 642 nm rig check.
- **Open loop: a `max_current` below the potentiometer's floor** (about
  17.25 mA) warns that the ceiling is enforced in software only and leaves the
  potentiometer alone, as in 0.2.4. If lowering the potentiometer fails (adjust
  mode refused, or even the lowest position above `max_current`), `initialize`
  warns the same way, records the limit the controller then reports, and goes
  on: no configuration that initialized in 0.2.4 fails here. Not yet run on
  hardware; needs the 642 nm rig check.
- **`light_on` and `setcurrent!` wait for the controller's setpoint read-back**
  (up to `SETPOINT_CONFIRM_TIMEOUT_S`, 1 s) and throw if it does not confirm;
  `light_on` then zeroes and disables the output. Not yet run on hardware; needs
  the 642 nm rig check.
- **`setcurrent!` with the output off sends nothing** (0.2.4 sent a setpoint the
  controller ignored); `light_on` applies it after the enable. When the driver
  recorded the output off, "off" is a fresh status read (one request/read round
  trip), since the polled word can lag a `light_off`. Not yet run on
  hardware; needs the 642 nm rig check.
- **`gui(laser)` on an open-loop `TCubeLaser` opens the diode-laser current
  panel** (mA). Not yet run on hardware; needs the 642 nm rig check.
- **Power mode re-checks the controller before emitting**: closed-loop
  `light_on` and `setoutputpower!` read the status word and the current limit
  afresh and refuse if the loop bit is gone or the limit is above `max_current`
  or more than half a pot step above the programmed clamp (a controller power
  cycle can restore the pot). The clamp is recorded only after the whole
  closed-loop `initialize` succeeded. Two more
  request/read round trips per call. Not yet run on hardware.
- `setpower(laser, mA)` on a `DiodeLaser`: on a `ConstantCurrent` laser it
  forwards to `setcurrent!` with a deprecation warning; on a
  `ConstantPhotocurrent` laser it throws, naming `setoutputpower!` and
  `setlevel!`, so that an mA call can never become an mW one.
- `export_state(::TCubeLaser)` ADDS the keys `regulation_mode`, `setpoint_unit`,
  `min_current_mA`, `max_current_mA`, `threshold_current_mA`; closed loop adds
  `power_reference`, `min_output_power_mW`, `max_output_power_mW`,
  `wa_calibration_W_per_A`, `tia_range_A`, `tec_stabilised`,
  `max_current_clamp_mA`, `output_power_requested_mW`,
  `photocurrent_requested_A`. The 0.2.4 keys (`min_current`, `max_current`,
  `power_unit`, `power`, `min_power`, `max_power`) are kept, in both modes.
- `LD_GetLaserDiodeCurrentReading` is bound as signed (`Cshort`): a negative
  reading used to decode to about 440 mA. Kinesis booleans are split by role:
  arguments as zero-extended `Cuint` (`KBOOL_ARG`), returns as one byte
  (`KBOOL_RET`), from `fix/revert-cppbool`.
- The contract test and the API-map generator walk the type hierarchy to its
  leaves: `subtypes` is one level deep and would have dropped `TCubeLaser` the
  moment it moved under `DiodeLaser`. **Downstream code calling
  `subtypes(MicroscopeControl.LightSource)` now sees `DiodeLaser` in place of
  `TCubeLaser` and `SimDiodeLaser`.**

### Removed
- The 2-argument interface stub `light_on(::LightSource, ipower::Float64)`,
  which no driver implemented and which only ever threw; the stub is now
  `light_on(::LightSource)`.

### Deferred
- Renaming `properties.is_on` to `is_on_requested` across all lights: deferred
  to a breaking release. It touches every light driver, which the same plan
  otherwise leaves untouched, and is independent of the laser modes.

## [0.2.4] - 2026-09-29

Safety patch for the TCube laser driver. **v0.2.3 and every earlier tag are
affected.**

**UPGRADE WARNING: this release applies `setpower` values that were never
applied before.** On v0.2.3 and earlier, `setpower(l, x); light_on(l)` never
delivered `x`: the diode ran on the controller's stored setpoint. From 0.2.4
it delivers `x`, so a rig whose `setpower` values were never really used (the
usual order, for example MicroscopeSeqSR's 405 nm laser) will run currents it
has never run, checked only against its ceiling, and `max_current` defaults to
160 mA. `light_on` while the output is already on also re-sends
`drive_current`, undoing a lower value set from Kinesis or the front panel.
Before repinning a rig to 0.2.4:
- check every `setpower` value that precedes a `light_on`;
- set `max_current` to the diode's rating;
- set the controller's current-limit potentiometer at or below that rating;
- run a hardware check of the new sequence.

**Hardware verification: NOT DONE in this repository.** The controller
behaviour below was found on the 642 nm rig (recorded in PR #66); the fix is
exercised against a fake controller that models it
(`test/tcube_output_order.jl`), and those tests fail on v0.2.3.

### Fixed
- **`light_on(::TCubeLaser)` ran the diode at the controller's stored
  setpoint, not the requested current.** The Thorlabs TLD001 ignores
  `LD_SetLaserSetPoint` while its output is disabled and, on the next
  `LD_EnableOutput`, runs on whatever setpoint it had stored. `setpower` sent
  the setpoint whenever it was called and `light_on` only enabled the output,
  so the ordinary `setpower(l, x); light_on(l)` ran at the stale value.
  Observed on the 642 nm rig's TLD001 (serial 64849775) on 2026-09-28; on
  2026-09-29 a script in that order drove the diode for about 13 s at the
  controller's ~160 mA limit, above the diode's absolute maximum. Now
  `light_on` re-checks the requested current against the ceiling, enables,
  and sends the setpoint immediately; if that setpoint fails it disables the
  output again and throws. `light_off` and `shutdown` zero the setpoint
  before disabling, so the controller's stored value is 0 and the next enable
  starts dark.
  - **Rigs pinned to v0.2.3 or earlier:** call `light_on` before `setpower`,
    and `setpower(l, 0.0)` before `light_off`, or move to v0.2.4.
  - `[limitation]` Between the enable and the setpoint that follows it (one
    USB round trip) the controller runs on its stored setpoint: 0 after this
    driver's `light_off` or `shutdown`, but anything up to the controller's
    current limit if other software (the Kinesis GUI, a session that died)
    left it there. In that window the current-limit potentiometer is the only
    hardware bound: 160 mA on the 642 nm rig, above that diode's absolute
    maximum.

### Changed
- **`light_on(::TCubeLaser)` sends `drive_current` every time**, including
  when the output is already on (see the upgrade warning).
- **`light_on(::TCubeLaser)` before any `setpower` enables the output at
  setpoint 0 and warns.** It used to run at whatever the controller had
  stored, which is the hazard above.
- **A failed zeroing in `light_off(::TCubeLaser)` logs `@error` instead of
  throwing**, because the output is disabled regardless; a failed disable
  still throws, as before.
- `setpower(::TCubeLaser, ...)` says when the output is off that the current
  will be applied by `light_on`.

### Changed (release process)
- **Lab decision 0033: `main` carries the next version with `-DEV`.**
  `TagOnMerge` skips a `-DEV` version quietly, and CI's version check accepts
  `X.Y.Z-DEV` (rules and their selftest in `.github/scripts/versions.py`).
- **`TagOnMerge` tags only a commit whose tree is identical to that of a
  commit with a passing `lab/tests` record** (decision 0009's amendment), the
  merged commit or its pull request's head; otherwise it fails and says why.
- `test/test_groups.toml` (the whole suite as group Core), `test/lab_summary.jl`
  and an ignored `dev/output/`, so admiral's `record_tests.jl` can record this
  package. `DAQmx`'s `[sources]` entry is committed in the form `Pkg.test()`
  rewrites it to (`rev = "main"`), so a test run leaves the tree clean;
  `[sources]` is read only in the root project, so no dependent sees it.

### Fixed (documentation)
- **Depending on this package needs more than pinning the tag, and the docs did
  not say so.** MicroscopeControl depends on the unregistered `DAQmx.jl` and
  declares it in its own `[sources]`, but `Pkg` honours `[sources]` only in the
  **root** project, never in a dependency's — so a downstream must repeat the
  entry or a clean `Pkg.instantiate` fails with `DAQmx has no known versions`.
  It bites only on a machine that has never resolved `DAQmx`, which is why it
  surfaced first on an instrument PC rather than on a development box.
  Documented in the README's Installation Notes and in `mc-system-design`.
  Registering `DAQmx.jl`, or publishing a lab registry, would remove the
  requirement. The README's install example also still named `v0.1.0`.

## [0.2.3] - 2026-09-23

TCube laser driver: safety, then correctness, then saying what was actually
commanded. Reported independently by two downstream rig repositories.

**Hardware verification: NOT DONE.** There is no Thorlabs TCube laser diode
controller on any build machine, so no change below has been exercised against
one. Every claim here is traced from the source. That is also why the changes
are ordered as they are: a change that can only *reduce* what reaches a laser
diode is worth taking unverified, while a change to what a working rig sees is
not, and the ones in the latter class are called out individually.

**Non-breaking.** Every fix below arrives without a line of calling code
changing. The safety fixes never needed an API change; the four places where
this work did originally break one are deprecations instead, listed under
Deprecated. The maintained consumers of this package are internal rig
repositories that pin exact tags, so what a breaking release actually costs is
a hardware re-verification session rather than a version digit — and those are
worth batching. What is queued for that batch is listed under Deferred at the
end of this entry.

**Behaviour changes a working rig can see.** No calling code has to change for
the API's sake, but these six are observable, and the first is the point of the
release. Numbers 3 and 6 were found by a downstream rig repository after five
adversarial review rounds had missed them, which is worth recording: the
reviews checked what the package promises, and these are about what consumers
had built on top of what it happened to do:

1. `setpower(::TCubeLaser, current)` with a current above the rig's own
   configured ceiling now throws an `ArgumentError` instead of logging one and
   sending the setpoint anyway. A rig relying on that log line was driving more
   current than it had declared safe. This breaks toward less light, which is
   why it is not deferred.
2. `initialize` no longer overwrites `max_current`, so a ceiling the caller
   passed now survives and keeps constraining `setpower`. **`max_current` is
   also a range endpoint and a persisted `export_state` attribute, so this
   changes more than validation, and it can move a mapped request in EITHER
   direction.** Where the controller's limit was higher than the caller's
   ceiling, a percentage mapped across `[min_current, max_current]` now asks
   for less. Where it was *lower*, the mapped request now asks for **more**:
   with `min_current = 60`, `max_current = 220` and a controller limit near
   160 mA, a 40 % request rose from about 100 mA to 124 mA, and high
   percentages can now throw because the mapping endpoint exceeds the enforced
   ceiling. Three quantities that 0.2.2 blurred into one field are now
   distinct: the caller's ceiling (`max_current`), the controller's limit
   (`controller_max_current`) and the enforced ceiling (the smaller of those
   and the DAC full scale). A reader of the exported `"max_current"` attribute
   gets the first of those where it used to get the second.
3. `min_current` defaults to `0.0` rather than `60.0`. As a *validation* bound
   this only widens what is accepted — the old default was a lower bound, so it
   rejected safe small currents while protecting against nothing. **But
   `min_current` is also read as a range endpoint, and there the change is
   silent and severe.** A consumer mapping a percentage linearly across
   `[min_current, max_current]` gets a different current for the same
   percentage: on the 642 nm rig that reported it, 40 % fell from about 94 mA
   to about 53 mA, below the lasing threshold, so the laser went dark at every
   setting under about 41 % **with no error**. Their mapping is
   `current = min_current + (p - 10)/90 * (max_current - min_current)` for
   `p` in 10..100, so the arithmetic is checkable: at 40 %, `[60, 160.9]` gives
   93.6 mA and `[0, 160]` gives 53.3 mA. Almost all of that is this change —
   moving the lower endpoint to 0 accounts for 40.0 mA of the 40.3 mA drop —
   and item 2 contributes the remaining 0.3 mA, because their controller's
   limit (160.9 mA) and the `max_current` default (160.0) happen to be nearly
   equal on this rig. On a rig where those two differ, item 2 dominates
   instead, in whichever direction. Nothing throws, because every
   value in the new range is legal. If you map across this range, pass
   `min_current` explicitly. The default is still `0.0`: a 60 mA floor is
   actively dangerous on a low-power diode — the 405 nm consumer caps its diode
   at 32.25 mA, so the old default put the floor above the ceiling and made the
   whole range empty.
4. The setpoint conversion truncates where it used to round, so a commanded
   current can be up to one code (~0.0067 mA at the default scale) below the
   request rather than up to half a code above it. This is what makes the
   ceiling hold at the wire.
5. `tcube_refresh` now throws. It is an **intentional removal, not a compatible
   deprecation**: a rig on which it worked will stop, and that is deliberate,
   because what it did was open the device and drive a hardcoded 90 mA under a
   name that warned nobody. The exported name is kept so the caller gets an
   explanation naming the replacement instead of a `MethodError`.

6. **Adding the 1-argument `export_state(::TCubeLaser)` can break a downstream
   that defined it first.** Because 0.2.1 shipped only the 2-argument form,
   `export_state(laser)` fell through to the throwing stub, and at least one
   consumer defined the 1-argument method itself to work around that. Julia
   fails precompilation on the method overwrite; whether that stops the package
   loading depends on the environment, since the loader can fall back to source
   in some configurations — in the one that reported it, the package did not
   load. The fix downstream is to guard the shim so it stands aside
   when ours exists. This is the type-piracy hazard `mc-extend` warns about,
   arriving from the other direction: the risk of defining a method on someone
   else's generic for someone else's type is not only that you might shadow
   them, but that they might later define it too.

One further divergence, confined to a field that is already deprecated: if a
caller assigns `max_current` *after* `initialize`, the derived
`properties.power` no longer follows that assignment, because the divisor is
now the controller limit recorded separately. 0.2.2 gave `50.0` where this
gives `25.000572235150496` for a 40 mA request with `max_current = 80.0`.
Reproducing it would mean intercepting writes to the field to reconstruct a
number the driver invents; `drive_current` is exact and has no lifecycle.

### Fixed
- **A wrong camera ROI went through with only a warning, and the argument
  order invites exactly that mistake.** `setroi!(::DCAM4Camera, hpos, hsize,
  vpos, vsize)` takes `(x, WIDTH, y, HEIGHT)`, while `CameraROI`'s field order
  is `(x_start, y_start, width, height)`. Passing a `CameraROI`'s fields
  positionally in their own order therefore swaps `y_start` with `width`, and
  the resulting readback mismatch was four `@warn`s — so the next frame was
  silently not the region asked for. Reported from a rig running an ORCA
  C11440-22CU. A mismatch now **throws**, naming each field that differs and
  what the camera took instead, and `camera.roi` is updated first so it tells
  the truth about the accepted region even on the throwing path. A new
  `setroi!(camera, ::CameraROI)` method takes the struct directly and is the
  preferred call; the four-argument form is kept, and its order documented
  loudly. Also documented: subarray positions are **0-based**, and the ORCA
  wants positions and sizes in multiples of 4.
- **Every digital output write to a line above line 0 was silently a no-op,
  and MC's own Vortran laser could not be switched on.** `setvoltage` on a
  digital task called `DAQmxWriteDigitalScalarU32`, which is **port format**:
  bit `n` is line `n` of the port, even when the task holds a single line. So
  a task on `Dev1/port0/line1` written with `1` set bit 0, which is not in the
  task, and nothing happened — no error, no warning. Only line 0 ever worked.
  Confirmed on hardware by a rig repository (NI-DAQmx 23.5, USB-6008): a TTL
  shutter on `port0/line1` ignored `1` and responded to `2`.
  `VortranLaser.light_on` wrote `8.0`, as though this were a voltage, setting
  bit 3 of the port word. `channelsDO[12]` is an enumeration index rather than
  a line number, so that addressed the intended line only on a rig where the
  twelfth discovered channel happens to be line 3; anywhere else `light_on`
  drove the intended line LOW and the laser did not come on. It now writes
  `1.0`. Not hardware-verified — no Vortran here.
  `setvoltage` now computes the port word from what the task actually holds
  (`do_port_word`): a single line channel shifts the level to that line's bit;
  a port-wide channel passes the word through unchanged, which is what the old
  code was right about; and a task holding several channels is refused,
  because one scalar across several lines is ambiguous. A channel name that is
  neither form — a custom virtual name, or a line range like `.../line0:3` —
  is refused too, rather than assumed to be a port: `channel_names` returns
  VIRTUAL names, which DAQmx lets you assign independently of the physical
  line, so guessing "port" would silently reproduce this very defect on a
  renamed single-line task. A single-line task
  also refuses any value other than `0` or `1`, since such a value is almost
  certainly a caller pre-shifting around this very defect — and shifting it
  again would drive a *different* line.
- **`setpower(::TCubeLaser, current)` sent out-of-range currents to the diode.**
  The range check logged `@error` and then execution continued: the setpoint was
  computed and `LD_SetLaserSetPoint` called anyway. What that cost depended on
  the request. 500 mA on a 160 mA diode never reached the controller — it
  logged, carried on, and died in the conversion with an `InexactError` — but
  200 mA, over the same ceiling and still inside the setpoint DAC's range,
  converted cleanly and was sent. A log line was the only thing separating the
  two. `setpower` now throws an `ArgumentError` naming the request and both
  bounds, before any setpoint is computed.
- **The enforced ceiling now holds at the wire.** The setpoint conversion
  rounded, so the 160 mA ceiling encoded to code 23831 = 160.00305 mA on the
  driver's own scale: the one request sitting exactly on the enforced limit was
  the one to exceed it. The conversion truncates now, and then corrects the
  code *downward* while it still decodes above the request — truncation alone
  was not sufficient, because `current / max_setcurrent * max_setpoint` can
  round a request one ulp below a code boundary up onto the boundary, leaving
  `floor` nothing to cut. 1794 requests below the default 160 mA ceiling did
  exactly that, the first being `prevfloat(9/32767*220) = 0.06042664876247444`,
  which encoded to code 9 and decoded back to 0.060426648762474444. The
  excesses were single ulps rather than overcurrent, but the guarantee was
  false as stated.

  The guarantee now, precisely: **the current the code decodes to, by this
  driver's own arithmetic (`setpoint_current`), never exceeds the current
  requested.** It is a claim about this driver's conversion, not about the
  controller's DAC or the current at the diode — neither of which this repo has
  observed. The cost is an undershoot of under one code (0.0067 mA at the
  default scale).
- **The bottom of the range commands nothing, and now says so.** Because the
  encoding only rounds down, a positive request smaller than one code — below
  `220/32767 ≈ 0.006714` mA at the default scale — encodes to code `0` and the
  diode is commanded off. That is deliberate; rounding such a request up would
  command more current than was asked for. But `properties.power` records the
  **requested** current, not the zero that was commanded, and `export_state`
  writes that requested value into the HDF5 attributes. No field here reports
  what actually reached the wire. This behaviour is unchanged, previously
  implicit, and now stated in `setpower`'s docstring.
- **The conversion parameters are validated before converting.** Four
  configurations passed the range check and then died in `UInt16(...)` with an
  `InexactError`: `max_setcurrent=0.0` (0 mA), `max_setcurrent=NaN` (80 mA),
  `max_setpoint=100000.0` (160 mA), and `min_current=-10.0` admitting −5 mA.
  Each now throws an `ArgumentError` naming the field at fault, still before
  anything is sent.
- **A failed `initialize` no longer leaks the connection.** After a successful
  `LD_Open`, a failure at the mode change or later threw without closing, and a
  controller left open refuses the next `LD_Open` — so the leak blocked the
  retry. The handle is closed on the way out; a failure of that close is logged,
  never raised, so the error the caller sees is the one that stopped
  initialization.
- **`initialize(::TCubeLaser)` destroyed the caller's current ceiling.** It
  overwrote `light.max_current` with the controller's own limit from
  `LD_GetLaserDiodeMaxCurrentLimit` (typically 160-220 mA), so a rig that
  passed `max_current=80.0` for a weak diode had it replaced, and `setpower`'s
  range check — which reads that same field — then validated against the
  controller instead of the diode. The controller's limit now goes to a new
  `controller_max_current` field (`NaN` until `initialize` runs);
  `max_current` stays the caller's, and `setpower` enforces the smallest of
  `max_current`, `controller_max_current` and `max_setcurrent`, ignoring
  whichever is `NaN`. `max_setcurrent` joins the list because a current above
  the setpoint DAC's full scale has no legal setpoint, and the bound that makes
  that true is the controller's **0–32767 protocol range**, not `UInt16`
  storage: 300 mA encodes to 44682 and 400 mA to 59576, both of which fit a
  `UInt16` and neither of which the controller will accept. That is precisely
  why the bound was needed: such a request passed the range check, converted
  cleanly — `UInt16` had room for it — and was *sent*, as an illegal setpoint,
  rather than failing anywhere the caller could see.
- **Every Kinesis return code is now checked.** `initialize`, `light_on`,
  `setpower`, `light_off`, `shutdown` and `tcube_get_current` each assigned the
  status of every call to an `err` local and never read it, so a failed open, a
  failed mode change and a failed setpoint were indistinguishable from success.
  Each now throws naming the operation and the code. `LD_Close` returns `void`
  and has nothing to check; `shutdown` closes the connection even when the
  preceding disable throws, because leaving the handle open would also block
  the reconnection needed to retry.
- **`light_on`/`light_off` recorded the request, not the outcome.** Both set
  `properties.is_on` *before* the call that was supposed to make it true, so a
  failed enable left the field claiming the laser was on. The field is written
  after the call succeeds. (`LightSourceProperties.is_on` is a requested-state
  field across this whole package, not just here; that is a separate interface
  question, not addressed in this release.)
- **`setupIO(::TCubeLaser)` hardcoded the DAQ device and channel.** It indexed
  `devs[2]` and `channelsAO[2]`, raising a bare `BoundsError` on a
  single-device rig. `TCubeLaser` gains `daq_device=` and `ao_channel=`
  keywords; when they are given they are validated against what discovery
  found and used. When they are `nothing` the **default selection is
  deliberately unchanged** — still the second device and the second AO channel
  — so a rig that works today keeps driving the same analogue output; what
  changed is that a failed lookup now names what was found and what to pass.
- `min_current` defaults to `0.0` instead of `60.0` mA. It is a *lower* bound,
  so the old default protected nothing and merely rejected safe small currents.
  A diode-specific floor is the caller's to set.

### Deprecated
Each of these was a genuine API break in an earlier draft of this release and
is now a deprecation, so nothing has to be migrated to receive the fixes
above. All four are scheduled for removal in a future 0.3.0.

- **`properties.power` and `properties.power_unit` on `TCubeLaser`.**
  `power_unit` still defaults to `"mW"` and `power` still holds
  `current * max_power / <controller limit>`, the same number 0.2.2 produced
  — reproducing that exactly took one extra step, because the old expression
  divided by `light.max_current` and 0.2.2's `initialize` overwrote that field
  with the controller's limit. `max_current` is the caller's now and stays so,
  so the divisor is `controller_max_current` once `initialize` has read it and
  `max_current` before that: the same quantity the old field held at each of
  those two moments. The figure is an uncalibrated linear guess the driver has
  no way to measure, contradicted by the bench data in the (now deleted)
  `helpers.jl` and preserved as a comment in `TCubeLaserControl.jl`, and the
  controller reports no optical power in the open-loop mode this driver uses.
  Read the new `drive_current` field instead (see Added).
- **`export_state(::TCubeLaser, sth)`.** The bug was the *absence* of the
  1-argument method — `export_state(laser)` matched nothing on this type and
  fell through to the throwing instrument-level stub — so adding that method
  is the whole fix and is purely additive. The 2-argument form stays as a
  forwarder that warns once per session, ignores its (never-read) argument and
  delegates.
- **`tcube_refresh`.** Its behaviour is gone; the exported name is not. See
  Removed.
- **`min_current`'s `60.0` default** is now `0.0`; see Fixed. Reading
  `laser.min_current` and expecting `60.0` is the only way to notice.

### Removed
- **`tcube_get_power`** — it was uncallable four ways over: it referenced an
  undefined `out`, overwrote its `serialNo` local with the hardcoded literal
  `"64849775"` immediately before use, discarded the reading it had just
  fetched, and called `LD_GetPowerReading`, which is not among the bindings in
  `functions_Tlaser.jl` at all. A scaling *is* derivable from the deleted
  `helpers.jl` — `power_mW = raw / 32767 * TIA_range_mA * calibration_W_per_A`,
  preserved with its assumptions as a comment in `TCubeLaserControl.jl` — but
  both factors there were assumptions from one bench setup that the driver
  cannot read back, and the controller reports no optical power in the
  open-loop mode this driver uses. So the getter was deleted rather than
  repaired around a guess.
- **`tcube_refresh`'s behaviour** — it opened the device, enabled the output,
  drove a hardcoded **90 mA**, slept a second, then disabled and closed. A
  bench procedure whose name warned no one, and the only function here that
  could raise the current on a diode without being handed a number. The
  **name and its export are kept**, with a body that throws and says what it
  used to do and that `setpower(light, current)` is the replacement: deleting
  an exported name would turn a caller's line into an `UndefVarError` that
  explains nothing, which is a break that buys nothing. Speak up if a rig
  depended on it.
- **`src/hardware_implementations/tcube_laser/helpers.jl`** — a top-level
  script that built a device list, opened the hardcoded serial `64849775`, set
  open-loop mode, enabled the output and drove 80 mA, all at `include` time.
  `TCubeLaserControl.jl` never included it, so it did not run; it was the only
  worked example of the closed-loop bindings, which is exactly why someone
  would have included it to crib from. Its measured expected-versus-actual
  power table and a pointer to the closed-loop call sequence are preserved as
  a comment in `TCubeLaserControl.jl`.

### Added
- **`TCubeLaser.drive_current`** — the drive current in mA that `setpower` last
  accepted, `NaN` before the first successful call, and the only field here
  that reports what the driver acted on. It is also written to
  `export_state`'s attributes. `properties.power` remains beside it, unchanged
  and deprecated, so a consumer can move across at its own pace rather than at
  this release's.
- Tests that do not need a controller, covering the parts of the driver that
  decide whether a current reaches the diode: constructor defaults,
  `check_current`'s bounds and message, that a caller's `max_current` survives
  the controller's limit being recorded, that `setpower` refuses an
  out-of-range request with its own `ArgumentError` rather than reaching the
  Kinesis `ccall`, and `export_state`'s arity and contents.
- `test/tcube_fake_sdk.jl`, a recorder that replaces the Kinesis wrappers — they
  are plain untyped functions in `TCubeLaserControl`, so a same-signature method
  defined into that module takes their place and no production code changes for
  the test's sake. It puts `initialize`, `setpower` and `shutdown` themselves
  under test: that the caller's `max_current` survives the *real* `initialize`
  (testing `record_controller_limit!` alone did not catch the assignment being
  restored), that the setpoint actually sent stays at or under the ceiling, that
  a refused request reaches no `LD_SetLaserSetPoint`, and that a failure after
  `LD_Open` is followed by `LD_Close`. What no test here can tell you is how a
  real controller answers.
- `test/contract.jl` no longer excludes `TCubeLaser` from `no_export_state`,
  and asserts directly that the 1-argument form dispatches to this type and
  that the deprecated 2-argument form is a method on this type rather than the
  throwing stub it used to shadow.
- The five Claude Code skills' TCube rows are updated, each naming the version
  that fixed the item (v0.2.3), since a downstream may hold an older installed
  copy.
  `mc-system-design` also gains an unrelated `[limitation]` note: `using
  MicroscopeControl` plus a blanket `using GLMakie` makes `Camera` ambiguous
  (it is the only name both packages export), so a field typed `::Camera`
  fails with `UndefVarError`.

### Deferred to a batched 0.3.0
Not in this release. Each is a real break, and a breaking release costs a rig
re-verification session, so they are queued to be spent once rather than four
times. Listed here so the queue is visible in one place rather than spread
across issues.

- Remove `properties.power` and `properties.power_unit` from this driver in
  favour of `drive_current`. The pair is a linear guess under a milliwatt
  label; the field that reports what was commanded already exists.
- Remove the deprecated 2-argument `export_state(::TCubeLaser, sth)` and the
  `tcube_refresh` throwing stub, both of which exist only to keep an old call
  site resolving.
- Rename `LightSourceProperties.is_on` to `is_on_requested` and add an
  optional measured counterpart. The field is a *requested* state across the
  whole package, not just in this driver, and nothing reads it back from
  hardware; a name that says so is a package-wide interface change. (From the
  Shutter interface ruling.)
- Fix `getposition`'s return shape across all stage drivers, which is
  inconsistent between them today.

## [0.2.2] - 2026-09-22

No functional change; CI configuration and contributor guidance only.

### Changed
- CI is trimmed to the minimum useful signal, because Actions minutes are a
  shared resource and a workflow re-run is not a cheap way to find out
  whether code compiles. A pull request now runs **one** Julia version
  instead of two, skips the docs build entirely, and does not run at all for
  a change confined to `docs/`, `dev/`, `.claude/`, `README.md`,
  `CHANGELOG.md`, `CLAUDE.md` or `LICENSE`. The full version matrix,
  coverage upload and docs build run once on `main` and on tags, where a
  version actually ships. Superseded runs are now cancelled on every ref
  rather than only on pull requests, so a branch pushed several times in a
  row builds once. `CompatHelper` drops from daily to weekly: this package
  is unregistered and its consumers pin exact tags, so a one-day-old compat
  bound buys nothing.
  `paths-ignore` deliberately does **not** include a blanket `**.md`:
  `test/skills.jl` reads each shipped `SKILL.md` and asserts on its
  frontmatter and version stamp, so a change under `skills/` must still be
  tested.
- `CLAUDE.md` gains a "Testing policy" section stating what was already
  true in practice: the **local** suite is the gate, run before every push,
  and CI is confirmation rather than the first signal. It records the
  command for the oldest supported Julia version, which pull requests no
  longer run, and how to get full signal on a branch without opening a pull
  request (`gh workflow run CI.yml --ref <branch>`).

## [0.2.1] - 2026-09-22

Hardware verification: NOT DONE for the DCAM4 change (touches a driver
runtime path and no Hamamatsu camera is available here). The `gui.jl`
change was exercised on simulated devices only.

### Fixed
- `gui(::LightSource)` no longer commands hardware when the panel is
  constructed. The power slider and on/off toggle used `lift`, which
  evaluates immediately on creation, so opening a light source panel used
  to call `setpower(light, 0.5)` and then `light_off(light)`/`light_on(light)`
  the instant the window appeared. Both are now wired with `on`, which
  only fires on a later change to the widget. The slider and toggle are
  also now initialised from the device's current `properties.power` and
  `properties.is_on` instead of a hardcoded default, so opening a panel is
  observably read-only. Caveat: what `properties.power` holds after a
  `setpower` differs by driver. `SimLight` stores the argument it was given;
  `TCubeLaser` stores a calculated power while its `setpower` takes current
  in milliamps, so the displayed and wire units differ; `CrystaLaser`,
  `VortranLaser` and `DaqTrLight` never write the field, so the slider can
  display a stale cached value on those three. This is not a new
  opening-time write, only what the widget displays. The other enabled GUI panels (`stage_interface`,
  `camera_interface`, `attenuator_interface`, `daq_interface`,
  `triggerscope_interface`, `pi_n472`) were audited for the same
  construction-time `lift` pattern; none had it. This does not mean every
  hardware call is behind a callback: `gui(::DAQ)` queries `showdevices`
  and `showchannels` directly at construction, outside any `on`/`lift`, to
  populate its dropdown menus, so it is not observably read-only. The
  disabled `objective_positioner_interface/gui.jl` (not included in the
  build) calls `initialize(positioner)` immediately and was excluded from
  this audit for that reason.
- `DCAM4Camera()` now throws instead of returning a non-camera value on
  either SDK failure path, matching the "returns a camera or throws"
  contract downstream callers (`check_hardware`, `initialize_all`) rely
  on. Previously, a `dcamapi_init` failure returned a `DCAMERR` value
  where a camera was expected, and a `dcamdev_open` failure logged an
  `@error` and returned `nothing` while leaving the DCAM SDK initialised,
  which is the state a second constructor call was landing in when it
  crashed downstream. Both failure paths now call `dcamapi_uninit()`
  before throwing an `ErrorException` naming the device id and the
  `DCAMERR` code, noting that the camera or controller may already be
  held by another process. This covers only the two checked SDK return
  paths: an exception raised after a successful open has no cleanup
  guard, and `dcamapi_uninit()`'s own return is not checked.

## [0.2.0] - 2026-09-20

Hardware verification: not required (no driver runtime paths changed).

### Added
- `install_skills`/`uninstall_skills`/`list_skills`, a Claude Code skill
  installer for downstream repos that compose MicroscopeControl.jl devices.
  `install_skills(target)` copies the package's `skills/` sources into
  `target/.claude/skills/`, stamps each installed `SKILL.md` with the
  package version, and writes a manifest (`.microscopecontrol-skills.toml`)
  tracking installed files by SHA-256 so a locally edited file is never
  silently overwritten (pass `force=true` to override). `uninstall_skills`
  reverses this using the same manifest, leaving unrelated skills alone.
- Five skill sources under `skills/`: `mc-system-design` (the entry point:
  responsibility split, upstream/downstream boundary test, design principles,
  worked composition example), `mc-extend` (diagnose a driver, report and work
  around without type piracy, implement an existing interface, define a new
  interface), `mc-acquire`, `mc-testing` (validate a composed system with
  simulators and fakes, then hardware acceptance) and `mc-api-map`. Earlier
  pre-release names on this branch (`mc-wire-device`, `mc-sim-testing`,
  `mc-driver-issue`, `mc-add-driver`, `mc-add-interface`) were consolidated
  into these before 0.2.0 shipped. `mc-api-map` also gets a
  generated `references/api-map.md`, built by introspecting the installed
  module rather than hand-maintained, listing each device type's
  device-specific and interface-inherited methods.
- New `[deps]`: `SHA`, `TOML`, `InteractiveUtils` (all stdlib; `Dates` was
  already a dependency), needed by the installer.

## [0.1.1] - 2026-09-20

Hardware verification: NOT DONE. This changes PI C-867 driver runtime paths
and was tested only against the simulated devices in CI. The downstream rig
repository that pins this tag should verify on the instrument before relying
on it.

### Fixed
- `PI_SVO` now receives `Cint` (32-bit `BOOL`) flags, one per axis, instead of
  a `UInt8` array. The DLL read axis 2's flag from whatever byte followed the
  array, so the Y servo was silently left off and every `PI_MOV` was refused
  with GCS error 5. The old packing happened to work on Julia 1.10 and failed
  on 1.13.
- `servox`/`servoy` assign a new `servostatus` tuple instead of mutating one
  element of an immutable tuple.
- `PI_EnumerateUSB`'s buffer-size argument is passed as `Cint`, matching the
  DLL signature.

### Changed
- `initialize` on a PI stage now fails loudly when the controller is present
  but held by another process (a second Julia session with an initialized
  stage, PIMikroMove, or an open COM port), and when `PI_ConnectUSB` returns
  a negative id, instead of continuing with a bad handle.
- `shutdown` clears `connectionstatus` on an already-disconnected stage.

## [0.1.0] - 2026-09-19

Hardware verification: not required (dispatch, exports and tests only; no
driver runtime paths changed).

### Changed
- Unified every `gui(device)` method onto a single generic in
  `AbstractInstrument`/`MicroscopeControl` so `gui` dispatches correctly
  instead of colliding across interface and driver modules.
- Resolved 20 other top-level names that two or more submodules exported as
  distinct, colliding bindings (`Dimensions`, `getdatatypes`,
  `getnumchannels`, `getranges`, `getvalue`, `isxmoving`, `isymoving`,
  `movexy`, `reference`, `reset`, `servoxy`, `set_exposuretime`, `set_roi`,
  `set_triggermode`, `setexposuretime`, `setexposuretime!`, `setroi!`,
  `settriggermode`, `setupIO`, `setvalue`) by lifting camera setters
  (`setexposuretime!`, `setroi!`, `settriggermode!`) into `CameraInterface`,
  extending `Base.reset` for `TRIG` devices instead of re-exporting a
  colliding `reset`, dropping dead exports that were never implemented, and
  unexporting device-specific helpers that only ever needed qualified
  access.
- Removed the SmarAct stage's bang-named duplicates
  (`initialize!, shutdown!, move!, move_um!, getposition!, home!,
  stopmotion!`) from its public exports; the StageInterface bridge in
  `stageinterface_bridge_smaract.jl` is the public API.
- Interface fallback stubs in `src/hardware_interfaces/*/interface_functions.jl`
  (and the stage GUI's dimension-dispatch fallback) now `error(...)` instead
  of `@error`-and-return-`nothing`, so an unimplemented method fails loudly.
  A device that has no concrete `initialize`/`shutdown`/`export_state` of its
  own therefore now throws when that method is called, where it previously
  logged and returned `nothing`. Still affected after this PR: `ThorCamCSCCamera`
  (`initialize`, `export_state`); `TCubeLaser` (its own `export_state` takes
  an extra, unused positional argument, so the 1-arg contract call never
  reaches it and falls through to the throwing stub); `MLSLM` (outside the
  `AbstractInstrument` hierarchy and with no lifecycle methods at all) and
  `Triggerscope4` (also outside the hierarchy; it implements `initialize` and
  `shutdown` but has no `export_state`). A downstream loop that calls
  `shutdown` on every device in turn should wrap each call in `try`/`catch`
  until these are fixed, or one throwing device aborts the rest of the loop.
- `NIdaq` gained concrete no-op `initialize`/`shutdown` (DAQmx tasks are
  created and deleted per operation via `createtask`/`deletetask`, so there
  was never a persistent connection to open or close); it no longer throws
  and is no longer one of the devices listed above.

### Removed
- SmarAct MCS2 stage's bang-named low-level methods are no longer exported
  from `MicroscopeControl` (see "Changed" above); qualified access remains,
  and the interface-level replacement differs in units and return value:
  - `initialize!`, `shutdown!`, `home!`, `stopmotion!` -> the interface's
    `initialize`, `shutdown`, `home`, `stopmotion`, or qualified as
    `MicroscopeControl.HardwareImplementations.MCS2Stage_mod.initialize!` etc.
  - `move!(stage, targets_pm::Vector{Int64})` (picometres) -> qualified as
    `MicroscopeControl.HardwareImplementations.MCS2Stage_mod.move!`, or the
    interface's `move(stage, x, y[, z])` in micrometres (`Float64`).
  - `move_um!(stage, targets_um::Vector{Float64})` (micrometres) -> qualified
    the same way, or the interface `move(stage, x, y[, z])`.
  - `getposition!(stage) -> Vector{Int64}` (picometres) -> qualified the same
    way, or the interface `getposition(stage)`, which updates
    `stage.real_x`/`real_y`/`real_z` in place and returns no vector.
- TCube laser's `setupIO` is no longer exported (it collided with OK_XEM's
  unrelated `setupIO`); use
  `MicroscopeControl.HardwareImplementations.TCubeLaserControl.setupIO`.

### Fixed
- `test/contract.jl` (new "Interface Contract" testset) guards against a
  regression of any of the above: no ambiguous top-level exports, every
  concrete device has the core `AbstractInstrument` methods it should, and
  the interface fallbacks actually throw.
- Added a binding-identity guard ("No shadowed generics in submodules") that
  catches a driver defining `gui`/`initialize`/etc. via a bare `using` of its
  interface (rather than an explicit `import` or a fully-qualified method
  definition): the definition silently creates a new, disconnected function
  local to that module instead of extending the real generic, so calls
  through `MicroscopeControl` fall through to an unrelated fallback instead
  of erroring. The guard found and fixed one real case:
  `CameraInterface`'s own `export_state` fallback was such a shadow (now
  imported explicitly in `CameraInterface.jl`). It also found that `pi_stage`
  (PI) intentionally shadows `move`/`getposition`/`getrange`/`stopmotion`/`servo`
  as private ccall helpers behind correctly-qualified public wrappers in
  `interface_methods.jl`; `getrange` was missing its wrapper (a real gap, now
  added) while the other four were already wired correctly, so the guard
  excludes PI's own binding for all five by name rather than "fixing" a
  pattern that isn't broken.
