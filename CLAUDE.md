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

### Testing policy: local first, CI as confirmation

**Run the full local suite before every push.** CI is confirmation, never the
first signal that a change works. Actions minutes are a shared, finite
resource, and a workflow re-run is not a cheap way to find out whether code
compiles.

```bash
# the gate, before any push
xvfb-run -a julia --project -e 'using Pkg; Pkg.test()'

# before a release, or when touching anything version-sensitive, also run the
# OLDEST supported version, which CI no longer runs on pull requests
xvfb-run -a ~/.julia/juliaup/julia-1.11*/bin/julia --project -e 'using Pkg; Pkg.test()'
```

What CI actually runs, deliberately thin (`.github/workflows/CI.yml`):
- **pull request**: one Julia version, the version-bump check, no docs build,
  and nothing at all when the change touches only `docs/`, `README.md`,
  `CHANGELOG.md`, `CLAUDE.md` or `LICENSE`.
- **push to `main` / tags**: the full version matrix, coverage upload, and the
  docs build — once, where the tag is actually cut.
- Full signal on a branch without opening a pull request:
  `gh workflow run CI.yml --ref <branch>`.

Batch fixups into one push rather than pushing each review round separately;
every push to an open pull request starts a fresh run.

Tests use simulated devices only (`SimCamera`, `SimStage3d`/`SimStage2d`/`SimStage1d`, `SimLight`) - no hardware required. GLMakie needs a display: run under `xvfb-run -a` on a headless Linux box (CI does this). Test sets: "Simulated Camera", "Simulated Stage", "Simulated Light Source", "Export State".

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
│  - AttenuatorInterface         │  - LCC1620                 │
└─────────────────────────────────────────────────────────────┘
```

### Core Pattern

All hardware inherits from `AbstractInstrument` (defined in `instrument.jl`):
- `initialize(device)` - setup hardware connection
- `shutdown(device)` - close hardware connection
- `export_state(device)` - returns `(attributes::Dict, data, children::Dict)` for HDF5 serialization
- `gui(device)` - open a GUI control panel for the device

Interfaces define method signatures with throwing `error("<name> not implemented for $(typeof(...)))")` stubs (see `test/contract.jl`'s "Interface Contract" testset). Implementations provide concrete methods that dispatch on the device type.

### Data Persistence

`h5_file_saving.jl` provides `save_h5(filename, state_tuple)`, where `state_tuple` is the `(attributes, data, children)` tuple returned by `export_state` (not the device itself). It runs on an `@async` task and returns that `Task`; `wait` it before reading the file. The synchronous form is `save_attributes_and_data(filename, group, attributes, data, children)`; `save_h5` calls it with `group = "Main"`. Children are further `(attributes, data, children)` tuples, written recursively as HDF5 groups.

### Adding New Hardware

1. Create directory under `hardware_implementations/your_device/`
2. Create `types.jl` with struct inheriting from interface type (e.g., `Camera`, `Stage`, `LightSource`)
3. Create `interface_methods.jl` implementing required interface functions
4. Add module to `HardwareImplementations.jl`
5. Re-export types/functions in main `MicroscopeControl.jl`

### Key Interface Methods

**Camera**: `capture`, `live`, `sequence`, `abort`, `getlastframe`, `getdata` (exposure and ROI are set through the `exposure_time` and `roi::CameraROI` fields)

**Stage**: `move`, `getposition`, `getrange`, `stopmotion`

**LightSource**: `setpower`, `light_on`, `light_off`

**DAQ**: `showdevices`, `showchannels`, `createtask`, `setvoltage`, `readvoltage`, `deletetask`

**Attenuator**: `setdrivevoltage`, `getdrivevoltage`, `settransmission`, `gettransmission`, `set_calibration!`

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

### Claude Code Skills

`skills/` holds the sources for Claude Code skills that `install_skills()`
copies into a downstream repo's `.claude/skills/` (see `src/skills.jl` and
the README's "Claude Code skills" section). `list_skills()` reads the
directory, so adding a skill is adding a directory with a `SKILL.md`; only
`test/skills.jl`'s expected-name list needs a matching edit. The five skills
are `mc-system-design` (entry point; design and composition), `mc-extend`
(diagnose, report/work around, implement an interface, define an interface),
`mc-acquire`, `mc-testing` and `mc-api-map` (whose `references/gui-fields.md`
is hand-written and tracked, unlike the generated map). Every architectural
statement in a skill is labelled as an
existing guarantee, a current limitation, or a recommended system policy;
keep that discipline when editing them. `mc-api-map`'s
`references/api-map.md` is generated at install time by introspecting the
loaded module and must never be committed; the repo-tracked `references/`
directory holds only the `.gitkeep` placeholder and the hand-written
`gui-fields.md`.

### Work in Progress

Some hardware modules are commented out in `MicroscopeControl.jl` while under development:
- `MCLMicroPositioner` - Mad City Labs microdrive positioner

### Versioning

This package is 0.x and not yet registered; install a pinned tag per the README's Installation Notes. **Work accumulates on a release-candidate branch between releases.** `main`
is what gets tagged; a branch named like `0.3rc1` is where fixes for the next
release collect. Open sub-branches and merge them into the release-candidate
branch with a pull request as usual; the version in `Project.toml` does **not**
move per merge, only once when the release is cut. CI knows: the version-bump
check runs only for pull requests into `main`, and a merge into a
release-candidate branch runs the full matrix because it is an integration
point. Keep `main` open for genuine safety hotfixes, tagged as patches, and
merge `main` into the release-candidate branch whenever one lands — the drift
is the standing cost of this arrangement and merging forward promptly is what
keeps it small.

Policy, following Julia's pre-1.0 convention: while the version is `0.x.y`, **`x` is the breaking component and `y` is the non-breaking one** -- `0.2.0 -> 0.3.0` declares a breaking release and `0.2.0 -> 0.2.1` a compatible one, which is also how Julia's `^0.2` compat bound reads them. So bump `x` only when working downstream code can behave differently (a signature, an export, or what a call returns or throws), and bump `y` for everything else, including bug fixes that change behaviour on a path that was already broken. Every merge to `main` is tagged automatically by `.github/workflows/TagOnMerge.yml`. Hardware verification is not tracked in this repo; it is recorded by the downstream rig repo that pins to a given tag. The merge gate is the local suite (see "Testing policy" above) plus `test/contract.jl`'s "Interface Contract" testset, which guards the no-ambiguous-exports and core-method invariants described above; CI confirms it on a reduced matrix.
