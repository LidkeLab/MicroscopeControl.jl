

include("constants_smaract.jl")
include("functions_smaract.jl")

const SmarAct = "C:\\Windows\\System32\\SmarActCTL.dll"


ptr = SA_CTL_GetFullVersionString()
version = unsafe_string(ptr)

println("SmarActCTL library version: $(version).")

function error_check!(errcode; msg="Operation failed")
    if errcode != SA_CTL_ERROR_NONE
        error(msg)
    end
end


# Find devices
bufsize = 1024
deviceList = Vector{Cchar}(undef, bufsize)

# Length variable (size_t *)
deviceListLen = Ref{Csize_t}(bufsize)

# Call function
errcode = SA_CTL_FindDevices("", deviceList, deviceListLen)
error_check!(errcode, msg="Failed to find devices.")

# Convert to Julia string (assumes null-terminated C string)
device_str = unsafe_string(pointer(deviceList))

if isempty(device_str)
    @error "No devices found."
    return
else
    println("Devices found: $(device_str)")
end

# open device
dHandle = Ref{SA_CTL_DeviceHandle_t}()


locator = device_str   
config = ""         

# Call function
errcode = SA_CTL_Open(dHandle,locator,config)

# Check result (same style as your example)
error_check!(errcode, msg="Failed to open device.")


println("Device opened successfully.")
println("Device handle: ", dHandle[])


# get device info


function get_property_string(dHandle, idx, pkey; buf_len=SA_CTL_STRING_MAX_LENGTH+1)
    buf = Vector{UInt8}(undef, buf_len)
    ioSize = Ref{Csize_t}(buf_len)

    errcode = SA_CTL_GetProperty_s(dHandle, idx, pkey, buf, ioSize)

    error_check!(errcode, msg="Failed to get string property (pkey=$pkey, idx=$idx)")

    return unsafe_string(pointer(buf))
end


function get_property_i32(dHandle, idx, pkey)
    value = Ref{Int32}()

    errcode = SA_CTL_GetProperty_i32(dHandle, idx, pkey, value, Ref{Csize_t}(1))

    error_check!(errcode, msg="Failed to get int32 property (pkey=$pkey, idx=$idx)")

    return value[]
end



println("\nDevice Serial Number: ",
    get_property_string(dHandle, 0, SA_CTL_PKEY_DEVICE_SERIAL_NUMBER))

println("Device Name: ",
    get_property_string(dHandle, 0, SA_CTL_PKEY_DEVICE_NAME))

type = get_property_i32(dHandle, 0, SA_CTL_PKEY_INTERFACE_TYPE)

if type == SA_CTL_INTERFACE_USB
    println("Interface Type: USB")
elseif type == SA_CTL_INTERFACE_ETHERNET
    println("Interface Type: Ethernet")
end

state = get_property_i32(dHandle, 0, SA_CTL_PKEY_DEVICE_STATE)

println("Hand Control Module present: ",
    (state & SA_CTL_DEV_STATE_BIT_HM_PRESENT) != 0 ? "yes" : "no")

noOfBusModules = get_property_i32(dHandle, 0, SA_CTL_PKEY_NUMBER_OF_BUS_MODULES)

noOfChannels = get_property_i32(dHandle, 0, SA_CTL_PKEY_NUMBER_OF_CHANNELS)

println("Number of Bus Modules: ", noOfBusModules)
println("Total Number of Channels: ", noOfChannels)

# ===== Module info =====
for i in 0:(noOfBusModules - 1)
    type = get_property_i32(dHandle, i, SA_CTL_PKEY_MODULE_TYPE)

    print("Module $i")

    if type == SA_CTL_STICK_SLIP_PIEZO_DRIVER
        println(" (Stick-Slip-Piezo-Driver):")
    elseif type == SA_CTL_MAGNETIC_DRIVER
        println(" (E-Magnetic-Driver):")
    elseif type == SA_CTL_PIEZO_SCANNER_DRIVER
        println(" (Piezo-Scanner-Driver):")
    else
        println()
    end

    num = get_property_i32(dHandle, i, SA_CTL_PKEY_NUMBER_OF_BUS_MODULE_CHANNELS)

    println("    Number of Bus Module Channels: $num")

    state = get_property_i32(dHandle, i, SA_CTL_PKEY_MODULE_STATE)

    print("    Sensor Module present: ")
    println((state & SA_CTL_MOD_STATE_BIT_SM_PRESENT) != 0 ? "yes" : "no")
end

   
# ===== Channel info =====
for i in 0:(noOfChannels - 1)
    println("        Channel: $i")

    pos_name = get_property_string(dHandle, i, SA_CTL_PKEY_POSITIONER_TYPE_NAME)

    type = get_property_i32(dHandle, i, SA_CTL_PKEY_POSITIONER_TYPE)

    println("        Positioner Type: $pos_name ($type)")

    state = get_property_i32(dHandle, i, SA_CTL_PKEY_CHANNEL_STATE)

    print("        Amplifier enabled: ")
    println((state & SA_CTL_CH_STATE_BIT_AMPLIFIER_ENABLED) != 0 ? "yes" : "no")

    # Channel type-specific info
    ch_type = get_property_i32(dHandle, i,
        SA_CTL_PKEY_CHANNEL_TYPE)

    if ch_type == SA_CTL_STICK_SLIP_PIEZO_DRIVER
        maxCLF = get_property_i32(dHandle, i, SA_CTL_PKEY_MAX_CL_FREQUENCY)

        println("        Max-CLF: $maxCLF Hz")

    elseif ch_type == SA_CTL_MAGNETIC_DRIVER
        print("        Channel is phased: ")
        println((state & SA_CTL_CH_STATE_BIT_IS_PHASED) != 0 ? "yes" : "no")
    end

    println("-------------------------------------------------------")
end


# reference the stage
function set_property_i32(dHandle, idx, pkey, value)
    errcode = SA_CTL_SetProperty_i32(dHandle, idx, pkey, value)

    error_check!(errcode, msg="SetProperty failed (pkey=$pkey, idx=$idx, value=$value)")
end

function set_property_i64(dHandle, idx, pkey, value)
    errcode = SA_CTL_SetProperty_i64(dHandle, idx, pkey, value)
    error_check!(errcode, msg="SetProperty_i64 failed (pkey=$pkey, idx=$idx)")
end


X_channel = 0
Y_channel = 1

for channel in (X_channel, Y_channel)

    #Set max closed loop frequency (maxCLF) to 6 kHz
    set_property_i32(dHandle, channel, SA_CTL_PKEY_MAX_CL_FREQUENCY, 6000)

    #set the hold time to 1000 ms.
    set_property_i32(dHandle, channel, SA_CTL_PKEY_HOLD_TIME, 1000)

    # Set velocity to 1 mm/s   
    set_property_i64(dHandle, channel, SA_CTL_PKEY_MOVE_VELOCITY, 1_000_000_000)

    #Set acceleration to 1 mm/s2
    set_property_i64(dHandle, channel, SA_CTL_PKEY_MOVE_ACCELERATION, 1_000_000_000)

end


function findReference(dHandle, channel)
    println("MCS2 find reference on channel: $channel.")

    set_property_i32(dHandle, channel, SA_CTL_PKEY_REFERENCING_OPTIONS, 0)

    errcode = SA_CTL_Reference(dHandle, channel, 0)

    error_check!(errcode, msg="Failed to start referencing on channel $channel")

    println("Referencing started.")
end

function wait_for_referencing(dHandle, channel; timeout = 60.0)
    println("Waiting for referencing to complete on channel $channel...")
    
    t0 = time()

    while true
        # Read channel state
        state = get_property_i32(dHandle, channel, SA_CTL_PKEY_CHANNEL_STATE)

        # Check referencing bit
        is_referencing = (state & SA_CTL_CH_STATE_BIT_REFERENCING) != 0

        if !is_referencing
            println("Referencing completed.")
            return
        end

        if time() - t0 > timeout
            error("Reference timeout after $timeout seconds")
        end

        sleep(0.1)   # avoid busy-waiting (100 ms)
    end
end
    
function reference_all(dHandle)

    for channel in (X_channel, Y_channel)
        findReference(dHandle, channel)
    end

    for channel in (X_channel, Y_channel)
        wait_for_referencing(dHandle, channel)
    end

end

# findReference(dHandle, channel)
# wait_for_referencing(dHandle, channel)
reference_all(dHandle)

#get position
function get_position(dHandle, channel)
    value = Ref{Int64}()

    err = SA_CTL_GetProperty_i64(dHandle, channel, SA_CTL_PKEY_POSITION, value, Ref{Csize_t}(1))

    error_check!(err)

    return value[]
end

function get_xy_position(dHandle)

    x = get_position(dHandle, X_channel)
    y = get_position(dHandle, Y_channel)

    return x, y 
end

# println(get_position(dHandle, channel), "pm")
println("X = $x, Y = $y")

# move the stage
function move_abs(dHandle, channel, moveValue)
    println("Starting move on channel $channel to position $moveValue...")

    errcode = SA_CTL_Move(dHandle, channel, moveValue, 0)

    error_check!(errcode, msg="Move command failed")

    println("Move started (non-blocking).")
end

function wait_for_move(dHandle, channel; timeout=10.0)
    println("Waiting for move to complete on channel $channel...")

    t0 = time()

    while true
        state = get_property_i32(dHandle, channel, SA_CTL_PKEY_CHANNEL_STATE)

        moving = (state & SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING) != 0
        closed_loop = (state & SA_CTL_CH_STATE_BIT_CLOSED_LOOP_ACTIVE) != 0

        # Movement is finished when not moving anymore
        # (optionally also require closed-loop inactive depending on behavior)
        if !moving
            println("Move completed.")
            return
        end

        if time() - t0 > timeout
            @error "Move timeout!"
            return
        end

        sleep(0.05)  # 50 ms polling
    end
end

function move_xy(dHandle, x_target, y_target)

    move_abs(dHandle, X_channel, x_target)

    move_abs(dHandle,Y_channel,y_target)

    wait_for_move(dHandle, X_channel)

    wait_for_move(dHandle,Y_channel)

end

# Move to 100 µm = 100e6 pm
# moveValue = Int64(100e6)
# move_abs(dHandle, channel, moveValue)

move_xy(dHandle, Int64(100e6), Int64(-50e6))
wait_for_move(dHandle, channel)


function stop(dHandle, channel)
    println("MCS2 stop channel: $channel.")

    errcode = SA_CTL_Stop(dHandle, channel, 0)

    error_check!(errcode, msg="Failed to stop channel $channel")
end

stop(dHandle, channel)

errcode = SA_CTL_Close(dHandle[])
error_check!(errcode, msg="Failed to close device")


