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
Pkg.add(url="https://github.com/LidkeLab/MicroscopeControl.jl.git", rev="v0.1.0")
```

Advance the pinned tag deliberately when you want a newer release. `Pkg.develop` (tracking `main` directly, no tag) is for contributors working on the package itself, not for rig code that depends on it.

This package follows a 0.x versioning policy: every merge to `main` is tagged (`.github/workflows/TagOnMerge.yml`), a minor bump (`0.x.0`) means an interface change, and a patch bump (`0.0.x`) is everything else. Hardware verification is not tracked here; it is recorded by the downstream rig repo that pins to a given tag.

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
seven skills:

- `mc-system-design` — start here: the driver/system responsibility split, the upstream/downstream boundary test, the design principles the source expresses, and a worked composition example with rollback and provenance.
- `mc-add-driver` — implement an existing interface (Camera, Stage, LightSource, ...) for a new device, downstream or as an upstream contribution.
- `mc-add-interface` — define a new device class: interface scaffold, wiring, the hand-maintained interface lists, and the simulated implementation that ships with it.
- `mc-api-map` — which methods you can call on each device type, generated per installed version.
- `mc-acquire` — capture/sequence/live patterns, safe live-view stop order, z-stacks.
- `mc-sim-testing` — SimCamera/SimStage/SimLight, headless testing under xvfb.
- `mc-driver-issue` — report a driver defect upstream, or override a method locally.

Reinstalling (`install_skills()` again) after advancing the pinned tag
refreshes all seven, including the generated API map, to match the new
version.

---


## Contributions
Contributions are welcome! We encourage pull requests that add support for new hardware or improve existing modules.
