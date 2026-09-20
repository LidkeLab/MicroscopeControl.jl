using TOML

# All targets are `mktempdir()`s -- never written into the repo itself.

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

    @testset "non-existent target directory" begin
        bad_target = joinpath(tempdir(), "mc-skills-does-not-exist-$(rand(UInt64))")
        @test_throws Exception MicroscopeControl.install_skills(bad_target)
    end
end
