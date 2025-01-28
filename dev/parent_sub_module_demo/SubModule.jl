# SubModule.jl
module SubModule

# Use parent module
using ..ParentModule

# Import from parent - note use of import for functions we'll extend
import ..ParentModule: base_operation

# Define a new type
struct SubType
    parent::ParentType
    extra::String
end

# Define methods using parent type
function enhanced_operation(x::ParentType)
    return base_operation(x) + 10
end

# Method that works with new type
function base_operation(x::SubType)
    return base_operation(x.parent) + length(x.extra)
end

# Export
export SubType, enhanced_operation

# Include a sub-submodule
include("SubSubModule.jl")
export SubSubModule # This only exports the module, not the types or methods

end