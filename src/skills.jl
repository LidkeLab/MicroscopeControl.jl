"""
Installer for the Claude Code skills shipped in this package's `skills/`
directory. Downstream repos that *compose* MicroscopeControl.jl devices
(rather than write drivers against it) run `install_skills()` once from
their own root to get Claude Code sessions that understand this package's
API without seeing its source.

Public API: `install_skills`, `uninstall_skills`, `list_skills`.
"""

using SHA
using TOML
using Dates
using InteractiveUtils

const _SKILLS_MANIFEST_NAME = ".microscopecontrol-skills.toml"

# sha2-256 of a file's bytes, hex-encoded. Always re-reads from disk so the
# hash reflects exactly what is (or was) written, not an in-memory guess.
_file_hash(path::AbstractString) = bytes2hex(SHA.sha2_256(read(path)))

# True if a resolved method's source file is one of this package's own
# interface-contract fallbacks (an `interface_functions.jl` under
# `hardware_interfaces/<iface>/`, or the AbstractInstrument-level stubs in
# `instrument.jl`) rather than a real shared implementation such as a
# `gui.jl`. Normalizes path separators first so this also works for a
# `Method.file` recorded with Windows-style backslashes.
function _is_contract_stub_file(path::AbstractString)
    normalized = replace(path, '\\' => '/')
    file = last(rsplit(normalized, '/'; limit=2))
    return file == "interface_functions.jl" || file == "instrument.jl"
end

"""
    list_skills() -> Vector{String}

Names of the Claude Code skills bundled in this package's `skills/`
directory, sorted alphabetically.
"""
function list_skills()
    src_root = joinpath(pkgdir(@__MODULE__), "skills")
    isdir(src_root) || error("list_skills: skills source directory not found at $(src_root)")
    return sort([name for name in readdir(src_root) if isdir(joinpath(src_root, name))])
end

# Every real file under a skill's source directory, relative to it, skipping
# `.gitkeep` placeholders used to keep otherwise-empty directories in git.
function _source_relfiles(src_dir::AbstractString)
    relfiles = String[]
    for (root, _, files) in walkdir(src_dir)
        rel = relpath(root, src_dir)
        for f in files
            f == ".gitkeep" && continue
            push!(relfiles, rel == "." ? f : joinpath(rel, f))
        end
    end
    return sort(relfiles)
end

# Introspects the loaded module to build the markdown body of
# references/api-map.md for the mc-api-map skill. Kept separate from its
# caller so the caller can wrap it in a try/catch without losing the happy
# path's structure.
function _generate_api_map()
    MC = @__MODULE__
    version = string(pkgversion(MC))
    generated = string(Dates.today())

    # Several drivers import a generic under a device-specific alias (e.g.
    # `import ...LightSourceInterface: gui as laser_488_gui`) purely so it's
    # exported alongside the driver; the alias is the *same* Function object
    # as the original, not a new method. Group exported names by function
    # identity so each generic is only listed once, under its shortest name.
    alias_groups = Dict{UInt64,Vector{Symbol}}()
    for n in names(MC)
        isdefined(MC, n) || continue
        f = getfield(MC, n)
        f isa Function || continue
        push!(get!(alias_groups, objectid(f), Symbol[]), n)
    end

    canonical_of = Dict{UInt64,Symbol}()
    alias_notes = Tuple{Symbol,Vector{Symbol}}[]
    for (key, group_names) in alias_groups
        ordered = sort(group_names; by=n -> (length(String(n)), String(n)))
        canonical_of[key] = ordered[1]
        length(ordered) > 1 && push!(alias_notes, (ordered[1], sort(ordered[2:end])))
    end
    sort!(alias_notes; by=first)

    exported_functions = sort(collect(values(canonical_of)))

    io = IOBuffer()
    println(io, "# MicroscopeControl.jl API map")
    println(io)
    println(io, "Package version: $(version)")
    println(io, "Generated: $(generated)")
    println(io)
    println(io, "Every name below is callable unqualified after `using MicroscopeControl`. ",
                 "This file is regenerated on every `install_skills()` call; do not hand-edit it.")
    for (canonical, aliases) in alias_notes
        also = join(String.(aliases), ", ", " and ")
        println(io, "`$(canonical)` is also exported as $(also); they are the same function.")
    end

    interfaces = (MC.Stage, MC.Camera, MC.LightSource, MC.DAQ, MC.Attenuator, MC.SLM, MC.TRIG)

    for iface in interfaces
        println(io)
        println(io, "## $(nameof(iface))")

        devtypes = [T for T in InteractiveUtils.subtypes(iface)
                    if nameof(T) !== :StageFormat && !startswith(String(nameof(T)), "_")]

        for T in devtypes
            println(io)
            println(io, "### $(nameof(T))")

            device_specific = Symbol[]
            shared = Symbol[]
            stub = Symbol[]
            inherited_method = Dict{Symbol,Method}()
            for fname in exported_functions
                f = getfield(MC, fname)
                if any(m -> length(m.sig.parameters) >= 2 && m.sig.parameters[2] === T, methods(f))
                    push!(device_specific, fname)
                elseif hasmethod(f, Tuple{T})
                    m = which(f, Tuple{T})
                    if length(m.sig.parameters) >= 2 && m.sig.parameters[2] === iface
                        inherited_method[fname] = m
                        push!(_is_contract_stub_file(String(m.file)) ? stub : shared, fname)
                    end
                end
            end

            println(io)
            println(io, "**Device-specific:**")
            println(io)
            if isempty(device_specific)
                println(io, "- (none)")
            else
                for fname in sort(device_specific)
                    f = getfield(MC, fname)
                    for m in methods(f)
                        (length(m.sig.parameters) >= 2 && m.sig.parameters[2] === T) || continue
                        args = join(m.sig.parameters[3:end], ", ")
                        println(io, "- `$(fname)($(nameof(T))$(isempty(args) ? "" : ", " * args))`")
                    end
                end
            end

            if !isempty(shared)
                println(io)
                println(io, "**Inherited (shared implementation):**")
                println(io)
                for fname in sort(shared)
                    m = inherited_method[fname]
                    args = join(m.sig.parameters[3:end], ", ")
                    println(io, "- `$(fname)($(nameof(iface))$(isempty(args) ? "" : ", " * args))`")
                end
            end

            if !isempty(stub)
                println(io)
                println(io, "**Not implemented for this device (throws):**")
                println(io)
                println(io, "These are interface contract stubs, not device-specific code; ",
                             "calling one on this device typically raises an error naming the type.")
                println(io)
                for fname in sort(stub)
                    m = inherited_method[fname]
                    args = join(m.sig.parameters[3:end], ", ")
                    println(io, "- `$(fname)($(nameof(iface))$(isempty(args) ? "" : ", " * args))`")
                end
            end

            if isempty(shared) && isempty(stub)
                println(io)
                println(io, "**Inherited from the interface:**")
                println(io)
                println(io, "- (none)")
            end
        end
    end

    return String(take!(io))
end

function _api_map_content()
    try
        return _generate_api_map()
    catch e
        @warn "mc-api-map: API map generation failed; writing a placeholder instead" exception = (e, catch_backtrace())
        version = string(pkgversion(@__MODULE__))
        generated = string(Dates.today())
        msg = sprint(showerror, e)
        return """
        # MicroscopeControl.jl API map

        Package version: $(version)
        Generated: $(generated)

        ## Generation failed

        Introspecting the loaded module raised an error:

        ```
        $(msg)
        ```
        """
    end
end

_version_stamp(version::AbstractString) =
    "\n---\n\n*Installed from MicroscopeControl.jl v$(version) — regenerate with `using MicroscopeControl; install_skills()`.*"

# Bytes to write to `dest_dir/relfile` for a given skill, before any
# already-installed-file conflict check. `SKILL.md` gets the version stamp
# appended; the generated API map is built fresh; everything else is copied
# verbatim.
function _rendered_bytes(src_dir::AbstractString, relfile::AbstractString, version::AbstractString)
    if relfile == joinpath("references", "api-map.md")
        return Vector{UInt8}(_api_map_content())
    elseif basename(relfile) == "SKILL.md"
        text = read(joinpath(src_dir, relfile), String) * _version_stamp(version)
        return Vector{UInt8}(text)
    else
        return read(joinpath(src_dir, relfile))
    end
end

"""
    install_skills(target=pwd(); skills=:all, force=false, quiet=false) -> Vector{String}

Copy Claude Code skills from this package's `skills/` directory into
`target`'s `.claude/skills/`, stamping each `SKILL.md` with the installed
package version and recording a manifest of installed files and hashes.

`skills` is `:all` or a `Vector` of skill names/Symbols to install
selectively. On reinstall, a file whose on-disk hash no longer matches the
manifest (a local edit, or a file the manifest never tracked) is left alone
unless `force=true`; otherwise it is reported in an error listing every such
file. Returns the names of the skills that were (at least partially)
processed.
"""
function install_skills(target::AbstractString=pwd(); skills=:all, force::Bool=false, quiet::Bool=false)
    isdir(target) || error("install_skills: target directory does not exist: $(target)")

    available = list_skills()
    selected = if skills === :all
        available
    else
        requested = string.(skills)
        unknown = setdiff(requested, available)
        isempty(unknown) ||
            error("install_skills: unknown skill(s) $(join(unknown, ", ")); valid skills are $(join(available, ", "))")
        requested
    end

    src_root = joinpath(pkgdir(@__MODULE__), "skills")
    isdir(src_root) || error("install_skills: skills source directory not found at $(src_root)")

    dest_root = joinpath(target, ".claude", "skills")
    mkpath(dest_root)

    manifest_path = joinpath(dest_root, _SKILLS_MANIFEST_NAME)
    manifest = isfile(manifest_path) ? TOML.parsefile(manifest_path) : Dict{String,Any}()

    version = string(pkgversion(@__MODULE__))
    now_str = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

    modified = String[]

    for name in selected
        src_dir = joinpath(src_root, name)
        dest_dir = joinpath(dest_root, name)
        mkpath(dest_dir)

        relfiles = _source_relfiles(src_dir)
        name == "mc-api-map" && push!(relfiles, joinpath("references", "api-map.md"))

        prior = get(manifest, name, nothing)
        prior_hashes = Dict{String,String}()
        if prior !== nothing
            for (f, h) in zip(get(prior, "files", String[]), get(prior, "hashes", String[]))
                prior_hashes[string(f)] = string(h)
            end
        end

        final_files = String[]
        final_hashes = String[]

        for relfile in relfiles
            dest_path = joinpath(dest_dir, relfile)

            if isfile(dest_path) && !force
                current_hash = _file_hash(dest_path)
                expected = get(prior_hashes, relfile, nothing)
                if expected === nothing || expected != current_hash
                    push!(modified, dest_path)
                    if expected !== nothing
                        push!(final_files, relfile)
                        push!(final_hashes, expected)
                    end
                    continue
                end
            end

            mkpath(dirname(dest_path))
            write(dest_path, _rendered_bytes(src_dir, relfile, version))
            push!(final_files, relfile)
            push!(final_hashes, _file_hash(dest_path))
        end

        manifest[name] = Dict(
            "version" => version,
            "installed" => now_str,
            "files" => final_files,
            "hashes" => final_hashes,
        )

        quiet || println("installed $(name) -> $(dest_dir)")
    end

    open(manifest_path, "w") do io
        TOML.print(io, manifest)
    end

    if !isempty(modified) && !force
        error("install_skills: local edits detected, not overwritten: $(join(modified, ", ")). " *
              "Pass force=true to overwrite.")
    end

    return selected
end

"""
    uninstall_skills(target=pwd(); quiet=false) -> Vector{String}

Remove skills previously installed by `install_skills` into `target`,
using the manifest written there. Only files whose on-disk hash still
matches the manifest are removed; a locally modified file is left in
place (and reported), and its skill is not counted as removed. Never
touches `.claude/skills` itself or skills not present in the manifest.
"""
function uninstall_skills(target::AbstractString=pwd(); quiet::Bool=false)
    dest_root = joinpath(target, ".claude", "skills")
    manifest_path = joinpath(dest_root, _SKILLS_MANIFEST_NAME)
    isfile(manifest_path) || return String[]

    manifest = TOML.parsefile(manifest_path)
    removed = String[]
    modified = String[]
    remaining_manifest = Dict{String,Any}()

    for (name, entry) in manifest
        dest_dir = joinpath(dest_root, name)
        files = string.(get(entry, "files", String[]))
        hashes = string.(get(entry, "hashes", String[]))

        kept_files = String[]
        kept_hashes = String[]
        for (relfile, expected_hash) in zip(files, hashes)
            path = joinpath(dest_dir, relfile)
            isfile(path) || continue
            if _file_hash(path) == expected_hash
                rm(path)
            else
                push!(modified, path)
                push!(kept_files, relfile)
                push!(kept_hashes, expected_hash)
            end
        end

        # Remove now-empty directories bottom-up (references/ before the
        # skill dir itself), but never anything still holding a kept file.
        if isdir(dest_dir)
            for (root, _, _) in Iterators.reverse(collect(walkdir(dest_dir)))
                isdir(root) && isempty(readdir(root)) && rm(root)
            end
        end

        if isdir(dest_dir)
            remaining_manifest[name] = Dict(
                "version" => get(entry, "version", ""),
                "installed" => get(entry, "installed", ""),
                "files" => kept_files,
                "hashes" => kept_hashes,
            )
        else
            push!(removed, name)
        end

        quiet || println("uninstalled $(name) -> $(dest_dir)")
    end

    if isempty(remaining_manifest)
        rm(manifest_path)
    else
        open(manifest_path, "w") do io
            TOML.print(io, remaining_manifest)
        end
    end

    if !isempty(modified)
        @warn "uninstall_skills: kept locally modified file(s)" files = modified
    end

    return removed
end
