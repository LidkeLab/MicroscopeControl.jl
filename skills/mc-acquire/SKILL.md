---
name: mc-acquire
description: Covers capture/sequence/live acquisition patterns, safe live-view stop order, z-stacks, and array conventions for MicroscopeControl.jl cameras and stages; activates for "capture an image", "start live view", "build a z-stack", or "mc-acquire".
---

# mc-acquire

This skill will cover the `capture`/`sequence`/`live` acquisition patterns
for MicroscopeControl.jl cameras, the safe order for calling `abort` on a
running live view before starting another acquisition, building z-stacks by
interleaving stage `move` calls with captures, and the `(H, W)`/`(H, W, N)`
array conventions returned by `getdata`.

It targets acquisition code composed in a downstream repo, not the camera
driver implementations themselves.
