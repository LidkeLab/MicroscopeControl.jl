# MicroscopeControl.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LidkeLab.github.io/MicroscopeControl.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LidkeLab.github.io/MicroscopeControl.jl/dev/)
[![Build Status](https://github.com/LidkeLab/MicroscopeControl.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LidkeLab/MicroscopeControl.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LidkeLab/MicroscopeControl.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LidkeLab/MicroscopeControl.jl)

MicroscopeControl.jl is a Julia package designed to streamline the control of optical microscopy hardware, providing a flexible and high-performance solution for biologists. Julia is a high-level, high-performance language optimized for scientific computing. It is fast, dynamic, reproducible, and open-source, using multiple dispatch to facilitate both object-oriented and functional programming patterns.

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

### Example Workflow
1. Create an object of a specific device type.  
2. Call `initialize` to set up the hardware.  
3. Use various control functions (e.g., `light_on`, `move_stage`, `capture_image`).  
4. Call `export_state` to retrieve the device’s current settings and data.  
5. Shut down with `shutdown` when finished.

---

## Common Features

1. **Constructor Methods**  
   Each hardware component has a constructor that takes relevant parameters (like serial numbers or device addresses). After constructing the device object, you can call `initialize` or other methods to start interacting with the hardware.

2. **Export State**  
   The function `export_state` gives you a structured overview of the device’s current settings:  
   - **Attributes**: Key-value pairs with the device’s configuration.  
   - **Data**: Measurement or imaging data.  
   - **Children**: Nested hardware components or linked instruments.

3. **Functional Tests**  
   Many instrument modules include test functions that validate basic operations (e.g., turning a laser on/off, adjusting power, capturing an image). These help confirm that the hardware is working correctly.

4. **Graphical User Interface**  
   Some modules provide a simple GUI for controlling hardware, created using Julia packages like Gtk or Makie. This interface often allows for easy on/off toggling, parameter changes, and live readouts.

---

## Installation Notes

- **Julia Environment**: Ensure you have a compatible version of Julia installed.  
- **Driver/SDK Requirements**: Most hardware devices require manufacturer-specific drivers and SDKs installed on your system (e.g., Thorlabs Kinesis for TCube devices, DCAM-API for Hamamatsu cameras, NI-DAQ for National Instruments cards).  
- **Package Installation**:  
  ```julia
  using Pkg
  Pkg.add("MicroscopeControl")
  ```
- **Initial Setup**: Depending on the device, you may need to provide the path to certain libraries (e.g., `.dll` or `.so` files). Check each hardware implementation’s documentation for details.

---

## Testing

MicroscopeControl.jl includes test scripts for simulated devices and real hardware (where supported). To run tests from the Julia REPL:

```julia
using Pkg
Pkg.test("MicroscopeControl")
```

These tests ensure that abstract interfaces and concrete implementations behave as expected.

---

## Top-Level Files and Directories

| Name         | Description                                                     |
|--------------|-----------------------------------------------------------------|
| LICENSE      | MIT license                                                    |
| README.md    | This document                                                  |
| src          | Julia code source (main package contents)                      |
| docs         | Documentation files for MicroscopeControl.jl                   |
| tests        | Contains unit tests and example hardware tests                 |
| .github      | GitHub continuous integration (CI) workflows                   |

---

## High-Level Usage Examples

- **Sequential or TIRF Super-Resolution**: By importing multiple hardware modules (cameras, stages, lasers), you can orchestrate advanced imaging protocols.  
- **Live Acquisition**: Start cameras in continuous mode, adjust lasers for illumination, and read data in real time.  
- **Automated Routines**: Use Julia’s scripting capabilities to run experiments, move stages, and log data automatically.

---

## Projects Using MicroscopeControl
- Multiple super-resolution microscopy setups in the Lidke Lab.  
- Automated laser control in time-lapse and multi-color imaging experiments.  
- Potential expansion to additional optical devices and novel imaging platforms.

---

## Related Software
- **Micro-Manager**: Java-based platform for device control.  
- **PYME** (Python Microscopy Environment): Python-based imaging platform for super-resolution.  
- **LSMAQ**: MATLAB-based laser scanning microscope acquisition software.

MicroscopeControl.jl provides Julia-centric hardware control, offering a bridge for scientists who prefer Julia’s performance and syntax.

---

## Documentation
Full, auto-generated documentation is hosted on GitHub Pages:
- [Stable Docs](https://LidkeLab.github.io/MicroscopeControl.jl/stable/)
- [Development Docs](https://LidkeLab.github.io/MicroscopeControl.jl/dev/)

Documentation includes API references for each abstract interface and hardware module.

---

## Contributions
Contributions are welcome! Please see our guidelines in the repository’s CONTRIBUTING.md for more details. We encourage pull requests that add support for new hardware or improve existing modules.
