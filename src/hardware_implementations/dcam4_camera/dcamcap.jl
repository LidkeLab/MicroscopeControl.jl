# dcamcap_ 

## Structures
@enum DCAMCAP_START begin
    DCAMCAP_START_SEQUENCE = -1
    DCAMCAP_START_SNAP = 0
end


@enum DCAMCAP_STATUS begin
    DCAMCAP_STATUS_ERROR = 0x0000
    DCAMCAP_STATUS_BUSY = 0x0001
    DCAMCAP_STATUS_READY = 0x0002
    DCAMCAP_STATUS_STABLE = 0x0003
    DCAMCAP_STATUS_UNSTABLE = 0x0004
end


mutable struct DCAMCAP_TRANSFERINFO
    size::Int32
    iKind::Int32
    nNewestFrameIndex::Int32
    nFrameCount::Int32
end

function DCAMCAP_TRANSFERINFO()
    s = DCAMCAP_TRANSFERINFO(0, 0, -1, 0)
    s.size = sizeof(s)
    return s
end

## Functions 

function dcamcap_start(hdcam::Ptr{Cvoid}, mode::Int32)
    err = @ccall "dcamapi.dll".dcamcap_start(hdcam::Ptr{Cvoid}, mode::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Start"
    end
    return err
end

function dcamcap_stop(hdcam::Ptr{Cvoid})
    err = @ccall "dcamapi.dll".dcamcap_stop(hdcam::Ptr{Cvoid})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Stop"
    end
    return err
end

function dcamcap_status(hdcam::Ptr{Cvoid})
    pStatus = Ref{Int32}(0)
    err = @ccall "dcamapi.dll".dcamcap_status(hdcam::Ptr{Cvoid}, pStatus::Ref{Int32})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Get Status"
    end
    return err, DCAMCAP_STATUS(pStatus[])
end

function dcamcap_transferinfo(hdcam::Ptr{Cvoid})
    param = DCAMCAP_TRANSFERINFO()  # Create the struct
    err = @ccall "dcamapi.dll".dcamcap_transferinfo(hdcam::Ptr{Cvoid}, param::Ref{DCAMCAP_TRANSFERINFO})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Get Transfer Info"
    end
    return err, param
end

function dcamcap_firetrigger(hdcam::Ptr{Cvoid})
    iKind = 0
    err = @ccall "dcamapi.dll".dcamcap_firetrigger(hdcam::Ptr{Cvoid}, iKind::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Fire Trigger"
    end
    return err
end


# # if __platform_system == 'Windows':
#     dcamcap_record = __dll.dcamcap_record
#     dcamcap_record.argtypes = [c_void_p, c_void_p]
#     dcamcap_record.restype = DCAMERR