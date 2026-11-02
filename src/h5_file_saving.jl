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


# Use the filesystem rename directly: Julia 1.11's Filesystem.rename falls back to copying on an error.
# Both the mktemp stream and the HDF5 handle must be closed first, including on Windows.
function publish_h5(temporary::String, filename::String, overwrite::Bool)
    if overwrite
        ispath(filename) && @warn "Replacing existing HDF5 file" filename
        err = ccall(:jl_fs_rename, Int32, (Cstring, Cstring), temporary, filename)
        err < 0 && Base.uv_error("rename HDF5 file to $(repr(filename))", err)
    else
        # An exclusive directory entry also protects against a file created while the task was writing.
        hardlink(temporary, filename)
        rm(temporary)
    end
    return nothing
end

"""
    save_h5(filename::String, state_data; overwrite::Bool = true)

Save the state data to an HDF5 file.

# Arguments
- `filename::String`: Path to the HDF5 file
- `state_data`: Tuple of dictionaries containing the attributes, data, and children of the instrument.

Copies the entire state tree before scheduling the write and returns the `Task`; `wait` it before reading.
Writes and closes a temporary HDF5 file in the destination directory, then publishes it by rename.
A failed write or rename removes the temporary file and preserves an earlier destination.
`overwrite = false` refuses an existing destination before writing; replacing one emits a warning.
[limitation] The default remains overwrite for compatibility in 0.2.x; refusing by default waits for 0.3.
The snapshot does not synchronize concurrent device changes while `export_state` is being assembled.

An image in `data` is stored as it is, `(y, x)` or
`(y, x, frame)`, with `dimension_order` and `dimension_order_convention` attributes (see
`save_attributes_and_data`; lab decision 0040, `docs/src/conventions.md`). Files from 2026-01-29 until this change
carry `dimension_order = "HW"` or `"HWN"`; a reader should keep accepting both.
"""
function save_h5(filename::String, state_data; overwrite::Bool = true)
    !overwrite && ispath(filename) && throw(ArgumentError("HDF5 file already exists: $filename"))
    snapshot = deepcopy(state_data)
    @async begin
        temporary, stream = mktemp(dirname(abspath(filename)))
        try
            close(stream)
            attributes, data, children = snapshot
            save_attributes_and_data(temporary, "Main", attributes, data, children)
            publish_h5(temporary, filename, overwrite)
            println("Data and attributes successfully saved to $filename")
        finally
            isopen(stream) && close(stream)
            ispath(temporary) && rm(temporary)
        end
    end
end
