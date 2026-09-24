---
name: mc-testing
description: Validate a composed MicroscopeControl.jl instrument's behaviour and failure handling without hardware -- what a system test must establish, which simulator or fake serves each claim, matching dimensionality and adapting where semantics differ, running headless under xvfb, and stating what hardware acceptance must still establish; activates for "test", "simulate", "no hardware", "headless", "CI", "acceptance", or "does it work on the rig".
---

# mc-testing

The simulators are a means, not the subject. A system test establishes
something about *your instrument*: that it comes up and goes down in the right
order, refuses unsafe requests, records what it did, and fails visibly. Choose
the simulator or fake that lets you assert that, then write down what the test
did **not** prove, because that is the hardware acceptance list. Labels as in
`mc-system-design`: **[guarantee]** verified at MC v0.2.0, **[limitation]** current
shortfall, **[policy]** recommended. Everything marked executed ran under
`xvfb-run -a` on v0.2.0.

## What to establish, with what, and what remains

| Claim about the system | Establish it with | Still unproven afterwards |
|---|---|---|
| every device the system holds has its **own** `initialize`/`shutdown`/`export_state` method, so no lifecycle call lands on the throwing `AbstractInstrument` stub | the dispatch check below, on the *hardware* types too (it needs no hardware) | that the method works: dispatch establishes method selection only. A concrete method can throw on the hardware path (`initialize(::Triggerscope4)` opens the serial port with `LibSerialPort.open`, which throws on a missing port; traced), log and return (`initialize(::PIStage)` `@error`s and leaves `connectionstatus == false`), or do nothing useful (`stopmotion(::MCLStage)` logs `STOP MOTION NOT IMPLEMENTED` and returns `nothing`; executed). The check does catch the fourth case, a missing method: `ThorCamCSCCamera` has no `initialize`, so dispatch reaches the throwing stub |
| `initialize` rolls back what it opened when a later device fails, including devices claimed at construction | Sim devices plus a bare `struct Broken <: LightSource end` whose stubs throw, and a fake that is "open" from its constructor (`mc-system-design`, worked example) | that a real SDK's failure surfaces as an exception rather than an `@error` and a normal return, which most drivers do (`mc-extend`, section 1) |
| the camera is used single-owner and single-acquisition: one blocking acquisition at a time, `set_state` refused in flight, a failed abort makes it unavailable until rebuilt | `SimCamera` (`sequence_length = -1` makes `getdata` throw; a fake whose `abort` throws) | frame timing, trigger behaviour, buffer lifetime; and nothing about stopping early, because the drivers' own tasks cannot be joined (`mc-system-design`, Decision 3) |
| the saved record names what is missing | a child whose `export_state` throws, through `save_h5`, read back | that hardware attributes are readbacks rather than cached requests |
| array shapes and the `(H, W, N)` convention survive to the file | `SimCamera` with a non-square `roi` (`CameraROI(1, 1, 64, 32)` gives `(32, 64)`) | that the vendor buffer was permuted correctly (`mc-acquire`) |
| ordering and units of a z-stack | `SimStage3d` (`move` writes `targ_*`, `getposition` copies to `real_*`) | motion time, settling, range limits, direction sign |
| the shared panels open for every device | `gui(dev)` under `xvfb-run -a` for cameras and lights | **[limitation]** cannot be written for the Sim stages today, see below |

## What bites first: the load needs a display

`using MicroscopeControl` pulls in GLMakie; on a headless Linux box the **load
itself** fails during GLFW initialization (executed with `DISPLAY` unset):

```
ERROR: InitError: Exception[GLFW.GLFWError(65550, "X11: The DISPLAY environment variable is missing"), ErrorException("glfwInit failed")]
```

Run every Julia process that loads the package under `xvfb-run -a` (`-a` picks a
free display, so parallel jobs do not collide); upstream CI does exactly this.
Serial-port and vendor-SDK drivers are loaded, not opened, at `using` time, so a
machine with no hardware or DLLs loads the package fine.

## The simulated devices, and what they do not simulate

| Type | Constructor | Key fields and defaults |
|---|---|---|
| `SimCamera` | keyword, all defaulted | `exposure_time=0.1` (s), `roi=CameraROI(1, 1, 1024, 1024)`, `sequence_length=10`, `capture_mode=LIVE`, `is_running=false` |
| `SimStage3d` / `SimStage2d` / `SimStage1d` | `Base.@kwdef` | `dimensions=3/2/1`, `range_*=(0, 100)`, `real_*=0.0`, `targ_*=0.0`, `connectionstatus=false`, `label` |
| `SimLight` | keyword | `properties=LightSourceProperties("mW", 0.0, false, 0.0, 100.0)` |

All implement `initialize`, `shutdown`, `export_state` **[guarantee]**. There is no
simulated DAQ, attenuator, Triggerscope or SLM; for those, write a fake behind
the driver's transport (the `FakePort` pattern in `mc-extend`'s
`references/driver-scaffold.md`) or a system-level stand-in.

Honestly, per device (executed):

- **SimCamera.** Every frame is `rand(UInt16, roi.height, roi.width)`: no image
  content, no exposure scaling, no trigger behaviour, no `camera_format`
  coupling (the ROI may exceed the sensor). `getlastframe` sleeps
  `exposure_time`; `getdata` does not. `sequence` sets `is_running` and an
  `@async` task clears it after `sequence_length * exposure_time`; `getdata`
  returns `(H, W, N)` immediately regardless. **`capture` returns the enum it
  set (`SINGLE_FRAME`), not a frame.** `setexposuretime!`/`setroi!`/
  `settriggermode!` throw. The live-view buffer race in `mc-acquire` cannot
  happen here.
- **SimStage3d/2d/1d.** `move` writes `targ_*`; `getposition` copies `targ_*`
  into `real_*` and **returns the last assignment, a scalar** (`3.0` after
  `move(s, 1.0, 2.0, 3.0)`), not the documented tuple; read `real_*`. No motion
  time, no range enforcement (`move(stage, 1e6, 0.0, 0.0)` succeeds), servo and
  drift flags are stored only. `home` zeroes `real_*` but not `targ_*`. Every
  call `println`s a status line. `move` is `Float64`-only.
- **SimLight.** `setpower` writes `properties.power` with no clamp;
  `light_on`/`light_off` toggle `is_on`; `initialize` turns it **on**,
  `shutdown` off. 2-arg `light_on(light, power)` throws (interface arity
  mismatch shared by every light).

Good for: dispatch, composition, lifecycle order, state round trips,
`export_state`/`save_h5` tree shape, array shapes, refusal logic. Not good for:
timing, SDK error paths, buffer lifetimes, hardware limits, units.

## One constructor, two backends: match dimensionality, adapt semantics

**[policy]** Type the struct fields by interface and decide the backend in one
place. **[limitation]** the swap is not free: interface subtypes share dispatch,
not behaviour (`mc-system-design`, Principle 6). Two rules make it honest:

1. **Match dimensionality.** `PIStage` is two-axis (`dimensions = 2`,
   `move(stage, x, y)`), so its simulator is `SimStage2d`, not `SimStage3d`. A
   3-axis Sim would let `move(stage, x, y, z)` pass in tests and hit the throwing
   `Stage` fallback on the rig.
2. **Adapt where semantics differ, in one tested place.** `capture` returns an
   enum on `SimCamera` and the frame on `DCAM4Camera`/`ThorcamDCXCamera`
   (traced, `mc-acquire`). Code that does `frame = capture(cam)` works on one
   and not the other, so the system owns a `snap` that hides it.

Executed:

```julia
using MicroscopeControl
const MC = MicroscopeControl

mutable struct Rig <: AbstractSystem
    cam::Camera
    stage::Stage           # two-axis on this rig; the Sim MUST be two-axis too
    laser::LightSource
end

function Rig(; simulate::Bool = get(ENV, "RIG_SIMULATE", "false") == "true")
    if simulate
        Rig(SimCamera(exposure_time=0.01, roi=CameraROI(1, 1, 64, 32)), SimStage2d(), SimLight())
    else
        Rig(DCAM4Camera(), PIStage(), CrystaLaser())   # placeholder for your constructors; not executed here
    end
end

# The adapter: one place that knows capture's return value differs per driver.
snap(cam::SimCamera) = (capture(cam); getlastframe(cam))   # executed: (32, 64)
snap(cam::Camera)    = capture(cam)                        # DCAM4, DCX, CSC return the frame (traced)
```

The hardware branch is not side-effect free the way the Sim branch is:
`DCAM4Camera()` opens the camera and `CrystaLaser()` runs NI-DAQ discovery at
construction (`mc-system-design`, `references/driver-caveats.md`). Set
`RIG_SIMULATE=true` in the test environment and the whole
`initialize`/acquire/`export_state`/`shutdown` path runs with no hardware.

## Tests, executed against `Rig(simulate=true)`

The dispatch check is upstream's own (`test/contract.jl`): ask where dispatch
lands and fail if it is the throwing stub. It works on hardware types without
hardware, so run it against **both** branches:

```julia
using Test
has_specific(f, T, args...) =
    hasmethod(f, Tuple{T, args...}) && which(f, Tuple{T, args...}).sig.parameters[2] === T

@testset "devices satisfy the lifecycle contract" begin
    for T in (SimCamera, SimStage2d, SimLight,          # Sim branch
              DCAM4Camera, PIStage, CrystaLaser)         # hardware branch: types only, nothing constructed
        @test has_specific(initialize, T)
        @test has_specific(shutdown, T)
        @test has_specific(export_state, T)
        @test which(gui, Tuple{T}).sig.parameters[2] !== AbstractInstrument
    end
end
```

All 24 assertions pass for these six types (executed). Substitute your rig's
types; today the same loop fails for `ThorCamCSCCamera` (`initialize`,
`export_state`), naming the device that would throw during `shutdown` before it
does. `TCubeLaser` failed the `export_state` assertion too until **v0.2.3**, whose
`export_state(::TCubeLaser)` is the 1-argument method that was missing; the old
`export_state(::TCubeLaser, sth)` remains as a deprecated forwarder rather than
being deleted. An installed copy of this skill older than v0.2.3 still lists
`TCubeLaser` as failing.

Behavioural tests on top, executed:

```julia
@testset "acquisition through the adapter" begin
    rig = Rig(simulate=true); initialize(rig)
    @test size(snap(rig.cam)) == (32, 64)                 # (H, W): roi height 32, width 64
    rig.cam.sequence_length = 5
    sequence(rig.cam)
    while rig.cam.is_running == 1; sleep(0.01); end        # join the completion signal before reading
    @test size(getdata(rig.cam)) == (32, 64, 5)
    shutdown(rig)                                          # you define MC.shutdown(::Rig)
end

@testset "two-axis stage stays two-axis" begin
    rig = Rig(simulate=true)
    move(rig.stage, 1.0, 2.0)
    @test (rig.stage.targ_x, rig.stage.targ_y) == (1.0, 2.0)
    # Julia dispatches on the RUNTIME type, SimStage2d. No 3-arg `move` exists for it, but the
    # interface fallback `move(::Stage, ::Float64, ::Float64, ::Float64)` does match, so the call
    # lands there and throws ErrorException("move not implemented for SimStage2d"), not a MethodError.
    @test_throws ErrorException move(rig.stage, 1.0, 2.0, 3.0)
end

@testset "state file tree names its children" begin
    rig = Rig(simulate=true); initialize(rig)
    attributes, data, children = export_state(rig)         # you define MC.export_state(::Rig)
    fn = joinpath(mktempdir(), "state.h5")
    wait(save_h5(fn, (attributes, data, children)))         # save_h5 is @async; wait before reading
    MC.HDF5.h5open(fn, "r") do h
        @test Set(keys(h["Main"])) == Set(["cam", "stage", "laser"])
    end
    shutdown(rig)
    @test rig.laser.properties.is_on == false
end
```

For rollback, refused `set_state` during acquisition, a recorded missing child
and an observable shutdown failure, run the `Bench` example in
`mc-system-design` as a testset; it executed there with the outcomes tabulated.
Silence the Sim stage's `println` chatter with `redirect_stdout(devnull) do ... end`
if it bothers CI; it is not an error.

## GUI smoke tests: possible for cameras and lights, not for Sim stages

**[limitation]**, executed: `gui(SimStage1d())`, `gui(SimStage2d())` and
`gui(SimStage3d())` all throw `FieldError: type SimStage3d has no field stagelabel`.
The shared stage panel reads `stage.stagelabel` unguarded for its window title
and the Sim stages carry `label`. So a "every panel opens" smoke test cannot be
written against the simulated stages as of 0.2.1; `gui(SimCamera())` and
`gui(SimLight())` open (executed), as do `gui(PIStage())`, `gui(MCLStage())` and
`gui(MCS2Stage())` with no hardware attached, because those constructors are
pure. **Fixed in 0.2.1:** `gui(::LightSource)` used to call
`setpower(light, 0.5)` on open (executed against a fake-transport light,
before the fix); opening **the shared light panel** is now observably
read-only. That is the scope of the fix: it says nothing about the other
panels, and `gui(::DAQ)` in particular still queries `showdevices` and
`showchannels` at construction. (`test/gui.jl` is the upstream regression
test: it snapshots `export_state(dev)` before and after `gui(dev)` for every
Sim device, and additionally opens the light panel on a recording light whose
`setpower`/`light_on`/`light_off` log every call, asserting the log is empty.
The state snapshot alone cannot catch the defect, because the widgets now
initialise from the device's own values.) One remaining fact for a GUI test: the camera panel
uses `capture`'s return value as the frame, so "Start Capture" misbehaves on
`SimCamera`. Test the panels you can; list the rest under hardware
acceptance.

## CI recipe

Upstream's `.github/workflows/CI.yml` (Ubuntu):

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

Both halves matter: the background `Xvfb :99` plus `DISPLAY` covers
precompilation in `julia-buildpkg`, the `xvfb-run -a` prefix covers the test
process. Add `RIG_SIMULATE: "true"` to the job `env`. Pin MicroscopeControl.jl
to a tag (`Pkg.add(url=..., rev="v0.2.0")`) and rerun `install_skills()` after
moving it so the API map matches what CI tests against.

## What hardware acceptance must still establish

**[policy]** Write this list into the rig repo and tick it on the instrument,
because nothing above touches it:

- each device's `initialize` leaves it *usable*, not just returned
  (`connectionstatus`, a position readback, a real frame, non-empty channel
  lists on the DAQ-backed lights);
- units, direction signs and range limits on every axis; ROI origin convention
  and exposure unit on the camera (`mc-acquire`, per-driver table);
- timing: settling after `move`, `sequence` completion, live-view stop order
  (`mc-acquire`), and that a failed acquisition's `abort` leaves the SDK in a
  state the next acquisition can use (the Sim cannot show this). (Opening a
  light panel no longer commands power as of 0.2.1, so that is no longer a
  hardware-acceptance item — see the GUI smoke test section above.)
- SDK failure paths: what `capture` returns on failure per driver (`nothing`,
  or `ThorCamCSCCamera`'s silent all-zero frame);
- shared-connection ownership: two attenuators on one `Triggerscope4`, and that
  `shutdown(att)` means 0 V, full transmission, on an LCC1620;
- that saved attributes are readbacks where you assumed they were.

Record device, firmware, pinned tag and the date beside each tick; upstream
does not track hardware verification.
