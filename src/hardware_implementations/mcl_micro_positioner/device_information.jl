# This file contains wrappers for the Device Information C functions for the microdrive

"""
    mcl_device_attached(positioner::MclZPositioner, wait::Int)
Waits for specified number of milliseconds and checks to see if the MicroDrive is attached.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage
    - `wait::Uint32`: the time to wait in ms

# Returns 
    - `isattached::Bool`: true if the device is attached
"""
function mcl_device_attached(positioner::MclZPositioner, wait::Uint32)
    isattached = @ccall madlibpath.MCL_DeviceAttached(wait::Cuint, positioner.handle)::Bool
    return isattached
end

"""
    mcl_get_firmware_version(positioner::MclZPositioner)
Retrives Firmware version number and profile information

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `version::Int16`: The Firmware Version Number
    - `profile::Int16`: The profile number
"""
function mcl_get_firmware_version(positioner::MclZPositioner)
    version = Vector{Cshort}(undef, 1)
    profile = Vector{Cshort}(undef, 1)

    call = @ccall madlibpath.MCL_GetFirmwareVersion(
        version::Ptr{Cshort},
        profile::Ptr{Cshort},
        positioner.handle::Cint
    )::Cint

    if call != 0 
        @error "Failed to retrive MicroDrive information. Error code: $(HardwareReturn[call])"
    end

    return version, profile
end

"""
    mcl_print_device_info(positioner::MclZPositioner)
Prints product name, product ID, DDL version, and other product infromation to the console.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - nothing
"""
function mcl_print_device_info(positioner::MclZPositioner)
    @ccall madlibpath.MCL_PrintDeviceInfo(positioner.handle::Cint)::Cvoid
    return nothing
end

"""
    mcl_get_serial_number(positioner::MclZPositioner)
Returns the serial number.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `serial_num::Int`: The serial number.
"""
function mcl_get_serial_number(positioner::MclZPositioner)
    serial_num = @ccall madlibpath.MCL_GetSerialNumber(positioner.handle::Cint)::Cint
    return serial_num
end

"""
    mcl_dll_version(positioner::MclZPositioner)
Retrives the version of the firmware.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `version::String`: The Firmware Version Number
"""
function mcl_dll_version(positioner::MclZPositioner)
    version = Vector{Cshort}(undef, 1)
    revision = Vector{Cshort}(undef, 1)

    @ccall madlibpath.MCL_DLLVersion(
        version::Ptr{Cshort},
        revision::Ptr{Cshort},
        positioner.handle::Cint
    )::Cvoid

    return String(version[1]) * "." * String(revision[1])
end

"""
    mcl_get_product_id(positioner::MclZPositioner)
Returns the product ID.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `id::Int`: The product ID
"""
function mcl_get_product_id(positioner::MclZPositioner)
    id = Vector{Cushort}(undef, 1)

    call = @ccall madlibpath.MCL_GetProductID(
        id::Ptr{Cushort},
        positioner.handle::Cint
    )::Cint

    if call != 0
        @error "Failed to Retrive device information"
    end

    return id
end