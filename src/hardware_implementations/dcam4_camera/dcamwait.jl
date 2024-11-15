# dcamwait_ 

## Structures 

mutable struct DCAMWAIT_OPEN
    size::Int32
    supportevent::Int32
    hwait::Ptr{Cvoid}
    hdcam::Ptr{Cvoid}
end

function DCAMWAIT_OPEN(hdcam::Ptr{Cvoid})
    dwo = DCAMWAIT_OPEN(0, 0, C_NULL, hdcam)
    dwo.size = sizeof(dwo)
    return dwo
end


mutable struct DCAMWAIT_START
    size::Int32
    eventhappened::Int32
    eventmask::Int32
    timeout::Int32
end

function DCAMWAIT_START(eventmask::Int32, timeout::Int32)
    return DCAMWAIT_START(sizeof(DCAMWAIT_START), 0, eventmask, timeout)
end

@enum DCAMWAIT_CAPEVENT begin
    DCAMWAIT_CAPEVENT_TRANSFERRED = 0x0001
    DCAMWAIT_CAPEVENT_FRAMEREADY = 0x0002
    DCAMWAIT_CAPEVENT_CYCLEEND = 0x0004
    DCAMWAIT_CAPEVENT_EXPOSUREEND = 0x0008
    DCAMWAIT_CAPEVENT_STOPPED = 0x0010
end

@enum DCAMWAIT_RECEVENT begin
    DCAMWAIT_RECEVENT_STOPPED = 0x0100
    DCAMWAIT_RECEVENT_WARNING = 0x0200
    DCAMWAIT_RECEVENT_MISSED = 0x0400
    DCAMWAIT_RECEVENT_DISKFULL = 0x1000
    DCAMWAIT_RECEVENT_WRITEFAULT = 0x2000
    DCAMWAIT_RECEVENT_SKIPPED = 0x4000
end


## Functions

function dcamwait_open(hdcam::Ptr{Cvoid})
    dwo = DCAMWAIT_OPEN(hdcam)
    param = Ref(dwo)
    err = @ccall "dcamapi.dll".dcamwait_open(param::Ref{DCAMWAIT_OPEN})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Open Wait:  $(err)))"
    end
    return err, dwo.hwait
end

function dcamwait_close(hwait::Ptr{Cvoid})
    err = @ccall "dcamapi.dll".dcamwait_close(hwait::Ptr{Cvoid})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Close Wait:  $(err)))"
    end
    return err
end

function dcamwait_start(hwait::Ptr{Cvoid}, param::Ref{DCAMWAIT_START})
    err = @ccall "dcamapi.dll".dcamwait_start(hwait::Ptr{Cvoid}, param::Ref{DCAMWAIT_START})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Start Wait: $(err))"
    end
    return err
end

function dcamwait_abort(hwait::Ptr{Cvoid})
    err = @ccall "dcamapi.dll".dcamwait_abort(hwait::Ptr{Cvoid})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Abort Wait:  $(err)))"
    end
    return err
end

function dcamwait_event(hwait::Ptr{Cvoid}, eventmask::Int32, timeout_millisec::Int32)
    dws = DCAMWAIT_START(0, 0, eventmask, timeout_millisec)
    err = dcamwait_start(hwait, Ref(dws))
    if is_failed(err)
        @error "DCAM Failed to Wait for Event:  $(err)))"
    end
    return err, dws.eventhappened
end



