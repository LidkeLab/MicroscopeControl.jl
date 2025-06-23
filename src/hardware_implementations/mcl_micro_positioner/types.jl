"""
    `MclZPositioner` is a mutable struct inhereted from `ZpositionerInterface`. It is used to control the Z-positioner of a microscope using MCL hardware.
# Feilds
    -   

"""
mutable struct MclZPositioner <: Zpositioner
    label::String = "MCLZPositioner"
    units::String = "Microns"
    connectionstatus::Bool = false
    handle::Int = 0
    real_z::Float64 = 0.0
    targ_z::Float64 = 0.0
    velocity::Float64 = 5.0
    axis::Int = 1 # 1 = x, 2 = y, 3 = z
    rounding::Int = 0 # Nearest microstep = 0, Nearest full step = 1, Nearest half step = 2
end

HardwareReturn = Dict(
    0 => "MCL_SUCCESS"
    -1 => "MCL_GENERAL_ERROR"
    -2 => "MCL_DEV_ERROR"
    -3 => "MCL_DEV_NOT_ATTACHED"
    -4 => "MCL_USAGE_ERROR"
    -5 => "MCL_DEV_NOT_READY"
    -6 => "MCL_ARGUMENT_ERROR"
    -7 => "MCL_INVALID_AXIS"
    -8 => "MCL_INVALID_HANDLE"
)