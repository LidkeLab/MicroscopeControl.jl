# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows the 0.x versioning policy described in the
README's Installation section (every merge to `main` is tagged; minor bumps
are interface changes, patch bumps are everything else).

## [Unreleased]

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

### Fixed
- `test/contract.jl` (new "Interface Contract" testset) guards against a
  regression of any of the above: no ambiguous top-level exports, every
  concrete device has the core `AbstractInstrument` methods it should, and
  the interface fallbacks actually throw.
