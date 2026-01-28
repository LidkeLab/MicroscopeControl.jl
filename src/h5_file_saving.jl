"""                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
    save_attributes_and_data(filename::String, group::String, attributes::Dict, data::Any, children::Dict{String,Any})

Saves hierarchical data to an HDF5 file.

# Arguments
- `filename::String`: Path to the HDF5 file
- `group::String`: Name of the HDF5 group
- `attributes::Dict`: Dictionary of attributes to save
- `data::Any`: Data to save in the group
- `children::Dict{String,Any}`: Dictionary of child groups
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
    save_h5(filename::String, state_data)

Save the state data to an HDF5 file.

# Arguments
- `filename::String`: Path to the HDF5 file
- `state_data`: Tuple of dictionaries containing the attributes, data, and children of the instrument.
"""
function save_h5(filename::String, state_data)
    @async begin
        # Name the startigng group as "Main"
        group = "Main"
        # Extract the attributes, data and children from each instrument using the export_state function
        attributes, data, children = state_data
        # Save the attributes and data to the hdf5 file
        save_attributes_and_data(filename, group, attributes, data, children)
        # Declare that the data and attributes have been saved to the file
        println("Data and attributes successfully saved to $filename")
    end
end