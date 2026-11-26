
# ==== declare structures for DCAM-API functions ====
mutable struct DCAMAPI_INIT
    size::Int32
    iDeviceCount::Int32  # out
    reserved::Int32
    initoptionbytes::Int32
    initoption::Ptr{Int32}
    guid::Ptr{Cvoid}  # const DCAM_GUID*
end

function DCAMAPI_INIT()
    dci = DCAMAPI_INIT(0,0,0,0,C_NULL,C_NULL)
    dci.size = sizeof(DCAMAPI_INIT)
    return dci
end

function dcamapi_init()
    dci = DCAMAPI_INIT()
    err = @dcamcall libdcam.dcamapi_init(dci::Ref{DCAMAPI_INIT})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Initialize"
    end
    return err, dci
end

"""
    dcamapi_uninit() -> DCAMERR

Call the DCAM-API's `dcamapi_uninit` through the library named by `Libraries.libdcam`, and return its
`DCAMERR`. On failure an error is logged and the code is still returned, not thrown. It tears down the
process-wide DCAM-API state; uninitializing while a device is still open or while another part of the
process still uses the API is the caller's problem (the camera `shutdown` calls it when the last holder
gives back its count of the API).
"""
function dcamapi_uninit()
    err = @dcamcall libdcam.dcamapi_uninit()::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Un-Initialize"
    end
    return err
end
