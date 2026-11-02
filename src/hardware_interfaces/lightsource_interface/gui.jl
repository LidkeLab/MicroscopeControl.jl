# DAQ lights specialize this to use their requested voltage and voltage bounds,
# independent of a caller's edits to properties.power.
_power_settings(light::LightSource) = (lo=light.properties.min_power, hi=light.properties.max_power,
    requested=light.properties.power, unit=light.properties.power_unit)

"""
    gui(light::LightSource)

Open a panel in the light's own unit and range, without issuing a command,
and return its `GLMakie.Screen`. Text submissions issue one command even
when the slider position does not change; invalid entries are
refused at the box. Command failures are shown in the panel and the toggle
follows the driver's state. Closing the panel does not switch off the light.
"""
gui(light::LightSource) = _show_panel(_light_panel(light), light)

# Build without displaying so tests can reach the figure and its controls.
function _light_panel(light::LightSource)
    settings = _power_settings(light)
    lo, hi, unit = settings.lo, settings.hi, settings.unit
    fig = Figure(size=(760, 260))
    Label(fig[1, 1:3], "$(light.unique_id): requested level [$lo $unit - $hi $unit]";
        halign=:left, tellwidth=false)
    describe() = "requested: $(_power_settings(light).requested) $unit"
    # Include both endpoints, even when the range is not a multiple of 0.1.
    values = range(lo, hi; length=max(2, ceil(Int, (hi - lo) / 0.1) + 1))
    message = _attach_setpoint!(fig, light, values, settings.requested, x -> setpower(light, x), describe)
    _attach_output_toggle!(fig, 5, light, message)
    return fig
end
