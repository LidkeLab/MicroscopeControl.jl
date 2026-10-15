"""
    TriggerscopeBackend(scope; x_channel = 1, y_channel = 2, range = PLUSMINUS10, owns_device = true)

Drives a two-axis steerer from a pair of Triggerscope4 DAC outputs.

The Triggerscope DACs are 16-bit over the selected range, so the finest addressable step
is `span / 65535` — about 305 µV on ±10 V and about 76 µV on ±2.5 V. Pick the narrowest
range that still reaches the deflection you need and the steps get correspondingly finer;
[`min_voltage_step`](@ref) reports what the current range gives you.

# Arguments
- `scope::Triggerscope4`: The Triggerscope driving the device.

# Keywords
- `x_channel::Int`: DAC channel for the X axis. Default `1`.
- `y_channel::Int`: DAC channel for the Y axis. Default `2`.
- `range::Range`: DAC range applied to both channels on open. Default `PLUSMINUS10`.
- `owns_device::Bool`: When `true` (the default), opening this backend opens the
  Triggerscope's serial port and closing it closes the port. Set it to `false` when the
  same Triggerscope also drives other hardware and something else manages its lifetime —
  then the port must already be open before `initialize`.
- `boot_delay::Real`: Seconds to wait after opening the port before talking to the
  Triggerscope. The board resets when the port opens (Arduino DTR reset) and ignores
  commands until it has booted. Default `2.0`; ignored when `owns_device` is `false`.
"""
mutable struct TriggerscopeBackend <: SteeringBackend
    scope::Triggerscope4
    x_channel::Int
    y_channel::Int
    range::Range
    owns_device::Bool
    boot_delay::Float64
end

function TriggerscopeBackend(scope::Triggerscope4;
    x_channel::Int=1,
    y_channel::Int=2,
    range::Range=PLUSMINUS10,
    owns_device::Bool=true,
    boot_delay::Real=2.0)

    x_channel == y_channel &&
        throw(ArgumentError("x_channel and y_channel must differ, both are $x_channel"))
    for (name, ch) in (("x_channel", x_channel), ("y_channel", y_channel))
        1 <= ch <= scope.dacoutputs ||
            throw(ArgumentError("$name $ch is outside the Triggerscope's 1:$(scope.dacoutputs) DAC channels"))
    end

    return TriggerscopeBackend(scope, x_channel, y_channel, range, owns_device, Float64(boot_delay))
end

"""
    DAQmxBackend(x_channel, y_channel; vmin = -10.0, vmax = 10.0)

Drives a two-axis steerer from a pair of National Instruments analog outputs, through
NI-DAQmx.

One `AOTask` per axis is created and started by `initialize` and held open until
`shutdown`, so each move is a single `write_scalar` with no task setup cost. This is the
same arrangement the HVA200 scripts in `dev/MINFLUX Project/` use.

# Arguments
- `x_channel::String`: NI channel for the X axis, e.g. `"Dev2/ao0"`.
- `y_channel::String`: NI channel for the Y axis, e.g. `"Dev2/ao1"`.

# Keywords
- `vmin::Real`, `vmax::Real`: Output range requested of the NI card when the tasks are
  created. Defaults `-10.0` and `10.0`.
"""
mutable struct DAQmxBackend <: SteeringBackend
    x_channel::String
    y_channel::String
    vmin::Float64
    vmax::Float64
    x_task::Union{Nothing,DAQmx.AOTask}
    y_task::Union{Nothing,DAQmx.AOTask}
end

function DAQmxBackend(x_channel::String, y_channel::String; vmin::Real=-10.0, vmax::Real=10.0)
    vmin < vmax || throw(ArgumentError("vmin ($vmin) must be below vmax ($vmax)"))
    x_channel == y_channel &&
        throw(ArgumentError("x_channel and y_channel must differ, both are \"$x_channel\""))
    return DAQmxBackend(x_channel, y_channel, Float64(vmin), Float64(vmax), nothing, nothing)
end
