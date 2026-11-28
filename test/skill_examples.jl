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

# The camera calls the examples may make only inside a wrapper (mc-acquire, "Finite ordered sequence"): `with_camera`,
# which refuses a camera marked unknown or reserved and has no switch to turn that off, or `with_stop`, which lets a
# stop through, in a `stop_camera!` method. The one other exception: a `getlastframe` inside `read_frames!`, the reader
# loop, which launches no task of its own and which only `start_reader!` may launch, inside a task, after a
# `with_camera` executed as a top-level statement of its body (so every path to the launch runs it); `stop_reader!`
# joins it before it stops the camera. And one reference rule (`REFERENCES`): each of these names may appear only in
# the bodies of the functions listed for it, anywhere in a fence, its top level included.
const CAMERA_CALLS = (:live, :sequence, :capture, :getdata, :getlastframe, :abort)
const CAMERA_WRAPPERS = (:with_camera, :with_stop)
const READER_LOOP = :read_frames!
const REFERENCES = Dict(:with_stop => (:stop_camera!,),
                        :CAMERA_UNKNOWN => (:mark_unknown!, :refuse_unknown, :in_service),
                        :CAMERA_LIVE => (:refuse_unknown, :in_service, :start_reader!, :stop_reader!),
                        :start_reader! => (:live_view!,),
                        :stop_reader! => (:live_view!,))
const TASK_MACROS = (Symbol("@async"), Symbol("@spawn"), Symbol("@threads"))

last_name(f) = f isa Symbol ? f : f isa Expr && f.head === :. && f.args[end] isa QuoteNode ? f.args[end].value : nothing
callee_name(ex) = ex isa Expr && ex.head === :call ? last_name(ex.args[1]) : nothing
signature_name(sig) = sig isa Expr && sig.head in (:where, :(::)) ? signature_name(sig.args[1]) :
                      sig isa Expr && sig.head === :call ? last_name(sig.args[1]) : nothing
is_lambda(ex) = ex isa Expr && (ex.head === :-> || (ex.head === :function && !(ex.args[1] isa Expr && ex.args[1].head === :call)))
is_task_macro(ex) = ex isa Expr && ex.head === :macrocall && last_name(ex.args[1]) in TASK_MACROS   # bare or qualified
is_task_launch(ex) = is_task_macro(ex) || callee_name(ex) in (:Task, :schedule, :Timer)

# The default values in a signature: positional (`x = v`) and keyword, which run before the body.
function signature_defaults(sig, out = Any[])
    sig isa Expr || return out
    if sig.head === :kw
        push!(out, sig.args[2])
    else
        foreach(a -> signature_defaults(a, out), sig.args)
    end
    return out
end

# The wrapper a call is (`with_camera` or `with_stop`, called or with a do-block), or `nothing`.
function wrapper_name(ex)
    ex isa Expr || return nothing
    name = ex.head === :do ? callee_name(ex.args[1]) : callee_name(ex)
    return name in CAMERA_WRAPPERS ? name : nothing
end

# A wrapper call's eagerly evaluated arguments, keywords included, and its function argument (the do-block's, or a
# lambda).
function wrapper_parts(ex)
    call, fn = ex.head === :do ? (ex.args[1], Any[ex.args[2]]) : (ex, Any[])
    eager = Any[]
    for a in call.args[2:end]
        if a isa Expr && a.head === :parameters
            append!(eager, [p isa Expr && p.head === :kw ? p.args[2] : p for p in a.args])
        elseif a isa Expr && a.head === :kw
            push!(eager, a.args[2])
        elseif is_lambda(a)
            push!(fn, a)
        else
            push!(eager, a)
        end
    end
    return eager, fn
end

# The `with_camera` calls every path through a function body runs: its top-level statements, alone or as the right
# side of an assignment to a variable. One inside an `if`, a loop, a `try`, a short-circuit or a local function
# definition (`guard() = with_camera(...)`, which runs only if called) is not among them.
function dominating_guards(body)
    guards = Base.IdSet{Any}()
    stmts = body isa Expr && body.head === :block ? body.args : Any[body]
    for st in stmts
        rhs = st isa Expr && st.head === :(=) && signature_name(st.args[1]) === nothing ? st.args[2] : st
        wrapper_name(rhs) === :with_camera && push!(guards, rhs)
    end
    return guards
end

# Walk one function's code, in source order. `found` collects camera calls outside a wrapper (and a misplaced
# `with_stop` call, reader launch or task), `inside` those inside one; `in_task` is whether the walk is inside an
# `@async`/`@spawn` task; `seen[]` whether one of `guards`, the function's dominating `with_camera` calls, has been
# walked yet, so a reader launch can be checked to come after it.
function walk_camera_calls!(found, inside, fname, ex, seen, guards; guarded = false, in_task = false)
    ex isa Expr || return
    walk(a; g = guarded, t = in_task) = walk_camera_calls!(found, inside, fname, a, seen, guards; guarded = g, in_task = t)
    wrapper = wrapper_name(ex)
    if wrapper !== nothing
        eager, fn = wrapper_parts(ex)
        foreach(walk, eager)                                                 # they run before the guard
        allowed = wrapper === :with_camera || fname === :stop_camera!
        allowed || push!(found, :with_stop)                                  # a stop, misplaced
        foreach(f -> walk(f; g = guarded || allowed), fn)
        ex in guards && (seen[] = true)
        return
    end
    name = callee_name(ex)
    if name in CAMERA_CALLS
        exempt = name === :getlastframe && fname === READER_LOOP
        guarded || exempt ? push!(inside, name) : push!(found, name)
    elseif name === READER_LOOP
        launched = fname === :start_reader! && in_task && seen[]
        launched ? push!(inside, name) : push!(found, name)
    end
    fname === READER_LOOP && is_task_launch(ex) && push!(found, :task)       # the reader loop starts no task
    task = in_task || is_task_macro(ex)
    foreach(a -> walk(a; t = task), ex.args)
end

# The reference rule: every occurrence of a name in `REFERENCES` (bare, qualified, or quoted) outside the bodies of the
# functions listed for it, as (enclosing function or :toplevel, name). The innermost named function counts; a
# function's own name in its signature and a `const NAME = ...` definition are not references.
function misplaced_references!(out, ex, fname = :toplevel)
    name = ex isa Symbol ? ex : ex isa QuoteNode && ex.value isa Symbol ? ex.value : nothing
    if name !== nothing
        haskey(REFERENCES, name) && !(fname in REFERENCES[name]) && push!(out, (fname, name))
        return out
    end
    ex isa Expr || return out
    if ex.head in (:function, :(=)) && length(ex.args) == 2 && signature_name(ex.args[1]) !== nothing
        inner = signature_name(ex.args[1])
        foreach(d -> misplaced_references!(out, d, inner), signature_defaults(ex.args[1]))
        return misplaced_references!(out, ex.args[2], inner)
    elseif ex.head === :const && ex.args[1] isa Expr && ex.args[1].head === :(=) && ex.args[1].args[1] isa Symbol
        return misplaced_references!(out, ex.args[1].args[2], fname)
    end
    foreach(a -> misplaced_references!(out, a, fname), ex.args)
    return out
end

# Every function defined in `code` (long or short form, at any depth, documented or not), as
# `(offenders, wrapped)`: `offenders` holds (function, call) for each camera call that runs outside a wrapper (in the
# body, in a default argument, or in an eager argument of a wrapper), (function, :with_stop) for a `with_stop` call
# outside `stop_camera!`, (function, :read_frames!) for a reader launch anywhere but in a task in `start_reader!` after
# a dominating `with_camera`, (:read_frames!, :task) for a task the reader loop starts, and every misplaced reference
# (`misplaced_references!`); `wrapped` names the functions whose camera calls are all guarded. A method of a camera
# call itself is a driver, not a caller, and is not checked.
function camera_call_report(code::AbstractString)
    offenders = Tuple{Symbol,Symbol}[]
    wrapped = Set{Symbol}()
    function visit(ex)
        ex isa Expr || return
        if ex.head in (:function, :(=)) && length(ex.args) == 2
            name = signature_name(ex.args[1])
            if name !== nothing && !(name in CAMERA_CALLS)
                found, inside, seen, guards = Symbol[], Symbol[], Ref(false), dominating_guards(ex.args[2])
                foreach(d -> walk_camera_calls!(found, inside, name, d, seen, guards), signature_defaults(ex.args[1]))
                walk_camera_calls!(found, inside, name, ex.args[2], seen, guards)
                foreach(c -> push!(offenders, (name, c)), unique(found))
                isempty(found) && !isempty(inside) && push!(wrapped, name)
            end
        end
        foreach(visit, ex.args)
    end
    parsed = Meta.parseall(code)
    visit(parsed)
    append!(offenders, misplaced_references!(Tuple{Symbol,Symbol}[], parsed))
    return unique!(offenders), wrapped
end
camera_calls_outside_wrapper(code::AbstractString) = first(camera_call_report(code))

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

# The fake DCAM SDK fixtures the `camera`, `acquire-snap` and `acquire-reader` checks share, as their prelude: the
# recorder (`test/dcam4_fake_sdk.jl`, installed in the child) and a DCAM4 camera built on it without an SDK call.
const FAKE_DCAM_PRELUDE = """
using MicroscopeControl
FK = Main.FakeDCAM
function fake_dcam(mode)
    D = MicroscopeControl.HardwareImplementations.DCAM4
    return D.DCAM4Camera("fake", D.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0, D.CameraROI(0, 0, 1, 1),
                         mode, D.DCAMPROP_TRIGGER_MODE__NORMAL, 2, D.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 1, 1), NaN, 0)
end
"""

# group name => (min_passes, prelude, checks). The prelude runs before the fences, the checks after; both in the fences'
# module. `min_passes` is the floor `test/skills.jl` holds the group's passing checks to: a group whose checks were
# emptied or cut short fails the suite. Raise it when a group gains checks.
const SKILL_EXAMPLE_GROUPS = Dict{String,NamedTuple{(:min_passes, :prelude, :checks),Tuple{Int,String,String}}}()

# Groups that have checks and no fence: statements the skills make about the package that no example runs.
const SKILL_FENCELESS_GROUPS = ["statements"]

# group => the groups whose fences run first, in its module: the per-driver camera functions in mc-acquire are used
# by the reader there and by mc-system-design's Bench.
const SKILL_GROUP_USES = Dict("acquire-reader" => ["camera"], "bench" => ["camera"], "acquire-snap" => ["camera"],
                              "acquire-zstack" => ["camera", "acquire-snap"], "testing" => ["camera", "acquire-snap"])

# A group's fences: those of the groups it uses, then its own.
skill_group_fences(groups, name) = vcat((groups[u] for u in get(SKILL_GROUP_USES, name, String[]))..., get(groups, name, []))

SKILL_EXAMPLE_GROUPS["bench"] = (min_passes = 105, prelude = "", checks = raw"""
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
struct ParamCam{T} <: Camera end                 # readers with a parametric type, and with an Integer length
read_sequence(::ParamCam{T}, n::Int) where {T} = zeros(UInt16, 2, 3, n)
MC.initialize(::ParamCam) = nothing
MC.shutdown(::ParamCam) = nothing
struct IntegerCam <: Camera end
read_sequence(::IntegerCam, n::Integer) = zeros(UInt16, 2, 3, n)
struct RecordingCam <: Camera                    # records every call the example makes to it
    calls::Vector{Symbol}
end
RecordingCam() = RecordingCam(Symbol[])
MC.initialize(c::RecordingCam) = (push!(c.calls, :initialize); nothing)
MC.shutdown(c::RecordingCam) = (push!(c.calls, :shutdown); nothing)
MC.CameraInterface.abort(c::RecordingCam) = (push!(c.calls, :abort); nothing)
read_sequence(c::RecordingCam, n::Integer) = (push!(c.calls, :read); zeros(UInt16, 2, 3, n))
stop_camera!(c::RecordingCam) = (push!(c.calls, :stop); true)
camera_ok(c::RecordingCam) = (push!(c.calls, :camera_ok); true)
struct NotOkBenchCam <: Camera                   # records calls; the fallback stop, and camera_ok says no
    calls::Vector{Symbol}
end
MC.initialize(c::NotOkBenchCam) = nothing
MC.shutdown(c::NotOkBenchCam) = nothing
MC.CameraInterface.abort(c::NotOkBenchCam) = (push!(c.calls, :abort); nothing)
read_sequence(c::NotOkBenchCam, n::Integer) = (push!(c.calls, :read); zeros(UInt16, 2, 3, n))
camera_ok(c::NotOkBenchCam) = (push!(c.calls, :camera_ok); false)
struct NoReaderCam <: Camera                     # records calls, and has no read_sequence method
    calls::Vector{Symbol}
end
NoReaderCam() = NoReaderCam(Symbol[])
MC.initialize(c::NoReaderCam) = (push!(c.calls, :initialize); nothing)
MC.shutdown(c::NoReaderCam) = (push!(c.calls, :shutdown); nothing)
MC.CameraInterface.abort(c::NoReaderCam) = (push!(c.calls, :abort); nothing)
camera_ok(c::NoReaderCam) = (push!(c.calls, :camera_ok); true)
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
    @test sys.in_flight == false && !(sys.cam in CAMERA_UNKNOWN)
    @test size(acquire!(sys, 3)) == (32, 64, 3)

    sys.in_flight = true
    for f in (() -> MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 2.5)),
              () -> acquire!(sys, 1), () -> MC.shutdown(sys))
        e = try f(); nothing catch e e end
        @test e !== nothing && occursin("in flight", message(e))
    end
    sys.in_flight = false

    held(cam) = (b = Bench(cam, SimStage3d(), SimLight()); MC.initialize(b); b)   # a system holding the camera
    unknown(sys) = sys.cam in CAMERA_UNKNOWN
    rec = RecordingCam()
    notyet = Bench(rec, SimStage3d(), SimLight())
    e = try acquire!(notyet, 1); nothing catch e e end
    @test message(e) == "the camera is not held: initialize(sys) first"         # before initialize
    @test isempty(rec.calls)                                                    # and no call reached the camera
    MC.initialize(notyet); MC.shutdown(notyet); empty!(rec.calls)
    e = try acquire!(notyet, 1); nothing catch e e end
    @test message(e) == "the camera is not held: initialize(sys) first"         # after shutdown
    @test isempty(rec.calls)
    rec = RecordingCam()
    withstuck = held(rec); empty!(rec.calls)
    push!(withstuck.stuck, BrokenLight() => ErrorException("x"))
    e = try acquire!(withstuck, 1); nothing catch e e end
    @test startswith(message(e), "devices in an unknown state")              # while a device is stuck
    @test isempty(rec.calls)
    rec = RecordingCam()
    marked = held(rec); empty!(rec.calls)
    mark_unknown!(rec)                                                          # as stop_reader! marks a camera
    e = try acquire!(marked, 1); nothing catch e e end
    @test startswith(message(e), "camera unavailable: it is marked unknown")
    @test isempty(rec.calls)
    nok = NotOkBenchCam(Symbol[])
    stopped = held(nok)
    stop_camera!(nok)                                                           # a standalone stop: it returns, camera_ok says no
    empty!(nok.calls)
    e = try acquire!(stopped, 1); nothing catch e e end
    @test startswith(message(e), "camera unavailable: it is marked unknown")
    @test isempty(nok.calls)                                                    # no call reached the camera
    rec = RecordingCam()
    fine = held(rec); empty!(rec.calls)
    @test size(acquire!(fine, 2)) == (2, 3, 2) && rec.calls == [:read, :camera_ok]   # the recorder sees calls

    norec = NoReaderCam()
    nocam = Bench(norec, SimStage3d(), SimLight(); claimed_at_construction = (norec,))
    e = try acquire!(nocam, 1); nothing catch e e end
    @test message(e) == "no sequence reader for NoReaderCam; write one (see mc-acquire)"
    @test isempty(norec.calls) && !unknown(nocam) && !nocam.in_flight   # refused before anything touched it

    @test has_reader(ParamCam{Int}(), 1) && has_reader(IntegerCam(), 1)   # parametric and Integer readers both count
    @test has_reader(IntegerCam(), Int16(1)) && !has_reader(ParamCam{Int}(), Int16(1))   # checked for the length's type
    @test !has_reader(NoReaderCam(), 1)
    param = held(ParamCam{Int}())
    e = try acquire!(param, Int16(1)); nothing catch e e end
    @test startswith(message(e), "no sequence reader for ParamCam") && !unknown(param)

    cam = FailingCam()
    bad = held(cam)
    e = try acquire!(bad, 3) catch e e end
    @test message(e) == "SDK: read failed"
    @test cam.aborts == 1 && camera_ok(cam)
    @test bad.in_flight == false && unknown(bad)                 # the read threw: marked, though the stop worked
    e = try acquire!(bad, 3) catch e e end
    @test startswith(message(e), "camera unavailable") && cam.aborts == 1   # refused: the camera saw no call

    bad = held(FailingCam(abort_mode = :throws))
    e = try acquire!(bad, 3) catch e e end
    @test message(e) == "SDK: read failed"
    @test unknown(bad)
    e = try acquire!(bad, 3) catch e e end
    @test startswith(message(e), "camera unavailable")
    MC.shutdown(bad)
    @test MC.initialize(bad) === bad                             # initialize succeeds ...
    e = try acquire!(bad, 3) catch e e end
    @test startswith(message(e), "camera unavailable")           # ... and acquire! still refuses
    rebuilt = Bench(mkcam(), bad.stage, bad.laser); MC.initialize(rebuilt)
    @test size(acquire!(rebuilt, 3)) == (32, 64, 3)

    for (mode, running) in ((:keeps_running, true), (:clears_flag, false))
        cam = FailingCam(abort_mode = mode)
        bad = held(cam)
        e = @test_logs (:error, r"the stop after a failed acquisition: the camera is not known stopped") match_mode = :any (try acquire!(bad, 3) catch e e end)
        @test message(e) == "SDK: read failed"
        @test cam.aborts == 1 && cam.is_running == running && unknown(bad)
    end

    cam = FailingCam(abort_mode = :clears_then_throws)
    bad = held(cam)
    e = @test_logs (:error, r"the stop after a failed acquisition: the camera is not known stopped") match_mode = :any (try acquire!(bad, 3) catch e e end)
    @test message(e) == "SDK: read failed"
    @test camera_ok(cam) && unknown(bad)                          # camera_ok would say yes; the throws decided

    cam = FailingCam(abort_mode = :interrupted)
    bad = held(cam)
    e = try acquire!(bad, 3) catch e e end
    @test e isa InterruptException && unknown(bad)               # the Ctrl-C reached the caller

    cam = FailingCam(read_fails = false, cleanup_fails = true)
    bad = held(cam)
    @test size(acquire!(bad, 4)) == (2, 3, 4)                    # the stack comes back
    @test unknown(bad) && cam.aborts == 0                        # and the camera is out of service

    for into in (:timer, :waiter)                                # where the Ctrl-C lands
        slow = Bench(SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.02), SimStage3d(), SimLight())
        MC.initialize(slow)
        running = @async acquire!(slow, 20)                       # about 0.4 s of exposures
        sleep(0.1)
        timer = SIM_TIMER[slow.cam]
        schedule(into === :timer ? timer : running, InterruptException(); error = true)
        e = try join_task(running); nothing catch err err end
        @test e isa InterruptException                            # plain, wherever it landed
        @test istaskdone(timer) && slow.cam.is_running == false   # the camera was stopped
        @test unknown(slow) && !slow.in_flight                    # and marked: the read threw
    end
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

SKILL_EXAMPLE_GROUPS["testing"] = (min_passes = 164, prelude = "", checks = raw"""
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
    stage = SimStage3d()                         # the checks run with only the Sim stages' status lines dropped
    move(stage, 1.0, 2.0, 3.0)
    @test getposition(stage) == 3.0                                                    # a scalar, the last assignment
    @test (stage.real_x, stage.real_y, stage.real_z) == (1.0, 2.0, 3.0)
    move(stage, 1e6, 0.0, 0.0)                                                         # no range enforcement
    @test stage.targ_x == 1e6
    home(stage)
    @test stage.real_x == 0.0 && stage.targ_x == 1e6                                   # home zeroes real_*, not targ_*
    @test_throws MethodError move(stage, 1, 2, 3)
    @test getrange(stage) == ((0.0, 100.0), (0.0, 100.0), (0.0, 100.0))
    two = SimStage2d()
    err = try move(two, 1.0, 2.0, 3.0); nothing catch e e end
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
    e = try TCubeLaser("00000000"; kw..., tia_range = 2e-3); nothing catch err err end
    @test e isa ArgumentError && occursin("is not a TLD001 photodiode range", e.msg)
    ref = (tia_range = tia, ref_current_mA = 71.0, ref_photocurrent_A = 0.85e-3)         # indicates 85 mW, above 33
    @test SimDiodeLaser(; kw..., ref...) isa SimDiodeLaser
    e = try TCubeLaser("00000000"; kw..., ref...); nothing catch err err end
    @test e isa ArgumentError && occursin("above properties.max_power", e.msg)
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

SKILL_EXAMPLE_GROUPS["acquire-reader"] = (min_passes = 67, prelude = FAKE_DCAM_PRELUDE * """
cam = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))
latest = Ref{Any}(nothing)
fps = 100
""", checks = raw"""
@test latest[] !== nothing && size(latest[]) == (32, 64)       # the reader read frames until stopped
@test istaskdone(h.reader) && !istaskfailed(h.reader)           # joined, and it ended on its own flag
@test outcome == (reader_error = nothing, stop_error = nothing, camera_ok = true) && in_service(cam)
@test cam.is_running == false && h.state === :done

Base.@kwdef mutable struct RecLiveCam <: Camera                 # records every call made to it; each step fails as chosen
    calls::Vector{Symbol} = Symbol[]
    live_mode::Symbol = :works                                  # :works, :throws (an ordinary error) or :interrupt
    started::Any = true                                         # what live_started says, or :interrupt to throw one
    abort_mode::Symbol = :works                                 # :works, :throws or :interrupt
    stopped::Bool = true                                        # what camera_ok says
    frame_fails::Bool = false                                   # getlastframe throws, as an SDK read that failed
    frame_wait::Float64 = 0.0                                   # getlastframe takes this long, as a long SDK call
    reserved_at_live::Bool = false                              # whether the camera was reserved when live was called
end
fail_as(mode, what) = mode === :throws ? error("SDK: $what failed") : mode === :interrupt ? throw(InterruptException()) : nothing
MC.CameraInterface.live(c::RecLiveCam) = (push!(c.calls, :live); c.reserved_at_live = c in CAMERA_LIVE; fail_as(c.live_mode, "live"))
function MC.CameraInterface.getlastframe(c::RecLiveCam)
    push!(c.calls, :getlastframe)
    c.frame_wait > 0 && sleep(c.frame_wait)
    c.frame_fails && error("reader: SDK read failed")
    return nothing
end
MC.CameraInterface.abort(c::RecLiveCam) = (push!(c.calls, :abort); fail_as(c.abort_mode, "stop"))
live_started(c::RecLiveCam) = (push!(c.calls, :live_started); c.started === :interrupt ? throw(InterruptException()) : c.started)
camera_ok(c::RecLiveCam) = (push!(c.calls, :camera_ok); c.stopped)

# The published recipe, `live_view!`, on any camera; `body(h)` runs once the reader is up. Returns the handle, the
# outcome (`nothing` when something was thrown) and what was thrown.
function run_live(c; body = h -> sleep(0.05), h = ReaderHandle(c))
    outcome, err = nothing, nothing
    try
        outcome = live_view!(body, h, Ref{Any}(nothing), 100)
    catch e
        err = e
    end
    return (; h, outcome, err)
end
reused(r) = (try live_view!(h -> nothing, r.h, Ref{Any}(nothing), 100); nothing catch err err end)   # the same handle again
refused_new(e) = e isa ErrorException && occursin("make a new ReaderHandle", e.msg)

# A clean live view: the camera is reserved before live, and in service after the confirmed start and stop.
rc = RecLiveCam()
r = run_live(rc)
@test r.err === nothing && rc.reserved_at_live && r.outcome.camera_ok && in_service(rc)
@test r.h.state === :done && rc.calls[end-1:end] == [:abort, :camera_ok]
ncalls = length(rc.calls)
@test refused_new(reused(r)) && length(rc.calls) == ncalls       # a handle runs one live view; no call reached it
during = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))   # during the live view: reserved, so refused
seen = Any[]
r = run_live(during; body = h -> (push!(seen, during in CAMERA_LIVE);
                                  push!(seen, try read_sequence(during, 1); nothing catch err err end); sleep(0.05)))
@test seen[1] && seen[2] isa ErrorException && startswith(seen[2].msg, "camera unavailable: a live view holds it")
@test r.err === nothing && in_service(during) && during.is_running == false   # after the confirmed stop: in service

# A reader that throws: still joined, the camera still stopped, and the outcome carries the reader's error.
r = run_live(RecLiveCam(frame_fails = true))
@test r.err === nothing && r.outcome.reader_error isa TaskFailedException
@test occursin("reader: SDK read failed", sprint(showerror, r.outcome.reader_error))
@test r.outcome.stop_error === nothing && r.outcome.camera_ok && r.h.cam.calls[end-1:end] == [:abort, :camera_ok]
# A stop that throws an ordinary error: in the outcome, logged, and the camera marked unknown.
r = @test_logs (:error, r"not known stopped") match_mode = :any run_live(RecLiveCam(abort_mode = :throws))
@test r.err === nothing && r.outcome.stop_error isa ErrorException && r.outcome.camera_ok == false
@test r.h.cam in CAMERA_UNKNOWN
# After a confirmed start, a stop that returns unconfirmed: logged, marked unknown, and a guarded read refused.
declined = RecLiveCam(stopped = false)
r = @test_logs (:error, r"not known stopped") match_mode = :any run_live(declined)
@test r.err === nothing && r.outcome.camera_ok == false && declined in CAMERA_UNKNOWN
@test_throws r"^camera unavailable: it is marked unknown" with_camera(() -> push!(declined.calls, :read), declined)
@test !(:read in declined.calls)
# A stop that throws an interrupt: marked unknown, the interrupt rethrown, nothing logged at warning or above.
r = @test_logs min_level = Base.CoreLogging.Warn run_live(RecLiveCam(abort_mode = :interrupt))
@test r.err isa InterruptException && r.h.cam in CAMERA_UNKNOWN
mutable struct PrologueCam <: Camera                            # its stop is interrupted before with_stop is reached
    calls::Vector{Symbol}
end
MC.CameraInterface.live(c::PrologueCam) = (push!(c.calls, :live); nothing)
MC.CameraInterface.getlastframe(c::PrologueCam) = nothing
live_started(c::PrologueCam) = true
stop_camera!(c::PrologueCam) = throw(InterruptException())
pro = PrologueCam(Symbol[])
r = @test_logs min_level = Base.CoreLogging.Warn run_live(pro)
@test r.err isa InterruptException && pro in CAMERA_UNKNOWN && r.h.state === :done
@test_throws r"^camera unavailable" with_camera(() -> push!(pro.calls, :read), pro)   # a guarded read is refused
@test pro.calls == [:live]

# A camera marked unknown is refused before any call reaches it, the stop calls nothing either, and the handle is used.
marked = RecLiveCam(); mark_unknown!(marked)
r = run_live(marked)
@test r.err isa ErrorException && startswith(r.err.msg, "camera unavailable: it is marked unknown")
@test isempty(marked.calls) && r.h.state === :done && r.h.stop[] && refused_new(reused(r))
mutable struct EarlyCam <: Camera                               # an interrupt lands in the refusal, before the reservation
    calls::Vector{Symbol}
    armed::Bool
end
MC.CameraInterface.live(c::EarlyCam) = (push!(c.calls, :live); nothing)
MC.CameraInterface.abort(c::EarlyCam) = (push!(c.calls, :abort); nothing)
Base.in(c::EarlyCam, s::Base.IdSet{Camera}) =                   # the hook: the refusal's first look at a set
    c.armed ? (c.armed = false; throw(InterruptException())) : invoke(in, Tuple{Any,Base.IdSet}, c, s)
early = EarlyCam(Symbol[], true)
r = run_live(early)
@test r.err isa InterruptException && !early.armed && isempty(early.calls) && in_service(early)
@test r.h.state === :done                                       # unstarted, nothing to stop, and the handle used

# A live start that fails: no reader, a stop attempted, and the camera marked unknown, a confirmed stop included.
notlive = RecLiveCam(started = false)                           # live returns, and live_started says no
r = @test_logs min_level = Base.CoreLogging.Warn run_live(notlive)   # a stop the driver confirms is not logged
@test r.err isa ErrorException && occursin("did not start", r.err.msg) && occursin("attempts the stop", r.err.msg)
@test notlive.calls == [:live, :live_started, :abort, :camera_ok] && notlive in CAMERA_UNKNOWN && r.h.reader === nothing
unconfirmed = RecLiveCam(started = false, stopped = false)      # the same, and the stop returns unconfirmed
r = @test_logs (:error, r"not known stopped") match_mode = :any run_live(unconfirmed)
@test occursin("did not start", r.err.msg) && unconfirmed in CAMERA_UNKNOWN && r.h.reader === nothing
throws = RecLiveCam(live_mode = :throws)                        # live throws: the stop runs, live's error comes out
r = run_live(throws)
@test r.err isa ErrorException && r.err.msg == "SDK: live failed"
@test throws.calls == [:live, :abort, :camera_ok] && throws in CAMERA_UNKNOWN && r.h.reader === nothing
intstop = RecLiveCam(started = false, abort_mode = :interrupt)  # the stop after a failed start throws an interrupt
r = run_live(intstop)
@test r.err isa InterruptException && intstop.calls == [:live, :live_started, :abort] && intstop in CAMERA_UNKNOWN
@test r.h.reader === nothing
inlive = RecLiveCam(live_mode = :interrupt)                     # an interrupt inside live
r = run_live(inlive)
@test r.err isa InterruptException && inlive.calls == [:live, :abort, :camera_ok] && inlive in CAMERA_UNKNOWN
@test r.h.reader === nothing
between = RecLiveCam(started = :interrupt)                      # an interrupt in live_started, after live returned
r = run_live(between)
@test r.err isa InterruptException && between.calls == [:live, :live_started, :abort, :camera_ok]
@test between in CAMERA_UNKNOWN && r.h.reader === nothing
bare = RecLiveCam(started = false)                              # start_reader! alone, with no finally around it
hb = ReaderHandle(bare)
e = try start_reader!(hb, Ref{Any}(nothing), 100); nothing catch err err end
@test e isa ErrorException && bare in CAMERA_LIVE && !(bare in CAMERA_UNKNOWN) && bare.calls == [:live, :live_started]
@test hb.state === :starting                                    # reserved and unstopped, until the stop it is owed
stop_reader!(hb)
@test bare.calls == [:live, :live_started, :abort, :camera_ok] && bare in CAMERA_UNKNOWN && hb.state === :done
win = RecLiveCam()                                              # a handle :live with no reader, as an interrupt just
hw = ReaderHandle(win)                                          # after `h.state = :live`, before the launch, leaves it
push!(CAMERA_LIVE, win); hw.state = :live; live(win)
r = stop_reader!(hw)
@test r.camera_ok && in_service(win) && win.calls == [:live, :abort, :camera_ok]   # stopped, the reservation ended

FK.reset!(); FK.codes["dcambuf_alloc"] = DCAM4.DCAMERR_NOMEMORY # DCAM4 over the fake SDK: a failed allocation
nolive = fake_dcam(DCAM4.LIVE)
r = run_live(nolive)
@test r.err isa ErrorException && occursin("did not start", r.err.msg) && nolive in CAMERA_UNKNOWN && !nolive.is_running
@test r.h.reader === nothing && !("dcamwait_open" in FK.calls)  # no reader: its getlastframe would open a frame wait
FK.reset!()
half = fake_dcam(DCAM4.LIVE)                                    # an error reported while the capture went ahead
FK.on_start[] = mode -> (half.last_error = DCAM4.DCAMERR_NOTREADY; FK.status[] = DCAM4.DCAMCAP_STATUS_BUSY)
r = run_live(half)
@test r.err isa ErrorException && half in CAMERA_UNKNOWN && r.h.reader === nothing
@test !half.is_running && "dcamcap_stop" in FK.calls && !("dcamwait_open" in FK.calls)   # stopped, and no reader
FK.reset!()
stuck = fake_dcam(DCAM4.LIVE)                                   # the same, and then the stop fails too
FK.on_start[] = mode -> (stuck.last_error = DCAM4.DCAMERR_NOTREADY; FK.status[] = DCAM4.DCAMCAP_STATUS_BUSY)
FK.codes["dcamcap_stop"] = DCAM4.DCAMERR_NOTREADY
r = @test_logs (:error, r"not known stopped") match_mode = :any run_live(stuck)
@test occursin("did not start", r.err.msg) && stuck in CAMERA_UNKNOWN && r.h.reader === nothing
@test stuck.is_running && stuck.last_error == DCAM4.DCAMERR_NOTREADY && "dcamcap_stop" in FK.calls   # still running
FK.reset!()
owner = fake_dcam(DCAM4.LIVE)                                   # the owner ends the reader and stops the camera itself,
function own_stop(h)                                            # the driver reports a failed release, and the recipe's
    h.stop[] = true                                             # later stop then succeeds
    join_task(h.reader)
    FK.status[] = DCAM4.DCAMCAP_STATUS_READY
    FK.codes["dcambuf_release"] = DCAM4.DCAMERR_NOTREADY
    push!(seen_owner, stop_camera!(h.cam))
    delete!(FK.codes, "dcambuf_release")
end
seen_owner = Any[]
r = run_live(owner; body = own_stop)
@test seen_owner == [false] && r.err === nothing && r.outcome.stop_error === nothing && !owner.is_running
@test owner in CAMERA_UNKNOWN && !(owner in CAMERA_LIVE)        # the failure outlasts the confirmed stop
@test_throws r"^camera unavailable: it is marked unknown" read_sequence(owner, 2)
FK.reset!()

# A Ctrl-C lands in the reader, which wakes every frame: the body runs on, and the join rethrows it, plainly.
interrupt_reader(h) = (sleep(0.05); schedule(h.reader, InterruptException(); error = true); sleep(0.05))
cam4 = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))
r = run_live(cam4; body = interrupt_reader)
@test r.err isa InterruptException                              # plain, not a TaskFailedException
@test cam4.is_running == false && in_service(cam4)              # the reader had ended, so the camera was stopped
@test refused_new(reused(r))                                    # its handle again: refused, not the old interrupt
failing = RecLiveCam(abort_mode = :throws)                      # the same, and the stop fails: logged, then rethrown
r = @test_logs (:error, r"not known stopped") match_mode = :any run_live(failing; body = interrupt_reader)
@test r.err isa InterruptException && failing in CAMERA_UNKNOWN

# The wait itself ends with an exception while the reader still runs (a Ctrl-C, or anything else).
for thrown in (InterruptException(), ErrorException("the wait timed out"))
    slow = RecLiveCam(frame_wait = 3.0)                         # a reader inside a long SDK call
    h3 = ReaderHandle(slow)
    start_reader!(h3, Ref{Any}(nothing), 100)
    sleep(0.05)
    stopping = @async stop_reader!(h3)
    sleep(0.1)
    schedule(stopping, thrown; error = true)                    # delivered to the task waiting for the reader
    local e = try join_task(stopping); nothing catch err err end
    @test thrown isa InterruptException ? e isa InterruptException : (e isa TaskFailedException && e.task.exception === thrown)
    @test !istaskdone(h3.reader) && !(:abort in slow.calls)     # the camera was left alone
    @test slow in CAMERA_LIVE && !(slow in CAMERA_UNKNOWN) && h3.state === :live   # reserved; its stop still owed
end
""")

SKILL_EXAMPLE_GROUPS["acquire-snap"] = (min_passes = 14, prelude = FAKE_DCAM_PRELUDE, checks = raw"""
sim = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
@test size(snap(sim)) == (32, 64)
@test sim.capture_mode == MC.HardwareImplementations.SimulatedCamera.SINGLE_FRAME   # capture ran before the read
@test snap(SimCamera(roi = CameraROI(1, 1, 64, 32))) isa Matrix{UInt16}
@test which(snap, Tuple{SimCamera}).sig.parameters[2] === SimCamera
@test which(snap, Tuple{DCAM4Camera}).sig.parameters[2] === Camera              # the hardware drivers take the generic method
struct SnapRecCam <: Camera                                                     # records every call made to it
    calls::Vector{Symbol}
end
MC.CameraInterface.capture(c::SnapRecCam) = (push!(c.calls, :capture); zeros(UInt16, 2, 3))
camera_ok(c::SnapRecCam) = true
rc = SnapRecCam(Symbol[])
@test size(snap(rc)) == (2, 3) && rc.calls == [:capture]
mark_unknown!(rc); empty!(rc.calls)
@test_throws r"^camera unavailable: it is marked unknown" snap(rc)
@test isempty(rc.calls)                                                         # refused: no call reached the camera
simmark = SimCamera(roi = CameraROI(1, 1, 64, 32))
mark_unknown!(simmark)
@test_throws r"^camera unavailable" snap(simmark)
@test simmark.capture_mode == MC.HardwareImplementations.SimulatedCamera.LIVE   # the Sim method refuses too: not captured
FK.reset!()
FK.values[Int32(DCAM4.DCAM_IDPROP_IMAGE_WIDTH)] = 3.0                            # a non-square frame: 2 rows, 3 columns
FK.values[Int32(DCAM4.DCAM_IDPROP_IMAGE_ROWBYTES)] = 6.0
dc = fake_dcam(DCAM4.LIVE)
@test size(snap(dc)) == (2, 3) && !(dc in CAMERA_UNKNOWN)                        # DCAM4 over the fake SDK: (H, W)
mark_unknown!(dc); empty!(FK.start_modes)
@test_throws r"^camera unavailable" snap(dc)
@test isempty(FK.start_modes)                                                   # no capture started
FK.reset!(); FK.codes["dcambuf_alloc"] = DCAM4.DCAMERR_NOMEMORY                 # the driver reports a failed allocation
dc2 = fake_dcam(DCAM4.LIVE)
@test snap(dc2) === nothing && dc2 in CAMERA_UNKNOWN                            # nothing, and the camera is marked
FK.reset!()
""")
SKILL_EXAMPLE_GROUPS["acquire-exposure"] = (min_passes = 6, prelude = "using MicroscopeControl; cam = SimCamera()", checks = raw"""
@test cam.exposure_time == 0.02
@test (cam.roi.x_start, cam.roi.y_start, cam.roi.width, cam.roi.height) == (1, 1, 512, 256)
@test fieldtype(ThorCamCSCCamera, :exposure_time) == Clonglong                  # an integer field (microseconds)
@test_throws InexactError convert(Clonglong, 0.02)
@test fieldtype(DCAM4Camera, :exposure_time) == Float64 && fieldtype(ThorcamDCXCamera, :exposure_time) == Float64
@test ThorcamDCXCamera().exposure_time == 0.01                                  # the constructor is pure
""")
SKILL_EXAMPLE_GROUPS["camera"] = (min_passes = 76, prelude = FAKE_DCAM_PRELUDE, checks = raw"""
cam = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
t = @elapsed stack = read_sequence(cam, 5)
@test size(stack) == (32, 64, 5) && eltype(stack) == UInt16
@test t >= 5 * 0.01                                                             # the timer was joined
@test camera_ok(cam) && cam.is_running == false
@test getdata(cam) != stack                                                     # the same finished sequence, read again
@test read_sequence(cam, 5) != stack                                            # a second sequence: new frames
neg = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
e = try read_sequence(neg, -1); nothing catch err err end
@test e isa ArgumentError && neg in CAMERA_UNKNOWN                              # a read that throws marks the camera
running = SimCamera()
running.is_running = true
@test !haskey(SIM_TIMER, running) && camera_ok(running) == false                # set flag, no timer: not stopped
slow = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.02)
reading = @async read_sequence(slow, 20)                                        # about 0.4 s of timer
sleep(0.1)
timer = SIM_TIMER[slow]
@test !istaskdone(timer) && size(getdata(slow)) == (32, 64, 20)                 # getdata returns at once, mid-sequence
@test getdata(slow) != getdata(slow)                                            # and nothing mid-sequence is cached
abort(slow)
@test slow.is_running == false && !istaskdone(timer)                           # abort leaves the timer running
@test camera_ok(slow) == false                                                  # so the camera is not yet known stopped
@test stop_camera!(slow) === true                                               # the stop, confirmed
@test istaskdone(timer) && camera_ok(slow)                                      # stop_camera! waited for it
@test size(fetch(reading)) == (32, 64, 20)
struct UnknownCam <: Camera end
@test_throws r"^no sequence reader for UnknownCam; write one \(see mc-acquire\)$" read_sequence(UnknownCam(), 1)
@test camera_ok(UnknownCam()) == false
marked = SimCamera()
mark_unknown!(marked)
@test camera_ok(marked) && (marked in CAMERA_UNKNOWN)                           # the mark, not the driver, says no
@test_throws r"^camera unavailable" read_sequence(marked, 1)
struct NotOkCam <: Camera                                                       # its stop returns; camera_ok says no
    calls::Vector{Symbol}
end
MC.CameraInterface.abort(c::NotOkCam) = (push!(c.calls, :abort); nothing)
camera_ok(c::NotOkCam) = (push!(c.calls, :camera_ok); false)
nok = NotOkCam(Symbol[])
@test stop_camera!(nok) === false                                               # a standalone stop, the fallback's
@test nok.calls == [:abort, :camera_ok] && nok in CAMERA_UNKNOWN                 # it returned, and marked the camera
nok2 = NotOkCam(Symbol[])                                                       # attempt_stop!: an unconfirmed stop
@test (@test_logs (:error, r"^here: the camera is not known stopped") attempt_stop!(nok2, "here")) ==
      (stop_error = nothing, stopped = false)
mutable struct AbortFailsCam <: Camera                                          # mutable: each is its own camera
    interrupt::Bool
end
MC.CameraInterface.abort(c::AbortFailsCam) = c.interrupt ? throw(InterruptException()) : error("SDK: abort failed")
af = AbortFailsCam(false)
r = @test_logs (:error, r"not known stopped") attempt_stop!(af, "here")         # a stop that throws: logged, returned
@test r.stop_error isa ErrorException && r.stop_error.msg == "SDK: abort failed" && !r.stopped && af in CAMERA_UNKNOWN
ai = AbortFailsCam(true)
e = @test_logs min_level = Base.CoreLogging.Warn (try attempt_stop!(ai, "here"); nothing catch err err end)
@test e isa InterruptException && ai in CAMERA_UNKNOWN                          # rethrown, not logged
@test (@test_logs min_level = Base.CoreLogging.Warn attempt_stop!(SimCamera(), "here")) ==
      (stop_error = nothing, stopped = true)                                    # confirmed: quiet
mutable struct InterruptOnceLogger <: Base.CoreLogging.AbstractLogger         # throws an interrupt once, as it writes
    thrown::Bool
    messages::Vector{Any}
end
Base.CoreLogging.min_enabled_level(::InterruptOnceLogger) = Base.CoreLogging.Debug
Base.CoreLogging.shouldlog(::InterruptOnceLogger, args...) = true
Base.CoreLogging.catch_exceptions(::InterruptOnceLogger) = true                 # as the console logger's
function Base.CoreLogging.handle_message(l::InterruptOnceLogger, level, msg, args...; kwargs...)
    l.thrown || (l.thrown = true; throw(InterruptException()))
    push!(l.messages, msg)
    return nothing
end
lg = InterruptOnceLogger(false, Any[])
nok3 = NotOkCam(Symbol[])
r = Base.CoreLogging.with_logger(() -> attempt_stop!(nok3, "here"), lg)         # the limitation: Julia's logging
@test lg.thrown && r == (stop_error = nothing, stopped = false) && nok3 in CAMERA_UNKNOWN   # swallowed the interrupt
@test any(m -> occursin("Exception while generating log record", string(m)), lg.messages)
reserved = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)       # a camera a live view holds
push!(CAMERA_LIVE, reserved)
@test_throws r"^camera unavailable: a live view holds it" read_sequence(reserved, 1)
@test reserved.capture_mode == MC.HardwareImplementations.SimulatedCamera.LIVE && !in_service(reserved)
delete!(CAMERA_LIVE, reserved)
struct EarlyStopCam <: Camera end                                               # interrupted before with_stop is reached
stop_camera!(::EarlyStopCam) = throw(InterruptException())
esc = EarlyStopCam()
@test_throws InterruptException attempt_stop!(esc, "here")
@test esc in CAMERA_UNKNOWN                                                     # marked all the same
simmarked = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
mark_unknown!(simmarked)
@test_throws r"^camera unavailable: it is marked unknown" read_sequence(simmarked, 3)
@test simmarked.capture_mode == MC.HardwareImplementations.SimulatedCamera.LIVE && !haskey(SIM_TIMER, simmarked)   # unstarted
@test with_camera(() -> 7, SimCamera()) == 7                                     # with_camera returns f's value
okcam = SimCamera()
@test with_camera(() -> 8, okcam; ok = _ -> false) == 8 && okcam in CAMERA_UNKNOWN   # and marks on a false postcondition
ic = SimCamera()
@test_throws InterruptException with_camera(() -> throw(InterruptException()), ic)
@test ic in CAMERA_UNKNOWN                                                      # an interrupt marks too, and is rethrown
mc_ = SimCamera(); mark_unknown!(mc_)
ran = Ref(false)
@test_throws MethodError with_camera(() -> (ran[] = true), mc_; refuse = false)  # no keyword turns the refusal off
@test !ran[]
@test with_stop(() -> (ran[] = true), mc_) === true && ran[] && mc_ in CAMERA_UNKNOWN   # a stop is let through; marked still
function fake_sequence!(; release_fails = false)          # a two-frame sequence, BUSY for 50 ms after its start
    FK.reset!(); FK.frames_transferred[] = 2
    t0 = Ref(0.0)
    FK.on_start[] = mode -> (t0[] = time(); release_fails && (FK.codes["dcambuf_release"] = DCAM4.DCAMERR_NOTREADY))
    FK.on_status[] = () -> (FK.status[] = time() - t0[] < 0.05 ? DCAM4.DCAMCAP_STATUS_BUSY : DCAM4.DCAMCAP_STATUS_READY)
    FK.status[] = DCAM4.DCAMCAP_STATUS_STABLE
end
fake_sequence!()
clean = fake_dcam(DCAM4.SEQUENCE)
@test size(read_sequence(clean, 2)) == (2, 2, 2) && !(clean in CAMERA_UNKNOWN)  # DCAM4, a clean read
fake_sequence!(release_fails = true)
leaky = fake_dcam(DCAM4.SEQUENCE)
@test size(read_sequence(leaky, 2)) == (2, 2, 2)                                # the release fails: the stack comes back
@test leaky.last_error == DCAM4.DCAMERR_NOTREADY && leaky in CAMERA_UNKNOWN      # and the camera is marked
timedwait(() -> !leaky.is_running, 5.0)
delete!(FK.codes, "dcambuf_release"); empty!(FK.start_modes)
@test_throws r"^camera unavailable" read_sequence(leaky, 2)
@test isempty(FK.start_modes)                                                   # refused before the driver started anything
ncalls = length(FK.calls)
stop_camera!(leaky)
@test length(FK.calls) > ncalls                                                 # a stop on the marked camera still runs
FK.reset!(); FK.status[] = DCAM4.DCAMCAP_STATUS_READY                            # a standalone stop on a fresh camera,
FK.codes["dcambuf_release"] = DCAM4.DCAMERR_NOTREADY                            # whose release the driver reports failed
fresh = fake_dcam(DCAM4.SEQUENCE)
@test stop_camera!(fresh) === false                                             # unconfirmed
@test fresh.last_error == DCAM4.DCAMERR_NOTREADY && fresh in CAMERA_UNKNOWN     # marks it
FK.reset!()
dl = fake_dcam(DCAM4.LIVE)
live(dl)
@test live_started(dl)                                                          # a clean DCAM4 live start
@test stop_camera!(dl) === true                                                 # confirmed
@test !dl.is_running && !(dl in CAMERA_UNKNOWN)
FK.reset!(); FK.codes["dcambuf_alloc"] = DCAM4.DCAMERR_NOMEMORY                 # live returns, its allocation failed
dl2 = fake_dcam(DCAM4.LIVE)
live(dl2)
@test !live_started(dl2) && !dl2.is_running
FK.reset!()
@test live_started(SimCamera()) == false                                        # Sim: not running, not started
sl = SimCamera(); live(sl)
@test live_started(sl)
pc = SimCamera()                                                                # a postcondition that throws
@test_throws InterruptException with_camera(() -> 1, pc; ok = _ -> throw(InterruptException()))
@test pc in CAMERA_UNKNOWN
@test_throws r"^camera unavailable" read_sequence(pc, 1)                        # the same camera is refused next
endless = SimCamera(exposure_time = 0.01, sequence_length = 1)                  # a timer that never ends
SIM_TIMER[endless] = @async sleep(30)
took = @elapsed (e = try stop_camera!(endless); nothing catch err err end)
@test e isa ErrorException && occursin("timer did not end", e.msg) && took < 5  # the wait is bounded (1.01 s here)
@test endless in CAMERA_UNKNOWN                                                 # the stop threw: marked
@test_throws r"^camera unavailable" read_sequence(endless, 3)                   # so a read on the same camera is refused
@test endless.capture_mode == MC.HardwareImplementations.SimulatedCamera.LIVE   # and the camera was not started
interrupted = @async sleep(30)
yield(); schedule(interrupted, InterruptException(); error = true)
@test_throws InterruptException join_task(interrupted)                          # plain, not a TaskFailedException
failed = @async error("not an interrupt")
@test_throws TaskFailedException join_task(failed)                              # any other failure stays wrapped
normal = @async 42
join_task(normal)                                                               # a task that ends normally: no throw
@test istaskdone(normal) && fetch(normal) == 42
for T in (SimCamera, DCAM4Camera)
    @test which(read_sequence, Tuple{T,Int}).sig.parameters[2] === T && which(camera_ok, Tuple{T}).sig.parameters[2] === T
    @test which(stop_camera!, Tuple{T}).sig.parameters[2] === T
end
for T in (ThorcamDCXCamera, ThorCamCSCCamera)                                   # not covered: the fallback
    @test which(read_sequence, Tuple{T,Int}).sig.parameters[2] === Camera && which(camera_ok, Tuple{T}).sig.parameters[2] === Camera
end
@test !isassigned(ThorcamDCXCamera().pImage_Mem, 1)                             # the table's unset first element
@test DCAM4.DCAMERR_SUCCESS isa DCAM4.DCAMERR && fieldtype(DCAM4Camera, :last_error) === DCAM4.DCAMERR
@test fieldtype(DCAM4Camera, :is_running) === Bool
""")

SKILL_EXAMPLE_GROUPS["acquire-zstack"] = (min_passes = 6, prelude = "", checks = raw"""
@test allunique(eachslice(stack; dims = 3))                                     # a new frame per plane, not one reused
const SimMode = MC.HardwareImplementations.SimulatedCamera
mutable struct ModeResetStage <: Stage              # every move puts the Sim camera back in SEQUENCE mode, where its
    cam::SimCamera                                  # getdata returns a stack: a plane is a frame only when snap's
    targ_x::Float64                                 # capture ran after that move
    targ_y::Float64
    targ_z::Float64
    real_z::Float64
end
MC.move(s::ModeResetStage, x::Float64, y::Float64, z::Float64) = (s.targ_z = z; s.cam.capture_mode = SimMode.SEQUENCE; nothing)
MC.getposition(s::ModeResetStage) = (s.real_z = s.targ_z)
sim = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01, sequence_length = 2)
@test size(zstack(sim, ModeResetStage(sim, 0.0, 0.0, 0.0, 0.0), zs)) == (32, 64, 5)   # capture after every move
mutable struct ZCam <: Camera                       # notes the stage's z inside capture, when the frame is taken
    stage::Stage
    taken_at::Vector{Float64}
end
MC.CameraInterface.capture(c::ZCam) = (push!(c.taken_at, c.stage.real_z); fill(UInt16(length(c.taken_at)), 2, 3))
camera_ok(::ZCam) = true                            # known stopped after each capture, so snap keeps it in service
zc = ZCam(SimStage3d(), Float64[])
s = zstack(zc, zc.stage, zs)
@test zc.taken_at == collect(zs)                                                # one capture per plane, after its move
@test [s[1, 1, i] for i in axes(s, 3)] == 1:length(zs)                          # each plane is that capture's frame
""")

SKILL_EXAMPLE_GROUPS["acquire-units"] = (min_passes = 6, prelude = "using MicroscopeControl; stage = PIStage()", checks = raw"""
@test PIStage().units == "Milimeters" && MCLStage().units == "Microns" && N472().units == "mm"
@test !hasfield(MCS2Stage, :units) && !hasfield(SimStage3d, :units)
for T in (MCS2Stage, SimStage3d)
    local e = try T().units; nothing catch err err end
    @test missing_field(e, T, :units)
end
@test_throws MethodError move(SimStage3d(), 1, 2, 3)
@test stage isa PIStage && hasfield(typeof(stage), :units)                      # the fence's guarded branch ran
""")
SKILL_EXAMPLE_GROUPS["apimap"] = (min_passes = 18, prelude = "", checks = raw"""
@test which(setcurrent!, Tuple{TCubeLaser{ConstantPhotocurrent},Float64}).sig.parameters[2] === DiodeLaser     # the stub, not a driver method
@test which(export_state, Tuple{TCubeLaser}).sig == Tuple{typeof(export_state), TCubeLaser}
@test hasmethod(export_state, Tuple{TCubeLaser,Any})                           # the deprecated forwarder is still there
@test !has_specific(setcurrent!, TCubeLaser, Float64)
""")
SKILL_EXAMPLE_GROUPS["extend-shim"] = (min_passes = 2, prelude = "", checks = raw"""
# the guard did not install the shim: dispatch lands on the driver's own method, not the abstract stub
@test which(MC.export_state, Tuple{MC.TCubeLaser}).sig.parameters[2] === MC.TCubeLaser
@test which(MC.export_state, Tuple{MC.TCubeLaser}).module !== @__MODULE__        # the driver's method, not a shim from here
""")
SKILL_EXAMPLE_GROUPS["extend-shadow"] = (min_passes = 5, prelude = "", checks = raw"""
@test_throws r"^setpower not implemented for .*ShadowLED$" MicroscopeControl.setpower(ShadowDriver.ShadowLED(), 1.0)
@test ShadowDriver.setpower !== MicroscopeControl.setpower
""")
SKILL_EXAMPLE_GROUPS["scaffold"] = (min_passes = 35, prelude = "", checks = raw"""
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
SKILL_EXAMPLE_GROUPS["shutter"] = (min_passes = 14, prelude = "", checks = raw"""
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
# The floor is one under the count: one check runs on Linux only (Triggerscope4 refusing a port name not on the host).
SKILL_EXAMPLE_GROUPS["statements"] = (min_passes = 125, prelude = "", checks = raw"""
@testset "statements: every function in the examples calls a camera only inside a wrapper" begin
    fenced = Main.skill_example_blocks(joinpath(pkgdir(MicroscopeControl), "skills"))
    offenders = Tuple{String,Int,Symbol,Symbol}[]
    wrapped = Set{Symbol}()
    for blocks in values(fenced), b in blocks
        off, w = Main.camera_call_report(b.code)
        append!(offenders, [(basename(dirname(b.file)), b.line, f, c) for (f, c) in off])
        union!(wrapped, w)
    end
    isempty(offenders) || @error "camera calls outside a wrapper, as (skill, fence line, function, call)" offenders
    @test isempty(offenders)
    @test wrapped == Set([:snap, :read_sequence, :stop_camera!, :start_reader!, :read_frames!])   # the skills' entries
    # what the rule sees
    rule(code) = Main.camera_calls_outside_wrapper(code)
    @test rule("f(cam) = capture(cam)") == [(:f, :capture)]
    @test rule("function g(c)\n    @async getlastframe(c)\nend") == [(:g, :getlastframe)]
    @test rule("h(c::C{T}, n) where {T} = (x = 1; MC.CameraInterface.abort(c))") == [(:h, :abort)]
    @test rule("f(cam, frame = capture(cam)) = frame") == [(:f, :capture)]                      # a default argument
    @test rule("f(cam; frame = capture(cam)) = frame") == [(:f, :capture)]                      # a keyword default
    @test rule("f(cam) = with_camera(cam; ok = (capture(cam); camera_ok)) do\n    nothing\nend") == [(:f, :capture)]   # eager
    @test rule("f(cam) = with_camera(getdata(cam), cam)") == [(:f, :getdata)]                   # an eager argument
    # the stop's wrapper: only in a stop_camera! method, and any reference to it elsewhere fails
    @test Set(rule("snap(cam) = with_stop(cam) do\n    capture(cam)\nend")) == Set([(:snap, :with_stop), (:snap, :capture)])
    @test rule("f(cam) = with_stop(() -> nothing, cam)") == [(:f, :with_stop)]
    @test rule("f(cam) = Base.invokelatest(with_stop, () -> nothing, cam)") == [(:f, :with_stop)]   # passed
    @test rule("f(cam) = Base.invokelatest(Main.with_stop, () -> nothing, cam)") == [(:f, :with_stop)]   # qualified
    @test rule("function f(cam)\n    w = with_stop\n    w(() -> nothing, cam)\nend") == [(:f, :with_stop)]   # bound
    @test isempty(rule("stop_camera!(cam) = with_stop(cam) do\n    abort(cam)\nend"))
    # the reader: getlastframe only in read_frames!, which starts no task, launched only as a task in start_reader!,
    # after a with_camera every path runs
    guard = "    started = with_camera(h.cam) do\n        live(h.cam)\n    end\n"
    launch = "    h.reader = @async read_frames!(h, latest, fps)\n"
    starter(body) = "function start_reader!(h, latest, fps)\n" * body * "end"
    @test isempty(rule(starter(guard * launch)))                                                 # the shape
    @test isempty(rule(starter(guard * "    if started\n" * launch * "    end\n")))             # dominated
    @test isempty(rule("function read_frames!(h, latest, fps)\n    while true\n        getlastframe(h.cam)\n    end\nend"))
    @test rule(starter("    @async getlastframe(h.cam)\n    refuse_unknown(h.cam)\n" * guard * launch)) ==
          [(:start_reader!, :getlastframe)]                                                     # a task before the guard
    @test rule(starter(guard * "    @async getlastframe(h.cam)\n")) == [(:start_reader!, :getlastframe)]   # not the loop
    @test rule(starter(launch * guard)) == [(:start_reader!, :read_frames!)]                     # launched before the guard
    @test rule(starter("    if fps > 0\n" * guard * "    else\n" * launch * "    end\n")) ==
          [(:start_reader!, :read_frames!)]                                                     # the guard in the other arm
    @test rule(starter("    if fps > 0\n" * guard * "    end\n" * launch)) == [(:start_reader!, :read_frames!)]   # in an if
    @test rule(starter("    try\n" * guard * "    catch\n    end\n" * launch)) ==
          [(:start_reader!, :read_frames!)]                                                     # in a try
    @test rule(starter("    started = with_camera(h.cam) do\n        live(h.cam)\n" * launch * "    end\n")) ==
          [(:start_reader!, :read_frames!)]                                                     # inside the guard
    @test rule(starter(guard * "    read_frames!(h, latest, fps)\n")) == [(:start_reader!, :read_frames!)]   # not a task
    @test rule("peek(h) = @async read_frames!(h, Ref{Any}(), 10)") == [(:peek, :read_frames!)]   # launched elsewhere
    @test rule("function read_frames!(h, latest, fps)\n    capture(h.cam)\nend") == [(:read_frames!, :capture)]
    @test rule("function read_frames!(h, latest, fps)\n    @async getlastframe(h.cam)\nend") == [(:read_frames!, :task)]
    @test rule("function read_frames!(h, latest, fps)\n    schedule(Task(() -> nothing))\nend") == [(:read_frames!, :task)]
    @test rule("function read_frames!(h, latest, fps)\n    Base.@async getlastframe(h.cam)\nend") == [(:read_frames!, :task)]
    @test rule("function read_frames!(h, latest, fps)\n    Threads.@spawn getlastframe(h.cam)\nend") == [(:read_frames!, :task)]
    @test rule("function read_frames!(h, latest, fps)\n    Threads.@threads for i in 1:2\n        getlastframe(h.cam)\n" *
               "    end\nend") == [(:read_frames!, :task)]
    @test rule("function read_frames!(h, latest, fps)\n    Timer(_ -> getlastframe(h.cam), 0.1)\nend") == [(:read_frames!, :task)]
    @test rule(starter("    guard() = with_camera(h.cam) do\n        live(h.cam)\n    end\n" * launch)) ==
          [(:start_reader!, :read_frames!)]                                                     # a local guard, never run
    @test rule(starter("    guard() = with_camera(h.cam) do\n        live(h.cam)\n    end\n    started = guard()\n" * launch)) ==
          [(:start_reader!, :read_frames!)]                                                     # a local guard, run
    @test isempty(rule(starter(guard * "    h.reader = Base.@async read_frames!(h, latest, fps)\n")))   # qualified, a task
    # the one reference rule: each name only in the functions listed for it, the top level included
    @test rule("f(cam) = delete!(CAMERA_UNKNOWN, cam)") == [(:f, :CAMERA_UNKNOWN)]
    @test rule("f() = empty!(CAMERA_UNKNOWN)") == [(:f, :CAMERA_UNKNOWN)]
    @test rule("f(cam) = delete!(Main.CAMERA_UNKNOWN, cam)") == [(:f, :CAMERA_UNKNOWN)]          # qualified
    @test rule("function f(cam)\n    s = CAMERA_UNKNOWN\n    delete!(s, cam)\nend") == [(:f, :CAMERA_UNKNOWN)]   # aliased
    @test rule("delete!(CAMERA_UNKNOWN, cam)") == [(:toplevel, :CAMERA_UNKNOWN)]                 # at the top level
    @test rule("empty!(CAMERA_UNKNOWN)") == [(:toplevel, :CAMERA_UNKNOWN)]
    @test rule("stop_reader!(h) = delete!(CAMERA_UNKNOWN, h.cam)") == [(:stop_reader!, :CAMERA_UNKNOWN)]   # not even here
    @test rule("f(cam) = push!(CAMERA_LIVE, cam)") == [(:f, :CAMERA_LIVE)]
    @test rule("forgive(cam) = getfield(Main, :CAMERA_LIVE)") == [(:forgive, :CAMERA_LIVE)]      # quoted
    @test rule("const w = with_stop") == [(:toplevel, :with_stop)]
    @test rule("start_reader!(h, Ref{Any}(), 10)") == [(:toplevel, :start_reader!)]              # outside live_view!
    @test rule("function g(h)\n    try\n        start_reader!(h, Ref{Any}(), 10)\n    finally\n        stop_reader!(h)\n" *
               "    end\nend") == [(:g, :start_reader!), (:g, :stop_reader!)]
    @test isempty(rule("const CAMERA_UNKNOWN = Base.IdSet{Camera}()\nmark_unknown!(cam) = push!(CAMERA_UNKNOWN, cam)"))
    @test isempty(rule("stop_reader!(h) = delete!(CAMERA_LIVE, h.cam)\nlive_view!(h) = (start_reader!(h); stop_reader!(h))"))
    @test isempty(rule("f(cam) = with_camera(cam) do\n    capture(cam)\nend"))
    @test isempty(rule("f(cam) = with_camera(() -> capture(cam), cam)"))
    @test isempty(rule("MC.CameraInterface.abort(c::X) = live(c)"))                              # a driver method
    @test isempty(rule("cam.exposure_time = 0.02; stop[] = true"))                               # not definitions
end

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

# One line per group, `skill-group NAME pass=P fail=F error=E broken=B`, from the group's own testset: what
# `test/skills.jl` reads back (Julia's printed summary drops a column whose count is zero, so it is not parsed).
function skill_group_line(name, ts)
    c = Test.get_test_counts(ts)
    return "skill-group $(name) pass=$(c.passes + c.cumulative_passes) fail=$(c.fails + c.cumulative_fails) " *
           "error=$(c.errors + c.cumulative_errors) broken=$(c.broken + c.cumulative_broken)"
end

# Run as a script (by test/skills.jl, in its own process): every group, in name order, writing each group's counts to
# the file named by the first argument. The fakes runtests.jl installs for the TCube, N-472 and PI stage wrappers come
# first, so an example that reaches one of those wrappers reaches the recorder, and so do the DCAM4 wrappers
# (`dcam4_fake_sdk.jl`), which the `camera`, `acquire-snap` and `acquire-reader` checks drive on purpose; the other drivers' wrappers
# (DCx, CSC and the rest) are not replaced, and no example calls them. Each include is its own top-level statement,
# before anything runs, as those files require.
const RUN_AS_SCRIPT = abspath(PROGRAM_FILE) == abspath(@__FILE__)
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "tcube_fake_sdk.jl"))
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "pi_n472_fake_sdk.jl"))
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "pi_stage_fake_sdk.jl"))
RUN_AS_SCRIPT && include(joinpath(@__DIR__, "dcam4_fake_sdk.jl"))   # the DCAM4 methods of mc-acquire run against it
if RUN_AS_SCRIPT
    import GLMakie
    counts_file = get(ARGS, 1, "")
    @testset "Skill examples" begin
        groups = skill_example_blocks(joinpath(pkgdir(MicroscopeControl), "skills"))
        lines = String[]
        for name in sort(collect(keys(SKILL_EXAMPLE_GROUPS)))
            spec = SKILL_EXAMPLE_GROUPS[name]
            ts = @testset "$name" begin
                run_skill_example(name, skill_group_fences(groups, name); prelude = spec.prelude, checks = spec.checks)
            end
            push!(lines, skill_group_line(name, ts))
        end
        isempty(counts_file) || write(counts_file, join(lines, "\n") * "\n")
    end
end
