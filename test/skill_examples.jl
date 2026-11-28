# The skills' executed examples. `test/skills.jl` runs this file as a script in its own Julia process, so the types
# and methods the examples define never reach the rest of the suite (`test/contract.jl` walks the interface subtypes,
# and `install_skills` lists every method it finds). `test/skills.jl` also includes it, for `SKILL_EXAMPLE_GROUPS`
# and the fence reader only: everything above the script section defines strings and functions, no types.
#
# A julia fence preceded by `<!-- mc-test: NAME -->` belongs to group NAME. Every fence of a group (in file order, the
# files in path order) is joined and evaluated in one fresh module that loads nothing: the group's own prelude
# supplies what the fences do not, and a group can run another group's fences first (`SKILL_GROUP_USES`). Then the
# group's checks run, after `using Test, MicroscopeControl` and `import GLMakie`. A fence line `code  # -> VALUE`, or
# a line `# -> VALUE` after an expression, states that expression's value: the harness asserts it, so the stated value
# is the asserted one. A statement the suite checks is labeled `suite: NAME` in the skill, and `test/skills.jl` fails
# on a label whose NAME is not a group here.

using Test
using MicroscopeControl

const SKILL_MARKER = r"^\s*<!--\s*mc-test:\s*(\S+)\s*-->\s*$"
const SKILL_FENCE = r"^\s*```"

# name => every fence marked with it, in order, as `(file, line, code)` with `line` the fence's first code line. A
# marker inside another fence is that fence's text, not a marker. A marker that is not followed by a julia fence, or a
# fence that is not closed, is an error.
function skill_example_blocks(root::AbstractString)
    groups = Dict{String,Vector{NamedTuple{(:file, :line, :code),Tuple{String,Int,String}}}}()
    files = String[]
    for (dir, _, names) in walkdir(root), n in names
        endswith(n, ".md") && push!(files, joinpath(dir, n))
    end
    for file in sort(files)
        lines = readlines(file)
        i = 1
        in_fence = false
        while i <= length(lines)
            if in_fence                            # only a bare ``` closes a fence
                occursin(r"^\s*```\s*$", lines[i]) && (in_fence = false)
                i += 1
                continue
            end
            if occursin(SKILL_FENCE, lines[i])     # an unmarked fence opens
                in_fence = true
                i += 1
                continue
            end
            m = match(SKILL_MARKER, lines[i])
            if m === nothing
                i += 1
                continue
            end
            i < length(lines) || error("$file:$i: an mc-test marker on the last line has no fence after it")
            fence = match(r"^(\s*)```julia\s*$", lines[i+1])
            fence === nothing && error("$file:$i: an mc-test marker must sit on the line before a ```julia fence")
            indent = length(fence.captures[1])
            j = i + 2
            code = String[]
            while true
                j <= length(lines) || error("$file:$i: the fence after this mc-test marker is not closed")
                occursin(r"^\s*```\s*$", lines[j]) && break
                push!(code, lines[j][min(indent, length(lines[j]) - length(lstrip(lines[j])))+1:end])
                j += 1
            end
            blocks = get!(groups, String(m.captures[1]), NamedTuple{(:file, :line, :code),Tuple{String,Int,String}}[])
            push!(blocks, (file = file, line = i + 2, code = join(code, "\n")))
            i = j + 1
        end
        in_fence && error("$file: a fence is not closed")
    end
    return groups
end

# The value a `# -> VALUE` comment states, and whether it sits on its own line (then it states the value of the
# expression before it) or after code (the expression on its line). The value runs to a further ` #` or the end.
function stated_values(code::AbstractString)
    out = Tuple{Int,Bool,String}[]
    for (n, line) in enumerate(split(code, '\n'))
        m = match(r"^(.*?)#\s*->\s*(.*?)\s*(?:\s#.*)?$", line)
        m === nothing && continue
        push!(out, (n, isempty(strip(m.captures[1])), String(m.captures[2])))
    end
    return out
end

# The Sim stages print a status line per call. Only those lines are dropped from a fence's output; everything else it
# prints, a failing `@test` included, reaches the log.
const SIM_STAGE_NOISE = r"^(Initializing|Shutting down|Moving|Getting|Stopping|Setting) stage\b.*\.\.\.$"
function without_stage_noise(f)
    path, io = mktemp()
    try
        return redirect_stdout(f, io)
    finally
        close(io)
        for line in eachline(path)
            occursin(SIM_STAGE_NOISE, line) || println(line)
        end
        rm(path; force = true)
    end
end

const SKILL_CHECKS_PRELUDE = """
using Test, MicroscopeControl
import GLMakie
# The missing-field exception: a `FieldError` from Julia 1.12, an `ErrorException` before (as in test/gui.jl).
missing_field(e, T, f) = @static if isdefined(Core, :FieldError)
    e isa Core.FieldError && e.type === T && e.field === f
else
    e isa ErrorException && e.msg == "type \$(nameof(T)) has no field \$(f)"
end
"""

# Run in the caller's testset: the prelude, the fences (asserting their stated values), then the checks, in one
# fresh module. Every top-level value of the fences is pushed to the module's `block_values` (the testing fences
# return a testset). `fences` are `skill_example_blocks` entries; `prelude` and `checks` are code.
function run_skill_example(name, fences; prelude = "", checks = "")
    modname = Symbol("SkillExample_", replace(name, '-' => '_'))
    m = Module(modname)
    Core.eval(Main, :($modname = $m))     # bound in Main so `subtypes` finds the types a fence defines, as in a script
    Core.eval(m, :(block_values = Any[]))
    blocks = [(file = "$name prelude", line = 1, code = prelude); fences]
    for b in blocks
        isempty(b.code) && continue
        values = Tuple{Int,Any}[]          # (first line within the fence, value) of each top-level expression
        line = 0
        # Parsed with the fence's file and line, so a failing `@test` in a fence names where it is in the skill.
        for ex in Meta.parseall(b.code; filename = b.file, lineno = b.line).args
            if ex isa LineNumberNode
                line = ex.line - b.line + 1
                continue
            end
            val = without_stage_noise(() -> Core.eval(m, ex))
            push!(values, (line, val))
            Core.eval(m, :(push!(block_values, $(QuoteNode(val)))))
        end
        for (n, alone, text) in stated_values(b.code)
            at = "$(b.file):$(b.line + n - 1)"
            k = alone ? findlast(v -> v[1] < n, values) : findlast(v -> v[1] == n, values)
            k === nothing && error("$at: `# -> $text` follows no expression")
            stated = Core.eval(m, Meta.parse(text))
            ok = isequal(values[k][2], stated)
            ok || @error "a stated value is not the value" group = name at stated = text got = values[k][2]
            @test ok
        end
    end
    Core.eval(m, Meta.parseall(SKILL_CHECKS_PRELUDE))
    isdefined(m, :MC) || Core.eval(m, :(const MC = MicroscopeControl))
    isempty(checks) || for ex in Meta.parseall(checks; filename = "$name checks").args
        ex isa LineNumberNode && continue
        without_stage_noise(() -> Core.eval(m, ex))
    end
    return m
end

# group name => (prelude, checks). The prelude runs before the fences, the checks after; both in the fences' module.
const SKILL_EXAMPLE_GROUPS = Dict{String,NamedTuple{(:prelude, :checks),Tuple{String,String}}}()

# Groups that have checks and no fence: statements the skills make about the package that no example runs.
const SKILL_FENCELESS_GROUPS = ["statements"]

# group => the groups whose fences run first, in its module: the per-driver camera functions in mc-acquire are used
# by the reader there and by mc-system-design's Bench.
const SKILL_GROUP_USES = Dict("acquire-reader" => ["camera"], "bench" => ["camera"])

# A group's fences: those of the groups it uses, then its own.
skill_group_fences(groups, name) = vcat((groups[u] for u in get(SKILL_GROUP_USES, name, String[]))..., get(groups, name, []))

SKILL_EXAMPLE_GROUPS["bench"] = (prelude = "", checks = raw"""
mkcam() = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
message(e) = sprint(showerror, e)
stuck_devices(sys) = first.(sys.stuck)
struct RecLight <: LightSource                   # notes the order of shutdowns
    name::Symbol
    log::Vector{Symbol}
end
MC.shutdown(l::RecLight) = (push!(l.log, l.name); nothing)
mutable struct FailOnceLight <: LightSource      # notes each shutdown; the first fails
    name::Symbol
    log::Vector{Symbol}
    left::Int
end
MC.shutdown(l::FailOnceLight) = (push!(l.log, l.name); l.left > 0 && (l.left -= 1; error("$(l.name) failed")); nothing)
struct IntLight <: LightSource end               # its shutdown is interrupted
MC.shutdown(::IntLight) = throw(InterruptException())
@testset "bench: rollback" begin
    cam = ClaimedAtConstruction()
    sys = Bench(cam, SimStage3d(), BrokenLight(); claimed_at_construction = (cam,))
    e = try MC.initialize(sys); nothing catch e e end
    @test occursin("initialize not implemented for", message(e)) && occursin("BrokenLight", message(e))
    @test cam.open == false
    @test isempty(sys.owned) && length(sys.stuck) == 1 && stuck_devices(sys)[1] isa BrokenLight

    stage = SimStage3d(); laser = SimLight()
    sys = Bench(BrokenCam(), stage, laser)
    e = try MC.initialize(sys); nothing catch e e end
    @test message(e) == "BrokenCam: no device"
    @test stage.connectionstatus == false
    @test laser.properties.is_on == false
    @test isempty(sys.owned) && isempty(sys.stuck)

    flaky = FlakyLight()
    sys = Bench(BrokenCam(), SimStage3d(), flaky)
    e = try MC.initialize(sys); nothing catch e e end
    @test message(e) == "BrokenCam: no device"                   # the cause, not the rollback's own failure
    @test isempty(sys.owned) && stuck_devices(sys) == [flaky]
    e = try MC.initialize(sys); nothing catch e e end
    @test occursin("unknown state", message(e)) && occursin("FlakyLight: write timed out", message(e))
    @test flaky.failures_left == 0
    MC.shutdown(sys)                                             # the retry works, so nothing is left stuck
    @test isempty(sys.stuck)

    daq = LineDAQ(failures = 2)                                  # the 0 V write fails twice, then works
    crysta = CrystaLaser(daq = daq, channel = "Dev1/ao0")
    sys = Bench(mkcam(), SimStage3d(), crysta)
    e = try MC.initialize(sys); nothing catch e e end
    @test message(e) == "LineDAQ: write failed"
    @test stuck_devices(sys) == [crysta] && crysta.properties.is_on == true   # its initialize threw: state unknown
    @test MC.shutdown(sys) === nothing && isempty(sys.stuck)                  # the next shutdown retried it
    @test crysta.properties.is_on == false && daq.writes == fill("Dev1/ao0" => 0.0, 3)

    cam = ClaimedAtConstruction()
    sys = Bench(cam, SimStage3d(), SimLight(); claimed_at_construction = (cam,))
    MC.initialize(sys); MC.shutdown(sys)
    e = try MC.initialize(sys); nothing catch e e end
    @test message(e) == "ClaimedAtConstruction was claimed at construction and has been shut down; reconstruct it and rebuild the system"
    @test cam.open == false && isempty(sys.owned)

    order = Symbol[]
    sys = Bench(mkcam(), SimStage3d(), SimLight())
    sys.owned = AbstractInstrument[RecLight(:owned_first, order), RecLight(:owned_second, order)]
    sys.stuck = Pair{AbstractInstrument,Any}[RecLight(:stuck_first, order) => ErrorException("a"),
                                             RecLight(:stuck_second, order) => ErrorException("b")]
    MC.shutdown(sys)
    @test order == [:stuck_second, :stuck_first, :owned_second, :owned_first]  # newest first

    order = Symbol[]
    first_on, second_on = FailOnceLight(:first, order, 1), FailOnceLight(:second, order, 1)
    sys = Bench(mkcam(), SimStage3d(), SimLight())
    sys.owned = AbstractInstrument[first_on, second_on]          # acquired in that order; both shutdowns fail once
    @test_throws ErrorException MC.shutdown(sys)
    @test stuck_devices(sys) == [first_on, second_on]            # stuck keeps acquisition order
    MC.shutdown(sys)
    @test order == [:second, :first, :second, :first]            # so the retry is newest first too
end
@testset "bench: requested versus measured, acquisitions, guards" begin
    daq = LineDAQ()
    laser = CrystaLaser(daq = daq, channel = "Dev1/ao0")
    sys = Bench(mkcam(), SimStage3d(), laser); MC.initialize(sys)
    @test daq.writes == ["Dev1/ao0" => 0.0]                     # initialize writes 0 V
    st = BenchState(exposure_time = 0.02, z = 1.0, laser_power = 2.5)
    MC.set_state(sys, st)
    @test MC.get_state(sys).laser_power == 2.5
    @test sys.cam.exposure_time == 0.02                          # the request reached the camera
    @test laser.level_requested == 2.5 && laser.level_staged
    @test daq.writes == ["Dev1/ao0" => 0.0]                     # nothing written while off
    @test isnan(measured_power(sys))
    a = MC.export_state(sys)[1]
    @test a["laser_power_requested"] == 2.5 && a["laser_power_unit"] == "V"
    light_on(laser)
    @test daq.writes[end] == ("Dev1/ao0" => 2.5)                 # the staged request, at the enable
    light_off(laser)
    e = try (MC.get_state(sys).laser_power = 4.5; nothing) catch e e end
    @test message(e) == "setfield!: immutable struct of type BenchState cannot be changed"

    t = @elapsed first_stack = acquire!(sys, 5)
    @test size(first_stack) == (32, 64, 5)
    @test t >= 5 * 0.02                                          # five of the exposures set_state asked for
    @test sys.in_flight == false && sys.cam_unavailable == false
    @test size(acquire!(sys, 3)) == (32, 64, 3)

    sys.in_flight = true
    for f in (() -> MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 2.5)),
              () -> acquire!(sys, 1), () -> MC.shutdown(sys))
        e = try f(); nothing catch e e end
        @test e !== nothing && occursin("in flight", message(e))
    end
    sys.in_flight = false

    claimed = ClaimedAtConstruction()
    nocam = Bench(claimed, SimStage3d(), SimLight())
    e = try acquire!(nocam, 1); nothing catch e e end
    @test message(e) == "no sequence reader for ClaimedAtConstruction; write one (see mc-acquire)"
    @test claimed.open && !nocam.cam_unavailable && !nocam.in_flight   # refused before anything touched it

    cam = FailingCam()
    bad = Bench(cam, SimStage3d(), SimLight())
    e = try acquire!(bad, 3) catch e e end
    @test message(e) == "SDK: read failed"
    @test cam.aborts == 1 && camera_ok(cam)
    @test bad.in_flight == false && bad.cam_unavailable == false
    e = try acquire!(bad, 3) catch e e end
    @test message(e) == "SDK: read failed" && cam.aborts == 2    # still available: the next call reached the camera

    bad = Bench(FailingCam(abort_mode = :throws), SimStage3d(), SimLight())
    e = try acquire!(bad, 3) catch e e end
    @test message(e) == "SDK: read failed"
    @test bad.cam_unavailable
    e = try acquire!(bad, 3) catch e e end
    @test startswith(message(e), "camera unavailable")
    MC.shutdown(bad)
    e = try (MC.initialize(bad); acquire!(bad, 3)) catch e e end
    @test startswith(message(e), "camera unavailable")
    rebuilt = Bench(mkcam(), bad.stage, bad.laser); MC.initialize(rebuilt)
    @test size(acquire!(rebuilt, 3)) == (32, 64, 3)

    for (mode, running) in ((:keeps_running, true), (:clears_flag, false))
        cam = FailingCam(abort_mode = mode)
        bad = Bench(cam, SimStage3d(), SimLight())
        e = try acquire!(bad, 3) catch e e end
        @test message(e) == "SDK: read failed"
        @test cam.aborts == 1 && cam.is_running == running && bad.cam_unavailable
    end

    cam = FailingCam(read_fails = false, cleanup_fails = true)
    bad = Bench(cam, SimStage3d(), SimLight())
    @test size(acquire!(bad, 4)) == (2, 3, 4)                    # the stack comes back
    @test bad.cam_unavailable && cam.aborts == 0                 # and the camera is out of service
end
@testset "bench: export with a failed child, shutdown failure" begin
    sys = Bench(mkcam(), SimStage3d(), BrokenLight())
    attributes, data, children = MC.export_state(sys)
    @test attributes["complete"] == false
    @test attributes["missing_children"] == "laser"
    file = joinpath(mktempdir(), "bench.h5")
    wait(save_h5(file, (attributes, data, children)))
    MC.HDF5.h5open(file, "r") do h
        @test sort(collect(keys(h["Main"]))) == ["camera", "laser", "stage"]
        @test MC.HDF5.attrs(h["Main"])["missing_children"] == "laser"
    end

    stage = SimStage3d()
    sys = Bench(mkcam(), stage, SimLight()); MC.initialize(sys)
    broken = BrokenLight()
    pushfirst!(sys.owned, broken)
    names_broken(e) = startswith(message(e), "shutdown failed, state unknown: BrokenLight: shutdown not implemented for ") &&
                      endswith(message(e), "BrokenLight")      # the stub names the type with its module
    e = try MC.shutdown(sys) catch e e end
    @test names_broken(e)
    @test stage.connectionstatus == false
    @test isempty(sys.owned) && stuck_devices(sys) == [broken]
    e = try MC.initialize(sys); nothing catch e e end
    @test e !== nothing && occursin("call shutdown(sys) until it succeeds, or rebuild the system", message(e))
    @test stage.connectionstatus == false                        # refused before touching any device
    e = try MC.shutdown(sys) catch e e end
    @test names_broken(e)

    flaky = FlakyLight()
    sys = Bench(mkcam(), SimStage3d(), flaky); MC.initialize(sys)
    e = try MC.shutdown(sys) catch e e end
    @test message(e) == "shutdown failed, state unknown: FlakyLight: FlakyLight: write timed out"
    @test MC.shutdown(sys) === nothing && isempty(sys.stuck)
    MC.initialize(sys)
    @test length(sys.owned) == 3

    sys = Bench(mkcam(), SimStage3d(), SimLight()); MC.initialize(sys)
    stage = sys.stage
    push!(sys.owned, IntLight())
    e = try MC.shutdown(sys); nothing catch e e end
    @test e isa InterruptException                               # a Ctrl-C stays one
    @test stuck_devices(sys)[1] isa IntLight && stage.connectionstatus == false   # after the loop finished
end
@testset "bench: the camera task reads the exposure as it runs" begin
    cam = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01, sequence_length = 20)
    t0 = time()
    task = sequence(cam)
    @test task isa Task
    sleep(0.05)                                                  # about five of the twenty frames
    @test !istaskdone(task) && cam.is_running == true            # the change lands while the task runs
    cam.exposure_time = 0.05
    wait(task)
    @test time() - t0 > 0.5                                      # read again: about 0.8 s; read once at the start: 0.2 s
end
@testset "bench: a DiodeLaser in the laser field" begin
    laser = SimDiodeLaser()
    sys = Bench(mkcam(), SimStage3d(), laser); MC.initialize(sys)
    MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 0.5))
    @test laser.drive_current == laser.min_current + 0.5 * (laser.max_current - laser.min_current)
    @test isnan(measured_power(sys))
    @test MC.export_state(sys)[1]["laser_power_unit"] == "fraction of the declared range"
    wa, tia = 100.0, 1e-3                                        # synthetic: W/A and A
    max_mW = 0.5 * tia * wa * 1000                               # half the photocurrent full scale, in mW
    pm = SimDiodeLaser(mode = ConstantPhotocurrent(), wa_calibration = wa, tia_range = tia, tec_stabilised = missing,
        max_current = 120.0, properties = LightSourceProperties("mW", 0.0, false, 0.0, max_mW))
    sys = Bench(mkcam(), SimStage3d(), pm); MC.initialize(sys)
    MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 0.5))
    light_on(pm)
    @test isapprox(measured_power(sys), 0.5 * max_mW; rtol = 1e-3)  # indicated_output_power, mW at the laser output
end
""")

SKILL_EXAMPLE_GROUPS["testing"] = (prelude = "", checks = raw"""
@testset "testing: the blocks' own testsets" begin
    sets = [v for v in block_values if v isa Test.DefaultTestSet]
    @test length(sets) == 4                      # the dispatch check and the three behavioral testsets
    dispatch = sets[1]
    @test dispatch.description == "devices satisfy the lifecycle contract"
    counts = Test.get_test_counts(dispatch)
    @test counts.passes == 24 && counts.fails == 0 && counts.errors == 0     # "All 24 assertions pass for these six types"
    failing = [t.description for t in sets if Test.get_test_counts(t).fails + Test.get_test_counts(t).errors > 0]
    @test isempty(failing)                       # names the block testsets that failed
end
@testset "testing: the CSC camera has no initialize but exports its settings" begin
    @test !has_specific(initialize, ThorCamCSCCamera)
    @test has_specific(export_state, ThorCamCSCCamera)
    @test has_specific(shutdown, ThorCamCSCCamera)
end
@testset "testing: SimCamera" begin
    cam = SimCamera(exposure_time = 0.05, roi = CameraROI(1, 1, 64, 32))
    @test (cam.exposure_time, cam.sequence_length, cam.capture_mode, cam.is_running) ==
          (0.05, 10, MC.HardwareImplementations.SimulatedCamera.LIVE, false)
    roi_tuple(c) = (c.roi.x_start, c.roi.y_start, c.roi.width, c.roi.height)
    @test roi_tuple(cam) == (1, 1, 64, 32)
    @test SimCamera().exposure_time == 0.1 && roi_tuple(SimCamera()) == (1, 1, 1024, 1024)
    @test capture(cam) == MC.HardwareImplementations.SimulatedCamera.SINGLE_FRAME     # the enum, not a frame
    calls_sleep(f) = occursin("sleep", string(only(code_lowered(f, (SimCamera,)))))
    @test !calls_sleep(getdata)                                                        # no sleep in getdata's body
    @test calls_sleep(getlastframe)                                                    # the check sees getlastframe's
    @test @elapsed(getlastframe(cam)) >= 0.05                                          # getlastframe sleeps exposure_time
    @test size(getlastframe(cam)) == (32, 64) && eltype(getlastframe(cam)) == UInt16
    cam.exposure_time = 0.01; cam.sequence_length = 5
    task = sequence(cam)
    @test cam.is_running == true
    @test size(getdata(cam)) == (32, 64, 5)                                            # at once, while it still runs
    wait(task)
    @test cam.is_running == false
    for f in (setexposuretime!, setroi!, settriggermode!)
        @test_throws ErrorException f(cam)
    end
end
@testset "testing: Sim stages" begin
    for (T, dims) in ((SimStage1d, 1), (SimStage2d, 2), (SimStage3d, 3))
        stage = T()
        @test stage.dimensions == dims && stage.range_x == (0.0, 100.0) && stage.connectionstatus == false
        @test hasfield(T, :label) && !hasfield(T, :stagelabel)
        err = try gui(stage); nothing catch e e end
        @test missing_field(err, T, :stagelabel)                                       # the unguarded stagelabel read
        GLMakie.closeall()
    end
    stage = SimStage3d()
    redirect_stdout(devnull) do
        move(stage, 1.0, 2.0, 3.0)
        @test getposition(stage) == 3.0                                                # a scalar, the last assignment
        @test (stage.real_x, stage.real_y, stage.real_z) == (1.0, 2.0, 3.0)
        move(stage, 1e6, 0.0, 0.0)                                                     # no range enforcement
        @test stage.targ_x == 1e6
        home(stage)
        @test stage.real_x == 0.0 && stage.targ_x == 1e6                               # home zeroes real_*, not targ_*
        @test_throws MethodError move(stage, 1, 2, 3)
        @test getrange(stage) == ((0.0, 100.0), (0.0, 100.0), (0.0, 100.0))
    end
    two = SimStage2d()
    err = redirect_stdout(devnull) do
        try move(two, 1.0, 2.0, 3.0); nothing catch e e end
    end
    @test err isa ErrorException && err.msg == "move not implemented for SimStage2d"   # the interface fallback, not a MethodError
end
@testset "testing: SimLight" begin
    light = SimLight()
    p = light.properties
    @test (p.power_unit, p.power, p.is_on, p.min_power, p.max_power) == ("mW", 0.0, false, 0.0, 100.0)
    initialize(light); @test light.properties.is_on == true
    setpower(light, 500.0); @test light.properties.power == 500.0                       # no clamp
    shutdown(light); @test light.properties.is_on == false
    @test_throws MethodError light_on(light, 1.0)
    @test SimLight().modulator === nothing
end
@testset "testing: the shared panels open" begin
    for T in (SimCamera, SimLight, PIStage, MCLStage, MCS2Stage)
        @test gui(T()) isa GLMakie.Screen                                               # a window, not a no-op
        GLMakie.closeall()
    end
end
@testset "testing: SimDiodeLaser" begin
    SDL = MC.HardwareImplementations.SimulatedDiodeLaser
    sim = SimDiodeLaser()
    table = read(joinpath(pkgdir(MicroscopeControl), "skills", "mc-testing", "SKILL.md"), String)
    for f in (:min_current, :efficiency)
        @test occursin("`$(f)=$(getfield(sim, f))`", table)                            # the defaults the table states
    end
    @test sim.threshold_current > sim.min_current && sim.max_current > sim.threshold_current
    @test sim.properties.power_unit == "mA"
    @test_throws ErrorException setcurrent!(sim, 100.0)                                 # before initialize
    @test_throws ErrorException measured_current(sim)
    initialize(sim)
    setcurrent!(sim, sim.threshold_current / 2); light_on(sim)
    @test SDL.true_output_power(sim) == 0.0                                             # below threshold: max(0, ...)
    setcurrent!(sim, 100.0)
    @test SDL.true_output_power(sim) ≈ sim.efficiency * (100.0 - sim.threshold_current)  # P = efficiency * max(0, I - threshold)
    @test !(:true_output_power in names(SDL)) && !isdefined(MC, :true_output_power)     # not exported
    @test measured_photocurrent(sim) ≈ sim.responsivity * (1 + sim.responsivity_drift) * SDL.true_output_power(sim) / 1000
    empty!(sim.log); loop_status(sim)
    @test sim.log == [(:read, :loop_status)]                                            # reads are logged too
    GLMakie.closeall()
    empty!(sim.log); gui(sim); GLMakie.closeall()
    @test isempty(sim.log)                                                              # opening the panel issues nothing
    shutdown(sim)
    @test_throws ErrorException light_on(sim)                                           # after shutdown

    wa, tia = 100.0, 1e-3                                                               # synthetic: W/A and A
    power = SimDiodeLaser(mode = ConstantPhotocurrent(), wa_calibration = wa, tia_range = tia, tec_stabilised = missing,
        max_current = 120.0, properties = LightSourceProperties("mW", 0.0, false, 0.0, 0.5 * tia * wa * 1000))
    initialize(power); setoutputpower!(power, 10.0); light_on(power)
    @test indicated_output_power(power) ≈ SDL.true_output_power(power)
    asked = 10.0 / 1000 / wa                                                            # A of photocurrent for 10 mW
    got = power.pd.photocurrent_requested
    @test got != asked && got <= asked && asked - got < tia / 32767                     # rounded down, by under one step
    indicated = indicated_output_power(power)
    true_before = SDL.true_output_power(power)
    power.responsivity_drift = 0.2
    @test indicated_output_power(power) ≈ indicated                                     # the indication stays put
    @test SDL.true_output_power(power) < 0.9 * true_before                               # while the true power moves
    power.responsivity_drift = 0.0; power.pd_blocked = true
    @test measured_current(power) == power.pd.max_current_clamp && loop_status(power).saturated
    GLMakie.closeall()

    # Two power-mode checks the TCube's constructor makes and the Sim's does not (synthetic values).
    kw = (mode = ConstantPhotocurrent(), wa_calibration = wa, tec_stabilised = missing, max_current = 120.0,
          properties = LightSourceProperties("mW", 0.0, false, 0.0, 33.0))
    @test SimDiodeLaser(; kw..., tia_range = 2e-3) isa SimDiodeLaser                     # not a TLD001 range
    @test_throws r"is not a TLD001 photodiode range" TCubeLaser("00000000"; kw..., tia_range = 2e-3)
    ref = (tia_range = tia, ref_current_mA = 71.0, ref_photocurrent_A = 0.85e-3)         # indicates 85 mW, above 33
    @test SimDiodeLaser(; kw..., ref...) isa SimDiodeLaser
    @test_throws r"above properties.max_power" TCubeLaser("00000000"; kw..., ref...)
end
@testset "testing: Camera is the only name MicroscopeControl and GLMakie both export" begin
    @test intersect(Set(names(MC)), Set(names(GLMakie))) == Set([:Camera])
    both = Module(:CameraAmbiguity)
    Core.eval(both, :(using MicroscopeControl))
    Core.eval(both, :(using GLMakie))
    @test_throws UndefVarError Core.eval(both, :(struct Rig; cam::Camera; end))       # `Camera` is ambiguous
    narrow = Module(:CameraNarrow)
    Core.eval(narrow, :(using MicroscopeControl))
    Core.eval(narrow, :(using GLMakie: Figure, Axis))
    Core.eval(narrow, :(struct Rig; cam::Camera; end))
    @test fieldtype(narrow.Rig, :cam) === MC.Camera                                    # the narrow import fixes it
end
@testset "testing: a stub that logs and returns, and the cameras' panel fields" begin
    @test_logs (:error, r"STOP MOTION NOT IMPLEMENTED") @test stopmotion(MCLStage()) === nothing
    for T in (DCAM4Camera, SimCamera, ThorCamCSCCamera, ThorcamDCXCamera)
        for f in (:unique_id, :exposure_time, :roi, :capture_mode, :trigger_mode, :sequence_length, :is_running)
            @test hasfield(T, f)
        end
        @test fieldtype(T, :capture_mode) <: Enum && fieldtype(T, :trigger_mode) <: Enum
    end
    @test fieldtype(ThorCamCSCCamera, :unique_id) == Vector{UInt8}                  # the panel's `"Unique ID: " * id` cannot take it
    for T in (SimStage3d, PIStage, MCLStage, MCS2Stage)
        for f in (:dimensions, :connectionstatus, :stagelabel, :targ_x, :real_x, :range_x)
            T === SimStage3d && f === :stagelabel && continue
            @test hasfield(T, f)
        end
    end
    @test !hasfield(N472, :real_x) && hasfield(N472, :pos)
    @test which(gui, Tuple{N472}).sig.parameters[2] === N472                        # N472 ships its own panel
    @test !has_specific(getrange, N472)                                              # only the interface fallback
end
""")

SKILL_EXAMPLE_GROUPS["acquire-reader"] = (prelude = """
using MicroscopeControl
cam = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))
latest = Ref{Any}(nothing)
fps = 100
""", checks = raw"""
@test latest[] !== nothing && size(latest[]) == (32, 64)       # the reader read frames until stopped
@test istaskdone(reader) && !istaskfailed(reader)               # joined, and it ended on its own flag
@test cam.is_running == false && camera_ok(cam)                 # stopped after the join
cam2 = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))
live(cam2)
failing = @async error("reader: SDK read failed")               # a reader that throws
thrown = try stop_reader!(cam2, failing, Threads.Atomic{Bool}(false)); nothing catch err err end
@test thrown isa TaskFailedException && occursin("reader: SDK read failed", sprint(showerror, thrown))   # its error, kept
@test cam2.is_running == false                                  # and the camera was still stopped
""")
SKILL_EXAMPLE_GROUPS["acquire-snap"] = (prelude = "using MicroscopeControl", checks = raw"""
sim = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
@test size(snap(sim)) == (32, 64)
@test sim.capture_mode == MC.HardwareImplementations.SimulatedCamera.SINGLE_FRAME   # capture ran before the read
@test snap(SimCamera(roi = CameraROI(1, 1, 64, 32))) isa Matrix{UInt16}
@test which(snap, Tuple{SimCamera}).sig.parameters[2] === SimCamera
@test which(snap, Tuple{DCAM4Camera}).sig.parameters[2] === Camera              # the hardware drivers take the generic method
""")
SKILL_EXAMPLE_GROUPS["acquire-exposure"] = (prelude = "using MicroscopeControl; cam = SimCamera()", checks = raw"""
@test cam.exposure_time == 0.02
@test (cam.roi.x_start, cam.roi.y_start, cam.roi.width, cam.roi.height) == (1, 1, 512, 256)
@test fieldtype(ThorCamCSCCamera, :exposure_time) == Clonglong                  # an integer field (microseconds)
@test_throws InexactError convert(Clonglong, 0.02)
@test fieldtype(DCAM4Camera, :exposure_time) == Float64 && fieldtype(ThorcamDCXCamera, :exposure_time) == Float64
@test ThorcamDCXCamera().exposure_time == 0.01                                  # the constructor is pure
""")
SKILL_EXAMPLE_GROUPS["camera"] = (prelude = "", checks = raw"""
cam = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
t = @elapsed stack = read_sequence(cam, 5)
@test size(stack) == (32, 64, 5) && eltype(stack) == UInt16
@test t >= 5 * 0.01                                                             # the timer was joined
@test camera_ok(cam) && cam.is_running == false
@test read_sequence(cam, 5) != stack                                            # a second read: new frames
@test_throws ArgumentError read_sequence(cam, -1)
struct UnknownCam <: Camera end
@test_throws r"^no sequence reader for UnknownCam; write one \(see mc-acquire\)$" read_sequence(UnknownCam(), 1)
@test camera_ok(UnknownCam()) == false
for T in (SimCamera, DCAM4Camera, ThorcamDCXCamera)
    @test which(read_sequence, Tuple{T,Int}).sig.parameters[2] === T && which(camera_ok, Tuple{T}).sig.parameters[2] === T
end
@test which(stop_camera!, Tuple{DCAM4Camera}).sig.parameters[2] === DCAM4Camera
@test which(stop_camera!, Tuple{ThorcamDCXCamera}).sig.parameters[2] === ThorcamDCXCamera
dcx = ThorcamDCXCamera()                                                         # builds without the SDK
@test !isassigned(dcx.pImage_Mem, 1) && dcx.is_running == false                 # so its abort would throw
@test stop_camera!(dcx) === nothing && camera_ok(dcx)                            # and stop_camera! does not call it
poller = @async sleep(0.3)                                                       # a poller still running
DCX_POLLER[dcx] = poller
@test camera_ok(dcx) == false
wait(poller)
@test camera_ok(dcx)
@test which(read_sequence, Tuple{ThorCamCSCCamera,Int}).sig.parameters[2] === Camera     # no CSC method: the fallback
@test which(camera_ok, Tuple{ThorCamCSCCamera}).sig.parameters[2] === Camera
@test DCAM4.DCAMERR_SUCCESS isa DCAM4.DCAMERR && fieldtype(DCAM4Camera, :last_error) === DCAM4.DCAMERR
@test fieldtype(DCAM4Camera, :is_running) === Bool && fieldtype(ThorcamDCXCamera, :is_running) === Bool
""")
SKILL_EXAMPLE_GROUPS["acquire-zstack"] = (prelude = "", checks = raw"""
@test allunique(eachslice(stack; dims = 3))                                     # a new frame per plane, not one reused
mutable struct ZCam <: Camera                       # notes the stage's z inside capture, when the frame is taken
    stage::Stage
    taken_at::Vector{Float64}
end
MC.CameraInterface.capture(c::ZCam) = (push!(c.taken_at, c.stage.real_z); fill(UInt16(length(c.taken_at)), 2, 3))
zc = ZCam(SimStage3d(), Float64[])
s = redirect_stdout(() -> zstack(zc, zc.stage, zs), devnull)
@test zc.taken_at == collect(zs)                                                # one capture per plane, after its move
@test [s[1, 1, i] for i in axes(s, 3)] == 1:length(zs)                          # each plane is that capture's frame
""")
SKILL_EXAMPLE_GROUPS["acquire-units"] = (prelude = "using MicroscopeControl; stage = PIStage()", checks = raw"""
@test PIStage().units == "Milimeters" && MCLStage().units == "Microns" && N472().units == "mm"
@test !hasfield(MCS2Stage, :units) && !hasfield(SimStage3d, :units)
for T in (MCS2Stage, SimStage3d)
    local e = try T().units; nothing catch err err end
    @test missing_field(e, T, :units)
end
@test_throws MethodError move(SimStage3d(), 1, 2, 3)
@test stage isa PIStage && hasfield(typeof(stage), :units)                      # the fence's guarded branch ran
""")
SKILL_EXAMPLE_GROUPS["apimap"] = (prelude = "", checks = raw"""
@test which(setcurrent!, Tuple{TCubeLaser{ConstantPhotocurrent},Float64}).sig.parameters[2] === DiodeLaser     # the stub, not a driver method
@test which(export_state, Tuple{TCubeLaser}).sig == Tuple{typeof(export_state), TCubeLaser}
@test hasmethod(export_state, Tuple{TCubeLaser,Any})                           # the deprecated forwarder is still there
@test !has_specific(setcurrent!, TCubeLaser, Float64)
""")
SKILL_EXAMPLE_GROUPS["extend-shim"] = (prelude = "", checks = raw"""
# the guard did not install the shim: dispatch lands on the driver's own method, not the abstract stub
@test which(MC.export_state, Tuple{MC.TCubeLaser}).sig.parameters[2] === MC.TCubeLaser
@test which(MC.export_state, Tuple{MC.TCubeLaser}).module !== @__MODULE__        # the driver's method, not a shim from here
""")
SKILL_EXAMPLE_GROUPS["extend-shadow"] = (prelude = "", checks = raw"""
@test_throws r"^setpower not implemented for .*ShadowLED$" MicroscopeControl.setpower(ShadowDriver.ShadowLED(), 1.0)
@test ShadowDriver.setpower !== MicroscopeControl.setpower
""")
SKILL_EXAMPLE_GROUPS["scaffold"] = (prelude = "", checks = raw"""
sets = [v for v in block_values if v isa Test.DefaultTestSet]
@test length(sets) == 1 && sets[1].description == "SerialLED contract"
counts = Test.get_test_counts(sets[1])
@test counts.passes == 23 && counts.fails == 0 && counts.errors == 0            # "the 23-assertion contract testset"
using .RigDrivers
led = SerialLED()
@test led.port.isopen == false                                                   # the constructor is pure
initialize(led); setpower(led, 12.5); light_on(led)
@test led.port.log == ["PWR 0", "OFF", "PWR 12", "ON"] && led.properties.power == 12.5
@test_throws ArgumentError setpower(led, 500.0)
shutdown(led)
@test !led.port.isopen
@test_throws "FakePort: write on closed port" setpower(led, 1.0)
@test_throws "FakePort: device not present" initialize(SerialLED(port = FakePort(fail_open = true)))
GLMakie.closeall()
sent = copy(led.port.log)
@test gui(led) isa GLMakie.Screen                                                # the panel opens on the closed port
@test led.port.log == sent                                                       # and commands nothing
GLMakie.closeall()
file = joinpath(mktempdir(), "led.h5")
a, d, c = export_state(led)
save_attributes_and_data(file, "Main", a, d, c)
MC.HDF5.h5open(file, "r") do h
    @test MC.HDF5.attrs(h["Main"])["is_on"] == 0.0                              # Bool is stored as Float64
    @test MC.HDF5.attrs(h["Main"])["power_requested"] == 12.5
end
""")
SKILL_EXAMPLE_GROUPS["shutter"] = (prelude = "", checks = raw"""
using .ShutterInterface, .SimulatedShutter
struct NoMethodsShutter <: Shutter end
has_specific(f, T, args...) = hasmethod(f, Tuple{T,args...}) && which(f, Tuple{T,args...}).sig.parameters[2] === T
@test_throws r"^open_shutter! not implemented for .*NoMethodsShutter$" open_shutter!(NoMethodsShutter())
@test_throws "initialize not implemented" initialize(NoMethodsShutter())
@test_throws "gui not implemented" gui(NoMethodsShutter())
sh = SimShutter()
initialize(sh); open_shutter!(sh)
@test is_open(sh) === true
@test export_state(sh)[1]["is_open"] == true
for f in (initialize, shutdown, export_state, open_shutter!, close_shutter!, is_open)
    @test has_specific(f, SimShutter)
end
@test SimulatedShutter.open_shutter! === ShutterInterface.open_shutter!
@test SimulatedShutter.export_state === MicroscopeControl.export_state
using InteractiveUtils
@test Set(subtypes(Shutter)) == Set([NoMethodsShutter, SimShutter])
""")

# Statements about the generated API map, the SLM stubs, the exports and `save_h5` that no example block runs.
SKILL_EXAMPLE_GROUPS["statements"] = (prelude = "", checks = raw"""
@testset "statements: the generated map" begin
    mktempdir() do tmp
        MicroscopeControl.install_skills(tmp; quiet=true)
        map_text = read(joinpath(tmp, ".claude", "skills", "mc-api-map", "references", "api-map.md"), String)
        section(name) = match(Regex("### $(name)\\n(.*?)\\n(?:### |## |\\z)", "s"), map_text).captures[1]
        @test occursin("`gui` is also exported as attenuator_gui, laser_488_gui, laser_561_gui, nidaq_gui, red_laser_gui and tr_light_gui", map_text)
        for heading in ("## Stage", "## Camera", "## LightSource", "## DAQ", "## Attenuator", "## SLM", "## TRIG")
            @test occursin(heading * "\n", map_text)
        end
        @test !occursin("XEM", map_text)                                   # outside the seven inventoried interfaces
        csc = section("ThorCamCSCCamera")
        fallback = csc[first(findfirst("**Interface fallback", csc)):end]
        @test occursin("- `initialize(AbstractInstrument)`", fallback)
        @test occursin("- `setroi!(Camera)`", fallback) && occursin("- `settriggermode!(Camera)`", fallback)
        @test !occursin("export_state", fallback)
        @test occursin("- `export_state(ThorCamCSCCamera)`", csc)
        sim = section("SimCamera")
        @test occursin("- `setexposuretime!(Camera)`", sim) && occursin("- `gui(Camera)`", sim) && occursin("- `start_live(Camera)`", sim)
        tcube = section("TCubeLaser")
        @test occursin("- `setcurrent!(TCubeLaser{ConstantCurrent}, Float64)`", tcube)
        @test occursin("- `setoutputpower!(TCubeLaser{ConstantPhotocurrent}, Float64)`", tcube)
        @test occursin("- `light_on(TCubeLaser)`", tcube)
        @test occursin("- `export_state(TCubeLaser, Any)`", tcube)         # the deprecated forwarder is listed too
        @test !occursin("setpower(", tcube) && !occursin("setlevel!(", tcube)   # the 2-arg blind spot
        @test occursin("- `displayimage(SLM)`", section("MLSLM"))
        @test occursin("- `move(MCS2Stage, Float64, Float64, Float64)`", section("MCS2Stage"))
        @test occursin("- `getdata(SimCamera)`", sim) && occursin("- `initialize(SimCamera)`", sim)   # the table's examples
        @test occursin("- `setroi!(Camera)`", sim)
        dcam = section("DCAM4Camera")
        @test occursin("- `sequence(DCAM4Camera, Real)`", dcam) && occursin("- `sequence(DCAM4Camera)`", dcam)
    end
end
@testset "statements: the stubs and the devices outside AbstractInstrument" begin
    slm = MLSLM()
    @test displayimage(slm) === nothing                                    # the empty body
    err = try displayimage(slm, zeros(2, 2)); nothing catch e e end
    @test err isa ErrorException && occursin("setfield! fields of Types should not be changed", err.msg)
    @test !isdefined(MicroscopeControl, :move!) && isdefined(MicroscopeControl.HardwareImplementations.MCS2Stage_mod, :move!)
    @test hasmethod(initialize, Tuple{XEM}) && !hasmethod(export_state, Tuple{XEM}) && !hasmethod(gui, Tuple{XEM})
    @test !(MLSLM <: AbstractInstrument) && !(Triggerscope4 <: AbstractInstrument)
    @test !hasmethod(export_state, Tuple{Triggerscope4})
    # The constructor builds a LibSerialPort object for the port name, and libserialport refuses a name that is not a
    # port on this machine: the default "COM3" is not one on Linux.
    Sys.islinux() && @test_throws ErrorException Triggerscope4()
end
@testset "statements: export_state returns the tuple save_h5 writes" begin
    # The devices the persistence row names: each built without touching hardware (the DAQ lights with named outputs).
    for f in (SimCamera, SimStage1d, SimStage2d, SimStage3d, SimLight, SimDiodeLaser, PIStage, MCLStage, MCS2Stage,
              N472, ThorcamDCXCamera, MLSLM, NIdaq, () -> TCubeLaser("00000000"), () -> CrystaLaser(channel = "Dev1/ao0"),
              () -> DaqTrLight(channel = "Dev1/ao0"), () -> VortranLaser(ao_channel = "Dev1/ao0", do_channel = "Dev1/port0/line0"))
        r = redirect_stdout(() -> export_state(f()), devnull)
        @test r isa Tuple && length(r) == 3 && r[1] isa AbstractDict && r[3] isa AbstractDict
        file = joinpath(mktempdir(), "export.h5")
        redirect_stdout(() -> save_attributes_and_data(file, "Main", r...), devnull)
        @test MC.HDF5.h5open(h -> haskey(h, "Main"), file, "r")
    end
end
@testset "statements: save_h5" begin
    mktempdir() do dir
        @test_throws MethodError redirect_stderr(devnull) do
            save_attributes_and_data(joinpath(dir, "tuple.h5"), "Main", Dict{String,Any}("range" => (0.0, 100.0)), nothing, Dict{String,Any}())
        end                                                                 # a Tuple attribute fails in HDF5
        file = joinpath(dir, "stack.h5")
        save_attributes_and_data(file, "Main", Dict{String,Any}("is_on" => true), rand(3, 2, 4), Dict{String,Any}())
        MicroscopeControl.HDF5.h5open(file, "r") do h
            @test MicroscopeControl.HDF5.attrs(h["Main"])["is_on"] === 1.0     # a Bool reads back as a Float64
            a = MicroscopeControl.HDF5.attrs(h["Main/data"])
            @test a["dimension_order"] == "y,x,frame"
            @test a["dimension_order_convention"] == "column-major (Julia/MATLAB); C-order tools list it reversed"
            @test a["dimension_labels"] == ["height", "width", "frames"] && a["memory_layout"] == "column_major_julia"
            @test size(h["Main/data"]) == (3, 2, 4)
        end
    end
end
""")

# Run as a script (by test/skills.jl, in its own process): every group, in name order. The fakes runtests.jl installs
# for the TCube, N-472 and PI stage wrappers come first, so no example can reach a vendor library even by mistake;
# each include is its own top-level statement, before anything runs, as those files require.
const RUN_AS_SCRIPT = abspath(PROGRAM_FILE) == abspath(@__FILE__)
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "tcube_fake_sdk.jl"))
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "pi_n472_fake_sdk.jl"))
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "pi_stage_fake_sdk.jl"))
if RUN_AS_SCRIPT
    import GLMakie
    @testset "Skill examples" begin
        groups = skill_example_blocks(joinpath(pkgdir(MicroscopeControl), "skills"))
        for name in sort(collect(keys(SKILL_EXAMPLE_GROUPS)))
            spec = SKILL_EXAMPLE_GROUPS[name]
            @testset "$name" begin
                run_skill_example(name, skill_group_fences(groups, name); prelude = spec.prelude, checks = spec.checks)
            end
        end
    end
end
