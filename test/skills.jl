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
# The skills' executed examples run in their own Julia process (`test/skill_examples.jl`, which says how), so the
# types and methods they define never reach the rest of this suite. Included here for the group names and the fence
# extractor only; the checks below read files and run nothing from the skills.
# ---------------------------------------------------------------------------------------------------------------
include("skill_examples.jl")

@testset "Skill example extraction" begin
    groups = skill_example_blocks(joinpath(pkgdir(MicroscopeControl), "skills"))
    @testset "every marked group has a harness entry, and every entry but the fenceless ones a fence" begin
        @test sort(collect(keys(groups))) == sort(setdiff(collect(keys(SKILL_EXAMPLE_GROUPS)), SKILL_FENCELESS_GROUPS))
        @test all(g -> !haskey(groups, g), SKILL_FENCELESS_GROUPS)
    end
    @testset "markers are read only outside other fences, and a dangling one is an error" begin
        mktempdir() do dir
            write(joinpath(dir, "a.md"), """
                ```markdown
                <!-- mc-test: inside -->
                ```julia
                x = 1
                ```
                <!-- mc-test: outside -->
                ```julia
                y = 2  # -> 2
                ```
                """)
            g = skill_example_blocks(dir)
            @test collect(keys(g)) == ["outside"] && g["outside"] == ["y = 2  # -> 2"]
            write(joinpath(dir, "b.md"), "text\n<!-- mc-test: last -->")
            @test_throws r"on the last line" skill_example_blocks(dir)
            write(joinpath(dir, "b.md"), "<!-- mc-test: open -->\n```julia\nz = 3\n")
            @test_throws r"not closed" skill_example_blocks(dir)
        end
        @test stated_values("a = 1\n# -> 1\nb = 2   # -> Tuple{Int, Float64}   # a note") ==
              [(2, true, "1"), (3, false, "Tuple{Int, Float64}")]
    end
end

# Every [guarantee] and [limitation] in the skills names the version it was checked at, or `suite: GROUP` for a
# statement a group of `test/skill_examples.jl` asserts. The legend in mc-system-design's "How to read this skill" may
# write the placeholder `V` (and `suite: GROUP`); nowhere else may. A version token is read whole, prerelease
# included, and may not be later than this package's; one after "since" or "fixed in" may name the release this
# version leads to. None may say 0.2.0 except to describe history ("historical"). Every "suite: NAME" anywhere names
# a group, and no skill pins MicroscopeControl to a hard-coded tag (the install recipe takes the tag from the
# `Installed from` line). Returns the problems found and the number of labels read.
function skill_label_problems(text::AbstractString; groups, version::VersionNumber, legend::UnitRange{Int} = 1:0)
    release = VersionNumber(version.major, version.minor, version.patch)
    token = r"(since |fixed in )?v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z]+)*)?)"
    problems = String[]
    labels = 0
    for m in eachmatch(r"\[(?:guarantee|limitation)([^\]\n]*)\]", text)
        labels += 1
        body = m.captures[1]
        m.offset in legend && body == ", V" && continue
        if occursin("suite", body)
            s = match(r"^, suite: ([a-z0-9-]+)$", body)
            (s !== nothing && s.captures[1] in groups) ||
                push!(problems, "$(m.match): a suite label is exactly [guarantee|limitation, suite: GROUP], GROUP a harness group")
            continue
        end
        versions = [(t.captures[1], VersionNumber(t.captures[2])) for t in eachmatch(token, body)]
        isempty(versions) && push!(problems, "$(m.match): names no version")
        for (prefix, v) in versions
            v <= (prefix === nothing ? version : release) || push!(problems, "$(m.match): $v is later than $version")
        end
        occursin("0.2.0", body) && !occursin("historical", body) && push!(problems, "$(m.match): 0.2.0 outside history")
    end
    for s in eachmatch(r"suite: ([A-Za-z0-9_-]+)", text)
        s.offset in legend && s.captures[1] == "GROUP" && continue
        s.captures[1] in groups || push!(problems, "suite: $(s.captures[1]): no such group in the harness")
    end
    occursin(r"MicroscopeControl\.jl\.git\",\s*rev\s*=\s*\"v\d", text) &&
        push!(problems, "pins MicroscopeControl to a hard-coded tag")
    return problems, labels
end

@testset "Skill labels name a version or a suite group" begin
    groups = Set(keys(SKILL_EXAMPLE_GROUPS))
    pv = pkgversion(MicroscopeControl)
    @testset "the skills" begin
        root = joinpath(pkgdir(MicroscopeControl), "skills")
        files = sort([joinpath(dir, n) for (dir, _, names) in walkdir(root) for n in names if endswith(n, ".md")])
        @test length(files) >= 10
        labels = 0
        for file in files
            text = read(file, String)
            legend = 1:0
            if endswith(file, joinpath("mc-system-design", "SKILL.md"))
                a = findfirst("## How to read this skill", text)
                legend = first(a):first(findnext(r"\n## ", text, last(a)))
            end
            problems, n = skill_label_problems(text; groups, version = pv, legend)
            labels += n
            isempty(problems) || @error "label problems" file problems
            @test isempty(problems)
        end
        @test labels > 150
    end
    @testset "the checker refuses what it should" begin
        v = v"0.2.7-DEV"
        bad(text) = !isempty(first(skill_label_problems(text; groups, version = v)))
        @test !bad("[guarantee, 0.2.7-DEV] [limitation, fixed in 0.2.7 for DCAM4] [guarantee, since 0.2.6; checked 0.2.7-DEV]")
        @test !bad("[guarantee, suite: bench] and (suite: testing)")
        @test !bad("[limitation, historical: v0.2.0 to v0.2.3]")
        @test bad("[guarantee, V]")                                  # the placeholder, outside the legend
        @test isempty(first(skill_label_problems("x [guarantee, V] y"; groups, version = v, legend = 1:20)))  # in the legend
        @test bad("[guarantee, checked in the suite]")               # a bare "suite"
        @test bad("[guarantee, 0.2.7-DEV; suite]")
        @test bad("[guarantee, suite: no-such-group]")
        @test bad("prose (suite: no-such-group)")
        @test bad("[guarantee, 0.2.7]")                              # later than 0.2.7-DEV
        @test bad("[guarantee, 0.2.7-rc1]")                          # the prerelease is read: rc1 sorts after DEV
        @test bad("[guarantee, since 0.2.8]")
        @test bad("[guarantee, 0.2.0]")
        @test bad("[guarantee, traced]")
        @test bad("Pkg.add(url=\"https://github.com/LidkeLab/MicroscopeControl.jl.git\", rev=\"v0.2.6\")")
        @test !bad("[guarantee, 0.2.6]")
        @test isempty(first(skill_label_problems("[guarantee, 0.2.7-DEV]"; groups, version = v"0.2.7")))  # after the release
    end
end

@testset "Skill examples, in their own process" begin
    runner = joinpath(@__DIR__, "skill_examples.jl")
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(runner)`
    log = tempname()
    ok = open(log, "w") do io
        success(pipeline(cmd; stdout = io, stderr = io))
    end
    out = read(log, String)
    ok || println(out)
    i = findlast("Test Summary:", out)
    ok && i !== nothing && println(out[first(i):end])
    @test ok
end
