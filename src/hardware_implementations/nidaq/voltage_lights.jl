# One short-lived task per command. Cleanup is part of the write: a failed
# deletion must not let a caller record the command as successful.
function _write_voltage(daq::DAQ, kind::String, channel::String, voltage::Float64)
    task = createtask(daq, kind, channel)
    try
        setvoltage(daq, task, voltage)
    finally
        deletetask(daq, task)
    end
    return nothing
end

# Keep the legacy discovery order, including a partially discovered AO list.
# A supplied channel bypasses discovery for that kind of output.
function _light_channels(daq::DAQ, name, device_index; ao=nothing, do_line=nothing)
    channelsAO = ao === nothing ? String[] : [ao]
    channelsDO = do_line === nothing ? String[] : [do_line]
    if ao === nothing || do_line === nothing
        try
            devices = showdevices(daq)
            if 1 <= device_index <= length(devices) && !isempty(devices[device_index])
                device = devices[device_index]
                ao === nothing && (channelsAO = showchannels(daq, "AO", device))
                do_line === nothing && (channelsDO = showchannels(daq, "DO", device))
            else
                @warn "$name: NI-DAQ device index $device_index not available"
            end
        catch e
            @warn "$name: NI-DAQ discovery failed" exception=e
        end
    end
    return channelsAO, channelsDO
end

_discovered_channel(channels, index) = length(channels) >= index ? channels[index] : ""

function _light_channel(light, field::Symbol)
    channel = getproperty(light, field)
    isempty(strip(channel)) && error("$(nameof(typeof(light))) $(light.unique_id): missing $field")
    return channel
end

function _check_voltage(light, voltage)
    !(light.min_voltage <= voltage <= light.max_voltage) && throw(ArgumentError(
        "$(light.unique_id): voltage must be between $(light.min_voltage) and $(light.max_voltage) V, got $voltage"))
    return nothing
end

function _record_level!(light, voltage)
    light.level_requested = voltage
    # A caller can use its properties object for a percentage or a calibrated
    # optical display. Only a voltage display can receive this voltage value.
    light.properties.power_unit == "V" && (light.properties.power = voltage)
    return nothing
end

# Called only after an uncertain enable/level write. The original exception
# remains the command's error, even when this attempt to darken fails too.
function _darken_after_failure!(light, kind, channel)
    try
        isempty(strip(channel)) && error("$(light.unique_id): missing darkening channel")
        _write_voltage(light.daq, kind, channel, 0.0)
        light.properties.is_on = false
    catch
        light.properties.is_on = true # off cannot be claimed
    end
    return nothing
end

function _single_line_setpower!(light, voltage::Float64)
    lock(light.lock) do
        channel = _light_channel(light, :channel)
        _check_voltage(light, voltage)
        if light.properties.is_on
            try
                _write_voltage(light.daq, "AO", channel, voltage)
            catch
                _darken_after_failure!(light, "AO", channel)
                rethrow()
            end
        end
        _record_level!(light, voltage)
        light.properties.is_on || (light.level_staged = true)
    end
    return nothing
end

function _single_line_on!(light)
    lock(light.lock) do
        channel = _light_channel(light, :channel)
        voltage = light.level_staged ? light.level_requested : clamp(1.0, light.min_voltage, light.max_voltage)
        try
            _write_voltage(light.daq, "AO", channel, voltage)
        catch
            _darken_after_failure!(light, "AO", channel)
            rethrow()
        end
        _record_level!(light, voltage)
        light.properties.is_on = true
        light.level_staged = false
    end
    return nothing
end

function _single_line_off!(light)
    lock(light.lock) do
        channel = _light_channel(light, :channel)
        _write_voltage(light.daq, "AO", channel, 0.0)
        light.properties.is_on = false
    end
    return nothing
end

_voltage_panel_settings(light) = (lo=light.min_voltage, hi=light.max_voltage,
    requested=light.level_requested, unit="V")

function _voltage_light_state(light; separate_enable=false)
    attributes, daq = lock(light.lock) do
        attributes = Dict{String,Any}(
            "unique_id" => light.unique_id,
            "power_unit" => "V",
            "power" => light.level_requested,
            "power_requested" => light.level_requested,
            "is_on" => light.properties.is_on,
            "min_power" => light.min_voltage,
            "max_power" => light.max_voltage,
            "min_voltage" => light.min_voltage,
            "max_voltage" => light.max_voltage,
        )
        hasproperty(light, :laser_color) && (attributes["laser_color"] = light.laser_color)
        if separate_enable
            attributes["channelsAO"] = copy(light.channelsAO)
            attributes["channelsDO"] = copy(light.channelsDO)
            attributes["ao_channel"] = light.ao_channel
            attributes["do_channel"] = light.do_channel
        else
            attributes["channels_AO"] = copy(light.channelsAO)
            attributes["channels_DO"] = copy(light.channelsDO)
            attributes["channel"] = light.channel
        end
        return attributes, light.daq
    end
    return attributes, nothing, Dict{String,Any}("daq" => export_state(daq))
end
