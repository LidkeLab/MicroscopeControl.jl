# ParentModule.jl
module ParentModule

# Define a basic type we will export 
struct ParentType
    value::Int
end

# Define a private type we don't export 
struct ParentPrivateType
    value::Int
end


# Define a basic method
function base_operation(x::ParentType)
    return x.value * 2
end


# Export the type and method
export ParentType, base_operation


# Include and export a submodule
include("SubModule.jl")
export SubModule # This only exports the module, not the types or methods

end