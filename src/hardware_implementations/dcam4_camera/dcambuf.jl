# dcambuf_ 

## Structures

mutable struct DCAMBUF_ATTACH
    size::Int32
    iKind::Int32
    buffer::Ptr{Ptr{Cvoid}}
    buffercount::Int32
end

struct DCAM_TIMESTAMP
    sec::Int32
    microsec::Int32
end

@enum DCAM_PIXELTYPE::Int32 begin
    DCAM_PIXELTYPE_NONE = 0  # no pixeltype specified
    DCAM_PIXELTYPE_MONO8 = 1  # B/W 8 bit
    DCAM_PIXELTYPE_MONO16 = 2  # B/W 16 bit
end

mutable struct DCAMBUF_FRAME
    size::Int32
    iKind::Int32
    option::Int32
    iFrame::Int32
    buf::Ptr{Cvoid}
    rowbytes::Int32
    type::DCAM_PIXELTYPE
    width::Int32
    height::Int32
    left::Int32
    top::Int32
    timestamp::DCAM_TIMESTAMP
    framestamp::Int32
    camerastamp::Int32
end

function DCAMBUF_FRAME()
    dcf = DCAMBUF_FRAME(0, 0, 0, 0, C_NULL, 0, DCAM_PIXELTYPE_NONE, 0, 0, 0, 0, DCAM_TIMESTAMP(0, 0), 0, 0)
    dcf.size = sizeof(dcf)
    return dcf
end

mutable struct DCAM_METADATAHDR
    size::Int32
    iKind::Int32
    option::Int32
    iFrame::Int32
end

function DCAM_METADATAHDR()
    s = DCAM_METADATAHDR(0, 0, 0, 0)
    s.size = sizeof(s)
    return s
end


## Functions 

function dcambuf_alloc(hdcam::Ptr{Cvoid}, framecount::Int32)
    err = @ccall "dcamapi.dll".dcambuf_alloc(hdcam::Ptr{Cvoid}, framecount::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Allocate Buffer"
    end
    return err
end

function dcambuf_attach(hdcam::Ptr{Cvoid}, param::Ptr{DCAMBUF_ATTACH})
    err = @ccall "dcamapi.dll".dcambuf_attach(hdcam::Ptr{Cvoid}, param::Ptr{DCAMBUF_ATTACH})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Attach Buffer"
    end
    return err
end

function dcambuf_release(hdcam::Ptr{Cvoid})
    iKind = Int32(0)
    err = @ccall "dcamapi.dll".dcambuf_release(hdcam::Ptr{Cvoid}, iKind::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Release Buffer"
    end
    return err
end

function dcambuf_lockframe(hdcam::Ptr{Cvoid}, pFrame::Ptr{DCAMBUF_FRAME})
    err = @ccall "dcamapi.dll".dcambuf_lockframe(hdcam::Ptr{Cvoid}, pFrame::Ptr{DCAMBUF_FRAME})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Lock Frame"
    end
    return err
end

function dcambuf_copyframe(hdcam::Ptr{Cvoid}, pFrame::Ptr{DCAMBUF_FRAME})
    err = @ccall "dcamapi.dll".dcambuf_copyframe(hdcam::Ptr{Cvoid}, pFrame::Ptr{DCAMBUF_FRAME})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Copy Frame"
    end
    return err
end

function dcambuf_getframe(hdcam::Ptr{Cvoid}, iFrame::Int32)

    err, width = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_WIDTH))
    err, height = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_HEIGHT))
    err, rowbytes = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_ROWBYTES))
    err, type = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_PIXELTYPE))

    if DCAM_PIXELTYPE(Int32(type)) == DCAM_PIXELTYPE_MONO16
        data = zeros(UInt16, Int(height), Int(width))
    elseif DCAM_PIXELTYPE(Int32(type)) == DCAM_PIXELTYPE_MONO8
        data = zeros(UInt8, Int(height), Int(width))
    end

    dcf = DCAMBUF_FRAME()
    dcf.iFrame = iFrame
    dcf.width = Int32(width)
    dcf.height = Int32(height)
    dcf.rowbytes = Int32(rowbytes)
    dcf.type = DCAM_PIXELTYPE(Int32(type))
    dcf.buf = pointer(data)

    pFrame=Ref(dcf)

    err = @ccall "dcamapi.dll".dcambuf_copyframe(hdcam::Ptr{Cvoid}, pFrame::Ptr{DCAMBUF_FRAME})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Copy Frame"
    end
    return data
end

function dcambuf_getlastframe(hdcam::Ptr{Cvoid})
    return dcambuf_getframe(hdcam::Ptr{Cvoid}, Int32(-1))
end

function dcambuf_copymetadata(hdcam::Ptr{Cvoid}, hdr::Ptr{DCAM_METADATAHDR})
    err = @ccall "dcamapi.dll".dcambuf_copymetadata(hdcam::Ptr{Cvoid}, hdr::Ptr{DCAM_METADATAHDR})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to Copy Metadata"
    end
    return err
end
