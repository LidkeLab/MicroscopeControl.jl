"""
    SimStage3d(; label="Simulated 3D Stage", range_x=(0, 100), range_y=(0, 100), range_z=(0, 100), kwargs...)

A simulated three-axis stage, for tests, examples and system code run without hardware. Every field is a keyword
with the default shown in the struct; positions are plain numbers in whatever unit the caller uses.

- `initialize` and `shutdown` set `connectionstatus`.
- `move(stage, x, y, z)` takes `Float64`s and stores them as the target (`targ_x`, `targ_y`, `targ_z`); it does
  not check them against the range. The stage arrives at once: the next `getposition` copies the targets into
  `real_x`, `real_y`, `real_z`.
- `getrange(stage)` returns `(range_x, range_y, range_z)`.
- `servo` and `driftcorrection` record their flags in `servostatus` and `driftcorrectionstatus`; `stopmotion` does
  nothing.
- Every method prints a line describing what it did.
- `[limitation]` `getposition` returns only `real_z`, not the `(x, y, z)` tuple the `Stage` interface describes;
  read `real_x`, `real_y` and `real_z` after calling it.
- `[limitation]` `home` sets `real_x`, `real_y` and `real_z` to 0 but leaves the targets, so the next
  `getposition` reports the old target again.

See also [`SimStage2d`](@ref), [`SimStage1d`](@ref).
"""
Base.@kwdef mutable struct SimStage3d <: Stage
    label::String = "Simulated 3D Stage"
    id::Int = 0
    dimensions::Int = 3
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    real_z::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    targ_z::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    range_y::Tuple{Float64, Float64} = (0, 100)
    range_z::Tuple{Float64, Float64} = (0, 100)
    servostatus::Tuple{Bool, Bool, Bool} = (false, false, false)
    driftcorrectionstatus::Tuple{Bool, Bool, Bool} = (false, false, false)
end

"""
    SimStage2d(; label="Simulated 2D Stage", range_x=(0, 100), range_y=(0, 100), kwargs...)

A simulated two-axis stage. It behaves as [`SimStage3d`](@ref) without the z axis: `move(stage, x, y)` takes
`Float64`s, and `getrange` returns `(range_x, range_y)`.

`[limitation]` `getposition` returns only `real_y`; read `real_x` and `real_y` after calling it. `home` zeroes the
positions but not the targets, as on `SimStage3d`.
"""
Base.@kwdef mutable struct SimStage2d <: Stage
    label::String = "Simulated 2D Stage"
    id::Int = 0
    dimensions::Int = 2
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    real_y::Float64 = 0.0
    targ_x::Float64 = 0.0
    targ_y::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    range_y::Tuple{Float64, Float64} = (0, 100)
    servostatus::Tuple{Bool, Bool} = (false, false)
    driftcorrectionstatus::Tuple{Bool, Bool} = (false, false)
end

"""
    SimStage1d(; label="Simulated 1D Stage", range_x=(0, 100), kwargs...)

A simulated single-axis stage. It behaves as [`SimStage3d`](@ref) with one axis: `move(stage, x)` takes a
`Float64`, `getposition` returns `real_x` as a number (not a one-element tuple), and `getrange` returns
`range_x`. `servostatus` and
`driftcorrectionstatus` are single `Bool`s. `home` zeroes the position but not the target, as on `SimStage3d`.
"""
Base.@kwdef mutable struct SimStage1d <: Stage
    label::String = "Simulated 1D Stage"
    id::Int = 0
    dimensions::Int = 1
    connectionstatus::Bool = false
    real_x::Float64 = 0.0
    targ_x::Float64 = 0.0
    range_x::Tuple{Float64, Float64} = (0, 100)
    servostatus::Bool = false
    driftcorrectionstatus::Bool = false
end