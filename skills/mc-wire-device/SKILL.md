---
name: mc-wire-device
description: Adds a MicroscopeControl.jl device to a downstream system struct -- field, constructor, initialize/shutdown order, gui menu entry, export_state children; activates for "add a camera to my system", "wire up a stage", or "mc-wire-device".
---

# mc-wire-device

This skill will cover composing a MicroscopeControl.jl device into a
downstream instrument-control struct: adding the device as a field,
extending the constructor, choosing where the device falls in the
system-wide `initialize`/`shutdown` ordering, adding a `gui` menu entry, and
folding the device's `export_state` into the parent's `children` dict.

It targets composition in downstream repos (e.g. MicroscopeAdapt.jl), not
writing new drivers against `hardware_interfaces/`.
