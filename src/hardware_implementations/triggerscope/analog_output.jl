"""
    dac_range_volts(range::Range) -> (v_min, v_max)

The output voltage span of a Triggerscope DAC range.
"""
function dac_range_volts(range::Range)
    range == ZEROTOFIVE && return (0.0, 5.0)
    range == ZEROTOTEN && return (0.0, 10.0)
    range == PLUSMINUS5 && return (-5.0, 5.0)
    range == PLUSMINUS10 && return (-10.0, 10.0)
    range == PLUSMINUS2_5 && return (-2.5, 2.5)
    throw(ArgumentError("unknown Triggerscope range $range"))
end

"""
    dac_output(scope::Triggerscope4, dac::Integer; range = nothing) -> (; writer, v_range, output_id)

One Triggerscope DAC as a generic analogue output for a device that takes "a function that
writes a voltage", e.g. a TCube laser's MOD IN:

    enable_modulation!(laser; dac_output(scope, 3; range = ZEROTOFIVE)...)

- `writer`: `v -> nothing`, one `setdac` (the command and its reply under the scope's lock,
  so it never interleaves with other users of the same scope, such as attenuators).
- `v_range`: the DAC's span for its range. With `range` given, that range is first set on
  the device; otherwise the range the driver last set is used (`scope.dacranges[dac]`; the
  constructor's default is ±10 V).
- `output_id`: `"Triggerscope <port> DAC <n>"`, to claim the output.

Which DAC is free, and which range suits the input it drives, is the rig's business, not this
driver's. Each write costs a serial round trip plus twice `scope.compause` (the pause after
every write and every read), so set `compause` to 0 for fast use (measured: < 1 ms per DAC
write at 0, about 219 ms at the default 0.1). A warning is logged when it is above 10 ms.
"""
function dac_output(scope::Triggerscope4, dac::Integer; range::Union{Nothing,Range} = nothing)
    1 <= dac <= scope.dacoutputs || throw(ArgumentError(
        "Triggerscope: DAC $dac does not exist (1..$(scope.dacoutputs))"))
    d = Int(dac)
    range === nothing || setrange(scope, d, range)
    scope.compause > 0.01 && @warn "Triggerscope $(scope.portname): compause = $(scope.compause) s makes every DAC write cost about $(2 * scope.compause) s; set scope.compause = 0 for fast use"
    writer = v -> (setdac(scope, d, Float64(v)); nothing)
    return (; writer, v_range = dac_range_volts(scope.dacranges[d]), output_id = "Triggerscope $(scope.portname) DAC $d")
end
