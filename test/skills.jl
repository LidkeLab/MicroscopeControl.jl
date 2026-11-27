using TOML
using SHA

# All targets are `mktempdir()`s -- never written into the repo itself.

# A downstream-style parametric method extending a MicroscopeControl generic,
# used by "map generation with a parametric downstream method" below. Must
# live at file top level (`include` evaluates it at module scope regardless
# of the `@testset` it is textually nested in; see test/contract.jl's own
# dummy fixtures for the same reason). `_ParametricRig` is not a subtype of
# any interface this package knows about, but its `export_state` method
# still shows up in `methods(MicroscopeControl.export_state)`, which is
# exactly what previously crashed generation for every device type.
struct _ParametricRig{T}
    value::T
end
MicroscopeControl.export_state(r::_ParametricRig{T}) where {T} = (Dict{String,Any}(), nothing, Dict())

@testset "Skill Installation" begin
    available = MicroscopeControl.list_skills()

    @testset "list_skills" begin
        @test !isempty(available)
        @test available == sort(available)
        @test available == ["mc-acquire", "mc-api-map", "mc-extend", "mc-system-design", "mc-testing"]
    end

    @testset "full install" begin
        mktempdir() do tmp
            result = MicroscopeControl.install_skills(tmp; quiet=true)
            @test sort(result) == available
            for name in available
                @test isfile(joinpath(tmp, ".claude", "skills", name, "SKILL.md"))
            end
            @test isfile(joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml"))
        end
    end

    @testset "SKILL.md frontmatter and version stamp" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)
            version = string(pkgversion(MicroscopeControl))
            for name in available
                text = read(joinpath(tmp, ".claude", "skills", name, "SKILL.md"), String)
                @test startswith(text, "---")
                m = match(r"^name:\s*(\S+)"m, text)
                @test m !== nothing
                @test m.captures[1] == name
                @test occursin("Installed from MicroscopeControl.jl v$(version)", text)
            end
        end
    end

    @testset "partial install and unknown name" begin
        mktempdir() do tmp
            result = MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            @test result == ["mc-acquire"]
            @test isfile(joinpath(tmp, ".claude", "skills", "mc-acquire", "SKILL.md"))
            @test !isdir(joinpath(tmp, ".claude", "skills", "mc-api-map"))
            @test_throws Exception MicroscopeControl.install_skills(tmp; skills=["not-a-real-skill"], quiet=true)
        end
    end

    @testset "generated API map" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)
            text = read(joinpath(tmp, ".claude", "skills", "mc-api-map", "references", "api-map.md"), String)
            @test !isempty(text)
            @test occursin("SimCamera", text)
            @test occursin("SimStage3d", text)

            # `laser_561_gui` is just `gui` imported under a driver-specific
            # alias (same Function object); it must not be listed as if it
            # were its own method on every device.
            @test !occursin("laser_561_gui(", text)

            # `setexposuretime!` is a throwing interface-contract stub for
            # SimCamera (it has no device-specific method), not a real
            # shared implementation like `gui` -- it must be placed under
            # the interface-fallback heading, not "shared implementation".
            m = match(r"### SimCamera\n(.*?)\n(?:###|## )"s, text)
            @test m !== nothing
            section = m.captures[1]
            fallback_idx = findfirst("**Interface fallback (not a device implementation):**", section)
            @test fallback_idx !== nothing
            before, after = section[1:first(fallback_idx)-1], section[first(fallback_idx):end]
            @test !occursin("setexposuretime!", before)
            @test occursin("setexposuretime!", after)
        end
    end

    @testset "map generation with a parametric downstream method" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; skills=["mc-api-map"], quiet=true)
            text = read(joinpath(tmp, ".claude", "skills", "mc-api-map", "references", "api-map.md"), String)
            # `_ParametricRig`'s `export_state(r::_ParametricRig{T}) where T`
            # method has a `UnionAll` signature; generation must not choke on
            # it and fall back to the failure placeholder.
            @test !occursin("Generation failed", text)
            @test occursin("SimCamera", text)
        end
    end

    @testset "idempotency" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)
            manifest_path = joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml")
            before = TOML.parsefile(manifest_path)
            MicroscopeControl.install_skills(tmp; quiet=true)
            after = TOML.parsefile(manifest_path)
            for name in available
                @test before[name]["hashes"] == after[name]["hashes"]
                # Verify against what is actually on disk, not just that the
                # manifest's own recorded numbers didn't change.
                for (relfile, h) in zip(after[name]["files"], after[name]["hashes"])
                    path = joinpath(tmp, ".claude", "skills", name, relfile)
                    @test isfile(path)
                    @test bytes2hex(SHA.sha2_256(read(path))) == h
                end
            end
        end
    end

    @testset "local-edit protection" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)
            skill_md = joinpath(tmp, ".claude", "skills", "mc-acquire", "SKILL.md")
            edited = read(skill_md, String) * "\nlocal edit\n"
            write(skill_md, edited)

            @test_throws Exception MicroscopeControl.install_skills(tmp; quiet=true)
            @test read(skill_md, String) == edited

            MicroscopeControl.install_skills(tmp; force=true, quiet=true)
            @test read(skill_md, String) != edited

            # The manifest's recorded hash must match the regenerated file
            # actually on disk, not merely differ from the old edit.
            manifest = TOML.parsefile(joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml"))
            idx = findfirst(==("SKILL.md"), manifest["mc-acquire"]["files"])
            @test idx !== nothing
            @test manifest["mc-acquire"]["hashes"][idx] == bytes2hex(SHA.sha2_256(read(skill_md)))
        end
    end

    @testset "uninstall_skills" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)

            other_file = joinpath(tmp, ".claude", "skills", "other-skill", "SKILL.md")
            mkpath(dirname(other_file))
            write(other_file, "unrelated skill, never installed by MicroscopeControl")

            removed = MicroscopeControl.uninstall_skills(tmp; quiet=true)
            @test sort(removed) == available
            for name in available
                @test !isdir(joinpath(tmp, ".claude", "skills", name))
            end
            @test !isfile(joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml"))
            @test isfile(other_file)
        end
    end

    @testset "uninstall keeps a locally edited tracked file" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; quiet=true)
            skill_md = joinpath(tmp, ".claude", "skills", "mc-acquire", "SKILL.md")
            edited = read(skill_md, String) * "\nlocal edit\n"
            write(skill_md, edited)

            removed = MicroscopeControl.uninstall_skills(tmp; quiet=true)
            @test !("mc-acquire" in removed)
            @test isfile(skill_md)
            @test read(skill_md, String) == edited

            for name in available
                name == "mc-acquire" && continue
                @test !isdir(joinpath(tmp, ".claude", "skills", name))
            end

            manifest_path = joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml")
            @test isfile(manifest_path)
            manifest = TOML.parsefile(manifest_path)
            @test haskey(manifest, "mc-acquire")
            @test "SKILL.md" in manifest["mc-acquire"]["files"]
        end
    end

    @testset "reinstall reconciles an obsolete file" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            skill_dir = joinpath(tmp, ".claude", "skills", "mc-acquire")
            old_file = joinpath(skill_dir, "old.md")
            manifest_path = joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml")

            # An unmodified file the skill no longer ships: reinstall should
            # delete it and drop its ownership record.
            write(old_file, "old content, no longer shipped by this skill")
            old_hash = bytes2hex(SHA.sha2_256(read(old_file)))
            manifest = TOML.parsefile(manifest_path)
            push!(manifest["mc-acquire"]["files"], "old.md")
            push!(manifest["mc-acquire"]["hashes"], old_hash)
            open(io -> TOML.print(io, manifest), manifest_path, "w")

            MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            @test !isfile(old_file)
            after = TOML.parsefile(manifest_path)
            @test !("old.md" in after["mc-acquire"]["files"])

            # A locally modified obsolete file: reinstall must not delete it,
            # and must keep its ownership record rather than forgetting it
            # while it stays on disk. This case reports (and thus throws,
            # like any other local edit) unless force=true.
            write(old_file, "old content, no longer shipped, and now edited too")
            push!(after["mc-acquire"]["files"], "old.md")
            push!(after["mc-acquire"]["hashes"], old_hash) # stale hash: no longer matches the file above
            open(io -> TOML.print(io, after), manifest_path, "w")

            @test_throws Exception MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            # The edited bytes on disk must be untouched (not reverted, not
            # deleted), and the manifest must keep the *original* ownership
            # hash (what the file would be if unmodified), not the edited
            # content's hash -- otherwise the edit would be silently
            # "adopted" as the new baseline instead of being reported.
            @test read(old_file, String) == "old content, no longer shipped, and now edited too"
            final = TOML.parsefile(manifest_path)
            idx = findfirst(==("old.md"), final["mc-acquire"]["files"])
            @test idx !== nothing
            @test final["mc-acquire"]["hashes"][idx] == old_hash
        end
    end

    @testset "manifest path portability (backslash entries)" begin
        mktempdir() do tmp
            MicroscopeControl.install_skills(tmp; skills=["mc-api-map"], quiet=true)
            manifest_path = joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml")
            manifest = TOML.parsefile(manifest_path)
            files = manifest["mc-api-map"]["files"]
            idx = findfirst(==("references/api-map.md"), files)
            @test idx !== nothing
            files[idx] = "references\\api-map.md" # simulate a manifest written on Windows
            open(io -> TOML.print(io, manifest), manifest_path, "w")

            # A backslash-separated entry must not be misread as a local
            # edit (or as an untracked file) just because of the separator.
            MicroscopeControl.install_skills(tmp; skills=["mc-api-map"], quiet=true)

            after = TOML.parsefile(manifest_path)
            @test "references/api-map.md" in after["mc-api-map"]["files"]
            @test !any(f -> occursin('\\', f), after["mc-api-map"]["files"])
            @test isfile(joinpath(tmp, ".claude", "skills", "mc-api-map", "references", "api-map.md"))
        end
    end

    @testset "path containment: symlink and traversal refusal" begin
        mktempdir() do tmp
            outside = mktempdir()
            write(joinpath(outside, "evil.txt"), "should never be written to")
            skills_dir = joinpath(tmp, ".claude", "skills")
            mkpath(skills_dir)
            symlink(outside, joinpath(skills_dir, "mc-acquire"))

            @test_throws Exception MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            @test readdir(outside) == ["evil.txt"] # install never wrote through the symlink
        end

        mktempdir() do tmp
            outside_dir = mktempdir()
            victim = joinpath(outside_dir, "outside.txt")
            write(victim, "keep me")
            h = bytes2hex(SHA.sha2_256(read(victim)))
            skills_dir = joinpath(tmp, ".claude", "skills")
            # uninstall resolves a manifest entry's "files" relative to
            # `skills_dir/<name>`, not `skills_dir` itself -- the traversal
            # string and the skill directory it's read from must match that
            # exactly, or the resolved path silently lands one level off
            # from `victim` and the test would pass even with no
            # containment check at all.
            skill_dir = joinpath(skills_dir, "evil")
            mkpath(skill_dir)
            traversal = relpath(victim, skill_dir) # e.g. "../../<outside_dir>/outside.txt"
            manifest_path = joinpath(skills_dir, ".microscopecontrol-skills.toml")
            open(manifest_path, "w") do io
                TOML.print(io, Dict("evil" => Dict("version" => "0.2.0", "installed" => "x",
                                                    "files" => [traversal], "hashes" => [h])))
            end

            @test_throws Exception MicroscopeControl.uninstall_skills(tmp; quiet=true)
            @test isfile(victim)
            @test read(victim, String) == "keep me"

            # Ownership must survive the refusal too: `skill_dir` ends up
            # empty on disk (the traversal entry never created anything
            # *inside* it) and gets pruned, which must not be mistaken for
            # "this skill was fully uninstalled" -- the manifest still
            # needs to remember the refused entry.
            after = TOML.parsefile(manifest_path)
            @test haskey(after, "evil")
            @test after["evil"]["files"] == [traversal]
            @test after["evil"]["hashes"] == [h]
        end

        mktempdir() do tmp
            # A *dangling* symlink at the final destination: `ispath` is
            # false for it (its target doesn't exist), which must not be
            # mistaken for "just a not-yet-existing filename" -- `write`
            # would otherwise follow it and create the file outside.
            outside_dir = mktempdir()
            dangling_target = joinpath(outside_dir, "new.md")
            skills_dir = joinpath(tmp, ".claude", "skills")
            skill_dir = joinpath(skills_dir, "mc-acquire")
            mkpath(skill_dir)
            symlink(dangling_target, joinpath(skill_dir, "SKILL.md"))

            @test_throws Exception MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            @test !ispath(dangling_target)
        end

        mktempdir() do tmp
            # The manifest file itself as a symlink to an outside file: the
            # final write must not be allowed to follow it and clobber that
            # file. An empty TOML document is valid (parses as no prior
            # entries) so this reaches the write path rather than failing
            # to parse first.
            outside_dir = mktempdir()
            outside_manifest = joinpath(outside_dir, "clobbered.toml")
            write(outside_manifest, "")
            skills_dir = joinpath(tmp, ".claude", "skills")
            mkpath(skills_dir)
            symlink(outside_manifest, joinpath(skills_dir, ".microscopecontrol-skills.toml"))

            @test_throws Exception MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            @test read(outside_manifest, String) == ""
        end

        mktempdir() do tmp
            # Refusal must not lose ownership records: install a skill
            # legitimately, then corrupt its destination into a symlink
            # (standing in for "something else clobbered it later"), and
            # confirm uninstall's refusal still preserves the original
            # manifest entry rather than silently dropping it.
            MicroscopeControl.install_skills(tmp; skills=["mc-acquire"], quiet=true)
            manifest_path = joinpath(tmp, ".claude", "skills", ".microscopecontrol-skills.toml")
            original = TOML.parsefile(manifest_path)["mc-acquire"]

            skill_dir = joinpath(tmp, ".claude", "skills", "mc-acquire")
            rm(skill_dir; recursive=true)
            symlink(mktempdir(), skill_dir)

            @test_throws Exception MicroscopeControl.uninstall_skills(tmp; quiet=true)
            after = TOML.parsefile(manifest_path)
            @test haskey(after, "mc-acquire")
            @test after["mc-acquire"]["files"] == original["files"]
            @test after["mc-acquire"]["hashes"] == original["hashes"]
        end
    end

    # No standalone "Windows containment" test: `_contained_in` now compares
    # path components via `splitpath`, which is OS-native (splits on `\` on
    # Windows, only on `/` on POSIX). A test built by hand-splitting a
    # `C:\...`-style string on Linux would either call a private component
    # helper directly -- reimplementing the function it claims to test,
    # proving nothing about `_contained_in` itself -- or call
    # `_contained_in` with a fabricated Windows path, which `realpath` can't
    # resolve on a Linux CI runner in the first place. `splitpath`'s
    # Windows-specific behavior genuinely cannot be exercised meaningfully
    # from this Linux suite; the manifest-string separator normalization
    # (a different concern -- a *stored* path, not a live resolved one) is
    # already covered above by "manifest path portability".

    @testset "non-existent target directory" begin
        bad_target = joinpath(tempdir(), "mc-skills-does-not-exist-$(rand(UInt64))")
        @test_throws Exception MicroscopeControl.install_skills(bad_target)
    end
end

# ---------------------------------------------------------------------------------------------------------------
# The skills' executed examples. A julia fence preceded by `<!-- mc-test: NAME -->` is run here, with every fence of
# the same NAME (in file order, files in path order) joined and evaluated in one fresh module, after a prelude the
# group needs and before its checks. The checks assert the values the skill states ("executed", result tables), so
# a change that makes one false fails the suite; a statement checked here is labeled `suite` in the skill.
# ---------------------------------------------------------------------------------------------------------------

# name => the code of every fence marked with it, in order
function skill_example_blocks(root::AbstractString)
    groups = Dict{String,Vector{String}}()
    files = String[]
    for (dir, _, names) in walkdir(root), n in names
        endswith(n, ".md") && push!(files, joinpath(dir, n))
    end
    for file in sort(files)
        lines = readlines(file)
        i = 1
        while i < length(lines)
            m = match(r"^\s*<!--\s*mc-test:\s*(\S+)\s*-->\s*$", lines[i])
            if m !== nothing
                fence = match(r"^(\s*)```julia\s*$", lines[i+1])
                fence === nothing && error("$file:$i: an mc-test marker must sit on the line before a ```julia fence")
                indent = length(fence.captures[1])
                j = i + 2
                code = String[]
                while !occursin(r"^\s*```\s*$", lines[j])
                    push!(code, lines[j][min(indent, length(lines[j]) - length(lstrip(lines[j])))+1:end])
                    j += 1
                end
                push!(get!(groups, String(m.captures[1]), String[]), join(code, "\n"))
                i = j
            end
            i += 1
        end
    end
    return groups
end

# Evaluates `prelude`, the group's fences and `checks`, in this order, in one fresh module. Every top-level result of
# the fences is recorded in the module's `block_values` (the testing fences return a testset).
function run_skill_example(name, fences; prelude = "", checks = "")
    modname = Symbol("SkillExample_", replace(name, '-' => '_'))
    m = Module(modname)
    Core.eval(Main, :($modname = $m))     # bound in Main so `subtypes` finds the types a fence defines, as in a script
    Core.eval(m, :(using MicroscopeControl, Test))
    Core.eval(m, :(import GLMakie))
    Core.eval(m, :(const MC = MicroscopeControl))
    Core.eval(m, :(block_values = Any[]))
    for code in (prelude, fences...)
        isempty(code) && continue
        for ex in Meta.parseall(code).args
            ex isa LineNumberNode && continue
            val = redirect_stdout(() -> Core.eval(m, ex), devnull)   # the Sim stages print a line per call
            Core.eval(m, :(push!(block_values, $(QuoteNode(val)))))
        end
    end
    isempty(checks) || for ex in Meta.parseall(checks).args
        ex isa LineNumberNode && continue
        Core.eval(m, ex)
    end
    return m
end

# group name => (prelude, checks). Prelude runs before the fences, checks after; both in the fences' module.
const SKILL_EXAMPLE_GROUPS = Dict{String,NamedTuple{(:prelude, :checks),Tuple{String,String}}}()

SKILL_EXAMPLE_GROUPS["bench"] = (prelude = "", checks = raw"""
mkcam() = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)
shutdown_message(e) = sprint(showerror, e)
@testset "bench: rollback" begin
    cam = ClaimedAtConstruction()
    sys = Bench(cam, SimStage3d(), BrokenLight(); claimed_at_construction = (cam,))
    e = try MC.initialize(sys); nothing catch e e end
    @test occursin("initialize not implemented for", shutdown_message(e)) && occursin("BrokenLight", shutdown_message(e))
    @test cam.open == false
    @test isempty(sys.owned)

    stage = SimStage3d(); laser = SimLight()
    sys = Bench(BrokenCam(), stage, laser)
    e = try MC.initialize(sys); nothing catch e e end
    @test shutdown_message(e) == "BrokenCam: no device"
    @test stage.connectionstatus == false
    @test laser.properties.is_on == false
    @test isempty(sys.owned)
end
@testset "bench: requested versus measured, acquisitions, guards" begin
    laser = DaqLikeLight()
    sys = Bench(mkcam(), SimStage3d(), laser); MC.initialize(sys)
    MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 3.5))
    @test MC.get_state(sys).laser_power == 3.5
    @test laser.level_requested == 3.5
    @test laser.line_voltage == 0.0
    @test isnan(measured_power(sys))
    @test MC.export_state(sys)[1]["laser_power_requested"] == 3.5
    e = try (MC.get_state(sys).laser_power = 4.5; nothing) catch e e end
    @test shutdown_message(e) == "setfield!: immutable struct of type BenchState cannot be changed"

    t = @elapsed first_stack = acquire!(sys, 5)
    @test size(first_stack) == (32, 64, 5)
    @test t >= 5 * 0.01
    @test sys.in_flight == false
    @test size(acquire!(sys, 3)) == (32, 64, 3)

    sys.in_flight = true
    for f in (() -> MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 3.5)),
              () -> acquire!(sys, 1), () -> MC.shutdown(sys))
        e = try f(); nothing catch e e end
        @test e !== nothing && occursin("in flight", shutdown_message(e))
    end
    sys.in_flight = false

    e = try acquire!(sys, -1) catch e e end
    @test e isa ArgumentError
    @test sys.cam.is_running == false
    @test sys.in_flight == false && sys.cam_unavailable == false
    @test size(acquire!(sys, 2)) == (32, 64, 2)

    bad = Bench(ArmThenThrowCam(), SimStage3d(), laser)
    e = try acquire!(bad, 3) catch e e end
    @test shutdown_message(e) == "SDK: arm failed after start"
    @test bad.cam_unavailable
    e = try acquire!(bad, 3) catch e e end
    @test startswith(shutdown_message(e), "camera unavailable")
    MC.shutdown(bad)
    e = try (MC.initialize(bad); acquire!(bad, 3)) catch e e end
    @test startswith(shutdown_message(e), "camera unavailable")
    rebuilt = Bench(mkcam(), sys.stage, laser); MC.initialize(rebuilt)
    @test size(acquire!(rebuilt, 3)) == (32, 64, 3)
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
    pushfirst!(sys.owned, BrokenLight())
    e = try MC.shutdown(sys) catch e e end
    @test startswith(shutdown_message(e), "shutdown left devices open: ") && endswith(shutdown_message(e), "BrokenLight")
    @test stage.connectionstatus == false
    @test length(sys.owned) == 1 && sys.owned[1] isa BrokenLight
    e = try MC.shutdown(sys) catch e e end
    @test startswith(shutdown_message(e), "shutdown left devices open: ")
end
@testset "bench: the camera task reads the exposure as it runs" begin
    cam = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01, sequence_length = 20)
    t0 = time()
    task = sequence(cam)
    @test task isa Task
    cam.exposure_time = 0.05
    wait(task)
    @test time() - t0 > 0.5
end
@testset "bench: a DiodeLaser in the laser field" begin
    laser = SimDiodeLaser()
    sys = Bench(mkcam(), SimStage3d(), laser); MC.initialize(sys)
    MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 0.5))
    @test laser.drive_current == laser.min_current + 0.5 * (laser.max_current - laser.min_current)
    @test isnan(measured_power(sys))
    pm = SimDiodeLaser(mode = ConstantPhotocurrent(), wa_calibration = 224.2, tia_range = 1e-3, tec_stabilised = missing,
        max_current = 150.0, properties = LightSourceProperties("mW", 0.0, false, 0.0, 70.0))
    sys = Bench(mkcam(), SimStage3d(), pm); MC.initialize(sys)
    MC.set_state(sys, BenchState(exposure_time = 0.02, z = 1.0, laser_power = 0.5))
    light_on(pm)
    @test isfinite(measured_power(sys)) && measured_power(sys) > 0
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
    @test all(t -> Test.get_test_counts(t).fails + Test.get_test_counts(t).errors == 0, sets)
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
    @test @elapsed(getdata(cam)) < 0.04                                                # getdata does not sleep
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
        @test err isa FieldError && err.field === :stagelabel                          # the unguarded stagelabel read
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
        @test (gui(T()); true)
        GLMakie.closeall()
    end
end
@testset "testing: SimDiodeLaser" begin
    SDL = MC.HardwareImplementations.SimulatedDiodeLaser
    sim = SimDiodeLaser()
    @test (sim.threshold_current, sim.max_current, sim.min_current, sim.efficiency) == (65.0, 160.0, 0.0, 1.2)
    @test sim.properties.power_unit == "mA"
    @test_throws ErrorException setcurrent!(sim, 100.0)                                 # before initialize
    @test_throws ErrorException measured_current(sim)
    initialize(sim)
    setcurrent!(sim, 100.0); light_on(sim)
    @test SDL.true_output_power(sim) ≈ 1.2 * (100.0 - 65.0)                              # P = efficiency * max(0, I - threshold)
    @test measured_photocurrent(sim) ≈ sim.responsivity * (1 + sim.responsivity_drift) * SDL.true_output_power(sim) / 1000
    empty!(sim.log); loop_status(sim)
    @test sim.log == [(:read, :loop_status)]                                            # reads are logged too
    GLMakie.closeall()
    empty!(sim.log); gui(sim); GLMakie.closeall()
    @test isempty(sim.log)                                                              # opening the panel issues nothing
    shutdown(sim)
    @test_throws ErrorException light_on(sim)                                           # after shutdown

    power = SimDiodeLaser(mode = ConstantPhotocurrent(), wa_calibration = 224.2, tia_range = 1e-3, tec_stabilised = missing,
        max_current = 150.0, properties = LightSourceProperties("mW", 0.0, false, 0.0, 70.0))
    initialize(power); setoutputpower!(power, 10.0); light_on(power)
    @test indicated_output_power(power) ≈ SDL.true_output_power(power)
    @test power.pd.photocurrent_requested != 10.0 / 224.2 / 1000                         # the TLD001's round-down encoding
    power.responsivity_drift = 0.2
    @test SDL.true_output_power(power) < 0.9 * indicated_output_power(power)             # the true power moves, the indication does not
    power.responsivity_drift = 0.0; power.pd_blocked = true
    @test measured_current(power) == power.pd.max_current_clamp && loop_status(power).saturated
    GLMakie.closeall()
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
cam = SimCamera(exposure_time = 0.01, roi = CameraROI(1, 1, 64, 32))
latest = Ref{Any}(nothing)
fps = 100
""", checks = raw"""
@test latest[] !== nothing && size(latest[]) == (32, 64)       # the reader read frames until stopped
@test cam.is_running == false
""")
SKILL_EXAMPLE_GROUPS["acquire-snap"] = (prelude = "", checks = raw"""
@test size(snap(SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01))) == (32, 64)
@test snap(SimCamera(roi = CameraROI(1, 1, 64, 32))) isa Matrix{UInt16}
@test which(snap, Tuple{SimCamera}).sig.parameters[2] === SimCamera
@test which(snap, Tuple{DCAM4Camera}).sig.parameters[2] === Camera              # the hardware drivers take the generic method
""")
SKILL_EXAMPLE_GROUPS["acquire-exposure"] = (prelude = "cam = SimCamera()", checks = raw"""
@test cam.exposure_time == 0.02
@test (cam.roi.x_start, cam.roi.y_start, cam.roi.width, cam.roi.height) == (1, 1, 512, 256)
@test fieldtype(ThorCamCSCCamera, :exposure_time) == Clonglong                  # an integer field (microseconds)
@test_throws InexactError convert(Clonglong, 0.02)
@test fieldtype(DCAM4Camera, :exposure_time) == Float64 && fieldtype(ThorcamDCXCamera, :exposure_time) == Float64
@test ThorcamDCXCamera().exposure_time == 0.01                                  # the constructor is pure
""")
SKILL_EXAMPLE_GROUPS["acquire-sequence"] = (prelude = "cam = SimCamera(roi = CameraROI(1, 1, 64, 32), exposure_time = 0.01)", checks = raw"""
@test size(stack) == (32, 64, 5) && eltype(stack) == UInt16
@test cam.is_running == false
""")
SKILL_EXAMPLE_GROUPS["acquire-zstack"] = (prelude = "", checks = raw"""
@test size(stack) == (32, 64, 5)
@test stage.real_z == 8.0
@test zs == 0.0:2.0:8.0
""")
SKILL_EXAMPLE_GROUPS["acquire-units"] = (prelude = "stage = SimStage3d()", checks = raw"""
@test PIStage().units == "Milimeters" && MCLStage().units == "Microns" && N472().units == "mm"
@test !hasfield(MCS2Stage, :units) && !hasfield(SimStage3d, :units)
@test_throws FieldError MCS2Stage().units
@test_throws FieldError SimStage3d().units
@test_throws MethodError move(SimStage3d(), 1, 2, 3)
""")
SKILL_EXAMPLE_GROUPS["apimap"] = (prelude = "", checks = raw"""
@test hasmethod(light_on, Tuple{TCubeLaser,Float64}) == false
@test which(setpower, Tuple{TCubeLaser{ConstantCurrent},Float64}).sig == Tuple{typeof(setpower), DiodeLaser, Float64}
@test hasmethod(setcurrent!, Tuple{TCubeLaser{ConstantPhotocurrent},Float64})
@test which(setcurrent!, Tuple{TCubeLaser{ConstantPhotocurrent},Float64}).sig.parameters[2] === DiodeLaser     # the stub, not a driver method
@test which(setcurrent!, Tuple{TCubeLaser{ConstantCurrent},Float64}).sig == Tuple{typeof(setcurrent!), TCubeLaser{ConstantCurrent}, Float64}
@test which(export_state, Tuple{TCubeLaser}).sig == Tuple{typeof(export_state), TCubeLaser}
@test hasmethod(export_state, Tuple{TCubeLaser,Any})                           # the deprecated forwarder is still there
@test which(getdata, Tuple{SimCamera}).sig == Tuple{typeof(getdata), SimCamera}
@test which(gui, Tuple{SimCamera}).sig == Tuple{typeof(gui), Camera}
@test has_specific(initialize, SimCamera)
@test !has_specific(initialize, ThorCamCSCCamera)
@test has_specific(setpower, SimLight, Float64)
@test !has_specific(setpower, TCubeLaser, Float64)
@test has_specific(light_on, TCubeLaser)
@test has_specific(setcurrent!, TCubeLaser{ConstantCurrent}, Float64)
@test !has_specific(setcurrent!, TCubeLaser, Float64)
""")
SKILL_EXAMPLE_GROUPS["extend-shim"] = (prelude = "", checks = raw"""
# the guard did not install the shim: dispatch lands on the driver's own method, not the abstract stub
@test which(MC.export_state, Tuple{MC.TCubeLaser}).sig.parameters[2] === MC.TCubeLaser
""")
SKILL_EXAMPLE_GROUPS["extend-shadow"] = (prelude = "", checks = raw"""
@test ShadowDriver.gui !== MicroscopeControl.gui
@test which(MicroscopeControl.gui, Tuple{ShadowDriver.ShadowLED}).sig.parameters[2] === LightSource
@test_throws r"^setpower not implemented for .*ShadowLED$" MicroscopeControl.setpower(ShadowDriver.ShadowLED(), 1.0)
@test hasmethod(MicroscopeControl.setpower, Tuple{ShadowDriver.ShadowLED,Float64})
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
@test (GLMakie.closeall(); gui(led); GLMakie.closeall(); true)                   # opening the panel no longer commands the light
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

# Statements in the skills about the generated API map, the SLM stubs and the shared panel that no example block runs.
@testset "Skill statements: the generated map and the stubs" begin
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
    end
    slm = MLSLM()
    @test displayimage(slm) === nothing                                    # the empty body
    err = try displayimage(slm, zeros(2, 2)); nothing catch e e end
    @test err isa ErrorException && occursin("setfield! fields of Types should not be changed", err.msg)
    @test !isdefined(MicroscopeControl, :move!) && isdefined(MicroscopeControl.HardwareImplementations.MCS2Stage_mod, :move!)
    @test hasmethod(initialize, Tuple{XEM}) && !hasmethod(export_state, Tuple{XEM}) && !hasmethod(gui, Tuple{XEM})
    @test !(MLSLM <: AbstractInstrument) && !(Triggerscope4 <: AbstractInstrument)
    @test !hasmethod(export_state, Tuple{Triggerscope4})
    # `save_h5` facts the caveats file states
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
    # The constructor builds a LibSerialPort object for the port name, and libserialport refuses a name that is not a
    # port on this machine: the default "COM3" is not one on Linux.
    Sys.islinux() && @test_throws ErrorException Triggerscope4()
end

# Every [guarantee] and [limitation] in the skills names the version it was checked at, or says the suite checks it
# (the statements of the second kind are asserted by the examples below and cannot go stale). A label may not name a
# version later than this package's, and none may say 0.2.0 except to describe history ("historical").
@testset "Skill labels name a version or the suite" begin
    root = joinpath(pkgdir(MicroscopeControl), "skills")
    files = [joinpath(dir, n) for (dir, _, names) in walkdir(root) for n in names if endswith(n, ".md")]
    @test length(files) >= 10
    labels = 0
    for file in files
        for m in eachmatch(r"\[(?:guarantee|limitation)([^\]\n]*)\]", read(file, String))
            labels += 1
            body = m.captures[1]
            versions = [VersionNumber(v) for v in (x.match for x in eachmatch(r"\d+\.\d+\.\d+(?:-DEV)?", body))]
            named = body == ", V" || occursin("suite", body) || !isempty(versions)
            named || @error "label names no version" file label = m.match
            @test named
            @test all(v -> v <= pkgversion(MicroscopeControl), versions)
            @test !occursin("0.2.0", body) || occursin("historical", body)
        end
    end
    @test labels > 150
end

@testset "Skill examples" begin
    groups = skill_example_blocks(joinpath(pkgdir(MicroscopeControl), "skills"))
    @testset "every marked group has a harness entry" begin
        @test sort(collect(keys(groups))) == sort(collect(keys(SKILL_EXAMPLE_GROUPS)))
    end
    for name in sort(collect(keys(SKILL_EXAMPLE_GROUPS)))
        haskey(groups, name) || continue
        spec = SKILL_EXAMPLE_GROUPS[name]
        @testset "$name" begin
            run_skill_example(name, groups[name]; prelude = spec.prelude, checks = spec.checks)
        end
    end
end
