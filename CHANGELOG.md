# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows Julia's pre-1.0 versioning convention, described in
the README's Installation section: in `0.x.y`, `x` is the breaking component
and `y` is the non-breaking one (every merge to `main` is tagged).

## [Unreleased]

## [0.3.0] - 2026-09-22

TCube laser driver: safety, then correctness, then unit honesty. Reported
independently by two downstream rig repositories.

**Hardware verification: NOT DONE.** There is no Thorlabs TCube laser diode
controller on any build machine, so no change below has been exercised against
one. Every claim here is traced from the source. That is also why the changes
are ordered as they are: a change that can only *reduce* what reaches a laser
diode is worth taking unverified, while a change to what a working rig sees is
not, and the ones in the latter class are called out individually.

**Interface change (breaking, hence the minor bump).** Four things a working
caller can see changed:

- `TCubeLaser`'s `properties.power_unit` is now `"mA"` and `properties.power`
  holds the drive current in milliamps that `setpower` accepted. It used to be
  labelled `"mW"` and hold `current * max_power / max_current`, a linear
  current-to-power guess the driver has no way to measure and that the bench
  data in the (now deleted) `helpers.jl` contradicts. A caller reading
  `laser.properties.power` as milliwatts now silently reads milliamps, so read
  `power_unit` or convert at your own boundary.
- `export_state(::TCubeLaser, sth)` is now `export_state(::TCubeLaser)`. The
  second positional argument was unused and meant the 1-argument call every
  other device answers fell through to the throwing stub. A caller passing a
  second argument now gets a `MethodError`.
- `TCubeLaser`'s field list and positional order changed (new
  `controller_max_current`, `daq_device`, `ao_channel`). The keyword
  constructor `TCubeLaser(serialNo; ...)` is unaffected; a direct positional
  construction is not.
- **`tcube_refresh` is gone, and it was an exported name.** `using
  MicroscopeControl; tcube_refresh(...)` used to resolve; it is now an
  `UndefVarError`. See Removed below for what it did and why it went.

The constructor also now **rejects** `properties` whose `power_unit` is not
`"mA"`, with an `ArgumentError`. Defaulting the label to `"mA"` was not enough:
a caller passing `LightSourceProperties("mW", ...)` got the accepted drive
current stored under a milliwatt name and carried into `export_state` and the
HDF5 attributes written from it. That is the silent break this bump exists to
announce, so it is refused rather than documented.

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
  the one to exceed it. The conversion truncates now, everywhere, so the
  current commanded never exceeds the current requested; the cost is an
  undershoot of under one code (0.0067 mA at the default scale).
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
  `UInt16` and neither of which the controller will accept. Without the bound
  such a request passed the range check and then died in the conversion.
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
- **`tcube_refresh`** — it opened the device, enabled the output, drove a
  hardcoded **90 mA**, slept a second, then disabled and closed. A bench
  procedure whose name warned no one. Deleted rather than renamed; speak up if
  a rig depends on it.
- **`src/hardware_implementations/tcube_laser/helpers.jl`** — a top-level
  script that built a device list, opened the hardcoded serial `64849775`, set
  open-loop mode, enabled the output and drove 80 mA, all at `include` time.
  `TCubeLaserControl.jl` never included it, so it did not run; it was the only
  worked example of the closed-loop bindings, which is exactly why someone
  would have included it to crib from. Its measured expected-versus-actual
  power table and a pointer to the closed-loop call sequence are preserved as
  a comment in `TCubeLaserControl.jl`.

### Added
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
  and asserts directly that the 1-argument form dispatches to this type while
  no extra-argument method survives.
- The five Claude Code skills' TCube rows are updated, each naming the version
  that fixed the item, since a downstream may hold an older installed copy.
  `mc-system-design` also gains an unrelated `[limitation]` note: `using
  MicroscopeControl` plus a blanket `using GLMakie` makes `Camera` ambiguous
  (it is the only name both packages export), so a field typed `::Camera`
  fails with `UndefVarError`.

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
