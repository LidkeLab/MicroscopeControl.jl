---
name: mc-sim-testing
description: Testing downstream instrument code against MicroscopeControl.jl's SimCamera, SimStage1d/2d/3d and SimLight, swapping simulated for real devices behind one constructor, running headless under xvfb, and asserting the interface contract on a composed system; activates for "test", "simulate", "no hardware", "headless", or "CI".
---

# mc-sim-testing

Everything below was executed on MicroscopeControl.jl v0.2.0 under `xvfb-run -a`.

## What bites first

Loading the package needs a display. `using MicroscopeControl` pulls in GLMakie,
and on a headless Linux box with no X server the **load itself** fails during GLFW
initialization (executed on v0.2.0 with `DISPLAY` unset):

```
ERROR: InitError: Exception[GLFW.GLFWError(65550, "X11: The DISPLAY environment variable is missing"), ErrorException("glfwInit failed")]
during initialization of module GLFW
```

Nothing downstream of `using` runs, so this looks like a broken package rather than
a missing display. Run every Julia process that loads the package under
`xvfb-run -a`:

```bash
xvfb-run -a julia --project -e 'using Pkg; Pkg.test()'
xvfb-run -a julia --project test/runtests.jl
```

`-a` picks a free display number, so parallel CI jobs do not collide. The upstream
CI does exactly this. On a workstation with a real display nothing is needed.
Serial-port and vendor-SDK drivers are only loaded, not opened, at `using` time, so a
machine without any hardware or SDK DLLs loads the package fine.

## The simulated devices

| Type | Interface | Constructor | Key fields and defaults |
|---|---|---|---|
| `SimCamera` | `Camera` | keyword, all defaulted | `exposure_time=0.1` (s), `roi=CameraROI(1, 1, 1024, 1024)`, `sequence_length=10`, `camera_format=CameraFormat(1024, 1024, 6, 2, "SCMOS")`, `capture_mode=LIVE`, `is_running=false` |
| `SimStage3d` | `Stage` | `Base.@kwdef` | `range_x/y/z=(0, 100)`, `real_*=0.0`, `targ_*=0.0`, `connectionstatus=false`, `dimensions=3` |
| `SimStage2d` | `Stage` | `Base.@kwdef` | same, two axes, `dimensions=2` |
| `SimStage1d` | `Stage` | `Base.@kwdef` | `range_x`, `real_x`, `targ_x`, `dimensions=1`, scalar `servostatus` |
| `SimLight` | `LightSource` | keyword | `properties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0)` (unit, power, is_on, min, max) |

All five implement `initialize`, `shutdown`, `export_state`, and get `gui` from
their interface. There is no simulated DAQ, attenuator, Triggerscope or SLM.

## What they simulate, honestly

- **SimCamera.** Every frame is `rand(UInt16, roi.height, roi.width)`. No image
  content, no exposure scaling, no trigger behaviour, no `camera_format` coupling
  (the ROI can exceed the sensor and nothing complains). `getlastframe` sleeps
  `exposure_time` first; `getdata` does not sleep. `sequence` sets `is_running` and
  clears it from an `@async` task after `sequence_length * exposure_time` seconds;
  `getdata` returns the `(H, W, N)` array immediately regardless. `capture` returns
  the enum it set (`SINGLE_FRAME`), not a frame. `setexposuretime!`/`setroi!`/
  `settriggermode!` are not implemented and throw. The live-view buffer race
  described in `mc-acquire` cannot happen here, so a test that passes on
  `SimCamera` says nothing about stop order on hardware.
- **SimStage3d/2d/1d.** `move` writes `targ_*`; `getposition` copies `targ_*` into
  `real_*`. No motion time, no range enforcement (`move(stage, 1e6, 0.0, 0.0)`
  succeeds), no servo or drift-correction effect beyond storing the flags. `home`
  zeroes `real_*` but not `targ_*`. Every call `println`s a status line, so expect
  noise in test logs. `move` is `Float64`-only; integers are a `MethodError`.
- **SimLight.** `setpower` writes `properties.power` with no min/max clamp;
  `light_on`/`light_off` toggle `properties.is_on`. `initialize` turns it on,
  `shutdown` turns it off. The 2-arg `light_on(light, power)` throws (interface
  arity mismatch shared by every light source).

What the simulators are good for: dispatch, composition, lifecycle order, state
round trips, `export_state`/`save_h5` tree shape, array shapes. What they are not
good for: timing, error paths, buffer lifetimes, hardware limits.

## One constructor, two backends

Type the struct fields by interface, decide the backend in one place, and keep
everything downstream of the constructor identical:

```julia
using MicroscopeControl
const MC = MicroscopeControl

mutable struct Rig <: AbstractSystem
    cam::Camera
    stage::Stage
    laser::LightSource
end

function Rig(; simulate::Bool = get(ENV, "RIG_SIMULATE", "false") == "true")
    if simulate
        Rig(SimCamera(exposure_time=0.01), SimStage3d(), SimLight())
    else
        Rig(DCAM4Camera(), PIStage(), CrystaLaser())   # replace with your rig's constructors and arguments
    end
end
```

The hardware branch above is a placeholder for your drivers' constructor calls
and was not executed; consult the API map for each device's fields. Note that
`DCAM4Camera()` opens the camera and `CrystaLaser()` runs NI-DAQ discovery at
construction (see `mc-wire-device`, "Constructor side effects"), so the hardware
branch is not free of side effects the way the Sim branch is. Abstract field
types cost a dynamic dispatch per call, which is irrelevant at camera frame rates.
Set `RIG_SIMULATE=true` in the test environment (or pass `simulate=true` from the
test) and the whole `initialize`/acquire/`export_state`/`shutdown` path runs with
no hardware.

## Asserting the contract on a composed system

`test/contract.jl` upstream is the model: rather than calling every method, it
asks where dispatch lands and fails if that is the throwing stub. The check works
on any type, so a downstream test can assert that every device in the system
implements the lifecycle before the rig ever sees a `shutdown` loop that throws
halfway. This ran green on the Sim devices:

```julia
using MicroscopeControl, Test

has_specific(f, T, args...) =
    hasmethod(f, Tuple{T, args...}) && which(f, Tuple{T, args...}).sig.parameters[2] === T

@testset "Rig devices satisfy the instrument contract" begin
    rig = Rig(simulate=true)
    for dev in (rig.cam, rig.stage, rig.laser)
        T = typeof(dev)
        @test has_specific(initialize, T)
        @test has_specific(shutdown, T)
        @test has_specific(export_state, T)
        # gui is legitimately shared at the interface level; only the
        # AbstractInstrument stub counts as missing
        @test which(gui, Tuple{T}).sig.parameters[2] !== AbstractInstrument
    end
    @test has_specific(export_state, Rig)
end
```

Run the same testset with `simulate=false` on the rig machine. Today it will fail
for `ThorCamCSCCamera` (`initialize`, `export_state`) and `TCubeLaser`
(`export_state`), which is the point: it names the device that will throw during
shutdown before that happens.

Behavioural tests on top. The statements below were executed against a Sim-only
system struct (the `Bench` example in `mc-wire-device`); substitute your own type:

```julia
@testset "acquisition shapes" begin
    cam = SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32))
    capture(cam);  @test size(getdata(cam)) == (32, 64)
    cam.sequence_length = 5
    sequence(cam); @test size(getdata(cam)) == (32, 64, 5)
    live(cam);     @test size(getlastframe(cam)) == (32, 64)
    cam.is_running = false; abort(cam)
    @test cam.is_running == false
end

@testset "state file tree" begin
    rig = Rig(simulate=true); initialize(rig)
    attributes, data, children = export_state(rig)      # you define MC.export_state(::Rig)
    fn = joinpath(mktempdir(), "state.h5")
    wait(save_h5(fn, (attributes, data, children)))       # save_h5 is @async; wait before reading
    MicroscopeControl.HDF5.h5open(fn, "r") do h
        @test Set(keys(h["Main"])) == Set(["cam", "stage", "laser"])   # your children keys
    end
    shutdown(rig)
    @test rig.laser.properties.is_on == false
end
```

Silence the Sim stage's `println` chatter in CI with `redirect_stdout(devnull) do
... end` around the stage calls, or accept it; it is not an error.

## CI recipe

This is what the upstream `.github/workflows/CI.yml` does (Ubuntu runner):

```yaml
- uses: julia-actions/setup-julia@v3
  with:
    version: ${{ matrix.version }}
- name: Start virtual X display
  run: |
    sudo apt-get update
    sudo apt-get install -y xvfb
    Xvfb :99 -screen 0 1280x1024x24 &
    echo "DISPLAY=:99" >> "$GITHUB_ENV"
- uses: julia-actions/julia-buildpkg@v1
- uses: julia-actions/julia-runtest@v1
  with:
    prefix: xvfb-run -a
```

Both halves matter: the background `Xvfb :99` plus `DISPLAY` covers precompilation
in `julia-buildpkg`, and the `xvfb-run -a` prefix covers the test process. Add
`RIG_SIMULATE: "true"` to the job `env` if you use the constructor switch above.

Pin MicroscopeControl.jl to a tag in the downstream `Project.toml`/`Manifest.toml`
(`Pkg.add(url=..., rev="v0.2.0")`); the package is unregistered and every merge to
`main` is tagged. Reinstall the skills (`install_skills()`) after moving the pin so
the API map matches what CI tests against.
