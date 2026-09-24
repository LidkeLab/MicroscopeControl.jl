# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows Julia's pre-1.0 versioning convention, described in
the README's Installation section: in `0.x.y`, `x` is the breaking component
and `y` is the non-breaking one (every merge to `main` is tagged).

## [Unreleased]

### Changed
- **Breaking.** `MCS2Stage`'s `initialize!` no longer forces
  `MAX_CL_FREQUENCY` to a hardcoded 18500 Hz. It reads
  `SA_CTL_PKEY_DEFAULT_MAX_CL_FREQUENCY` per channel and applies that
  instead, falling back to whatever the controller already has if the
  property cannot be read. The hardcoded value was justified in a comment as
  the vendor default; it is not one for every positioner. The CT001/AT001
  units on the rig this was found on default to 5 kHz, so the override drove
  them at 3.7× their rated step rate — audible as a whine, and needless
  wear. Connected channels will now run at a different drive frequency than
  they did before, which is why this is the breaking component.
- **Breaking.** `find_reference!` now verifies the `IS_REFERENCED` state bit
  after homing and throws if it is clear, where it previously set
  `stage.is_referenced[i] = true` unconditionally. The `REFERENCING` bit
  clearing only means homing stopped, not that it succeeded, and an
  unreferenced channel reports positions against an arbitrary zero — so the
  old behaviour let an absolute move be computed from a zero that does not
  exist. It also sends a stop on timeout rather than leaving the positioner
  driving.

### Fixed
- **Breaking.** `MCS2Stage`'s `initialize!` throws on every failure path
  instead of logging and returning. Device-not-found, `SA_CTL_FindDevices`
  failure, `SA_CTL_Open` failure and double-initialise all returned normally
  with `dHandle` unopened, and the bridge's `initialize` then went straight
  on to `getposition` — so the visible error was `invalid device handle` from
  a property read, with the real cause buried in a log line above it. Same
  defect class as the DCAM4Camera fix in 0.2.x: a caller expecting an
  initialised stage now gets one or an exception, never neither. The
  device-not-found and open-failure messages also name the MCS2's
  single-connection limit, which is the usual cause when the controller is
  plugged in and enumerating but will not open.
- **Breaking.** `move_all!` now actually waits for motion to finish. Its poll
  loop ran inside an `@async` block while `query_positions!` ran immediately
  after it, so the function returned before anything had moved and reported
  positions sampled mid-move. Every readback after a `move!` or
  `StageInterface.move` was therefore a race, including the GUI's. It now
  blocks, and throws on timeout rather than logging from inside a task whose
  failure nothing observes. Callers that relied on the move returning
  immediately will now block until it completes or `timeout_s` elapses.

### Added
- `set_range_limits!(stage, ch_index, min_pm, max_pm)` for the MCS2. Nothing
  in the driver could write the controller's software travel limits —
  `initialize!` only read them — so whatever the last session happened to
  leave in the controller bounded every subsequent move, the GUI's included.
  The limits are volatile (forgotten on a power cycle) and are not validated
  against the positioner, so a value far wider than the real travel is
  accepted silently and protects nothing; the setter reads back what was
  actually stored and warns if it differs.
- `dev/smaract_rig_config.jl`, one definition of the rig's safe travel window
  shared by all three SmarAct dev scripts, so they cannot drift apart.
- `dev/test_smaract_motion.jl`, a hardware motion characterisation for the
  MCS2: long-range accuracy and hysteresis across the full travel,
  minimum incremental motion over a range of step sizes, and the two
  combined — fine positioning immediately after a long traverse, plus
  bidirectional repeatability. Every target is clamped into the controller's
  software limits, and it refuses to run against an unreferenced channel.
- Channel-state fault decoding for the SmarAct MCS2. `ACTIVELY_MOVING`
  clearing says only that a channel stopped, not that it arrived, so
  `move_abs!`, `move_all!` and `find_reference!` now decode and warn on
  `END_STOP_REACHED`, `RANGE_LIMIT_REACHED`, `FOLLOWING_LIMIT_REACHED`,
  `MOVEMENT_FAILED`, `POSITIONER_OVERLOAD`, `OVER_TEMPERATURE` and
  `POSITIONER_FAULT` before the position is read back.

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
