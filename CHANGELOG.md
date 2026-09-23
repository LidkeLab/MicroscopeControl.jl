# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows Julia's pre-1.0 versioning convention, described in
the README's Installation section: in `0.x.y`, `x` is the breaking component
and `y` is the non-breaking one (every merge to `main` is tagged).

## [Unreleased]

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
