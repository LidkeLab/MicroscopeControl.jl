function initialize(light::VortranLaser)
    lock(light.lock) do
        try
            channel = NIDAQcard._light_channel(light, :do_channel)
            NIDAQcard._write_voltage(light.daq, "DO", channel, 0.0)
        catch
            light.properties.is_on = true
            rethrow()
        end
        light.properties.is_on = false
    end
    return nothing
end

function LightSourceInterface.setpower(light::VortranLaser, voltage::Float64)
    lock(light.lock) do
        channel = NIDAQcard._light_channel(light, :ao_channel)
        NIDAQcard._check_voltage(light, voltage)
        try
            NIDAQcard._write_voltage(light.daq, "AO", channel, voltage)
        catch
            if light.properties.is_on
                NIDAQcard._darken_after_failure!(light, "DO", light.do_channel)
            end
            rethrow()
        end
        NIDAQcard._record_level!(light, voltage)
    end
    return nothing
end

function LightSourceInterface.light_on(light::VortranLaser)
    lock(light.lock) do
        channel = NIDAQcard._light_channel(light, :do_channel)
        try
            NIDAQcard._write_voltage(light.daq, "DO", channel, 1.0)
        catch
            NIDAQcard._darken_after_failure!(light, "DO", channel)
            rethrow()
        end
        light.properties.is_on = true
    end
    return nothing
end

function LightSourceInterface.light_off(light::VortranLaser)
    lock(light.lock) do
        try
            channel = NIDAQcard._light_channel(light, :do_channel)
            NIDAQcard._write_voltage(light.daq, "DO", channel, 0.0)
        catch
            light.properties.is_on = true
            # DO is enabled or unknown. AO 0 lowers output but does not
            # extinguish it; preserve the DO error and possible-emission report.
            try
                channel = NIDAQcard._light_channel(light, :ao_channel)
                NIDAQcard._write_voltage(light.daq, "AO", channel, 0.0)
                NIDAQcard._record_level!(light, 0.0)
            catch
                # The original switch-off failure must still reach the caller.
            end
            rethrow()
        end
        light.properties.is_on = false
    end
    return nothing
end

function shutdown(light::VortranLaser)
    lock(light.lock) do
        failures = Pair{String,Any}[]
        try
            channel = NIDAQcard._light_channel(light, :do_channel)
            NIDAQcard._write_voltage(light.daq, "DO", channel, 0.0)
            light.properties.is_on = false
        catch e
            push!(failures, "DO" => e)
        end
        try
            channel = NIDAQcard._light_channel(light, :ao_channel)
            NIDAQcard._write_voltage(light.daq, "AO", channel, 0.0)
            NIDAQcard._record_level!(light, 0.0)
        catch e
            push!(failures, "AO" => e)
        end
        if !isempty(failures)
            light.properties.is_on = true
            error("$(light.unique_id) shutdown failed: " *
                join(("$line: $(sprint(showerror, cause))" for (line, cause) in failures), "; "))
        end
    end
    return nothing
end

LightSourceInterface._power_settings(light::VortranLaser) = NIDAQcard._voltage_panel_settings(light)
export_state(light::VortranLaser) = NIDAQcard._voltage_light_state(light; separate_enable=true)
