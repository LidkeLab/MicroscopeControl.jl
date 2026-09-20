---
name: mc-api-map
description: Lists which methods you can call on each MicroscopeControl.jl device type, generated per installed package version; activates for "what can I call on this stage/camera", "what methods does SimCamera support", or "mc-api-map".
---

# mc-api-map

This skill points downstream sessions at the generated `references/api-map.md`,
which lists, per device type, the device-specific methods and the methods
inherited from its interface (Stage, Camera, LightSource, DAQ, Attenuator,
SLM, TRIG). The map is produced by introspecting the installed
MicroscopeControl.jl module (not hand-written), so it always matches the
pinned version rather than package source the session can't see.

Reinstall skills after bumping the pinned tag to refresh the map.
