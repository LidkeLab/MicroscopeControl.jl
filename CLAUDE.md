# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Run tests
julia --project -e 'using Pkg; Pkg.test()'

# Run tests with coverage
julia --project -e 'using Pkg; Pkg.test(coverage=true)'

# Load package in REPL for development
julia --project -e 'using Pkg; Pkg.instantiate(); using MicroscopeControl'

# Install as development package
julia -e 'using Pkg; Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")'
```

Tests use simulated devices only (`SimCamera`, `SimStage`, `SimLight`) - no hardware required.

## Architecture

MicroscopeControl.jl uses a **three-layer architecture** leveraging Julia's multiple dispatch:

```
┌─────────────────────────────────────────────────────────────┐
│  MicroscopeControl.jl (main module)                         │
│  Re-exports all types and functions for user convenience    │
├─────────────────────────────────────────────────────────────┤
│  hardware_interfaces/          │  hardware_implementations/ │
│  Abstract types + contracts    │  Concrete device drivers   │
│  - CameraInterface             │  - SimulatedCamera, DCAM4  │
│  - StageInterface              │  - SimulatedStage, PI, MCL │
│  - LightSourceInterface        │  - SimulatedLight, TCube   │
│  - DAQInterface                │  - NIDAQcard               │
│  - SLMInterface                │  - OK_XEM (FPGA)           │
└─────────────────────────────────────────────────────────────┘
```

### Core Pattern

All hardware inherits from `AbstractInstrument` (defined in `instrument.jl`):
- `initialize(device)` - setup hardware connection
- `shutdown(device)` - close hardware connection
- `export_state(device)` - returns `(attributes::Dict, data, children::Dict)`

Interfaces define method signatures with `@error "not implemented"` stubs. Implementations provide concrete methods that dispatch on the device type.

### Adding New Hardware

1. Create directory under `hardware_implementations/your_device/`
2. Create `types.jl` with struct inheriting from interface type (e.g., `Camera`, `Stage`, `LightSource`)
3. Create `interface_methods.jl` implementing required interface functions
4. Add module to `HardwareImplementations.jl`
5. Re-export types/functions in main `MicroscopeControl.jl`

### Key Interface Methods

**Camera**: `capture`, `live`, `sequence`, `abort`, `getlastframe`, `getdata`, `setexposuretime`, `setroi!`

**Stage**: `move`, `getposition`, `getrange`, `stopmotion`

**LightSource**: `setpower`, `light_on`, `light_off`

**DAQ**: `showdevices`, `showchannels`, `createtask`, `setvoltage`, `readvoltage`, `deletetask`

### GUI Components

Each interface has optional `gui.jl` with GLMakie-based control panels. Access via `gui(device)`.

### C Library Bindings

Hardware implementations use `ccall` for vendor SDKs:
- `dcam4_camera/dcamapi*.jl` - Hamamatsu DCAM4
- `pi_n472/functions_GCS2.jl` - PI GCS2 protocol
- `tcube_laser/tcubeapi.jl` - Thorlabs TCube
- `ok_xem/functions_okFP.jl` - Opal Kelly FrontPanel
