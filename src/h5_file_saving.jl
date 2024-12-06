using HDF5


# save attributes and data
function save_attributes_and_data(filename::String, group::String, attributes::Dict, data, children::Dict{String, Any})
    h5open(file, "w") do h5file
        h5group = create_group(h5file, group)

        # Saving data to the group
        write(h5group, data)

        # Saving attributes to the group
        for (name, value) in attributes
            attr_value = (eltype(value) == Bool) ? float.(value) : value
            attr(h5group, name, attr_value)
        end

        # Recursive scheme to save children
        for (child_name, child) in children
            child_group = joinpath(group, child_name)
            save_attributes_and_data(file, child_group, child["Attributes"], child["Data"], child["Children"])
        end
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

function save_h5(filename::String, state_data::Tuple{Dict, any, Dict})
    group = "/Main"
    attributes, data, children = state_data

    save_attributes_and_data(filename, group, attributes, data, children)
    println("Data and attributes successfully saved to $filename")
end


# Test the saving function of Red Laser
function test_save_to_hdf5(x, file::String)
    group = "/MainGroup"
    attributes, data, children = export_state(x)

    save_attributes_and_data(file, group, attributes, data, children)
    println("Data and attributes successfully saved to $file")
end



### TCube Laser Control ###
file_name = "Y:/Personal Folders/Ali.test_output.h5"
tcube_light = TCubeLaser("64849775")
MicroscopeControl.TCubeLaserControl.initialize(tcube_light)
MicroscopeControl.TCubeLaserControl.light_on(tcube_light)
MicroscopeControl.TCubeLaserControl.setpower(tcube_light, 70.0)

test_save_to_hdf5(tcube_light, file_name)

MicroscopeControl.TCubeLaserControl.light_off(tcube_light)
MicroscopeControl.TCubeLaserControl.shutdown(tcube_light)