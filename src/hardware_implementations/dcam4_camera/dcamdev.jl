# dcamdev_

## Enum

@enum DCAM_IDSTR::Int32 begin
    DCAM_IDSTR_BUS = 0x04000101
    DCAM_IDSTR_CAMERAID = 0x04000102
    DCAM_IDSTR_VENDOR = 0x04000103
    DCAM_IDSTR_MODEL = 0x04000104
    DCAM_IDSTR_CAMERAVERSION = 0x04000105
    DCAM_IDSTR_DRIVERVERSION = 0x04000106
    DCAM_IDSTR_MODULEVERSION = 0x04000107
    DCAM_IDSTR_DCAMAPIVERSION = 0x04000108
    DCAM_IDSTR_CAMERA_SERIESNAME = 0x0400012c
end


## Structures 

mutable struct DCAMDEV_OPEN
    size::Int32
    index::Int32
    hdcam::Ptr{Cvoid}  # out
end

function DCAMDEV_OPEN()
    dco = DCAMDEV_OPEN(0,0,C_NULL)
    dco.size = sizeof(DCAMDEV_OPEN)
    dco.index = 0
    return dco
end
    
mutable struct DCAMDEV_STRING
    size::Int32
    iString::Int32
    text::Ptr{Vector{Cchar}}
    textbytes::Int32
end

function DCAMDEV_STRING()
    dcs = DCAMDEV_STRING(0,0,C_NULL,0)
    dcs.size = sizeof(DCAMDEV_STRING)
    return dcs
end

function dcamdev_open(i::Int)
    dco = DCAMDEV_OPEN()
    dco.index = Int32(i)
    err = @ccall "dcamapi.dll".dcamdev_open(dco::Ref{DCAMDEV_OPEN})::DCAMERR
    if is_failed(err)
        display(err)
        @error "DCAM Failed to Open Camera"
    end
    return err, dco
end

function dcamdev_close(hdcam::Ptr{Cvoid})
    err = @ccall "dcamapi.dll".dcamdev_close(hdcam::Ptr{Cvoid})::DCAMERR
    if is_failed(err)
        display(err)
        @error "DCAM Failed to Close"
    end
    return err
end

function dcamdev_getstring(hdcam::Ptr{Cvoid}, strid::DCAM_IDSTR)
    dcs = DCAMDEV_STRING()
    dcs.iString = Int32(strid)
    maxlen = 256
    textbuf = Vector{Cchar}(undef, maxlen)
    dcs.text = pointer(textbuf)
    dcs.textbytes = sizeof(textbuf)

    err = @ccall "dcamapi.dll".dcamdev_getstring(hdcam::Ptr{Cvoid},dcs::Ref{DCAMDEV_STRING})::DCAMERR
    if is_failed(err)
        display(err)
        @error "DCAM Failed to Get String"
    end

    uint8_array = reinterpret(UInt8, textbuf)
    str = String(uint8_array)

    # Find the first null character
    null_char_pos = findfirst(==(0), uint8_array)

    # If a null character was found, truncate the string
    if null_char_pos !== nothing
        str = str[1:null_char_pos-1]
    end

    return err, str
end

