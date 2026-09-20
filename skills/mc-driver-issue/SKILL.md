---
name: mc-driver-issue
description: Covers reporting a MicroscopeControl.jl driver defect upstream and overriding a method locally without editing the installed package; activates for "driver bug", "report an issue upstream", "override a method locally", or "mc-driver-issue".
---

# mc-driver-issue

This skill will cover filing a reproducible defect report against a
MicroscopeControl.jl driver in the upstream repository, and, until a fix
lands, working around it in a downstream repo by defining a more specific
method on the device's own type rather than editing the installed package.

It targets downstream sessions that hit broken, missing, or surprising
driver behavior while composing an instrument.
