#=
This file contains the type definitions for the MCLStage struct.

Type Names may not match the Madlibs.dll naming convention as they correspond to the fields the gui function will be looking for.
=#

"""
    MCLStage(; stagelabel="MCL-NanoXYZ", units="Microns", kwargs...)

A Mad City Labs Nano-Drive three-axis piezo stage, driven through the Madlib library (`libmadlib`, resolved at load
time; set `MICROSCOPECONTROL_LIBMADLIB` to override the path). Every field is a keyword with the default shown in
the struct; positions are in micrometers.

The constructor does not touch the hardware. `initialize` takes the first available Nano-Drive handle
(`MCL_InitHandle`) into `id`, sets `connectionstatus`, reads each axis's calibrated range into `range_x`,
`range_y`, `range_z`, and sets the targets to the current position; it returns the handle, and when none is found
it logs an error and returns 0 without throwing. `shutdown` releases the handle.

- `move(stage, x, y, z)` takes `Float64`s, writes each axis, records the targets, and returns
  `("MCL_SUCCESS", "MCL_SUCCESS", "MCL_SUCCESS")`; a write the library refuses throws, naming the Madlib error.
  `move_to_z(stage, z)` writes the z axis alone.
- `getposition(stage)` reads the three axes into `real_x`, `real_y`, `real_z` and returns `(x, y, z)`;
  `get_z_position(stage)` reads z alone. A failed read throws.
- `getrange(stage)` reads the calibration of each axis and returns `(range_x, range_y, range_z)`.
- `home(stage)` moves to `(0, 0, 0)`.
- `[limitation]` `stopmotion` is not implemented for this stage; it logs an error and does nothing.
"""
Base.@kwdef mutable struct MCLStage <: Stage
    stagelabel::String = "MCL-NanoXYZ"
    units::String = "Microns"
    id::Int = 0                                 #This is the device handle
    dimensions::Int = 3
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    real_z::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    targ_z::Float64 = 0.0
    range_x::Tuple{Float64,Float64} = (0, 300)
    range_y::Tuple{Float64,Float64} = (0, 300)
    range_z::Tuple{Float64,Float64} = (0, 300)
end

HardwareReturn = Dict{Int, String}(
    0 => "MCL_SUCCESS",
    -1 => "MCL_GENERAL_ERROR",
    -2 => "MCL_DEV_ERROR",
    -3 => "MCL_DEV_NOT_ATTACHED",
    -4 => "MCL_USAGE_ERROR",
    -5 => "MCL_DEV_NOT_READY",
    -6 => "MCL_ARGUMENT_ERROR",
    -7 => "MCL_INVALID_AXIS",
    -8 => "MCL_INVALID_HANDLE"
)
