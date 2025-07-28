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
function mcl_device_attached(positioner::MclZPositioner, wait::UInt32)
    isattached = @ccall madlibpath.MCL_DeviceAttached(wait::Cuint, positioner.handle::Cint)::Bool
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
    version = Ref{Cshort}()
    profile = Ref{Cshort}()

    call = @ccall madlibpath.MCL_GetFirmwareVersion(
        version::Ref{Cshort},
        profile::Ref{Cshort},
        positioner.handle::Cint
    )::Cint

    if call != 0 
        @error "Failed to retrive MicroDrive information. Error code: $(HardwareReturn[call])"
    end

    return string(version[]) * "." * string(profile[])
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
    return serial_num[1]
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
    version = Ref{Cshort}()
    revision = Ref{Cshort}()

    @ccall madlibpath.MCL_DLLVersion(
        version::Ref{Cshort},
        revision::Ref{Cshort},
        positioner.handle::Cint
    )::Cvoid

    return string(version[]) * "." * string(Int32(revision[]))
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
    id = Ref{Cushort}()

    call = @ccall madlibpath.MCL_GetProductID(
        id::Ref{Cushort},
        positioner.handle::Cint
    )::Cint

    if call != 0
        @error "Failed to Retrive device information"
    end

    return id[]
end