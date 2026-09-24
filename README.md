# MicroscopeControl.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LidkeLab.github.io/MicroscopeControl.jl/dev/)
[![Build Status](https://github.com/LidkeLab/MicroscopeControl.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LidkeLab/MicroscopeControl.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LidkeLab/MicroscopeControl.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LidkeLab/MicroscopeControl.jl)

MicroscopeControl.jl is a Julia package for control of optical microscopy hardware, providing a flexible and high-performance solution for microscope developers. 

MicroscopeControl.jl utilizes three layers of code: high-level, low-level, and user-level. High-level code is generic, providing interfaces for stages, light sources, cameras, etc. Low-level code handles hardware-specific implementations, defining functions for individual microscope components. This design heavily leverages Julia’s multiple dispatch, enabling different behaviors for the same function based on argument types. The user-level code integrates these layers to control the microscope system.

---

## Module Structure Overview

MicroscopeControl.jl is organized to ensure scalability and easy integration of new hardware:

### Abstract Interfaces
- Defines basic functions and properties common across all device types (e.g., cameras, light sources, stages).  
- Each abstract interface (e.g., `CameraInterface`, `LightSourceInterface`, `StageInterface`) outlines the required methods, such as `initialize`, `shutdown`, and `export_state`.

### Hardware Implementations
- Provides concrete modules for each hardware device model (e.g., `TCubeLaserControl`, `DCAM4Camera`, `MCLStage`).  
- These modules implement the abstract interfaces and add device-specific functionality.


---

## Common Features

1. **Constructor Methods**  
   Each hardware component has a constructor that takes relevant parameters (like serial numbers or device addresses). After constructing the device object, you can call `initialize` or other methods to start interacting with the hardware.

2. **Export State**  
   The function `export_state` gives you a structured overview of the device’s current settings:  
   - **Attributes**: Key-value pairs with the device’s configuration.  
   - **Data**: Measurement or imaging data.  
   - **Children**: Nested hardware components or linked instruments.

3. **Graphical User Interface**  
   Many modules provide a simple GUI for controlling hardware, created using GLMakie. This interface often allows for easy on/off toggling, parameter changes, and live readouts.

---

## Supported Hardware

### Cameras
- Hamamatsu DCAM4 compatible cameras
- Thorlabs Scientific Cameras (CSC series)
- Simulated camera for testing

### Stages
- Mad City Labs nanopositioning stages
- Physik Instrumente (PI) stages
- PI N-472 linear stage
- Simulated stage for testing

### Light Sources
- Thorlabs TCube laser diode controller
- CrystaLaser 561nm
- Vortran 488nm laser
- Simulated light source for testing

### Other Hardware
- National Instruments DAQ cards
- Opal Kelly XEM FPGA boards
- DAQ-based transmission light control

---

## Installation Notes

Since this package is under active development and not yet registered, install it pinned to a released tag:

```julia
using Pkg
Pkg.add(url="https://github.com/LidkeLab/MicroscopeControl.jl.git", rev="v0.2.3")
```

**You must also declare this package's unregistered dependency in your own
`Project.toml`.** A `[sources]` entry in a *dependency* is not reliably used
when resolving your project, so the one MicroscopeControl declares for `DAQmx`
may do nothing for you, and a clean `Pkg.instantiate` then fails with
`DAQmx has no known versions`.

The simplest fix is to add `DAQmx` by URL **before** MicroscopeControl, which
writes both entries for you:

```julia
using Pkg
Pkg.add(url="https://github.com/LidkeLab/DAQmx.jl.git")
Pkg.add(url="https://github.com/LidkeLab/MicroscopeControl.jl.git", rev="v0.2.3")
```

If you write the TOML by hand, `[sources]` alone is **not** enough — Julia
rejects a project whose `[sources]` names something absent from `[deps]` with
`Sources for DAQmx not listed in deps or extras section`. You need both:

```toml
[deps]
DAQmx = "bc903ccc-f951-4f60-9748-ff64248ad6aa"

[sources]
DAQmx = {url = "https://github.com/LidkeLab/DAQmx.jl.git"}
```

This surfaces on an environment that has not already resolved `DAQmx`, which
is why it tends to appear first on a fresh instrument PC rather than on a
development box. Registering `DAQmx.jl`, or publishing a lab registry, would
remove the requirement entirely.

Advance the pinned tag deliberately when you want a newer release. `Pkg.develop` (tracking `main` directly, no tag) is for contributors working on the package itself, not for rig code that depends on it.

This package follows Julia's pre-1.0 versioning convention: while the version is `0.x.y`, `x` is the breaking component and `y` is the non-breaking one, so `0.2.0 -> 0.3.0` declares a breaking release and `0.2.0 -> 0.2.1` a compatible one. Every merge to `main` is tagged (`.github/workflows/TagOnMerge.yml`). Hardware verification is not tracked here; it is recorded by the downstream rig repo that pins to a given tag.

## Claude Code skills

Downstream repos that build an instrument out of MicroscopeControl.jl devices,
or write a driver against it, can install a set of Claude Code skills describing
this package's design and API, from the downstream repo's own root:

```julia
using MicroscopeControl
install_skills()
```

This copies skill sources into `.claude/skills/` in the current directory,
one subdirectory per skill, each stamped with the installed package version
and tracked in a manifest so a locally edited skill file is never silently
overwritten (pass `install_skills(force=true)` to overwrite anyway). The
five skills:

- `mc-system-design` — start here: the driver/system responsibility split, the upstream/downstream boundary test, the design principles the source expresses, and a worked composition example with rollback and provenance.
- `mc-extend` — in order of commitment: diagnose a misbehaving driver (usually the rig), report upstream and work around without type piracy, implement an existing interface for a new device, define a new device class.
- `mc-acquire` — capture/sequence/live patterns, safe live-view stop order, z-stacks, the `(H, W, N)` convention.
- `mc-testing` — validate the composed system with simulators and fakes, then what hardware acceptance must still establish; headless under xvfb.
- `mc-api-map` — a per-version dispatch inventory of which methods each device type has, plus the fields the shared GUI panels read.

Reinstalling (`install_skills()` again) after advancing the pinned tag
refreshes all five, including the generated API map, to match the new
version.

---


## Contributions
Contributions are welcome! We encourage pull requests that add support for new hardware or improve existing modules.
