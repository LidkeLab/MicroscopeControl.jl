# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Run all tests
julia --project -e 'using Pkg; Pkg.test()'

# Run tests with coverage
julia --project -e 'using Pkg; Pkg.test(coverage=true)'

# Run specific test interactively (useful for debugging)
julia --project -e 'using MicroscopeControl, Test; @testset "Simulated Camera" begin cam=SimCamera(); @test initialize(cam)===nothing end'

# Load package in REPL for development
julia --project -e 'using Pkg; Pkg.instantiate(); using MicroscopeControl'

# Install as development package
julia -e 'using Pkg; Pkg.develop(url="https://github.com/LidkeLab/MicroscopeControl.jl.git")'
```

Tests use simulated devices only (`SimCamera`, `SimStage`, `SimLight`) - no hardware required. Test sets: "Simulated Camera", "Simulated Stage", "Simulated Light Source", "Export State".

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
- `export_state(device)` - returns `(attributes::Dict, data, children::Dict)` for HDF5 serialization

Interfaces define method signatures with `@error "not implemented"` stubs. Implementations provide concrete methods that dispatch on the device type.

### Data Persistence

`h5_file_saving.jl` provides `save_h5(filename, device)` and `save_attributes_and_data(group, device)` for saving device state to HDF5 files using the `export_state` tuple format.

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
- `mcl_stage/*.jl` - Mad City Labs NanoDrive
- Serial devices (CrystaLaser, Vortran, Triggerscope) use `LibSerialPort`

### Camera Image Data Convention

**Convention:** Image data is stored and displayed as column-major `(H, W, N)` arrays where `data[row, col]` = `data[y, x]`.

**At DLL boundary (getdata):** C SDKs return row-major buffers. Must permute after reshape:
```julia
# WRONG: reshape(buffer, (W, H)) - Julia reads column-first, data is transposed
# CORRECT: permutedims(reshape(buffer, (W, H)), (2, 1)) -> (H, W)
```

**Display (Makie image/heatmap):** Both `image()` and `heatmap()` map dim1→x, dim2→y. For `(H, W)` data:
```julia
# Both work the same way:
image(permutedims(data); axis=(yreversed=true,))    # W→x, H→y, origin top-left
heatmap(permutedims(data); axis=(yreversed=true,))  # W→x, H→y, origin top-left
```

**Saving (HDF5):** No transform needed if getdata follows convention. Save `(H, W, N)` directly.

### Work in Progress

Some hardware modules are commented out in `MicroscopeControl.jl` while under development:
- `Triggerscope` - external trigger synchronization
- `MCLMicroPositioner` - Mad City Labs microdrive positioner
