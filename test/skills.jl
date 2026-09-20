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
        @test available == ["mc-acquire", "mc-api-map", "mc-driver-issue", "mc-sim-testing", "mc-wire-device"]
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
            @test isfile(old_file)
            final = TOML.parsefile(manifest_path)
            @test "old.md" in final["mc-acquire"]["files"]
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
            mkpath(skills_dir)
            traversal = relpath(victim, skills_dir) # e.g. "../../<tmp>/outside.txt"
            open(joinpath(skills_dir, ".microscopecontrol-skills.toml"), "w") do io
                TOML.print(io, Dict("evil" => Dict("version" => "0.2.0", "installed" => "x",
                                                    "files" => [traversal], "hashes" => [h])))
            end

            @test_throws Exception MicroscopeControl.uninstall_skills(tmp; quiet=true)
            @test isfile(victim)
            @test read(victim, String) == "keep me"
        end
    end

    @testset "non-existent target directory" begin
        bad_target = joinpath(tempdir(), "mc-skills-does-not-exist-$(rand(UInt64))")
        @test_throws Exception MicroscopeControl.install_skills(bad_target)
    end
end
