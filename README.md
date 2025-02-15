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

Since this package is under active development and not yet registered, install it using:

```julia
using Pkg
Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")
```
---


## Contributions
Contributions are welcome! We encourage pull requests that add support for new hardware or improve existing modules.
