
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
    err = @ccall "dcamapi.dll".dcamapi_init(dci::Ref{DCAMAPI_INIT})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Initialize"
    end
    return err, dci
end

function dcamapi_uninit()
    err = @ccall "dcamapi.dll".dcamapi_uninit()::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Un-Initialize"
    end
    return err
end
