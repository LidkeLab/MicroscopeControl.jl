```@meta
CurrentModule = MicroscopeControl
```

# MicroscopeControl.jl

MicroscopeControl.jl controls optical microscope hardware from Julia: cameras, stages, light sources, DAQ cards,
attenuators, spatial light modulators and trigger controllers. Each kind of device has a generic interface (an
abstract type and a set of functions), and each device model has a driver that implements it, so code written
against the interface runs on any device of that kind, including the simulated ones.

These pages document `main`, the development branch. An instrument computer should run a released tag (see
[Installation](@ref)); `?name` in the REPL shows the docstrings of the version you have installed.

## Installation

The package is not registered. Install a released tag, and add its unregistered dependency `DAQmx` first:

```julia
using Pkg
Pkg.add(url="https://github.com/LidkeLab/DAQmx.jl.git")
Pkg.add(url="https://github.com/LidkeLab/MicroscopeControl.jl.git", rev="v0.2.6")
```

The README explains why `DAQmx` must be added by hand and how the version numbers read; the [Quick start](@ref)
says when to install `main` instead.

## How the package is organized

Cameras, stages, light sources, DAQ cards and attenuators are subtypes of [`AbstractInstrument`](@ref), and each
has these four functions:

| Function | What it does |
|:---------|:-------------|
| [`initialize`](@ref initialize(::AbstractInstrument)) | Connect to the hardware. On the simulated devices: the camera does nothing, a stage marks itself connected, the laser diode opens its simulated controller with the output off, and `SimLight` switches on (with a modulator it stays off and opens the modulator). |
| [`shutdown`](@ref shutdown(::AbstractInstrument)) | Release the hardware; each driver's docstring says what it closes (an `LCC1620` leaves its shared serial port open). |
| [`export_state`](@ref export_state(::AbstractInstrument)) | Return `(attributes, data, children)`, the device's state for [`save_h5`](@ref). |
| [`gui`](@ref gui(::AbstractInstrument)) | Open a GLMakie control panel for the device. |

Each device class also has its interface: an abstract type and the generic functions its drivers implement.
Calling most interface functions on a driver that does not implement them throws
`"<function> not implemented for <type>"`; a few fallbacks do something else instead (the SLM display functions,
for example), and their docstrings say what. A
driver's docstring says whether its constructor or `initialize` opens the device.

| Device class | Abstract type | Interface functions | Drivers | Simulated |
|:-------------|:--------------|:--------------------|:--------|:----------|
| [Cameras](@ref) | `Camera` | `capture`, `live`, `sequence`, `abort`, `getlastframe`, `getdata` | `DCAM4Camera`, `ThorCamCSCCamera`, `ThorcamDCXCamera` | `SimCamera` |
| [Stages](@ref) | `Stage` | `move`, `getposition`, `getrange`, `stopmotion` | `MCLStage`, `PIStage`, `N472`, `MCS2Stage` | `SimStage1d`, `SimStage2d`, `SimStage3d` |
| [Light sources](@ref) | `LightSource` | `setpower`, `light_on`, `light_off` | `CrystaLaser`, `VortranLaser`, `DaqTrLight` | `SimLight` |
| [Light sources](@ref) | `DiodeLaser <: LightSource` | `setcurrent!`, `setoutputpower!`, `setlevel!`, and readbacks | `TCubeLaser` | `SimDiodeLaser` |
| [DAQ and FPGA boards](@ref) | `DAQ` | `createtask`, `setvoltage`, `readvoltage`, `deletetask` | `NIdaq` | |
| [Attenuators](@ref) | `Attenuator` | `settransmission`, `gettransmission`, `setdrivevoltage`, `getdrivevoltage` | `LCC1620` | |
| [Spatial light modulators](@ref) | `SLM` | `displayimage`, `displayzernike`, `displayblaze` | `MLSLM` | |
| [Triggerscope](@ref) | `TRIG` | channel values and ranges, for the control panel | `Triggerscope4` | |

`SLM` and `TRIG` are not subtypes of `AbstractInstrument`, and the Opal Kelly boards (`XEM`, `XEM_dac`, on the DAQ
page) have no abstract type; each has its own lifecycle functions, documented with the type.

The simulated devices need no hardware. The test suite runs on them, and so does the [Quick start](@ref).

Images follow one layout everywhere: an image is a column-major `(height, width)` array indexed `[y, x]`, a stack
is `(height, width, frames)`, and `[1, 1]` is the top-left pixel. [Image layout](@ref) has the details.

## Where to go next

- [Quick start](@ref): a camera, a stage and a light source, run on the simulated devices, saved to HDF5.
- The API pages, one per device class: the interface first, then the simulated device, then each driver, then the
  driver internals.
- [Image layout](@ref): the array convention, where drivers transpose and what `save_h5` records.
- `install_skills()`: Claude Code skills for a downstream repository that builds an instrument from these
  devices or writes a driver against them (see the README).
