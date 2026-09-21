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
#
# Compares path *components* (via `splitpath`, native to the current OS),
# not a hardcoded-separator string prefix: `root_real * "/"` failed a
# legitimate Windows child like `C:\repo\.claude\skills\mc-acquire`, and an
# earlier fix for that unconditionally treated `\` as a separator on every
# OS -- but `\` is a legal filename character on POSIX, so that made a
# sibling directory literally named `skills\evil` compare as a *child* of
# `skills`. `splitpath` is the right tool precisely because it is
# OS-aware: it splits on `\` (and `/`) on Windows and only on `/` on POSIX,
# matching how `root_real`/`target_real` (both freshly produced by
# `realpath`/`_resolve_path` on *this* process) are actually laid out --
# unlike a manifest string, a live resolved path is never "foreign-OS"
# relative to the process that just resolved it. Manifest-string separator
# normalization (a stored path written on a different OS) is a distinct
# concern, handled separately where manifest entries are read.
#
# RULING: if `root` itself sits under a symlinked ancestor (e.g. the user's
# own `.claude` is a symlink), `realpath(root)` follows it, and this compares
# against *that* resolved location -- which is correct, not a boundary
# violation: the resolved location IS the user's real skills directory, and
# operating inside it is exactly what should happen. We deliberately do not
# special-case or reject a symlinked ancestor of `dest_root`.
function _contained_in(root::AbstractString, path::AbstractString)
    root_real = realpath(root)
    target_real = _resolve_path(path)
    root_parts = splitpath(root_real)
    target_parts = splitpath(target_real)
    return length(target_parts) >= length(root_parts) && target_parts[1:length(root_parts)] == root_parts
end

# Validate a (skill name[, relative file]) pair against `dest_root` and
# return the literal filesystem path to operate on, or `nothing` if it must
# be refused: an unsafe name/path component, a symlinked skill directory or
# final destination (never followed, dangling or not, regardless of where it
# points), or a resolved location outside `dest_root`.
#
# RULING (TOCTOU): this validates at one point in time; nothing here stops a
# concurrent actor from replacing a parent directory with a symlink between
# this check and the write/remove that follows it. This package is a
# documentation installer that a repository's own owner runs against their
# own filesystem, not a service exposed to an adversary running alongside
# it, so full protection against a concurrent attacker is out of scope.
# `install_skills`/`uninstall_skills` do the cheap mitigation instead -- an
# `islink` re-check immediately before each write and each remove *of a
# tracked file* (`_safe_write`/`_safe_remove` below), which narrows but does
# not eliminate the window. This does not extend to the incidental
# now-empty-directory pruning in `uninstall_skills`, which still calls
# `rm` directly: those directories were only ever reachable by walking down
# from an already-validated, non-symlinked `dest_dir`. Full protection would
# need descriptor-based (openat/*at-style) operations, which are
# deliberately not attempted here.
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
    # `ispath` (stat, follows symlinks) is false for a *dangling* symlink, so
    # `_resolve_path` would otherwise treat one as "just a not-yet-existing
    # filename" under a legitimate parent and let it through; `islink` (lstat,
    # does not follow) catches the symlink itself regardless of whether its
    # target exists.
    islink(path) && return nothing
    _contained_in(dest_root, path) || return nothing
    return path
end

# Re-check `islink` immediately before the actual write/remove syscall (see
# the TOCTOU ruling above), then perform it. Returns `false` (performing
# nothing) if the target became a symlink since `_safe_dest_path` validated
# it; callers treat that exactly like any other refusal.
function _safe_write(path::AbstractString, bytes)
    islink(path) && return false
    write(path, bytes)
    return true
end

function _safe_remove(path::AbstractString)
    islink(path) && return false
    rm(path)
    return true
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
                    # The declaring type is whichever of `iface` or
                    # `AbstractInstrument` the method actually resolved to
                    # (params[2]), not always `iface` itself -- otherwise an
                    # AbstractInstrument-level fallback prints under the
                    # wrong type name.
                    declaring = params[2]
                    args = join(params[3:end], ", ")
                    println(io, "- `$(fname)($(nameof(declaring))$(isempty(args) ? "" : ", " * args))`")
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
                    declaring = params[2]
                    args = join(params[3:end], ", ")
                    println(io, "- `$(fname)($(nameof(declaring))$(isempty(args) ? "" : ", " * args))`")
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
    # Refuse before doing any file work at all, not just right before the
    # final write: writing skill files first and only then discovering the
    # manifest can't be persisted would leave those files on disk but
    # unrecorded, so a later run would see them as untracked local edits.
    # The equivalent check right before the final write (below) stays too,
    # in case the manifest becomes a symlink during this call.
    islink(manifest_path) &&
        error("install_skills: refused to write outside the skills directory or through a symlink: $(manifest_path)")
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
                # A refusal is not the same as "never installed": if this
                # file was previously tracked (e.g. it got swapped for a
                # symlink after a legitimate install), keep its ownership
                # record instead of losing it -- otherwise a later, entirely
                # unrelated reinstall would see it as untracked and (per the
                # obsolete-file reconciliation below) never touch it again.
                expected = get(prior_hashes, relfile, nothing)
                if expected !== nothing
                    push!(final_files, relfile)
                    push!(final_hashes, expected)
                end
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
            if !_safe_write(dest_path, _rendered_bytes(src_dir, relfile, version))
                push!(refused, dest_path)
                expected = get(prior_hashes, relfile, nothing)
                if expected !== nothing
                    push!(final_files, relfile)
                    push!(final_hashes, expected)
                end
                continue
            end
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
                if !_safe_remove(dest_path)
                    push!(refused, dest_path)
                    push!(final_files, relfile)
                    push!(final_hashes, expected)
                end
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

    if islink(manifest_path)
        # `open(path, "w")` follows an existing symlink and would otherwise
        # truncate/overwrite whatever outside file it points to.
        push!(refused, manifest_path)
    else
        open(manifest_path, "w") do io
            TOML.print(io, manifest)
        end
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
    # Refuse up front, symmetrically with install_skills: reading through a
    # symlinked manifest would mean acting on some unrelated file's content
    # as if it were this target's ownership records, and the final write
    # (below) must not follow it either way.
    islink(manifest_path) &&
        error("uninstall_skills: refused to touch entries outside the skills directory or through a symlink: $(manifest_path)")
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
            # Never touch anything under an unsafe or symlinked skill name --
            # but keep its ownership record exactly as read, untouched, so
            # that repairing the problem (e.g. removing the symlink) leaves
            # a later uninstall able to find these files again instead of
            # having permanently forgotten them.
            remaining_manifest[name] = entry
            continue
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
                if !_safe_remove(path)
                    push!(refused, path)
                    push!(kept_files, relfile)
                    push!(kept_hashes, expected_hash)
                end
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

        # Whether this skill's manifest entry survives is decided by
        # `kept_files` -- what we actually still need to track -- not by
        # whether `dest_dir` happens to still exist on disk. A refused
        # traversal entry (e.g. `../../outside.txt`) never created anything
        # *inside* `dest_dir`, so the directory can end up empty and get
        # pruned above even though `kept_files` still (correctly) holds
        # that entry; gating on `isdir(dest_dir)` would silently drop it
        # from `remaining_manifest` right after computing it.
        if isempty(kept_files)
            push!(removed, name)
        else
            remaining_manifest[name] = Dict(
                "version" => get(entry, "version", ""),
                "installed" => get(entry, "installed", ""),
                "files" => kept_files,
                "hashes" => kept_hashes,
            )
        end

        quiet || println("uninstalled $(name) -> $(dest_dir)")
    end

    if islink(manifest_path)
        # Same reasoning as install_skills: `open(path, "w")` would follow
        # an existing symlink and overwrite whatever outside file it points
        # to, so refuse outright rather than writing or deleting through it.
        push!(refused, manifest_path)
    elseif isempty(remaining_manifest)
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
