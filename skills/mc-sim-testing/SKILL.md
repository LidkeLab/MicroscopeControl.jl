---
name: mc-sim-testing
description: Covers testing downstream code against SimCamera/SimStage/SimLight and running MicroscopeControl.jl headlessly under xvfb; activates for "test with simulated devices", "headless test", "xvfb", or "mc-sim-testing".
---

# mc-sim-testing

This skill will cover writing downstream tests against `SimCamera`,
`SimStage1d`/`SimStage2d`/`SimStage3d`, and `SimLight` instead of real
hardware, and why loading MicroscopeControl.jl needs a display: GLMakie
requires one, so any test or session that uses the package should run under
`xvfb-run -a` on a headless machine.

It targets CI configuration and local test suites in repos that depend on
MicroscopeControl.jl.
