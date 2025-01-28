function LightSourceInterface.initialize(light::TCubeLaser)
    err = TLI_BuildDeviceList()
    numdev = TLI_GetDeviceListSize()

    serialNo = light.serialNo
    err = LD_Open(serialNo)
    err = LD_SetOpenLoopMode(serialNo)
    err = LD_RequestReadings(serialNo)
    sleep(0.1)
    out = LD_GetLaserDiodeMaxCurrentLimit(serialNo)
    light.max_current = Float64(out) / light.max_setpoint * light.max_setcurrent

    println("Laser initialized")
    @info "Max current: $(light.max_current) mA"
end

function LightSourceInterface.light_on(light::TCubeLaser)
    light.properties.is_on = true
    err = LD_EnableOutput(light.serialNo)
    println("$(light.laser_color)" * "_laser is on")
end

function LightSourceInterface.setpower(light::TCubeLaser, current::Float64)
    serialNo = light.serialNo
    if current < light.min_current || current > light.max_current
        @error "The current should be between $(light.min_current) and $(light.max_current)"
    end
    light.properties.power = current * light.properties.max_power / light.max_current
    current_setpoint::UInt16 = UInt16(round(current / light.max_setcurrent * light.max_setpoint))
    err = LD_SetLaserSetPoint(serialNo, current_setpoint)
    println("Laser current set to $current mA")
end

function LightSourceInterface.light_off(light::TCubeLaser)
    light.properties.is_on = false
    err = LD_DisableOutput(light.serialNo)
    println("$(light.laser_color)" * "_laser is off")
end

function LightSourceInterface.shutdown(light::TCubeLaser)
    light.properties.is_on = false
    serialNo = light.serialNo
    err = LD_DisableOutput(serialNo)
    err = LD_Close(serialNo)
    println("$(light.laser_color)" * "_laser is shutdown")
end

function tcube_get_current(light::TCubeLaser)
    serialNo = light.serialNo
    err = LD_RequestReadings(serialNo)
    sleep(0.1)
    out = LD_GetLaserDiodeCurrentReading(serialNo)
    current = Float64(out) / light.max_setpoint * light.max_setcurrent
    return current
end

function tcube_refresh(light::TCubeLaser)
    serialNo::String = light.serialNo
    LD_Open(serialNo)
    LD_SetOpenLoopMode(serialNo)
    LD_EnableOutput(serialNo)
    current::Float64 = 90 # [mA]
    current_setpoint::UInt16 = UInt16(round(current / light.max_setcurrent * light.max_setpoint))
    LD_SetLaserSetPoint(serialNo, current_setpoint)
    sleep(1)
    LD_DisableOutput(serialNo)
    LD_Close(serialNo)
    println("Laser refreshed")
end


function setupIO(light::TCubeLaser)
    devs = NIDAQcard.showdevices(light.daq)
    channelsAO = NIDAQcard.showchannels(light.daq, "AO", devs[2])
    task_mod = NIDAQcard.createtask(light.daq, "AO", channelsAO[2])
    light.task_mod = task_mod
    return nothing
end

function set_modvoltage(light::TCubeLaser, voltage::Float64)
    NIDAQcard.setvoltage(light.daq, light.task_mod, voltage)
    return nothing
end

function tcube_get_power(light::TCubeLaser)
    serialNo = light.serialNo
    err = LD_RequestReadings(serialNo)
    sleep(0.1)
    serialNo = "64849775"
    LD_GetPowerReading(serialNo)
    current = Float64(out) / light.max_setpoint * light.max_setcurrent
    power = current * light.properties.max_power / light.max_current
    return power
end

"""
    export_state(light::TCubeLaser)
"""
function export_state(light::TCubeLaser)

    attributes = Dict(
        "unique_id" => light.unique_id, "laser_color" => light.laser_color, "serialNo" => light.serialNo,
        "min_current" => light.min_current, "max_current" => light.max_current,
        "max_setcurrent" => light.max_setcurrent, "max_setpoint" => light.max_setpoint,
        "power_unit" => light.properties.power_unit, "power" => light.properties.power, "is_on" => light.properties.is_on,
        "min_power" => light.properties.min_power, "max_power" => light.properties.max_power
    )
    data = nothing
    children = Dict(
        "daq" => export_state(light.daq) # export_state function from NIDAQcard module
    )

    return attributes, data, children
end
