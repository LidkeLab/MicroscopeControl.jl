

include("constants_smaract.jl")
include("functions_smaract.jl")

const SmarAct = "C:\\Windows\\System32\\SmarActCTL.dll"


ptr = SA_CTL_GetFullVersionString()
version = unsafe_string(ptr)

println("SmarActCTL library version: $(version).")

function error_check!(errcode; msg="Operation failed")
    if errcode != SA_CTL_ERROR_NONE
        sdk_msg = unsafe_string(SA_CTL_GetResultInfo(errcode))
        error("$msg [SDK: $sdk_msg]")
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
device = Ref{SA_CTL_DeviceHandle_t}()


locator = device_str   
config = C_NULL         

# Call function
errcode = SA_CTL_Open(device,locator,config)

# Check result (same style as your example)
error_check!(errcode, msg="Failed to open device.")

dHandle = device[]

println("Device opened successfully.")
println("Device handle: ", dHandle)


# get device info
function get_property_string(dHandle, idx, pkey; buf_len=SA_CTL_STRING_MAX_LENGTH+1)
    buf = Vector{Cchar}(undef, buf_len)
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

function get_property_i64(dHandle, idx, pkey)
    value = Ref{Int64}()
    errcode = SA_CTL_GetProperty_i64(dHandle, idx, pkey, value, Ref{Csize_t}(1))
    error_check!(errcode)
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
    ch_type = get_property_i32(dHandle, i, SA_CTL_PKEY_CHANNEL_TYPE)

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
    #Set to closed-loop movement
    set_property_i32(dHandle, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_ABSOLUTE)

    #Set max closed loop frequency (maxCLF) to 6 kHz
    set_property_i32(dHandle, channel, SA_CTL_PKEY_MAX_CL_FREQUENCY, 6000)

    #set the hold time to 1000 ms.
    set_property_i32(dHandle, channel, SA_CTL_PKEY_HOLD_TIME, 1000)

    # Set velocity to 1 mm/s   
    set_property_i64(dHandle, channel, SA_CTL_PKEY_MOVE_VELOCITY, 1_000_000_000)

    #Set acceleration to 1 mm/s2
    set_property_i64(dHandle, channel, SA_CTL_PKEY_MOVE_ACCELERATION, 1_000_000_000)

end

for ch in (X_channel, Y_channel)
    #Check if both channels are in closed-loop mode
    mode = get_property_i32(dHandle, ch, SA_CTL_PKEY_MOVE_MODE)
    println("Channel $ch move mode = $mode")

end

function findReference(dHandle, channel)
    println("MCS2 find reference on channel: $channel.")
    set_property_i32(dHandle, channel, SA_CTL_PKEY_REFERENCING_OPTIONS, 2)

    errcode = SA_CTL_Reference(dHandle, channel, 0)

    error_check!(errcode, msg="Failed to start referencing on channel $channel")
    println("Referencing started.")
end

function wait_for_referencing(dHandle, channel)
    println("Waiting for referencing to complete on channel $channel...")
    
    t0 = time()

    while true
        # Read channel state
        state = get_property_i32(dHandle, channel, SA_CTL_PKEY_CHANNEL_STATE)

        # Check referencing bit
        is_referencing = (state & SA_CTL_CH_STATE_BIT_REFERENCING) != 0

        if !is_referencing

            # Check if referenced
            referenced = (state & SA_CTL_CH_STATE_BIT_IS_REFERENCED) !=0

            if !referenced
                error("Referencing failed on channel $channel")
            end

            println("Channel $channel referenced.")
            return
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

# Check for any physical position offset from (0, 0)
x_offset = get_property_i64(dHandle, X_channel, SA_CTL_PKEY_LOGICAL_SCALE_OFFSET)
y_offset = get_property_i64(dHandle, Y_channel, SA_CTL_PKEY_LOGICAL_SCALE_OFFSET)
println("X logical scale offset: $(x_offset) pm")
println("Y logical scale offset: $(y_offset) pm")

reference_all(dHandle)

#get position
function get_position(dHandle, channel)
    value = Ref{Int64}()

    err = SA_CTL_GetProperty_i64(dHandle, channel, SA_CTL_PKEY_POSITION, value, Ref{Csize_t}(1))

    error_check!(err)

    return value[]
end

function wait_for_move(dHandle, channel; timeout_s=60.0)
    t0 = time()
    while true
        state  = get_property_i32(dHandle, channel, SA_CTL_PKEY_CHANNEL_STATE)
        moving = (state & SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING) != 0
        moving || break
        if time() - t0 > timeout_s
            SA_CTL_Stop(dHandle, channel, 0)
            error("Channel $channel: move timeout after $(timeout_s)s")
        end
        sleep(0.05)
    end
end

function _drive_to_endstop(dHandle, channel, target_pm; timeout_s=60.0)
    set_property_i32(dHandle, channel, SA_CTL_PKEY_MOVE_MODE, SA_CTL_MOVE_MODE_CL_ABSOLUTE)

    errcode = SA_CTL_Move(dHandle, channel, target_pm, 0)
    error_check!(errcode, msg="Move command failed on channel $channel")

    wait_for_move(dHandle, channel; timeout_s=timeout_s)

    SA_CTL_Stop(dHandle, channel, 0)
end

function find_travel_range(dHandle, channel; overshoot_pm=Int64(70e9), timeout_s=60.0)
    println("Channel $channel: driving to negative end stop ...")
    _drive_to_endstop(dHandle, channel, -overshoot_pm; timeout_s=timeout_s)
    min_pos = get_position(dHandle, channel)
    println("  Negative end stop at $(min_pos/1e6) µm")

    println("Channel $channel: driving to positive end stop ...")
    _drive_to_endstop(dHandle, channel, overshoot_pm; timeout_s=timeout_s)
    max_pos = get_position(dHandle, channel)
    println("  Positive end stop at $(max_pos/1e6) µm")

    range_mm = (max_pos - min_pos) / 1e9
    println("Channel $channel: physical travel range ≈ $(range_mm) mm")

    return min_pos, max_pos
end

function find_xy_travel_range(dHandle)
    p_x_min, p_x_max = find_travel_range(dHandle, X_channel)
    p_y_min, p_y_max = find_travel_range(dHandle, Y_channel)
    return (p_x_min, p_x_max, p_y_min, p_y_max)
end

function get_xy_position(dHandle)

    x = get_position(dHandle, X_channel)
    y = get_position(dHandle, Y_channel)

    return x, y 
end

# println(get_position(dHandle, channel), "pm")
x, y = get_xy_position(dHandle)
println("X = $(x/1e6) µm")
println("Y = $(y/1e6) µm")

#get travel limit/range
function get_travel_range(dHandle, channel)

    min_pos = get_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MIN)
    max_pos = get_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MAX)

    return min_pos, max_pos
end

#for both channels
function get_xy_travel_range(dHandle)

    x_min, x_max = get_travel_range(dHandle, X_channel)
    y_min, y_max = get_travel_range(dHandle, Y_channel)

    return (x_min, x_max, y_min, y_max)
end

function set_travel_range(dHandle, channel, min_pm::Int64, max_pm::Int64)

    set_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MIN, min_pm)
    set_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MAX, max_pm)

    # Read back to confirm what device actually stored
    actual_min = get_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MIN)
    actual_max = get_property_i64(dHandle, channel, SA_CTL_PKEY_RANGE_LIMIT_MAX)

    return actual_min, actual_max
end

function set_xy_travel_range(dHandle, min_pm::Int64, max_pm::Int64)

    x_min, x_max = set_travel_range(dHandle, X_channel, min_pm, max_pm)
    y_min, y_max = set_travel_range(dHandle, Y_channel, min_pm, max_pm)

    return (x_min, x_max, y_min, y_max)
end

# Physical travel range — drives the stage to each mechanical end stop
p_x_min, p_x_max, p_y_min, p_y_max = find_xy_travel_range(dHandle)
println("Physical travel range — X: $(p_x_min/1e6) to $(p_x_max/1e6) µm  (≈$((p_x_max-p_x_min)/1e9) mm)")
println("Physical travel range — Y: $(p_y_min/1e6) to $(p_y_max/1e6) µm  (≈$((p_y_max-p_y_min)/1e9) mm)")

# Set software travel range limits
min_position_pm = Int64(-20e9)
max_position_pm = Int64(20e9)

# Software range limits (0/0 by default — these are configurable limits, not the physical range)
s_x_min, s_x_max, s_y_min, s_y_max = set_xy_travel_range(dHandle, min_position_pm,max_position_pm)
println("Software travel range - X: $(s_x_min/1e6) to $(s_x_max/1e6) µm" )
println("Software travel range - Y: $(s_y_min/1e6) to $(s_y_max/1e6) µm" )

# move the stage
function move_abs(dHandle, channel, moveValue)
    println("Starting move on channel $channel to position $moveValue...")

    errcode = SA_CTL_Move(dHandle, channel, moveValue, 0)

    error_check!(errcode, msg="Move command failed")

    println("Move started (non-blocking).")
end

function move_xy(dHandle, x_target, y_target)

    move_abs(dHandle, X_channel, x_target)

    move_abs(dHandle,Y_channel,y_target)

    wait_for_move(dHandle, X_channel)

    wait_for_move(dHandle,Y_channel)

end

move_xy(dHandle, Int64(100e6), Int64(-50e6))

# Check if the move was successful
x, y = get_xy_position(dHandle)
println("X=$(x/1e6) µm, " * "Y=$(y/1e6) µm")

function stop(dHandle, channel)
    println("MCS2 stop channel: $channel.")

    errcode = SA_CTL_Stop(dHandle, channel, 0)

    error_check!(errcode, msg="Failed to stop channel $channel")
end

stop(dHandle, X_channel)
stop(dHandle, Y_channel)

errcode = SA_CTL_Close(dHandle)
error_check!(errcode, msg="Failed to close device")


