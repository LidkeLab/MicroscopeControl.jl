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
        @error "Failed to save to HDF5 file" exception=e # Log the error message
        rethrow(e) # Rethrow the exception to the caller function.
    end
end

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


# Example method to emulate exportState in Julia
# function export_state()
#     attributes = Dict("Attribute1" => "Value1", "Attribute2" => 123)
#     data = Dict("Data1" => [1, 2, 3], "Data2" => "Some string data")
#     children = Dict(
#         "Child1" => Dict(
#             "Attributes" => Dict("ChildAttribute1" => 456),
#             "Data" => Dict("ChildData1" => [4, 5, 6]),
#             "Children" => Dict()
#         ),
#         "Child2" => Dict(
#             "Attributes" => Dict("ChildAttribute2" => true),
#             "Data" => Dict("ChildData2" => "Nested child data"),
#             "Children" => Dict()
#         )
#     )

#     return attributes, data, children
# end

# Test the saving function
# function test_save_to_hdf5()
#     file = "Y:/Personal Folders//Ali.test_output.h5"
#     group = "/MainGroup"
#     attributes, data, children = export_state()

#     save_attributes_and_data(file, group, attributes, data, children)
#     println("Data and attributes successfully saved to $file")
# end

# # Run the test function

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





# Example
# function export_state(instrument::SomeInstrument)
#     # Metadata about the instrument
#     attributes = Dict(
#         "model" => "XYZ-123",
#         "serial" => "ABC456",
#         "is_active" => true
#     )
    
#     # Actual measurement data
#     data = [1.0, 2.0, 3.0]  # or any other data type
    
#     # Nested components (e.g., DAQ, stage, etc.)
#     children = Dict(
#         "daq" => Dict(
#             "Attributes" => Dict("port" => "COM1"),
#             "Data" => [4.0, 5.0],
#             "Children" => Dict()
#         )
#     )
    
#     return attributes, data, children
# end

# function export_state(tcube_light::TCubeLaser)
#     attributes = Dict("some_key" => "some_value")
#     data = nothing
    
#     # Instead of passing nested tuples, store everything as `Any`
#     children = Dict{String,Any}()
#     children["some_child"] = Dict("Attributes" => Dict(...),
#                                   "Data"       => ...,
#                                   "Children"   => Dict{String,Any}())
    
#     return attributes, data, children
# end