
include("ParentModule.jl") # Import the module

using .ParentModule # noticed the dot here to use the included module, not the installed one

# We can see exported functions and types
parent = ParentType(5)

# These are not exported
sub = SubModule.SubType(parent, "extra")
deep = SubModule.SubSubModule.DeepType(sub, 1.5)

# Use methods
println(base_operation(parent))           # 10
println(SubModule.enhanced_operation(sub)) # 15
println(SubModule.enhanced_operation(deep)) # 22.5