# SubSubModule.jl
module SubSubModule

# using grandparent- this will give us all exported functions from ParentModule
using ...ParentModule

# get access to un-exported Type
using ...ParentModule: ParentPrivateType

# bring in a methods from SubModule to extend with our new type
import ..SubModule: enhanced_operation

# use the SubModule, which is a parent of this module
using ..SubModule

display(ParentModule)
# Define new type
struct DeepType
    sub::SubType
    factor::Float64
end

# Extend enhanced_operation to new type
function enhanced_operation(x::DeepType)
    base = enhanced_operation(x.sub)
    return base * x.factor
end

export DeepType

end