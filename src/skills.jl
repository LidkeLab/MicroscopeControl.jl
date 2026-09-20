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

# The generated API map's path, relative to its skill directory, always
# stored and compared in this forward-slash form (see the path-portability
# helpers below) regardless of which OS installed or reads the manifest.
const _API_MAP_RELPATH = "references/api-map.md"

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

# `Method.sig` is a `UnionAll` (not a plain `DataType`) for any method with
# a `where` type parameter -- e.g. a downstream `export_state(r::Rig{T})
# where T`. Indexing `.parameters` straight off such a signature errors;
# unwrap first so a legitimate parametric method elsewhere in a downstream
# session never takes down map generation for devices it has nothing to do
# with.
_sig_parameters(m::Method) = Base.unwrap_unionall(m.sig).parameters

# ---- Path containment -----------------------------------------------------
#
# A skill name or relative file path can come from data this package does
# not fully control: `uninstall_skills` reads both straight out of a
# manifest TOML file, which may have been hand-edited or arrived inside a
# cloned downstream repo. Each is validated as a plain, non-escaping path
# component, and the final location is required to still be inside
# `dest_root` as a real filesystem path -- symlinks resolved -- not merely
# as a string, before anything is written to or removed from disk.

# A single path component: non-empty, no separator, not "." or "..".
function _safe_component(name::AbstractString)
    isempty(name) && return false
    (name == "." || name == "..") && return false
    !occursin('/', name) && !occursin('\\', name)
end

# A relative file path made only of safe components (after normalizing `\`
# to `/`), and not itself absolute.
function _safe_relpath(relfile::AbstractString)
    isempty(relfile) && return false
    isabspath(relfile) && return false
    all(_safe_component, split(replace(relfile, '\\' => '/'), '/'))
end

# `path` resolved to an absolute, symlink-free form even if it (or part of
# it) does not exist yet: walk up to the nearest existing ancestor,
# `realpath` that, then re-append the not-yet-existing tail literally.
function _resolve_path(path::AbstractString)
    path = abspath(path)
    tail = String[]
    p = path
    while !ispath(p)
        parent = dirname(p)
        parent == p && break # reached the filesystem root without finding one
        pushfirst!(tail, basename(p))
        p = parent
    end
    base = realpath(p)
    return isempty(tail) ? base : joinpath(base, tail...)
end

# True if `path` -- once every symlink already on disk in its ancestry is
# resolved -- is `root` itself or somewhere inside it. `root` must exist.
function _contained_in(root::AbstractString, path::AbstractString)
    root_real = realpath(root)
    target_real = _resolve_path(path)
    return target_real == root_real || startswith(target_real, root_real * "/")
end

# Validate a (skill name[, relative file]) pair against `dest_root` and
# return the literal filesystem path to operate on, or `nothing` if it must
# be refused: an unsafe name/path component, a symlinked skill directory
# (never followed, regardless of where it points), or a resolved location
# outside `dest_root`.
function _safe_dest_path(dest_root::AbstractString, name::AbstractString, relfile::Union{Nothing,AbstractString}=nothing)
    _safe_component(name) || return nothing
    dest_dir = joinpath(dest_root, name)
    islink(dest_dir) && return nothing
    path = if relfile === nothing
        dest_dir
    else
        _safe_relpath(relfile) || return nothing
        joinpath(dest_dir, relfile)
    end
    _contained_in(dest_root, path) || return nothing
    return path
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

# Every real file under a skill's source directory, relative to it (always
# forward-slash separated, regardless of OS), skipping `.gitkeep`
# placeholders used to keep otherwise-empty directories in git.
function _source_relfiles(src_dir::AbstractString)
    relfiles = String[]
    for (root, _, files) in walkdir(src_dir)
        rel = replace(relpath(root, src_dir), '\\' => '/')
        for f in files
            f == ".gitkeep" && continue
            push!(relfiles, rel == "." ? f : rel * "/" * f)
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
                if any(m -> length(_sig_parameters(m)) >= 2 && _sig_parameters(m)[2] === T, methods(f))
                    push!(device_specific, fname)
                elseif hasmethod(f, Tuple{T})
                    m = which(f, Tuple{T})
                    params = _sig_parameters(m)
                    # Either the device's own interface (e.g. Stage) or, for
                    # a device lacking even that interface-level fallback,
                    # the shared AbstractInstrument-level stub -- both are
                    # "not this device's own code" and worth surfacing, so a
                    # missing lifecycle method (e.g. ThorCamCSCCamera's
                    # `initialize`) is visible instead of silently absent.
                    if length(params) >= 2 && (params[2] === iface || params[2] === MC.AbstractInstrument)
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
                        params = _sig_parameters(m)
                        (length(params) >= 2 && params[2] === T) || continue
                        args = join(params[3:end], ", ")
                        println(io, "- `$(fname)($(nameof(T))$(isempty(args) ? "" : ", " * args))`")
                    end
                end
            end

            if !isempty(shared)
                println(io)
                println(io, "**Inherited (shared implementation):**")
                println(io)
                for fname in sort(shared)
                    params = _sig_parameters(inherited_method[fname])
                    args = join(params[3:end], ", ")
                    println(io, "- `$(fname)($(nameof(iface))$(isempty(args) ? "" : ", " * args))`")
                end
            end

            if !isempty(stub)
                println(io)
                println(io, "**Interface fallback (not a device implementation):**")
                println(io)
                println(io, "These calls resolve to this package's own interface-level fallback, ",
                             "not to code written for this device. Most such fallbacks raise an ",
                             "error naming the type; a few return silently instead. Check the ",
                             "fallback's own source before relying on one.")
                println(io)
                for fname in sort(stub)
                    params = _sig_parameters(inherited_method[fname])
                    args = join(params[3:end], ", ")
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
    if relfile == _API_MAP_RELPATH
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
file. A file a skill used to ship but no longer does is removed if it is
still unmodified, or kept (and reported) if it was locally edited. A skill
name or relative path that would resolve outside `target`'s `.claude/skills`
directory -- including through a symlinked skill directory -- is always
refused, regardless of `force`. Returns the names of the skills that were
(at least partially) processed.
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
    refused = String[]

    for name in selected
        dest_dir = _safe_dest_path(dest_root, name)
        if dest_dir === nothing
            push!(refused, joinpath(dest_root, name))
            continue
        end

        mkpath(dest_dir)
        src_dir = joinpath(src_root, name)

        relfiles = _source_relfiles(src_dir)
        name == "mc-api-map" && push!(relfiles, _API_MAP_RELPATH)
        current = Set(relfiles)

        prior = get(manifest, name, nothing)
        prior_hashes = Dict{String,String}()
        if prior !== nothing
            for (f, h) in zip(get(prior, "files", String[]), get(prior, "hashes", String[]))
                prior_hashes[replace(string(f), '\\' => '/')] = string(h)
            end
        end

        final_files = String[]
        final_hashes = String[]

        for relfile in relfiles
            dest_path = _safe_dest_path(dest_root, name, relfile)
            if dest_path === nothing
                push!(refused, joinpath(dest_dir, relfile))
                continue
            end

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

        # Reconcile files this skill used to ship but no longer does: one
        # whose disk content still matches what we installed is safe to
        # remove outright; one that was locally modified keeps its
        # ownership record instead of vanishing from the manifest while
        # remaining on disk forever (uninstall_skills can still find it).
        for relfile in setdiff(keys(prior_hashes), current)
            expected = prior_hashes[relfile]
            dest_path = _safe_dest_path(dest_root, name, relfile)
            if dest_path === nothing
                push!(refused, joinpath(dest_dir, relfile))
                push!(final_files, relfile)
                push!(final_hashes, expected)
                continue
            end
            isfile(dest_path) || continue
            if _file_hash(dest_path) == expected
                rm(dest_path)
            else
                push!(modified, dest_path)
                push!(final_files, relfile)
                push!(final_hashes, expected)
            end
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

    if !isempty(refused)
        error("install_skills: refused to write outside the skills directory or through a symlink: " *
              join(refused, ", "))
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
place (and reported), and its skill is not counted as removed. A manifest
skill name or file path that would resolve outside `target`'s
`.claude/skills` directory -- including through a symlinked skill
directory -- is refused and reported rather than touched. Never touches
`.claude/skills` itself or skills not present in the manifest.
"""
function uninstall_skills(target::AbstractString=pwd(); quiet::Bool=false)
    dest_root = joinpath(target, ".claude", "skills")
    manifest_path = joinpath(dest_root, _SKILLS_MANIFEST_NAME)
    isfile(manifest_path) || return String[]

    manifest = TOML.parsefile(manifest_path)
    removed = String[]
    modified = String[]
    refused = String[]
    remaining_manifest = Dict{String,Any}()

    for (name, entry) in manifest
        dest_dir = _safe_dest_path(dest_root, name)
        if dest_dir === nothing
            push!(refused, name)
            continue # never touch anything under an unsafe or symlinked skill name
        end

        files = [replace(string(f), '\\' => '/') for f in get(entry, "files", String[])]
        hashes = string.(get(entry, "hashes", String[]))

        kept_files = String[]
        kept_hashes = String[]
        for (relfile, expected_hash) in zip(files, hashes)
            path = _safe_dest_path(dest_root, name, relfile)
            if path === nothing
                push!(refused, name * "/" * relfile)
                push!(kept_files, relfile)
                push!(kept_hashes, expected_hash)
                continue
            end
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

    if !isempty(refused)
        error("uninstall_skills: refused to touch entries outside the skills directory or through a symlink: " *
              join(refused, ", "))
    end

    return removed
end
