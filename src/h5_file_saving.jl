"""                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
    save_attributes_and_data(filename::String, group::String, attributes::Dict, data::Any, children::Dict{String,Any})

Saves hierarchical data to an HDF5 file.

# Arguments
- `filename::String`: Path to the HDF5 file
- `group::String`: Name of the HDF5 group
- `attributes::Dict`: Dictionary of attributes to save
- `data::Any`: Data to save in the group
- `children::Dict{String,Any}`: Dictionary of child groups

`data` is written as it is, without permuting. An image is `(y, x)` or a stack `(y, x, frame)` (lab decision 0040;
see `docs/src/conventions.md`), and any `data` of two or more dimensions gets the attributes
`dimension_order = "y,x"` or `"y,x,frame"` and
`dimension_order_convention = "column-major (Julia/MATLAB); C-order tools list it reversed"`, with the older
`dimension_labels` and `memory_layout`. C-order tools (h5py, h5dump) list the same dimensions reversed.

Files written from 2026-01-29 until this change carry `dimension_order = "HW"` or `"HWN"` for the same layout; a
reader should keep accepting both spellings.
"""
function save_attributes_and_data(filename::String, group::String, attributes::Dict, data, children)
    try
        h5open(filename, "w") do h5file
            save_group_recursive(h5file, group, attributes, data, children)
        end
    catch e # Catch any exceptions (errors) that occur during the saving process
        @error "Failed to save to HDF5 file" exception = e # Log the error message
        rethrow(e) # Rethrow the exception to the caller function.
    end
end

"""
    save_group_recursive(h5parent, group_name::String, attributes::Dict, data, children)

Recursively saves hierarchical data to an HDF5 file.

# Arguments
- `h5parent`: Parent HDF5 group
- `group_name::String`: Name of the HDF5 group
- `attributes::Dict`: Dictionary of attributes to save
- `data::Any`: Data to save in the group
- `children::Dict{String,Any}`: Dictionary of child groups
"""
function save_group_recursive(h5parent, group_name::String, attributes::Dict, data, children)
    h5group = create_group(h5parent, group_name)

    # Save data
    if !isnothing(data)
        write(h5group, "data", data)
        # Add dimension convention metadata for image data (lab image layout, decision 0040)
        if ndims(data) >= 2
            dset = h5group["data"]
            attrs(dset)["dimension_order"] = ndims(data) == 2 ? "y,x" : "y,x,frame"
            attrs(dset)["dimension_order_convention"] = "column-major (Julia/MATLAB); C-order tools list it reversed"
            attrs(dset)["dimension_labels"] = ndims(data) == 2 ? ["height", "width"] : ["height", "width", "frames"]
            attrs(dset)["memory_layout"] = "column_major_julia"
        end
    end

    # Save attributes
    for (name, value) in attributes
        attr_value = (eltype(value) == Bool) ? float.(value) : value
        attrs(h5group)[name] = attr_value
    end

    # Recursively save children
    for (child_name, child) in children
        child_attrs, child_data, child_children = child
        save_group_recursive(h5group, child_name, child_attrs, child_data, child_children)
    end
end

"""
    anchor_h5_path(filename::String) -> String

Resolve the parent directory through the filesystem once at call time, including drive-relative paths,
directory symlinks and `..`. Keep the leaf unchanged so HDF5 follows a symlink leaf itself.
If parent resolution fails, return `filename` exactly as given, so the save opens the path the caller passed (a
relative path then stays relative to the working directory, which still works when an ancestor of that directory is not
searchable); interrupts propagate.
"""
function anchor_h5_path(filename::String)
    cwd = pwd()
    requested = joinpath(cwd, filename)
    directory = dirname(requested)
    parent = try
        realpath(isempty(directory) ? cwd : directory)
    catch err
        err isa InterruptException && rethrow()
        return filename
    end
    return joinpath(parent, basename(filename))
end

"""
    save_h5(filename::String, state_data)

Save the state data to an HDF5 file.

# Arguments
- `filename::String`: Path to the HDF5 file
- `state_data`: Tuple of dictionaries containing the attributes, data, and children of the instrument.

Copies the entire state tree before returning the asynchronous `Task`; `wait` it before reading.
Writes in place with HDF5's `"w"` open, letting HDF5 follow symlinks. `anchor_h5_path` resolves the parent
through the filesystem once at call time; the task uses that same path for writing and cleanup.
Saves overwrite existing files in place and are not atomic.
Every task failure, including an interrupt, logs `@error "Failed to save to HDF5 file"` once and rethrows.
Before writing, records `ispath` on that path (following links). On failure, a newly created file
is removed, resolving its target with `realpath` only during cleanup if the path is a symlink, so the link stays.
An existing file is truncated to zero bytes in place, retaining its inode, owner, mode, ACLs and hard links.
Cleanup failures are logged separately without hiding the original error.
The snapshot does not synchronize concurrent device changes while `export_state` is being assembled.

An image in `data` is stored as it is, `(y, x)` or
`(y, x, frame)`, with `dimension_order` and `dimension_order_convention` attributes (see
`save_attributes_and_data`; lab decision 0040, `docs/src/conventions.md`). Files from 2026-01-29 until this change
carry `dimension_order = "HW"` or `"HWN"`; a reader should keep accepting both.
"""
function save_h5(filename::String, state_data)
    path = anchor_h5_path(filename)
    snapshot = deepcopy(state_data)
    @async begin
        existed = nothing
        try
            existed = ispath(path)
            attributes, data, children = snapshot
            h5open(path, "w") do h5file
                save_group_recursive(h5file, "Main", attributes, data, children)
            end
            println("Data and attributes successfully saved to $filename")
        catch err
            @error "Failed to save to HDF5 file" exception = err
            try
                if existed === true
                    open(path, "w") do io
                        truncate(io, 0)
                    end
                elseif existed === false && ispath(path)
                    rm(islink(path) ? realpath(path) : path)
                end
            catch cleanup_err
                @error "Failed to clean up HDF5 file after save failure" exception = cleanup_err
            end
            rethrow()
        end
    end
end
