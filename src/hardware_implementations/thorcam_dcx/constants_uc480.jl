const ULONG = Culong

const BYTE = Cuchar

const WORD = Cushort

const DWORD = Culong

const UINT = Cuint

const UINT64 = Culonglong

const CHAR = Cchar

const HANDLE = Ptr{Cvoid}

struct HWND__
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{HWND__}, f::Symbol)
    f === :unused && return Ptr{Cint}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::HWND__, f::Symbol)
    r = Ref{HWND__}(x)
    ptr = Base.unsafe_convert(Ptr{HWND__}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{HWND__}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const HWND = Ptr{HWND__}

struct HDC__
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{HDC__}, f::Symbol)
    f === :unused && return Ptr{Cint}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::HDC__, f::Symbol)
    r = Ref{HDC__}(x)
    ptr = Base.unsafe_convert(Ptr{HDC__}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{HDC__}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const HDC = Ptr{HDC__}

const INT = Cint

const HCAM = DWORD

struct BOARDINFO
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{BOARDINFO}, f::Symbol)
    f === :SerNo && return Ptr{NTuple{12, Cchar}}(x + 0)
    f === :ID && return Ptr{NTuple{20, Cchar}}(x + 12)
    f === :Version && return Ptr{NTuple{10, Cchar}}(x + 32)
    f === :Date && return Ptr{NTuple{12, Cchar}}(x + 42)
    f === :Select && return Ptr{Cuchar}(x + 54)
    f === :Type && return Ptr{Cuchar}(x + 55)
    f === :Reserved && return Ptr{NTuple{8, Cchar}}(x + 56)
    return getfield(x, f)
end

function Base.getproperty(x::BOARDINFO, f::Symbol)
    r = Ref{BOARDINFO}(x)
    ptr = Base.unsafe_convert(Ptr{BOARDINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{BOARDINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const PBOARDINFO = Ptr{BOARDINFO}

const IS_BOOTBOOST_ID = BYTE

const IS_CHAR = Cchar

const HFALC = DWORD

struct S_IS_RANGE_S32
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_RANGE_S32}, f::Symbol)
    f === :s32Min && return Ptr{INT}(x + 0)
    f === :s32Max && return Ptr{INT}(x + 4)
    f === :s32Inc && return Ptr{INT}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_RANGE_S32, f::Symbol)
    r = Ref{S_IS_RANGE_S32}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_RANGE_S32}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_RANGE_S32}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_RANGE_S32 = S_IS_RANGE_S32

struct S_IS_RANGE_F64
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_RANGE_F64}, f::Symbol)
    f === :f64Min && return Ptr{Cdouble}(x + 0)
    f === :f64Max && return Ptr{Cdouble}(x + 8)
    f === :f64Inc && return Ptr{Cdouble}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_RANGE_F64, f::Symbol)
    r = Ref{S_IS_RANGE_F64}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_RANGE_F64}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_RANGE_F64}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_RANGE_F64 = S_IS_RANGE_F64

struct _SENSORINFO
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{_SENSORINFO}, f::Symbol)
    f === :SensorID && return Ptr{WORD}(x + 0)
    f === :strSensorName && return Ptr{NTuple{32, IS_CHAR}}(x + 2)
    f === :nColorMode && return Ptr{Cchar}(x + 34)
    f === :nMaxWidth && return Ptr{DWORD}(x + 36)
    f === :nMaxHeight && return Ptr{DWORD}(x + 40)
    f === :bMasterGain && return Ptr{BOOL}(x + 44)
    f === :bRGain && return Ptr{BOOL}(x + 48)
    f === :bGGain && return Ptr{BOOL}(x + 52)
    f === :bBGain && return Ptr{BOOL}(x + 56)
    f === :bGlobShutter && return Ptr{BOOL}(x + 60)
    f === :wPixelSize && return Ptr{WORD}(x + 64)
    f === :nUpperLeftBayerPixel && return Ptr{Cchar}(x + 66)
    f === :Reserved && return Ptr{NTuple{13, Cchar}}(x + 67)
    return getfield(x, f)
end

function Base.getproperty(x::_SENSORINFO, f::Symbol)
    r = Ref{_SENSORINFO}(x)
    ptr = Base.unsafe_convert(Ptr{_SENSORINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_SENSORINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const SENSORINFO = _SENSORINFO

const PSENSORINFO = Ptr{_SENSORINFO}

@cenum _BAYER_PIXEL::UInt32 begin
    BAYER_PIXEL_RED = 0
    BAYER_PIXEL_GREEN = 1
    BAYER_PIXEL_BLUE = 2
end

const BAYER_PIXEL = _BAYER_PIXEL

struct _REVISIONINFO
    data::NTuple{132, UInt8}
end

function Base.getproperty(x::Ptr{_REVISIONINFO}, f::Symbol)
    f === :size && return Ptr{WORD}(x + 0)
    f === :Sensor && return Ptr{WORD}(x + 2)
    f === :Cypress && return Ptr{WORD}(x + 4)
    f === :Blackfin && return Ptr{DWORD}(x + 8)
    f === :DspFirmware && return Ptr{WORD}(x + 12)
    f === :USB_Board && return Ptr{WORD}(x + 14)
    f === :Sensor_Board && return Ptr{WORD}(x + 16)
    f === :Processing_Board && return Ptr{WORD}(x + 18)
    f === :Memory_Board && return Ptr{WORD}(x + 20)
    f === :Housing && return Ptr{WORD}(x + 22)
    f === :Filter && return Ptr{WORD}(x + 24)
    f === :Timing_Board && return Ptr{WORD}(x + 26)
    f === :Product && return Ptr{WORD}(x + 28)
    f === :Power_Board && return Ptr{WORD}(x + 30)
    f === :Logic_Board && return Ptr{WORD}(x + 32)
    f === :FX3 && return Ptr{WORD}(x + 34)
    f === :FPGA && return Ptr{WORD}(x + 36)
    f === :reserved && return Ptr{NTuple{92, BYTE}}(x + 38)
    return getfield(x, f)
end

function Base.getproperty(x::_REVISIONINFO, f::Symbol)
    r = Ref{_REVISIONINFO}(x)
    ptr = Base.unsafe_convert(Ptr{_REVISIONINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_REVISIONINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const REVISIONINFO = _REVISIONINFO

const PREVISIONINFO = Ptr{_REVISIONINFO}

@cenum _UC480_CAPTURE_STATUS::UInt32 begin
    IS_CAP_STATUS_API_NO_DEST_MEM = 162
    IS_CAP_STATUS_API_CONVERSION_FAILED = 163
    IS_CAP_STATUS_API_IMAGE_LOCKED = 165
    IS_CAP_STATUS_DRV_OUT_OF_BUFFERS = 178
    IS_CAP_STATUS_DRV_DEVICE_NOT_READY = 180
    IS_CAP_STATUS_USB_TRANSFER_FAILED = 199
    IS_CAP_STATUS_DEV_MISSED_IMAGES = 229
    IS_CAP_STATUS_DEV_TIMEOUT = 214
    IS_CAP_STATUS_DEV_FRAME_CAPTURE_FAILED = 217
    IS_CAP_STATUS_ETH_BUFFER_OVERRUN = 228
    IS_CAP_STATUS_ETH_MISSED_IMAGES = 229
end

const UC480_CAPTURE_STATUS = _UC480_CAPTURE_STATUS

struct _UC480_CAPTURE_STATUS_INFO
    data::NTuple{1088, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_CAPTURE_STATUS_INFO}, f::Symbol)
    f === :dwCapStatusCnt_Total && return Ptr{DWORD}(x + 0)
    f === :reserved && return Ptr{NTuple{60, BYTE}}(x + 4)
    f === :adwCapStatusCnt_Detail && return Ptr{NTuple{256, DWORD}}(x + 64)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_CAPTURE_STATUS_INFO, f::Symbol)
    r = Ref{_UC480_CAPTURE_STATUS_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_CAPTURE_STATUS_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_CAPTURE_STATUS_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_CAPTURE_STATUS_INFO = _UC480_CAPTURE_STATUS_INFO

@cenum E_CAPTURE_STATUS_CMD::UInt32 begin
    IS_CAPTURE_STATUS_INFO_CMD_RESET = 1
    IS_CAPTURE_STATUS_INFO_CMD_GET = 2
end

const CAPTURE_STATUS_CMD = E_CAPTURE_STATUS_CMD

struct _UC480_CAMERA_INFO
    data::NTuple{112, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_CAMERA_INFO}, f::Symbol)
    f === :dwCameraID && return Ptr{DWORD}(x + 0)
    f === :dwDeviceID && return Ptr{DWORD}(x + 4)
    f === :dwSensorID && return Ptr{DWORD}(x + 8)
    f === :dwInUse && return Ptr{DWORD}(x + 12)
    f === :SerNo && return Ptr{NTuple{16, IS_CHAR}}(x + 16)
    f === :Model && return Ptr{NTuple{16, IS_CHAR}}(x + 32)
    f === :dwStatus && return Ptr{DWORD}(x + 48)
    f === :dwReserved && return Ptr{NTuple{2, DWORD}}(x + 52)
    f === :FullModelName && return Ptr{NTuple{32, IS_CHAR}}(x + 60)
    f === :dwReserved2 && return Ptr{NTuple{5, DWORD}}(x + 92)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_CAMERA_INFO, f::Symbol)
    r = Ref{_UC480_CAMERA_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_CAMERA_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_CAMERA_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_CAMERA_INFO = _UC480_CAMERA_INFO

const PUC480_CAMERA_INFO = Ptr{_UC480_CAMERA_INFO}

struct _UC480_CAMERA_LIST
    data::NTuple{116, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_CAMERA_LIST}, f::Symbol)
    f === :dwCount && return Ptr{ULONG}(x + 0)
    f === :uci && return Ptr{NTuple{1, UC480_CAMERA_INFO}}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_CAMERA_LIST, f::Symbol)
    r = Ref{_UC480_CAMERA_LIST}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_CAMERA_LIST}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_CAMERA_LIST}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_CAMERA_LIST = _UC480_CAMERA_LIST

const PUC480_CAMERA_LIST = Ptr{_UC480_CAMERA_LIST}

struct _AUTO_BRIGHT_STATUS
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{_AUTO_BRIGHT_STATUS}, f::Symbol)
    f === :curValue && return Ptr{DWORD}(x + 0)
    f === :curError && return Ptr{Clong}(x + 4)
    f === :curController && return Ptr{DWORD}(x + 8)
    f === :curCtrlStatus && return Ptr{DWORD}(x + 12)
    return getfield(x, f)
end

function Base.getproperty(x::_AUTO_BRIGHT_STATUS, f::Symbol)
    r = Ref{_AUTO_BRIGHT_STATUS}(x)
    ptr = Base.unsafe_convert(Ptr{_AUTO_BRIGHT_STATUS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_AUTO_BRIGHT_STATUS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const AUTO_BRIGHT_STATUS = _AUTO_BRIGHT_STATUS

const PAUTO_BRIGHT_STATUS = Ptr{_AUTO_BRIGHT_STATUS}

struct _AUTO_WB_CHANNNEL_STATUS
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{_AUTO_WB_CHANNNEL_STATUS}, f::Symbol)
    f === :curValue && return Ptr{DWORD}(x + 0)
    f === :curError && return Ptr{Clong}(x + 4)
    f === :curCtrlStatus && return Ptr{DWORD}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_AUTO_WB_CHANNNEL_STATUS, f::Symbol)
    r = Ref{_AUTO_WB_CHANNNEL_STATUS}(x)
    ptr = Base.unsafe_convert(Ptr{_AUTO_WB_CHANNNEL_STATUS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_AUTO_WB_CHANNNEL_STATUS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const AUTO_WB_CHANNNEL_STATUS = _AUTO_WB_CHANNNEL_STATUS

const PAUTO_WB_CHANNNEL_STATUS = Ptr{_AUTO_WB_CHANNNEL_STATUS}

struct _AUTO_WB_STATUS
    data::NTuple{40, UInt8}
end

function Base.getproperty(x::Ptr{_AUTO_WB_STATUS}, f::Symbol)
    f === :RedChannel && return Ptr{AUTO_WB_CHANNNEL_STATUS}(x + 0)
    f === :GreenChannel && return Ptr{AUTO_WB_CHANNNEL_STATUS}(x + 12)
    f === :BlueChannel && return Ptr{AUTO_WB_CHANNNEL_STATUS}(x + 24)
    f === :curController && return Ptr{DWORD}(x + 36)
    return getfield(x, f)
end

function Base.getproperty(x::_AUTO_WB_STATUS, f::Symbol)
    r = Ref{_AUTO_WB_STATUS}(x)
    ptr = Base.unsafe_convert(Ptr{_AUTO_WB_STATUS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_AUTO_WB_STATUS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const AUTO_WB_STATUS = _AUTO_WB_STATUS

const PAUTO_WB_STATUS = Ptr{_AUTO_WB_STATUS}

@cenum E_AUTO_SHUTTER_PHOTOM::UInt32 begin
    AS_PM_NONE = 0
    AS_PM_SENS_CENTER_WEIGHTED = 1
    AS_PM_SENS_CENTER_SPOT = 2
    AS_PM_SENS_PORTRAIT = 4
    AS_PM_SENS_LANDSCAPE = 8
    AS_PM_SENS_CENTER_AVERAGE = 16
end

const AUTO_SHUTTER_PHOTOM = E_AUTO_SHUTTER_PHOTOM

@cenum E_AUTO_GAIN_PHOTOM::UInt32 begin
    AG_PM_NONE = 0
    AG_PM_SENS_CENTER_WEIGHTED = 1
    AG_PM_SENS_CENTER_SPOT = 2
    AG_PM_SENS_PORTRAIT = 4
    AG_PM_SENS_LANDSCAPE = 8
end

const AUTO_GAIN_PHOTOM = E_AUTO_GAIN_PHOTOM

@cenum E_ANTI_FLICKER_MODE::UInt32 begin
    ANTIFLCK_MODE_OFF = 0
    ANTIFLCK_MODE_SENS_AUTO = 1
    ANTIFLCK_MODE_SENS_50_FIXED = 2
    ANTIFLCK_MODE_SENS_60_FIXED = 4
end

const ANTI_FLICKER_MODE = E_ANTI_FLICKER_MODE

@cenum E_WHITEBALANCE_MODE::UInt32 begin
    WB_MODE_DISABLE = 0
    WB_MODE_AUTO = 1
    WB_MODE_ALL_PULLIN = 2
    WB_MODE_INCANDESCENT_LAMP = 4
    WB_MODE_FLUORESCENT_DL = 8
    WB_MODE_OUTDOOR_CLEAR_SKY = 16
    WB_MODE_OUTDOOR_CLOUDY = 32
    WB_MODE_FLUORESCENT_LAMP = 64
    WB_MODE_FLUORESCENT_NL = 128
end

const WHITEBALANCE_MODE = E_WHITEBALANCE_MODE

struct _UC480_AUTO_INFO
    data::NTuple{108, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_AUTO_INFO}, f::Symbol)
    f === :AutoAbility && return Ptr{DWORD}(x + 0)
    f === :sBrightCtrlStatus && return Ptr{AUTO_BRIGHT_STATUS}(x + 4)
    f === :sWBCtrlStatus && return Ptr{AUTO_WB_STATUS}(x + 20)
    f === :AShutterPhotomCaps && return Ptr{DWORD}(x + 60)
    f === :AGainPhotomCaps && return Ptr{DWORD}(x + 64)
    f === :AAntiFlickerCaps && return Ptr{DWORD}(x + 68)
    f === :SensorWBModeCaps && return Ptr{DWORD}(x + 72)
    f === :reserved && return Ptr{NTuple{8, DWORD}}(x + 76)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_AUTO_INFO, f::Symbol)
    r = Ref{_UC480_AUTO_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_AUTO_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_AUTO_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_AUTO_INFO = _UC480_AUTO_INFO

const PUC480_AUTO_INFO = Ptr{_UC480_AUTO_INFO}

struct _DC_INFO
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{_DC_INFO}, f::Symbol)
    f === :nSize && return Ptr{Cuint}(x + 0)
    f === :hDC && return Ptr{HDC}(x + 8)
    f === :nCx && return Ptr{Cuint}(x + 16)
    f === :nCy && return Ptr{Cuint}(x + 20)
    return getfield(x, f)
end

function Base.getproperty(x::_DC_INFO, f::Symbol)
    r = Ref{_DC_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_DC_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_DC_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const DC_INFO = _DC_INFO

const PDC_INFO = Ptr{_DC_INFO}

struct _KNEEPOINT
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{_KNEEPOINT}, f::Symbol)
    f === :x && return Ptr{Cdouble}(x + 0)
    f === :y && return Ptr{Cdouble}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_KNEEPOINT, f::Symbol)
    r = Ref{_KNEEPOINT}(x)
    ptr = Base.unsafe_convert(Ptr{_KNEEPOINT}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_KNEEPOINT}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const KNEEPOINT = _KNEEPOINT

const PKNEEPOINT = Ptr{_KNEEPOINT}

struct _KNEEPOINTARRAY
    data::NTuple{168, UInt8}
end

function Base.getproperty(x::Ptr{_KNEEPOINTARRAY}, f::Symbol)
    f === :NumberOfUsedKneepoints && return Ptr{INT}(x + 0)
    f === :Kneepoint && return Ptr{NTuple{10, KNEEPOINT}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_KNEEPOINTARRAY, f::Symbol)
    r = Ref{_KNEEPOINTARRAY}(x)
    ptr = Base.unsafe_convert(Ptr{_KNEEPOINTARRAY}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_KNEEPOINTARRAY}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const KNEEPOINTARRAY = _KNEEPOINTARRAY

const PKNEEPOINTARRAY = Ptr{_KNEEPOINTARRAY}

struct _KNEEPOINTINFO
    data::NTuple{240, UInt8}
end

function Base.getproperty(x::Ptr{_KNEEPOINTINFO}, f::Symbol)
    f === :NumberOfSupportedKneepoints && return Ptr{INT}(x + 0)
    f === :NumberOfUsedKneepoints && return Ptr{INT}(x + 4)
    f === :MinValueX && return Ptr{Cdouble}(x + 8)
    f === :MaxValueX && return Ptr{Cdouble}(x + 16)
    f === :MinValueY && return Ptr{Cdouble}(x + 24)
    f === :MaxValueY && return Ptr{Cdouble}(x + 32)
    f === :DefaultKneepoint && return Ptr{NTuple{10, KNEEPOINT}}(x + 40)
    f === :Reserved && return Ptr{NTuple{10, INT}}(x + 200)
    return getfield(x, f)
end

function Base.getproperty(x::_KNEEPOINTINFO, f::Symbol)
    r = Ref{_KNEEPOINTINFO}(x)
    ptr = Base.unsafe_convert(Ptr{_KNEEPOINTINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_KNEEPOINTINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const KNEEPOINTINFO = _KNEEPOINTINFO

const PKNEEPOINTINFO = Ptr{_KNEEPOINTINFO}

@cenum eUC480_GET_ESTIMATED_TIME_MODE::UInt32 begin
    IS_SE_STARTER_FW_UPLOAD = 1
    IS_CP_STARTER_FW_UPLOAD = 2
    IS_STARTER_FW_UPLOAD = 4
end

const UC480_GET_ESTIMATED_TIME_MODE = eUC480_GET_ESTIMATED_TIME_MODE

struct _SENSORSCALERINFO
    data::NTuple{128, UInt8}
end

function Base.getproperty(x::Ptr{_SENSORSCALERINFO}, f::Symbol)
    f === :nCurrMode && return Ptr{INT}(x + 0)
    f === :nNumberOfSteps && return Ptr{INT}(x + 4)
    f === :dblFactorIncrement && return Ptr{Cdouble}(x + 8)
    f === :dblMinFactor && return Ptr{Cdouble}(x + 16)
    f === :dblMaxFactor && return Ptr{Cdouble}(x + 24)
    f === :dblCurrFactor && return Ptr{Cdouble}(x + 32)
    f === :nSupportedModes && return Ptr{INT}(x + 40)
    f === :bReserved && return Ptr{NTuple{84, BYTE}}(x + 44)
    return getfield(x, f)
end

function Base.getproperty(x::_SENSORSCALERINFO, f::Symbol)
    r = Ref{_SENSORSCALERINFO}(x)
    ptr = Base.unsafe_convert(Ptr{_SENSORSCALERINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_SENSORSCALERINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const SENSORSCALERINFO = _SENSORSCALERINFO

struct _UC480TIME
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{_UC480TIME}, f::Symbol)
    f === :wYear && return Ptr{WORD}(x + 0)
    f === :wMonth && return Ptr{WORD}(x + 2)
    f === :wDay && return Ptr{WORD}(x + 4)
    f === :wHour && return Ptr{WORD}(x + 6)
    f === :wMinute && return Ptr{WORD}(x + 8)
    f === :wSecond && return Ptr{WORD}(x + 10)
    f === :wMilliseconds && return Ptr{WORD}(x + 12)
    f === :byReserved && return Ptr{NTuple{10, BYTE}}(x + 14)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480TIME, f::Symbol)
    r = Ref{_UC480TIME}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480TIME}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480TIME}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480TIME = _UC480TIME

struct _UC480IMAGEINFO
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{_UC480IMAGEINFO}, f::Symbol)
    f === :dwFlags && return Ptr{DWORD}(x + 0)
    f === :byReserved1 && return Ptr{NTuple{4, BYTE}}(x + 4)
    f === :u64TimestampDevice && return Ptr{UINT64}(x + 8)
    f === :TimestampSystem && return Ptr{UC480TIME}(x + 16)
    f === :dwIoStatus && return Ptr{DWORD}(x + 40)
    f === :wAOIIndex && return Ptr{WORD}(x + 44)
    f === :wAOICycle && return Ptr{WORD}(x + 46)
    f === :u64FrameNumber && return Ptr{UINT64}(x + 48)
    f === :dwImageBuffers && return Ptr{DWORD}(x + 56)
    f === :dwImageBuffersInUse && return Ptr{DWORD}(x + 60)
    f === :dwReserved3 && return Ptr{DWORD}(x + 64)
    f === :dwImageHeight && return Ptr{DWORD}(x + 68)
    f === :dwImageWidth && return Ptr{DWORD}(x + 72)
    f === :dwHostProcessTime && return Ptr{DWORD}(x + 76)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480IMAGEINFO, f::Symbol)
    r = Ref{_UC480IMAGEINFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480IMAGEINFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480IMAGEINFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480IMAGEINFO = _UC480IMAGEINFO

@cenum E_IMAGE_FORMAT_CMD::UInt32 begin
    IMGFRMT_CMD_GET_NUM_ENTRIES = 1
    IMGFRMT_CMD_GET_LIST = 2
    IMGFRMT_CMD_SET_FORMAT = 3
    IMGFRMT_CMD_GET_ARBITRARY_AOI_SUPPORTED = 4
    IMGFRMT_CMD_GET_FORMAT_INFO = 5
end

const IMAGE_FORMAT_CMD = E_IMAGE_FORMAT_CMD

@cenum E_CAPTUREMODE::UInt32 begin
    CAPTMODE_FREERUN = 1
    CAPTMODE_SINGLE = 2
    CAPTMODE_TRIGGER_SOFT_SINGLE = 16
    CAPTMODE_TRIGGER_SOFT_CONTINUOUS = 32
    CAPTMODE_TRIGGER_HW_SINGLE = 256
    CAPTMODE_TRIGGER_HW_CONTINUOUS = 512
end

const CAPTUREMODE = E_CAPTUREMODE

struct S_IMAGE_FORMAT_INFO
    data::NTuple{192, UInt8}
end

function Base.getproperty(x::Ptr{S_IMAGE_FORMAT_INFO}, f::Symbol)
    f === :nFormatID && return Ptr{INT}(x + 0)
    f === :nWidth && return Ptr{UINT}(x + 4)
    f === :nHeight && return Ptr{UINT}(x + 8)
    f === :nX0 && return Ptr{INT}(x + 12)
    f === :nY0 && return Ptr{INT}(x + 16)
    f === :nSupportedCaptureModes && return Ptr{UINT}(x + 20)
    f === :nBinningMode && return Ptr{UINT}(x + 24)
    f === :nSubsamplingMode && return Ptr{UINT}(x + 28)
    f === :strFormatName && return Ptr{NTuple{64, IS_CHAR}}(x + 32)
    f === :dSensorScalerFactor && return Ptr{Cdouble}(x + 96)
    f === :nReserved && return Ptr{NTuple{22, UINT}}(x + 104)
    return getfield(x, f)
end

function Base.getproperty(x::S_IMAGE_FORMAT_INFO, f::Symbol)
    r = Ref{S_IMAGE_FORMAT_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{S_IMAGE_FORMAT_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IMAGE_FORMAT_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IMAGE_FORMAT_INFO = S_IMAGE_FORMAT_INFO

struct S_IMAGE_FORMAT_LIST
    data::NTuple{216, UInt8}
end

function Base.getproperty(x::Ptr{S_IMAGE_FORMAT_LIST}, f::Symbol)
    f === :nSizeOfListEntry && return Ptr{UINT}(x + 0)
    f === :nNumListElements && return Ptr{UINT}(x + 4)
    f === :nReserved && return Ptr{NTuple{4, UINT}}(x + 8)
    f === :FormatInfo && return Ptr{NTuple{1, IMAGE_FORMAT_INFO}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::S_IMAGE_FORMAT_LIST, f::Symbol)
    r = Ref{S_IMAGE_FORMAT_LIST}(x)
    ptr = Base.unsafe_convert(Ptr{S_IMAGE_FORMAT_LIST}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IMAGE_FORMAT_LIST}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IMAGE_FORMAT_LIST = S_IMAGE_FORMAT_LIST

@cenum E_FDT_CAPABILITY_FLAGS::UInt32 begin
    FDT_CAP_INVALID = 0
    FDT_CAP_SUPPORTED = 1
    FDT_CAP_SEARCH_ANGLE = 2
    FDT_CAP_SEARCH_AOI = 4
    FDT_CAP_INFO_POSX = 16
    FDT_CAP_INFO_POSY = 32
    FDT_CAP_INFO_WIDTH = 64
    FDT_CAP_INFO_HEIGHT = 128
    FDT_CAP_INFO_ANGLE = 256
    FDT_CAP_INFO_POSTURE = 512
    FDT_CAP_INFO_FACENUMBER = 1024
    FDT_CAP_INFO_OVL = 2048
    FDT_CAP_INFO_NUM_OVL = 4096
    FDT_CAP_INFO_OVL_LINEWIDTH = 8192
end

const FDT_CAPABILITY_FLAGS = E_FDT_CAPABILITY_FLAGS

struct S_FDT_INFO_EL
    data::NTuple{72, UInt8}
end

function Base.getproperty(x::Ptr{S_FDT_INFO_EL}, f::Symbol)
    f === :nFacePosX && return Ptr{INT}(x + 0)
    f === :nFacePosY && return Ptr{INT}(x + 4)
    f === :nFaceWidth && return Ptr{INT}(x + 8)
    f === :nFaceHeight && return Ptr{INT}(x + 12)
    f === :nAngle && return Ptr{INT}(x + 16)
    f === :nPosture && return Ptr{UINT}(x + 20)
    f === :TimestampSystem && return Ptr{UC480TIME}(x + 24)
    f === :nReserved && return Ptr{UINT64}(x + 48)
    f === :nReserved2 && return Ptr{NTuple{4, UINT}}(x + 56)
    return getfield(x, f)
end

function Base.getproperty(x::S_FDT_INFO_EL, f::Symbol)
    r = Ref{S_FDT_INFO_EL}(x)
    ptr = Base.unsafe_convert(Ptr{S_FDT_INFO_EL}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_FDT_INFO_EL}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const FDT_INFO_EL = S_FDT_INFO_EL

struct S_FDT_INFO_LIST
    data::NTuple{104, UInt8}
end

function Base.getproperty(x::Ptr{S_FDT_INFO_LIST}, f::Symbol)
    f === :nSizeOfListEntry && return Ptr{UINT}(x + 0)
    f === :nNumDetectedFaces && return Ptr{UINT}(x + 4)
    f === :nNumListElements && return Ptr{UINT}(x + 8)
    f === :nReserved && return Ptr{NTuple{4, UINT}}(x + 12)
    f === :FaceEntry && return Ptr{NTuple{1, FDT_INFO_EL}}(x + 32)
    return getfield(x, f)
end

function Base.getproperty(x::S_FDT_INFO_LIST, f::Symbol)
    r = Ref{S_FDT_INFO_LIST}(x)
    ptr = Base.unsafe_convert(Ptr{S_FDT_INFO_LIST}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_FDT_INFO_LIST}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const FDT_INFO_LIST = S_FDT_INFO_LIST

@cenum E_FDT_CMD::UInt32 begin
    FDT_CMD_GET_CAPABILITIES = 0
    FDT_CMD_SET_DISABLE = 1
    FDT_CMD_SET_ENABLE = 2
    FDT_CMD_SET_SEARCH_ANGLE = 3
    FDT_CMD_GET_SEARCH_ANGLE = 4
    FDT_CMD_SET_SEARCH_ANGLE_ENABLE = 5
    FDT_CMD_SET_SEARCH_ANGLE_DISABLE = 6
    FDT_CMD_GET_SEARCH_ANGLE_ENABLE = 7
    FDT_CMD_SET_SEARCH_AOI = 8
    FDT_CMD_GET_SEARCH_AOI = 9
    FDT_CMD_GET_FACE_LIST = 10
    FDT_CMD_GET_NUMBER_FACES = 11
    FDT_CMD_SET_SUSPEND = 12
    FDT_CMD_SET_RESUME = 13
    FDT_CMD_GET_MAX_NUM_FACES = 14
    FDT_CMD_SET_INFO_MAX_NUM_OVL = 15
    FDT_CMD_GET_INFO_MAX_NUM_OVL = 16
    FDT_CMD_SET_INFO_OVL_LINE_WIDTH = 17
    FDT_CMD_GET_INFO_OVL_LINE_WIDTH = 18
    FDT_CMD_GET_ENABLE = 19
    FDT_CMD_GET_SUSPEND = 20
    FDT_CMD_GET_HORIZONTAL_RESOLUTION = 21
    FDT_CMD_GET_VERTICAL_RESOLUTION = 22
end

const FDT_CMD = E_FDT_CMD

@cenum E_FOCUS_CAPABILITY_FLAGS::UInt32 begin
    FOC_CAP_INVALID = 0
    FOC_CAP_AUTOFOCUS_SUPPORTED = 1
    FOC_CAP_MANUAL_SUPPORTED = 2
    FOC_CAP_GET_DISTANCE = 4
    FOC_CAP_SET_AUTOFOCUS_RANGE = 8
    FOC_CAP_AUTOFOCUS_FDT_AOI = 16
    FOC_CAP_AUTOFOCUS_ZONE = 32
end

const FOCUS_CAPABILITY_FLAGS = E_FOCUS_CAPABILITY_FLAGS

@cenum E_FOCUS_RANGE::UInt32 begin
    FOC_RANGE_NORMAL = 1
    FOC_RANGE_ALLRANGE = 2
    FOC_RANGE_MACRO = 4
end

const FOCUS_RANGE = E_FOCUS_RANGE

@cenum E_FOCUS_STATUS::UInt32 begin
    FOC_STATUS_UNDEFINED = 0
    FOC_STATUS_ERROR = 1
    FOC_STATUS_FOCUSED = 2
    FOC_STATUS_FOCUSING = 4
    FOC_STATUS_TIMEOUT = 8
    FOC_STATUS_CANCEL = 16
end

const FOCUS_STATUS = E_FOCUS_STATUS

@cenum E_FOCUS_ZONE_WEIGHT::UInt32 begin
    FOC_ZONE_WEIGHT_DISABLE = 0
    FOC_ZONE_WEIGHT_WEAK = 33
    FOC_ZONE_WEIGHT_MIDDLE = 50
    FOC_ZONE_WEIGHT_STRONG = 66
end

const FOCUS_ZONE_WEIGHT = E_FOCUS_ZONE_WEIGHT

@cenum E_FOCUS_ZONE_AOI_PRESET::UInt32 begin
    FOC_ZONE_AOI_PRESET_CENTER = 0
    FOC_ZONE_AOI_PRESET_UPPER_LEFT = 1
    FOC_ZONE_AOI_PRESET_BOTTOM_LEFT = 2
    FOC_ZONE_AOI_PRESET_UPPER_RIGHT = 4
    FOC_ZONE_AOI_PRESET_BOTTOM_RIGHT = 8
    FOC_ZONE_AOI_PRESET_UPPER_CENTER = 16
    FOC_ZONE_AOI_PRESET_BOTTOM_CENTER = 32
    FOC_ZONE_AOI_PRESET_CENTER_LEFT = 64
    FOC_ZONE_AOI_PRESET_CENTER_RIGHT = 128
end

const FOCUS_ZONE_AOI_PRESET = E_FOCUS_ZONE_AOI_PRESET

@cenum E_FOCUS_CMD::UInt32 begin
    FOC_CMD_GET_CAPABILITIES = 0
    FOC_CMD_SET_DISABLE_AUTOFOCUS = 1
    FOC_CMD_SET_ENABLE_AUTOFOCUS = 2
    FOC_CMD_GET_AUTOFOCUS_ENABLE = 3
    FOC_CMD_SET_AUTOFOCUS_RANGE = 4
    FOC_CMD_GET_AUTOFOCUS_RANGE = 5
    FOC_CMD_GET_DISTANCE = 6
    FOC_CMD_SET_MANUAL_FOCUS = 7
    FOC_CMD_GET_MANUAL_FOCUS = 8
    FOC_CMD_GET_MANUAL_FOCUS_MIN = 9
    FOC_CMD_GET_MANUAL_FOCUS_MAX = 10
    FOC_CMD_GET_MANUAL_FOCUS_INC = 11
    FOC_CMD_SET_ENABLE_AF_FDT_AOI = 12
    FOC_CMD_SET_DISABLE_AF_FDT_AOI = 13
    FOC_CMD_GET_AF_FDT_AOI_ENABLE = 14
    FOC_CMD_SET_ENABLE_AUTOFOCUS_ONCE = 15
    FOC_CMD_GET_AUTOFOCUS_STATUS = 16
    FOC_CMD_SET_AUTOFOCUS_ZONE_AOI = 17
    FOC_CMD_GET_AUTOFOCUS_ZONE_AOI = 18
    FOC_CMD_GET_AUTOFOCUS_ZONE_AOI_DEFAULT = 19
    FOC_CMD_GET_AUTOFOCUS_ZONE_POS_MIN = 20
    FOC_CMD_GET_AUTOFOCUS_ZONE_POS_MAX = 21
    FOC_CMD_GET_AUTOFOCUS_ZONE_POS_INC = 22
    FOC_CMD_GET_AUTOFOCUS_ZONE_SIZE_MIN = 23
    FOC_CMD_GET_AUTOFOCUS_ZONE_SIZE_MAX = 24
    FOC_CMD_GET_AUTOFOCUS_ZONE_SIZE_INC = 25
    FOC_CMD_SET_AUTOFOCUS_ZONE_WEIGHT = 26
    FOC_CMD_GET_AUTOFOCUS_ZONE_WEIGHT = 27
    FOC_CMD_GET_AUTOFOCUS_ZONE_WEIGHT_COUNT = 28
    FOC_CMD_GET_AUTOFOCUS_ZONE_WEIGHT_DEFAULT = 29
    FOC_CMD_SET_AUTOFOCUS_ZONE_AOI_PRESET = 30
    FOC_CMD_GET_AUTOFOCUS_ZONE_AOI_PRESET = 31
    FOC_CMD_GET_AUTOFOCUS_ZONE_AOI_PRESET_DEFAULT = 32
    FOC_CMD_GET_AUTOFOCUS_ZONE_ARBITRARY_AOI_SUPPORTED = 33
    FOC_CMD_SET_MANUAL_FOCUS_RELATIVE = 34
end

const FOCUS_CMD = E_FOCUS_CMD

@cenum E_IMGSTAB_CAPABILITY_FLAGS::UInt32 begin
    IMGSTAB_CAP_INVALID = 0
    IMGSTAB_CAP_IMAGE_STABILIZATION_SUPPORTED = 1
end

const IMGSTAB_CAPABILITY_FLAGS = E_IMGSTAB_CAPABILITY_FLAGS

@cenum E_IMGSTAB_CMD::UInt32 begin
    IMGSTAB_CMD_GET_CAPABILITIES = 0
    IMGSTAB_CMD_SET_DISABLE = 1
    IMGSTAB_CMD_SET_ENABLE = 2
    IMGSTAB_CMD_GET_ENABLE = 3
end

const IMGSTAB_CMD = E_IMGSTAB_CMD

@cenum E_SCENE_CMD::UInt32 begin
    SCENE_CMD_GET_SUPPORTED_PRESETS = 1
    SCENE_CMD_SET_PRESET = 2
    SCENE_CMD_GET_PRESET = 3
    SCENE_CMD_GET_DEFAULT_PRESET = 4
end

const SCENE_CMD = E_SCENE_CMD

@cenum E_SCENE_PRESET::UInt32 begin
    SCENE_INVALID = 0
    SCENE_SENSOR_AUTOMATIC = 1
    SCENE_SENSOR_PORTRAIT = 2
    SCENE_SENSOR_SUNNY = 4
    SCENE_SENSOR_ENTERTAINMENT = 8
    SCENE_SENSOR_NIGHT = 16
    SCENE_SENSOR_SPORTS = 64
    SCENE_SENSOR_LANDSCAPE = 128
end

const SCENE_PRESET = E_SCENE_PRESET

@cenum E_ZOOM_CMD::UInt32 begin
    ZOOM_CMD_GET_CAPABILITIES = 0
    ZOOM_CMD_DIGITAL_GET_NUM_LIST_ENTRIES = 1
    ZOOM_CMD_DIGITAL_GET_LIST = 2
    ZOOM_CMD_DIGITAL_SET_VALUE = 3
    ZOOM_CMD_DIGITAL_GET_VALUE = 4
    ZOOM_CMD_DIGITAL_GET_VALUE_RANGE = 5
    ZOOM_CMD_DIGITAL_GET_VALUE_DEFAULT = 6
end

const ZOOM_CMD = E_ZOOM_CMD

@cenum E_ZOOM_CAPABILITY_FLAGS::UInt32 begin
    ZOOM_CAP_INVALID = 0
    ZOOM_CAP_DIGITAL_ZOOM = 1
end

const ZOOM_CAPABILITY_FLAGS = E_ZOOM_CAPABILITY_FLAGS

@cenum E_SHARPNESS_CMD::UInt32 begin
    SHARPNESS_CMD_GET_CAPABILITIES = 0
    SHARPNESS_CMD_GET_VALUE = 1
    SHARPNESS_CMD_GET_MIN_VALUE = 2
    SHARPNESS_CMD_GET_MAX_VALUE = 3
    SHARPNESS_CMD_GET_INCREMENT = 4
    SHARPNESS_CMD_GET_DEFAULT_VALUE = 5
    SHARPNESS_CMD_SET_VALUE = 6
end

const SHARPNESS_CMD = E_SHARPNESS_CMD

@cenum E_SHARPNESS_CAPABILITY_FLAGS::UInt32 begin
    SHARPNESS_CAP_INVALID = 0
    SHARPNESS_CAP_SHARPNESS_SUPPORTED = 1
end

const SHARPNESS_CAPABILITY_FLAGS = E_SHARPNESS_CAPABILITY_FLAGS

@cenum E_SATURATION_CMD::UInt32 begin
    SATURATION_CMD_GET_CAPABILITIES = 0
    SATURATION_CMD_GET_VALUE = 1
    SATURATION_CMD_GET_MIN_VALUE = 2
    SATURATION_CMD_GET_MAX_VALUE = 3
    SATURATION_CMD_GET_INCREMENT = 4
    SATURATION_CMD_GET_DEFAULT_VALUE = 5
    SATURATION_CMD_SET_VALUE = 6
end

const SATURATION_CMD = E_SATURATION_CMD

@cenum E_SATURATION_CAPABILITY_FLAGS::UInt32 begin
    SATURATION_CAP_INVALID = 0
    SATURATION_CAP_SATURATION_SUPPORTED = 1
end

const SATURATION_CAPABILITY_FLAGS = E_SATURATION_CAPABILITY_FLAGS

@cenum E_TRIGGER_DEBOUNCE_MODE::UInt32 begin
    TRIGGER_DEBOUNCE_MODE_NONE = 0
    TRIGGER_DEBOUNCE_MODE_FALLING_EDGE = 1
    TRIGGER_DEBOUNCE_MODE_RISING_EDGE = 2
    TRIGGER_DEBOUNCE_MODE_BOTH_EDGES = 4
    TRIGGER_DEBOUNCE_MODE_AUTOMATIC = 8
end

const TRIGGER_DEBOUNCE_MODE = E_TRIGGER_DEBOUNCE_MODE

@cenum E_TRIGGER_DEBOUNCE_CMD::UInt32 begin
    TRIGGER_DEBOUNCE_CMD_SET_MODE = 0
    TRIGGER_DEBOUNCE_CMD_SET_DELAY_TIME = 1
    TRIGGER_DEBOUNCE_CMD_GET_SUPPORTED_MODES = 2
    TRIGGER_DEBOUNCE_CMD_GET_MODE = 3
    TRIGGER_DEBOUNCE_CMD_GET_DELAY_TIME = 4
    TRIGGER_DEBOUNCE_CMD_GET_DELAY_TIME_MIN = 5
    TRIGGER_DEBOUNCE_CMD_GET_DELAY_TIME_MAX = 6
    TRIGGER_DEBOUNCE_CMD_GET_DELAY_TIME_INC = 7
    TRIGGER_DEBOUNCE_CMD_GET_MODE_DEFAULT = 8
    TRIGGER_DEBOUNCE_CMD_GET_DELAY_TIME_DEFAULT = 9
end

const TRIGGER_DEBOUNCE_CMD = E_TRIGGER_DEBOUNCE_CMD

@cenum E_RGB_COLOR_MODELS::UInt32 begin
    RGB_COLOR_MODEL_SRGB_D50 = 1
    RGB_COLOR_MODEL_SRGB_D65 = 2
    RGB_COLOR_MODEL_CIE_RGB_E = 4
    RGB_COLOR_MODEL_ECI_RGB_D50 = 8
    RGB_COLOR_MODEL_ADOBE_RGB_D65 = 16
end

const RGB_COLOR_MODELS = E_RGB_COLOR_MODELS

@cenum E_LENS_SHADING_MODELS::UInt32 begin
    LSC_MODEL_AGL = 1
    LSC_MODEL_TL84 = 2
    LSC_MODEL_D50 = 4
    LSC_MODEL_D65 = 8
end

const LENS_SHADING_MODELS = E_LENS_SHADING_MODELS

@cenum E_COLOR_TEMPERATURE_CMD::UInt32 begin
    COLOR_TEMPERATURE_CMD_SET_TEMPERATURE = 0
    COLOR_TEMPERATURE_CMD_SET_RGB_COLOR_MODEL = 1
    COLOR_TEMPERATURE_CMD_GET_SUPPORTED_RGB_COLOR_MODELS = 2
    COLOR_TEMPERATURE_CMD_GET_TEMPERATURE = 3
    COLOR_TEMPERATURE_CMD_GET_RGB_COLOR_MODEL = 4
    COLOR_TEMPERATURE_CMD_GET_TEMPERATURE_MIN = 5
    COLOR_TEMPERATURE_CMD_GET_TEMPERATURE_MAX = 6
    COLOR_TEMPERATURE_CMD_GET_TEMPERATURE_INC = 7
    COLOR_TEMPERATURE_CMD_GET_TEMPERATURE_DEFAULT = 8
    COLOR_TEMPERATURE_CMD_GET_RGB_COLOR_MODEL_DEFAULT = 9
    COLOR_TEMPERATURE_CMD_SET_LENS_SHADING_MODEL = 10
    COLOR_TEMPERATURE_CMD_GET_LENS_SHADING_MODEL = 11
    COLOR_TEMPERATURE_CMD_GET_LENS_SHADING_MODEL_SUPPORTED = 12
    COLOR_TEMPERATURE_CMD_GET_LENS_SHADING_MODEL_DEFAULT = 13
end

const COLOR_TEMPERATURE_CMD = E_COLOR_TEMPERATURE_CMD

struct _OPENGL_DISPLAY
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{_OPENGL_DISPLAY}, f::Symbol)
    f === :nWindowID && return Ptr{Cint}(x + 0)
    f === :pDisplay && return Ptr{Ptr{Cvoid}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_OPENGL_DISPLAY, f::Symbol)
    r = Ref{_OPENGL_DISPLAY}(x)
    ptr = Base.unsafe_convert(Ptr{_OPENGL_DISPLAY}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_OPENGL_DISPLAY}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const OPENGL_DISPLAY = _OPENGL_DISPLAY

struct IS_POINT_2D
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{IS_POINT_2D}, f::Symbol)
    f === :s32X && return Ptr{INT}(x + 0)
    f === :s32Y && return Ptr{INT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::IS_POINT_2D, f::Symbol)
    r = Ref{IS_POINT_2D}(x)
    ptr = Base.unsafe_convert(Ptr{IS_POINT_2D}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_POINT_2D}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_SIZE_2D
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{IS_SIZE_2D}, f::Symbol)
    f === :s32Width && return Ptr{INT}(x + 0)
    f === :s32Height && return Ptr{INT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::IS_SIZE_2D, f::Symbol)
    r = Ref{IS_SIZE_2D}(x)
    ptr = Base.unsafe_convert(Ptr{IS_SIZE_2D}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_SIZE_2D}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

mutable struct IS_RECT
    data::NTuple{16, UInt8}
    IS_RECT() = new(ntuple(_ -> UInt8(0), 16))
end

function Base.getproperty(x::Ptr{IS_RECT}, f::Symbol)
    f === :s32X && return Ptr{INT}(x + 0)
    f === :s32Y && return Ptr{INT}(x + 4)
    f === :s32Width && return Ptr{INT}(x + 8)
    f === :s32Height && return Ptr{INT}(x + 12)
    return getfield(x, f)
end

# function Base.getproperty(x::IS_RECT, f::Symbol)
#     r = Ref{IS_RECT}(x)
#     ptr = Base.unsafe_convert(Ptr{IS_RECT}, r)
#     fptr = getproperty(ptr, f)
#     GC.@preserve r unsafe_load(fptr)
# end

function Base.getproperty(x::IS_RECT, f::Symbol)
    ptr = Ptr{IS_RECT}(pointer_from_objref(x))
    fptr = getproperty(ptr, f)
    return unsafe_load(fptr)
end


function Base.setproperty!(x::Ptr{IS_RECT}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.setproperty!(x::IS_RECT, f::Symbol, v)
    r = Ref{IS_RECT}(x)
    ptr = Base.unsafe_convert(Ptr{IS_RECT}, r)
    setproperty!(ptr, f, v)
end

struct AOI_SEQUENCE_PARAMS
    data::NTuple{112, UInt8}
end

function Base.getproperty(x::Ptr{AOI_SEQUENCE_PARAMS}, f::Symbol)
    f === :s32AOIIndex && return Ptr{INT}(x + 0)
    f === :s32NumberOfCycleRepetitions && return Ptr{INT}(x + 4)
    f === :s32X && return Ptr{INT}(x + 8)
    f === :s32Y && return Ptr{INT}(x + 12)
    f === :dblExposure && return Ptr{Cdouble}(x + 16)
    f === :s32Gain && return Ptr{INT}(x + 24)
    f === :s32BinningMode && return Ptr{INT}(x + 28)
    f === :s32SubsamplingMode && return Ptr{INT}(x + 32)
    f === :s32DetachImageParameters && return Ptr{INT}(x + 36)
    f === :dblScalerFactor && return Ptr{Cdouble}(x + 40)
    f === :byReserved && return Ptr{NTuple{64, BYTE}}(x + 48)
    return getfield(x, f)
end

function Base.getproperty(x::AOI_SEQUENCE_PARAMS, f::Symbol)
    r = Ref{AOI_SEQUENCE_PARAMS}(x)
    ptr = Base.unsafe_convert(Ptr{AOI_SEQUENCE_PARAMS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{AOI_SEQUENCE_PARAMS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct S_RANGE_OF_VALUES_U32
    data::NTuple{20, UInt8}
end

function Base.getproperty(x::Ptr{S_RANGE_OF_VALUES_U32}, f::Symbol)
    f === :u32Minimum && return Ptr{UINT}(x + 0)
    f === :u32Maximum && return Ptr{UINT}(x + 4)
    f === :u32Increment && return Ptr{UINT}(x + 8)
    f === :u32Default && return Ptr{UINT}(x + 12)
    f === :u32Infinite && return Ptr{UINT}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::S_RANGE_OF_VALUES_U32, f::Symbol)
    r = Ref{S_RANGE_OF_VALUES_U32}(x)
    ptr = Base.unsafe_convert(Ptr{S_RANGE_OF_VALUES_U32}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_RANGE_OF_VALUES_U32}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const RANGE_OF_VALUES_U32 = S_RANGE_OF_VALUES_U32

@cenum E_TRANSFER_CAPABILITY_FLAGS::UInt32 begin
    TRANSFER_CAP_IMAGEDELAY = 1
    TRANSFER_CAP_PACKETINTERVAL = 32
end

const TRANSFER_CAPABILITY_FLAGS = E_TRANSFER_CAPABILITY_FLAGS

@cenum E_TRANSFER_CMD::UInt32 begin
    TRANSFER_CMD_QUERY_CAPABILITIES = 0
    TRANSFER_CMD_SET_IMAGEDELAY_US = 1000
    TRANSFER_CMD_SET_PACKETINTERVAL_US = 1005
    TRANSFER_CMD_GET_IMAGEDELAY_US = 2000
    TRANSFER_CMD_GET_PACKETINTERVAL_US = 2005
    TRANSFER_CMD_GETRANGE_IMAGEDELAY_US = 3000
    TRANSFER_CMD_GETRANGE_PACKETINTERVAL_US = 3005
    TRANSFER_CMD_SET_IMAGE_DESTINATION = 5000
    TRANSFER_CMD_GET_IMAGE_DESTINATION = 5001
    TRANSFER_CMD_GET_IMAGE_DESTINATION_CAPABILITIES = 5002
end

const TRANSFER_CMD = E_TRANSFER_CMD

@cenum E_TRANSFER_TARGET::UInt32 begin
    IS_TRANSFER_DESTINATION_DEVICE_MEMORY = 1
    IS_TRANSFER_DESTINATION_USER_MEMORY = 2
end

const TRANSFER_TARGET = E_TRANSFER_TARGET

struct S_IS_BOOTBOOST_IDLIST
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_BOOTBOOST_IDLIST}, f::Symbol)
    f === :u32NumberOfEntries && return Ptr{DWORD}(x + 0)
    f === :aList && return Ptr{NTuple{1, IS_BOOTBOOST_ID}}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_BOOTBOOST_IDLIST, f::Symbol)
    r = Ref{S_IS_BOOTBOOST_IDLIST}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_BOOTBOOST_IDLIST}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_BOOTBOOST_IDLIST}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_BOOTBOOST_IDLIST = S_IS_BOOTBOOST_IDLIST

@cenum E_IS_BOOTBOOST_CMD::UInt32 begin
    IS_BOOTBOOST_CMD_ENABLE = 65537
    IS_BOOTBOOST_CMD_ENABLE_AND_WAIT = 65793
    IS_BOOTBOOST_CMD_DISABLE = 65553
    IS_BOOTBOOST_CMD_DISABLE_AND_WAIT = 65809
    IS_BOOTBOOST_CMD_WAIT = 65792
    IS_BOOTBOOST_CMD_GET_ENABLED = 536936481
    IS_BOOTBOOST_CMD_ADD_ID = 269484033
    IS_BOOTBOOST_CMD_SET_IDLIST = 269484037
    IS_BOOTBOOST_CMD_REMOVE_ID = 269484049
    IS_BOOTBOOST_CMD_CLEAR_IDLIST = 1048597
    IS_BOOTBOOST_CMD_GET_IDLIST = 806354977
    IS_BOOTBOOST_CMD_GET_IDLIST_SIZE = 537919522
end

const IS_BOOTBOOST_CMD = E_IS_BOOTBOOST_CMD

@cenum E_DEVICE_FEATURE_CMD::UInt32 begin
    IS_DEVICE_FEATURE_CMD_GET_SUPPORTED_FEATURES = 1
    IS_DEVICE_FEATURE_CMD_SET_LINESCAN_MODE = 2
    IS_DEVICE_FEATURE_CMD_GET_LINESCAN_MODE = 3
    IS_DEVICE_FEATURE_CMD_SET_LINESCAN_NUMBER = 4
    IS_DEVICE_FEATURE_CMD_GET_LINESCAN_NUMBER = 5
    IS_DEVICE_FEATURE_CMD_SET_SHUTTER_MODE = 6
    IS_DEVICE_FEATURE_CMD_GET_SHUTTER_MODE = 7
    IS_DEVICE_FEATURE_CMD_SET_PREFER_XS_HS_MODE = 8
    IS_DEVICE_FEATURE_CMD_GET_PREFER_XS_HS_MODE = 9
    IS_DEVICE_FEATURE_CMD_GET_DEFAULT_PREFER_XS_HS_MODE = 10
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_DEFAULT = 11
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE = 12
    IS_DEVICE_FEATURE_CMD_SET_LOG_MODE = 13
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_VALUE_DEFAULT = 14
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_VALUE_RANGE = 15
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_VALUE = 16
    IS_DEVICE_FEATURE_CMD_SET_LOG_MODE_MANUAL_VALUE = 17
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_GAIN_DEFAULT = 18
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_GAIN_RANGE = 19
    IS_DEVICE_FEATURE_CMD_GET_LOG_MODE_MANUAL_GAIN = 20
    IS_DEVICE_FEATURE_CMD_SET_LOG_MODE_MANUAL_GAIN = 21
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_MODE_DEFAULT = 22
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_MODE = 23
    IS_DEVICE_FEATURE_CMD_SET_VERTICAL_AOI_MERGE_MODE = 24
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_POSITION_DEFAULT = 25
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_POSITION_RANGE = 26
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_POSITION = 27
    IS_DEVICE_FEATURE_CMD_SET_VERTICAL_AOI_MERGE_POSITION = 28
    IS_DEVICE_FEATURE_CMD_GET_FPN_CORRECTION_MODE_DEFAULT = 29
    IS_DEVICE_FEATURE_CMD_GET_FPN_CORRECTION_MODE = 30
    IS_DEVICE_FEATURE_CMD_SET_FPN_CORRECTION_MODE = 31
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_SOURCE_GAIN_RANGE = 32
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_SOURCE_GAIN_DEFAULT = 33
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_SOURCE_GAIN = 34
    IS_DEVICE_FEATURE_CMD_SET_SENSOR_SOURCE_GAIN = 35
    IS_DEVICE_FEATURE_CMD_GET_BLACK_REFERENCE_MODE_DEFAULT = 36
    IS_DEVICE_FEATURE_CMD_GET_BLACK_REFERENCE_MODE = 37
    IS_DEVICE_FEATURE_CMD_SET_BLACK_REFERENCE_MODE = 38
    IS_DEVICE_FEATURE_CMD_GET_ALLOW_RAW_WITH_LUT = 39
    IS_DEVICE_FEATURE_CMD_SET_ALLOW_RAW_WITH_LUT = 40
    IS_DEVICE_FEATURE_CMD_GET_SUPPORTED_SENSOR_BIT_DEPTHS = 41
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_BIT_DEPTH_DEFAULT = 42
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_BIT_DEPTH = 43
    IS_DEVICE_FEATURE_CMD_SET_SENSOR_BIT_DEPTH = 44
    IS_DEVICE_FEATURE_CMD_GET_TEMPERATURE = 45
    IS_DEVICE_FEATURE_CMD_GET_JPEG_COMPRESSION = 46
    IS_DEVICE_FEATURE_CMD_SET_JPEG_COMPRESSION = 47
    IS_DEVICE_FEATURE_CMD_GET_JPEG_COMPRESSION_DEFAULT = 48
    IS_DEVICE_FEATURE_CMD_GET_JPEG_COMPRESSION_RANGE = 49
    IS_DEVICE_FEATURE_CMD_GET_NOISE_REDUCTION_MODE = 50
    IS_DEVICE_FEATURE_CMD_SET_NOISE_REDUCTION_MODE = 51
    IS_DEVICE_FEATURE_CMD_GET_NOISE_REDUCTION_MODE_DEFAULT = 52
    IS_DEVICE_FEATURE_CMD_GET_TIMESTAMP_CONFIGURATION = 53
    IS_DEVICE_FEATURE_CMD_SET_TIMESTAMP_CONFIGURATION = 54
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_HEIGHT_DEFAULT = 55
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_HEIGHT_NUMBER = 56
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_HEIGHT_LIST = 57
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_HEIGHT = 58
    IS_DEVICE_FEATURE_CMD_SET_VERTICAL_AOI_MERGE_HEIGHT = 59
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_ADDITIONAL_POSITION_DEFAULT = 60
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_ADDITIONAL_POSITION_RANGE = 61
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_ADDITIONAL_POSITION = 62
    IS_DEVICE_FEATURE_CMD_SET_VERTICAL_AOI_MERGE_ADDITIONAL_POSITION = 63
    IS_DEVICE_FEATURE_CMD_GET_SENSOR_TEMPERATURE_NUMERICAL_VALUE = 64
    IS_DEVICE_FEATURE_CMD_SET_IMAGE_EFFECT = 65
    IS_DEVICE_FEATURE_CMD_GET_IMAGE_EFFECT = 66
    IS_DEVICE_FEATURE_CMD_GET_IMAGE_EFFECT_DEFAULT = 67
    IS_DEVICE_FEATURE_CMD_GET_EXTENDED_PIXELCLOCK_RANGE_ENABLE_DEFAULT = 68
    IS_DEVICE_FEATURE_CMD_GET_EXTENDED_PIXELCLOCK_RANGE_ENABLE = 69
    IS_DEVICE_FEATURE_CMD_SET_EXTENDED_PIXELCLOCK_RANGE_ENABLE = 70
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_GET_SCOPE = 71
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_GET_PARAMS = 72
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_SET_PARAMS = 73
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_GET_MODE_DEFAULT = 74
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_GET_MODE = 75
    IS_DEVICE_FEATURE_CMD_MULTI_INTEGRATION_SET_MODE = 76
    IS_DEVICE_FEATURE_CMD_SET_I2C_TARGET = 77
    IS_DEVICE_FEATURE_CMD_SET_WIDE_DYNAMIC_RANGE_MODE = 78
    IS_DEVICE_FEATURE_CMD_GET_WIDE_DYNAMIC_RANGE_MODE = 79
    IS_DEVICE_FEATURE_CMD_GET_WIDE_DYNAMIC_RANGE_MODE_DEFAULT = 80
    IS_DEVICE_FEATURE_CMD_GET_SUPPORTED_BLACK_REFERENCE_MODES = 81
    IS_DEVICE_FEATURE_CMD_SET_LEVEL_CONTROLLED_TRIGGER_INPUT_MODE = 82
    IS_DEVICE_FEATURE_CMD_GET_LEVEL_CONTROLLED_TRIGGER_INPUT_MODE = 83
    IS_DEVICE_FEATURE_CMD_GET_LEVEL_CONTROLLED_TRIGGER_INPUT_MODE_DEFAULT = 84
    IS_DEVICE_FEATURE_CMD_GET_VERTICAL_AOI_MERGE_MODE_SUPPORTED_LINE_MODES = 85
    IS_DEVICE_FEATURE_CMD_SET_REPEATED_START_CONDITION_I2C = 86
    IS_DEVICE_FEATURE_CMD_GET_REPEATED_START_CONDITION_I2C = 87
    IS_DEVICE_FEATURE_CMD_GET_REPEATED_START_CONDITION_I2C_DEFAULT = 88
    IS_DEVICE_FEATURE_CMD_GET_TEMPERATURE_STATUS = 89
    IS_DEVICE_FEATURE_CMD_GET_MEMORY_MODE_ENABLE = 90
    IS_DEVICE_FEATURE_CMD_SET_MEMORY_MODE_ENABLE = 91
    IS_DEVICE_FEATURE_CMD_GET_MEMORY_MODE_ENABLE_DEFAULT = 92
    IS_DEVICE_FEATURE_CMD_93 = 93
    IS_DEVICE_FEATURE_CMD_94 = 94
    IS_DEVICE_FEATURE_CMD_95 = 95
    IS_DEVICE_FEATURE_CMD_96 = 96
    IS_DEVICE_FEATURE_CMD_GET_SUPPORTED_EXTERNAL_INTERFACES = 97
    IS_DEVICE_FEATURE_CMD_GET_EXTERNAL_INTERFACE = 98
    IS_DEVICE_FEATURE_CMD_SET_EXTERNAL_INTERFACE = 99
    IS_DEVICE_FEATURE_CMD_EXTENDED_AWB_LIMITS_GET = 100
    IS_DEVICE_FEATURE_CMD_EXTENDED_AWB_LIMITS_SET = 101
    IS_DEVICE_FEATURE_CMD_GET_MEMORY_MODE_ENABLE_SUPPORTED = 102
end

const DEVICE_FEATURE_CMD = E_DEVICE_FEATURE_CMD

@cenum E_DEVICE_FEATURE_MODE_CAPS::UInt32 begin
    IS_DEVICE_FEATURE_CAP_SHUTTER_MODE_ROLLING = 1
    IS_DEVICE_FEATURE_CAP_SHUTTER_MODE_GLOBAL = 2
    IS_DEVICE_FEATURE_CAP_LINESCAN_MODE_FAST = 4
    IS_DEVICE_FEATURE_CAP_LINESCAN_NUMBER = 8
    IS_DEVICE_FEATURE_CAP_PREFER_XS_HS_MODE = 16
    IS_DEVICE_FEATURE_CAP_LOG_MODE = 32
    IS_DEVICE_FEATURE_CAP_SHUTTER_MODE_ROLLING_GLOBAL_START = 64
    IS_DEVICE_FEATURE_CAP_SHUTTER_MODE_GLOBAL_ALTERNATIVE_TIMING = 128
    IS_DEVICE_FEATURE_CAP_VERTICAL_AOI_MERGE = 256
    IS_DEVICE_FEATURE_CAP_FPN_CORRECTION = 512
    IS_DEVICE_FEATURE_CAP_SENSOR_SOURCE_GAIN = 1024
    IS_DEVICE_FEATURE_CAP_BLACK_REFERENCE = 2048
    IS_DEVICE_FEATURE_CAP_SENSOR_BIT_DEPTH = 4096
    IS_DEVICE_FEATURE_CAP_TEMPERATURE = 8192
    IS_DEVICE_FEATURE_CAP_JPEG_COMPRESSION = 16384
    IS_DEVICE_FEATURE_CAP_NOISE_REDUCTION = 32768
    IS_DEVICE_FEATURE_CAP_TIMESTAMP_CONFIGURATION = 65536
    IS_DEVICE_FEATURE_CAP_IMAGE_EFFECT = 131072
    IS_DEVICE_FEATURE_CAP_EXTENDED_PIXELCLOCK_RANGE = 262144
    IS_DEVICE_FEATURE_CAP_MULTI_INTEGRATION = 524288
    IS_DEVICE_FEATURE_CAP_WIDE_DYNAMIC_RANGE = 1048576
    IS_DEVICE_FEATURE_CAP_LEVEL_CONTROLLED_TRIGGER = 2097152
    IS_DEVICE_FEATURE_CAP_REPEATED_START_CONDITION_I2C = 4194304
    IS_DEVICE_FEATURE_CAP_TEMPERATURE_STATUS = 8388608
    IS_DEVICE_FEATURE_CAP_MEMORY_MODE = 16777216
    IS_DEVICE_FEATURE_CAP_SEND_EXTERNAL_INTERFACE_DATA = 33554432
end

const DEVICE_FEATURE_MODE_CAPS = E_DEVICE_FEATURE_MODE_CAPS

@cenum E_IS_TEMPERATURE_CONTROL_STATUS::UInt32 begin
    TEMPERATURE_CONTROL_STATUS_NORMAL = 0
    TEMPERATURE_CONTROL_STATUS_WARNING = 1
    TEMPERATURE_CONTROL_STATUS_CRITICAL = 2
end

const IS_TEMPERATURE_CONTROL_STATUS = E_IS_TEMPERATURE_CONTROL_STATUS

@cenum E_NOISE_REDUCTION_MODES::UInt32 begin
    IS_NOISE_REDUCTION_OFF = 0
    IS_NOISE_REDUCTION_ADAPTIVE = 1
end

const NOISE_REDUCTION_MODES = E_NOISE_REDUCTION_MODES

@cenum E_LOG_MODES::UInt32 begin
    IS_LOG_MODE_FACTORY_DEFAULT = 0
    IS_LOG_MODE_OFF = 1
    IS_LOG_MODE_MANUAL = 2
    IS_LOG_MODE_AUTO = 3
end

const LOG_MODES = E_LOG_MODES

@cenum E_VERTICAL_AOI_MERGE_MODES::UInt32 begin
    IS_VERTICAL_AOI_MERGE_MODE_OFF = 0
    IS_VERTICAL_AOI_MERGE_MODE_FREERUN = 1
    IS_VERTICAL_AOI_MERGE_MODE_TRIGGERED_SOFTWARE = 2
    IS_VERTICAL_AOI_MERGE_MODE_TRIGGERED_FALLING_GPIO1 = 3
    IS_VERTICAL_AOI_MERGE_MODE_TRIGGERED_RISING_GPIO1 = 4
    IS_VERTICAL_AOI_MERGE_MODE_TRIGGERED_FALLING_GPIO2 = 5
    IS_VERTICAL_AOI_MERGE_MODE_TRIGGERED_RISING_GPIO2 = 6
end

const VERTICAL_AOI_MERGE_MODES = E_VERTICAL_AOI_MERGE_MODES

@cenum E_VERTICAL_AOI_MERGE_MODE_LINE_TRIGGER::UInt32 begin
    IS_VERTICAL_AOI_MERGE_MODE_LINE_FREERUN = 1
    IS_VERTICAL_AOI_MERGE_MODE_LINE_SOFTWARE_TRIGGER = 2
    IS_VERTICAL_AOI_MERGE_MODE_LINE_GPIO_TRIGGER = 4
end

const VERTICAL_AOI_MERGE_MODE_LINE_TRIGGER = E_VERTICAL_AOI_MERGE_MODE_LINE_TRIGGER

@cenum E_LEVEL_CONTROLLED_TRIGGER_INPUT_MODES::UInt32 begin
    IS_LEVEL_CONTROLLED_TRIGGER_INPUT_OFF = 0
    IS_LEVEL_CONTROLLED_TRIGGER_INPUT_ON = 1
end

const LEVEL_CONTROLLED_TRIGGER_INPUT_MODES = E_LEVEL_CONTROLLED_TRIGGER_INPUT_MODES

@cenum E_FPN_CORRECTION_MODES::UInt32 begin
    IS_FPN_CORRECTION_MODE_OFF = 0
    IS_FPN_CORRECTION_MODE_HARDWARE = 1
end

const FPN_CORRECTION_MODES = E_FPN_CORRECTION_MODES

@cenum E_BLACK_REFERENCE_MODES::UInt32 begin
    IS_BLACK_REFERENCE_MODE_OFF = 0
    IS_BLACK_REFERENCE_MODE_COLUMNS_LEFT = 1
    IS_BLACK_REFERENCE_MODE_ROWS_TOP = 2
end

const BLACK_REFERENCE_MODES = E_BLACK_REFERENCE_MODES

@cenum E_SENSOR_BIT_DEPTH::UInt32 begin
    IS_SENSOR_BIT_DEPTH_AUTO = 0
    IS_SENSOR_BIT_DEPTH_8_BIT = 1
    IS_SENSOR_BIT_DEPTH_10_BIT = 2
    IS_SENSOR_BIT_DEPTH_12_BIT = 4
end

const SENSOR_BIT_DEPTH = E_SENSOR_BIT_DEPTH

@cenum E_TIMESTAMP_CONFIGURATION_MODE::UInt32 begin
    IS_RESET_TIMESTAMP_ONCE = 1
end

const TIMESTAMP_CONFIGURATION_MODE = E_TIMESTAMP_CONFIGURATION_MODE

@cenum E_TIMESTAMP_CONFIGURATION_PIN::UInt32 begin
    TIMESTAMP_CONFIGURATION_PIN_NONE = 0
    TIMESTAMP_CONFIGURATION_PIN_TRIGGER = 1
    TIMESTAMP_CONFIGURATION_PIN_GPIO_1 = 2
    TIMESTAMP_CONFIGURATION_PIN_GPIO_2 = 3
end

const TIMESTAMP_CONFIGURATION_PIN = E_TIMESTAMP_CONFIGURATION_PIN

@cenum E_TIMESTAMP_CONFIGURATION_EDGE::UInt32 begin
    TIMESTAMP_CONFIGURATION_EDGE_FALLING = 0
    TIMESTAMP_CONFIGURATION_EDGE_RISING = 1
end

const TIMESTAMP_CONFIGURATION_EDGE = E_TIMESTAMP_CONFIGURATION_EDGE

struct S_IS_TIMESTAMP_CONFIGURATION
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_TIMESTAMP_CONFIGURATION}, f::Symbol)
    f === :s32Mode && return Ptr{INT}(x + 0)
    f === :s32Pin && return Ptr{INT}(x + 4)
    f === :s32Edge && return Ptr{INT}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_TIMESTAMP_CONFIGURATION, f::Symbol)
    r = Ref{S_IS_TIMESTAMP_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_TIMESTAMP_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_TIMESTAMP_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_TIMESTAMP_CONFIGURATION = S_IS_TIMESTAMP_CONFIGURATION

@cenum E_IMAGE_EFFECT_MODE::UInt32 begin
    IS_IMAGE_EFFECT_DISABLE = 0
    IS_IMAGE_EFFECT_SEPIA = 1
    IS_IMAGE_EFFECT_MONOCHROME = 2
    IS_IMAGE_EFFECT_NEGATIVE = 3
    IS_IMAGE_EFFECT_CROSSHAIRS = 4
end

const IMAGE_EFFECT_MODE = E_IMAGE_EFFECT_MODE

@cenum S_IS_EXTENDED_PIXELCLOCK_RANGE::UInt32 begin
    EXTENDED_PIXELCLOCK_RANGE_OFF = 0
    EXTENDED_PIXELCLOCK_RANGE_ON = 1
end

const IS_EXTENDED_PIXELCLOCK_RANGE = S_IS_EXTENDED_PIXELCLOCK_RANGE

@cenum E_IS_MULTI_INTEGRATION_MODE::UInt32 begin
    MULTI_INTEGRATION_MODE_OFF = 0
    MULTI_INTEGRATION_MODE_SOFTWARE = 1
    MULTI_INTEGRATION_MODE_GPIO1 = 2
    MULTI_INTEGRATION_MODE_GPIO2 = 3
end

const IS_MULTI_INTEGRATION_MODE = E_IS_MULTI_INTEGRATION_MODE

struct S_IS_MULTI_INTEGRATION_CYCLES
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_MULTI_INTEGRATION_CYCLES}, f::Symbol)
    f === :dblIntegration_ms && return Ptr{Cdouble}(x + 0)
    f === :dblPause_ms && return Ptr{Cdouble}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_MULTI_INTEGRATION_CYCLES, f::Symbol)
    r = Ref{S_IS_MULTI_INTEGRATION_CYCLES}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_MULTI_INTEGRATION_CYCLES}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_MULTI_INTEGRATION_CYCLES}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_MULTI_INTEGRATION_CYCLES = S_IS_MULTI_INTEGRATION_CYCLES

struct S_IS_MULTI_INTEGRATION_SCOPE
    data::NTuple{128, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_MULTI_INTEGRATION_SCOPE}, f::Symbol)
    f === :dblMinIntegration_ms && return Ptr{Cdouble}(x + 0)
    f === :dblMaxIntegration_ms && return Ptr{Cdouble}(x + 8)
    f === :dblIntegrationGranularity_ms && return Ptr{Cdouble}(x + 16)
    f === :dblMinPause_ms && return Ptr{Cdouble}(x + 24)
    f === :dblMaxPause_ms && return Ptr{Cdouble}(x + 32)
    f === :dblPauseGranularity_ms && return Ptr{Cdouble}(x + 40)
    f === :dblMinCycle_ms && return Ptr{Cdouble}(x + 48)
    f === :dblMaxCycle_ms && return Ptr{Cdouble}(x + 56)
    f === :dblCycleGranularity_ms && return Ptr{Cdouble}(x + 64)
    f === :dblMinTriggerCycle_ms && return Ptr{Cdouble}(x + 72)
    f === :dblMinTriggerDuration_ms && return Ptr{Cdouble}(x + 80)
    f === :nMinNumberOfCycles && return Ptr{UINT}(x + 88)
    f === :nMaxNumberOfCycles && return Ptr{UINT}(x + 92)
    f === :m_bReserved && return Ptr{NTuple{32, BYTE}}(x + 96)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_MULTI_INTEGRATION_SCOPE, f::Symbol)
    r = Ref{S_IS_MULTI_INTEGRATION_SCOPE}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_MULTI_INTEGRATION_SCOPE}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_MULTI_INTEGRATION_SCOPE}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_MULTI_INTEGRATION_SCOPE = S_IS_MULTI_INTEGRATION_SCOPE

@cenum E_IS_I2C_TARGET::UInt32 begin
    I2C_TARGET_DEFAULT = 0
    I2C_TARGET_SENSOR_1 = 1
    I2C_TARGET_SENSOR_2 = 2
    I2C_TARGET_LOGIC_BOARD = 4
end

const IS_I2C_TARGET = E_IS_I2C_TARGET

@cenum E_IS_MEMORY_MODE::UInt32 begin
    IS_MEMORY_MODE_OFF = 0
    IS_MEMORY_MODE_ON = 1
end

const IS_MEMORY_MODE = E_IS_MEMORY_MODE

@cenum E_IS_EXTERNAL_INTERFACE_TYPE::UInt32 begin
    IS_EXTERNAL_INTERFACE_TYPE_NONE = 0
    IS_EXTERNAL_INTERFACE_TYPE_I2C = 1
end

const IS_EXTERNAL_INTERFACE_TYPE = E_IS_EXTERNAL_INTERFACE_TYPE

@cenum E_IS_EXTERNAL_INTERFACE_REGISTER_TYPE::UInt32 begin
    IS_EXTERNAL_INTERFACE_REGISTER_TYPE_8BIT = 0
    IS_EXTERNAL_INTERFACE_REGISTER_TYPE_16BIT = 1
    IS_EXTERNAL_INTERFACE_REGISTER_TYPE_NONE = 2
end

const IS_EXTERNAL_INTERFACE_REGISTER_TYPE = E_IS_EXTERNAL_INTERFACE_REGISTER_TYPE

@cenum E_IS_EXTERNAL_INTERFACE_EVENT::UInt32 begin
    IS_EXTERNAL_INTERFACE_EVENT_RISING_VSYNC = 0
    IS_EXTERNAL_INTERFACE_EVENT_FALLING_VSYNC = 1
end

const IS_EXTERNAL_INTERFACE_EVENT = E_IS_EXTERNAL_INTERFACE_EVENT

@cenum E_IS_EXTERNAL_INTERFACE_DATA::UInt32 begin
    IS_EXTERNAL_INTERFACE_DATA_USER = 0
    IS_EXTERNAL_INTERFACE_DATA_TIMESTAMP_FULL = 1
    IS_EXTERNAL_INTERFACE_DATA_TIMESTAMP_LOWBYTE = 2
    IS_EXTERNAL_INTERFACE_DATA_TIMESTAMP_HIGHBYTE = 3
end

const IS_EXTERNAL_INTERFACE_DATA = E_IS_EXTERNAL_INTERFACE_DATA

struct S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION}, f::Symbol)
    f === :bySlaveAddress && return Ptr{BYTE}(x + 0)
    f === :wRegisterAddress && return Ptr{WORD}(x + 1)
    f === :byRegisterAddressType && return Ptr{BYTE}(x + 3)
    f === :byAckPolling && return Ptr{BYTE}(x + 4)
    f === :byReserved && return Ptr{NTuple{11, BYTE}}(x + 5)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION, f::Symbol)
    r = Ref{S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION = S_IS_EXTERNAL_INTERFACE_I2C_CONFIGURATION

struct S_IS_EXTERNAL_INTERFACE_CONFIGURATION
    data::NTuple{22, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_EXTERNAL_INTERFACE_CONFIGURATION}, f::Symbol)
    f === :wInterfaceType && return Ptr{WORD}(x + 0)
    f === :sInterfaceConfiguration && return Ptr{NTuple{16, BYTE}}(x + 2)
    f === :wSendEvent && return Ptr{WORD}(x + 18)
    f === :wDataSelection && return Ptr{WORD}(x + 20)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_EXTERNAL_INTERFACE_CONFIGURATION, f::Symbol)
    r = Ref{S_IS_EXTERNAL_INTERFACE_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_EXTERNAL_INTERFACE_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_EXTERNAL_INTERFACE_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_EXTERNAL_INTERFACE_CONFIGURATION = S_IS_EXTERNAL_INTERFACE_CONFIGURATION

@cenum E_EXPOSURE_CMD::UInt32 begin
    IS_EXPOSURE_CMD_GET_CAPS = 1
    IS_EXPOSURE_CMD_GET_EXPOSURE_DEFAULT = 2
    IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MIN = 3
    IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MAX = 4
    IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_INC = 5
    IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE = 6
    IS_EXPOSURE_CMD_GET_EXPOSURE = 7
    IS_EXPOSURE_CMD_GET_FINE_INCREMENT_RANGE_MIN = 8
    IS_EXPOSURE_CMD_GET_FINE_INCREMENT_RANGE_MAX = 9
    IS_EXPOSURE_CMD_GET_FINE_INCREMENT_RANGE_INC = 10
    IS_EXPOSURE_CMD_GET_FINE_INCREMENT_RANGE = 11
    IS_EXPOSURE_CMD_SET_EXPOSURE = 12
    IS_EXPOSURE_CMD_GET_LONG_EXPOSURE_RANGE_MIN = 13
    IS_EXPOSURE_CMD_GET_LONG_EXPOSURE_RANGE_MAX = 14
    IS_EXPOSURE_CMD_GET_LONG_EXPOSURE_RANGE_INC = 15
    IS_EXPOSURE_CMD_GET_LONG_EXPOSURE_RANGE = 16
    IS_EXPOSURE_CMD_GET_LONG_EXPOSURE_ENABLE = 17
    IS_EXPOSURE_CMD_SET_LONG_EXPOSURE_ENABLE = 18
    IS_EXPOSURE_CMD_GET_DUAL_EXPOSURE_RATIO_DEFAULT = 19
    IS_EXPOSURE_CMD_GET_DUAL_EXPOSURE_RATIO_RANGE = 20
    IS_EXPOSURE_CMD_GET_DUAL_EXPOSURE_RATIO = 21
    IS_EXPOSURE_CMD_SET_DUAL_EXPOSURE_RATIO = 22
end

const EXPOSURE_CMD = E_EXPOSURE_CMD

@cenum E_EXPOSURE_CAPS::UInt32 begin
    IS_EXPOSURE_CAP_EXPOSURE = 1
    IS_EXPOSURE_CAP_FINE_INCREMENT = 2
    IS_EXPOSURE_CAP_LONG_EXPOSURE = 4
    IS_EXPOSURE_CAP_DUAL_EXPOSURE = 8
end

const EXPOSURE_CAPS = E_EXPOSURE_CAPS

@cenum E_TRIGGER_CMD::UInt32 begin
    IS_TRIGGER_CMD_GET_BURST_SIZE_SUPPORTED = 1
    IS_TRIGGER_CMD_GET_BURST_SIZE_RANGE = 2
    IS_TRIGGER_CMD_GET_BURST_SIZE = 3
    IS_TRIGGER_CMD_SET_BURST_SIZE = 4
    IS_TRIGGER_CMD_GET_FRAME_PRESCALER_SUPPORTED = 5
    IS_TRIGGER_CMD_GET_FRAME_PRESCALER_RANGE = 6
    IS_TRIGGER_CMD_GET_FRAME_PRESCALER = 7
    IS_TRIGGER_CMD_SET_FRAME_PRESCALER = 8
    IS_TRIGGER_CMD_GET_LINE_PRESCALER_SUPPORTED = 9
    IS_TRIGGER_CMD_GET_LINE_PRESCALER_RANGE = 10
    IS_TRIGGER_CMD_GET_LINE_PRESCALER = 11
    IS_TRIGGER_CMD_SET_LINE_PRESCALER = 12
end

const TRIGGER_CMD = E_TRIGGER_CMD

struct S_IS_DEVICE_INFO_HEARTBEAT
    data::NTuple{248, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_DEVICE_INFO_HEARTBEAT}, f::Symbol)
    f === :reserved_1 && return Ptr{NTuple{24, BYTE}}(x + 0)
    f === :dwRuntimeFirmwareVersion && return Ptr{DWORD}(x + 24)
    f === :reserved_2 && return Ptr{NTuple{8, BYTE}}(x + 28)
    f === :wTemperature && return Ptr{WORD}(x + 36)
    f === :wLinkSpeed_Mb && return Ptr{WORD}(x + 38)
    f === :reserved_3 && return Ptr{NTuple{6, BYTE}}(x + 40)
    f === :wComportOffset && return Ptr{WORD}(x + 46)
    f === :reserved && return Ptr{NTuple{200, BYTE}}(x + 48)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_DEVICE_INFO_HEARTBEAT, f::Symbol)
    r = Ref{S_IS_DEVICE_INFO_HEARTBEAT}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_DEVICE_INFO_HEARTBEAT}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_DEVICE_INFO_HEARTBEAT}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_DEVICE_INFO_HEARTBEAT = S_IS_DEVICE_INFO_HEARTBEAT

struct S_IS_DEVICE_INFO_CONTROL
    data::NTuple{152, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_DEVICE_INFO_CONTROL}, f::Symbol)
    f === :dwDeviceId && return Ptr{DWORD}(x + 0)
    f === :reserved && return Ptr{NTuple{148, BYTE}}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_DEVICE_INFO_CONTROL, f::Symbol)
    r = Ref{S_IS_DEVICE_INFO_CONTROL}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_DEVICE_INFO_CONTROL}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_DEVICE_INFO_CONTROL}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_DEVICE_INFO_CONTROL = S_IS_DEVICE_INFO_CONTROL

struct S_IS_DEVICE_INFO
    data::NTuple{640, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_DEVICE_INFO}, f::Symbol)
    f === :infoDevHeartbeat && return Ptr{IS_DEVICE_INFO_HEARTBEAT}(x + 0)
    f === :infoDevControl && return Ptr{IS_DEVICE_INFO_CONTROL}(x + 248)
    f === :reserved && return Ptr{NTuple{240, BYTE}}(x + 400)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_DEVICE_INFO, f::Symbol)
    r = Ref{S_IS_DEVICE_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_DEVICE_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_DEVICE_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_DEVICE_INFO = S_IS_DEVICE_INFO

@cenum E_IS_DEVICE_INFO_CMD::UInt32 begin
    IS_DEVICE_INFO_CMD_GET_DEVICE_INFO = 33619969
end

const IS_DEVICE_INFO_CMD = E_IS_DEVICE_INFO_CMD

@cenum E_IS_CALLBACK_CMD::UInt32 begin
    IS_CALLBACK_CMD_INSTALL = 1
    IS_CALLBACK_CMD_UNINSTALL = 2
end

const IS_CALLBACK_CMD = E_IS_CALLBACK_CMD

@cenum E_IS_CALLBACK_EVENT::UInt32 begin
    IS_CALLBACK_EV_IMGPOSTPROC_START = 1
end

const IS_CALLBACK_EVENT = E_IS_CALLBACK_EVENT

struct S_IS_CALLBACK_EVCTX_DATA_PROCESSING
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_CALLBACK_EVCTX_DATA_PROCESSING}, f::Symbol)
    f === :pSrcBuf && return Ptr{Ptr{Cvoid}}(x + 0)
    f === :cbSrcBuf && return Ptr{UINT}(x + 8)
    f === :pDestBuf && return Ptr{Ptr{Cvoid}}(x + 16)
    f === :cbDestBuf && return Ptr{UINT}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_CALLBACK_EVCTX_DATA_PROCESSING, f::Symbol)
    r = Ref{S_IS_CALLBACK_EVCTX_DATA_PROCESSING}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_CALLBACK_EVCTX_DATA_PROCESSING}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_CALLBACK_EVCTX_DATA_PROCESSING}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_CALLBACK_EVCTX_DATA_PROCESSING = S_IS_CALLBACK_EVCTX_DATA_PROCESSING

struct S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING}, f::Symbol)
    f === :bufferInfo && return Ptr{IS_CALLBACK_EVCTX_DATA_PROCESSING}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING, f::Symbol)
    r = Ref{S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_CALLBACK_EVCTX_IMAGE_PROCESSING = S_IS_CALLBACK_EVCTX_IMAGE_PROCESSING

struct S_IS_CALLBACK_FDBK_IMAGE_PROCESSING
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_CALLBACK_FDBK_IMAGE_PROCESSING}, f::Symbol)
    f === :nDummy && return Ptr{UINT}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_CALLBACK_FDBK_IMAGE_PROCESSING, f::Symbol)
    r = Ref{S_IS_CALLBACK_FDBK_IMAGE_PROCESSING}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_CALLBACK_FDBK_IMAGE_PROCESSING}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_CALLBACK_FDBK_IMAGE_PROCESSING}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_CALLBACK_FDBK_IMAGE_PROCESSING = S_IS_CALLBACK_FDBK_IMAGE_PROCESSING

# typedef INT ( __cdecl * IS_CALLBACK_FUNC
const IS_CALLBACK_FUNC = Ptr{Cvoid}

const HCAM_CALLBACK = HCAM

struct S_IS_CALLBACK_INSTALLATION_DATA
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_CALLBACK_INSTALLATION_DATA}, f::Symbol)
    f === :nEvent && return Ptr{UINT}(x + 0)
    f === :pfFunc && return Ptr{IS_CALLBACK_FUNC}(x + 8)
    f === :pUserContext && return Ptr{Ptr{Cvoid}}(x + 16)
    f === :hCallback && return Ptr{HCAM_CALLBACK}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_CALLBACK_INSTALLATION_DATA, f::Symbol)
    r = Ref{S_IS_CALLBACK_INSTALLATION_DATA}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_CALLBACK_INSTALLATION_DATA}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_CALLBACK_INSTALLATION_DATA}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_CALLBACK_INSTALLATION_DATA = S_IS_CALLBACK_INSTALLATION_DATA

@cenum E_IS_OPTIMAL_CAMERA_TIMING_CMD::UInt32 begin
    IS_OPTIMAL_CAMERA_TIMING_CMD_GET_PIXELCLOCK = 1
    IS_OPTIMAL_CAMERA_TIMING_CMD_GET_FRAMERATE = 2
end

const IS_OPTIMAL_CAMERA_TIMING_CMD = E_IS_OPTIMAL_CAMERA_TIMING_CMD

struct S_IS_OPTIMAL_CAMERA_TIMING
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{S_IS_OPTIMAL_CAMERA_TIMING}, f::Symbol)
    f === :s32Mode && return Ptr{INT}(x + 0)
    f === :s32TimeoutFineTuning && return Ptr{INT}(x + 4)
    f === :ps32PixelClock && return Ptr{Ptr{INT}}(x + 8)
    f === :pdFramerate && return Ptr{Ptr{Cdouble}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::S_IS_OPTIMAL_CAMERA_TIMING, f::Symbol)
    r = Ref{S_IS_OPTIMAL_CAMERA_TIMING}(x)
    ptr = Base.unsafe_convert(Ptr{S_IS_OPTIMAL_CAMERA_TIMING}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IS_OPTIMAL_CAMERA_TIMING}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_OPTIMAL_CAMERA_TIMING = S_IS_OPTIMAL_CAMERA_TIMING

struct _UC480_ETH_ADDR_IPV4
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_ADDR_IPV4}, f::Symbol)
    f === :by && return Ptr{var"struct (unnamed at uc480.h:3981:7)"}(x + 0)
    f === :dwAddr && return Ptr{DWORD}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_ADDR_IPV4, f::Symbol)
    r = Ref{_UC480_ETH_ADDR_IPV4}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_ADDR_IPV4}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_ADDR_IPV4}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_ADDR_IPV4 = _UC480_ETH_ADDR_IPV4

const PUC480_ETH_ADDR_IPV4 = Ptr{_UC480_ETH_ADDR_IPV4}

struct _UC480_ETH_ADDR_MAC
    data::NTuple{6, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_ADDR_MAC}, f::Symbol)
    f === :abyOctet && return Ptr{NTuple{6, BYTE}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_ADDR_MAC, f::Symbol)
    r = Ref{_UC480_ETH_ADDR_MAC}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_ADDR_MAC}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_ADDR_MAC}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_ADDR_MAC = _UC480_ETH_ADDR_MAC

const PUC480_ETH_ADDR_MAC = Ptr{_UC480_ETH_ADDR_MAC}

struct _UC480_ETH_IP_CONFIGURATION
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_IP_CONFIGURATION}, f::Symbol)
    f === :ipAddress && return Ptr{UC480_ETH_ADDR_IPV4}(x + 0)
    f === :ipSubnetmask && return Ptr{UC480_ETH_ADDR_IPV4}(x + 4)
    f === :reserved && return Ptr{NTuple{4, BYTE}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_IP_CONFIGURATION, f::Symbol)
    r = Ref{_UC480_ETH_IP_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_IP_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_IP_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_IP_CONFIGURATION = _UC480_ETH_IP_CONFIGURATION

const PUC480_ETH_IP_CONFIGURATION = Ptr{_UC480_ETH_IP_CONFIGURATION}

@cenum _UC480_ETH_DEVICESTATUS::UInt32 begin
    IS_ETH_DEVSTATUS_READY_TO_OPERATE = 1
    IS_ETH_DEVSTATUS_TESTING_IP_CURRENT = 2
    IS_ETH_DEVSTATUS_TESTING_IP_PERSISTENT = 4
    IS_ETH_DEVSTATUS_TESTING_IP_RANGE = 8
    IS_ETH_DEVSTATUS_INAPPLICABLE_IP_CURRENT = 16
    IS_ETH_DEVSTATUS_INAPPLICABLE_IP_PERSISTENT = 32
    IS_ETH_DEVSTATUS_INAPPLICABLE_IP_RANGE = 64
    IS_ETH_DEVSTATUS_UNPAIRED = 256
    IS_ETH_DEVSTATUS_PAIRING_IN_PROGRESS = 512
    IS_ETH_DEVSTATUS_PAIRED = 1024
    IS_ETH_DEVSTATUS_FORCE_100MBPS = 4096
    IS_ETH_DEVSTATUS_NO_COMPORT = 8192
    IS_ETH_DEVSTATUS_RECEIVING_FW_STARTER = 65536
    IS_ETH_DEVSTATUS_RECEIVING_FW_RUNTIME = 131072
    IS_ETH_DEVSTATUS_INAPPLICABLE_FW_RUNTIME = 262144
    IS_ETH_DEVSTATUS_INAPPLICABLE_FW_STARTER = 524288
    IS_ETH_DEVSTATUS_REBOOTING_FW_RUNTIME = 1048576
    IS_ETH_DEVSTATUS_REBOOTING_FW_STARTER = 2097152
    IS_ETH_DEVSTATUS_REBOOTING_FW_FAILSAFE = 4194304
    IS_ETH_DEVSTATUS_RUNTIME_FW_ERR0 = 0x0000000080000000
end

const UC480_ETH_DEVICESTATUS = _UC480_ETH_DEVICESTATUS

struct _UC480_ETH_DEVICE_INFO_HEARTBEAT
    data::NTuple{248, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_DEVICE_INFO_HEARTBEAT}, f::Symbol)
    f === :abySerialNumber && return Ptr{NTuple{12, BYTE}}(x + 0)
    f === :byDeviceType && return Ptr{BYTE}(x + 12)
    f === :byCameraID && return Ptr{BYTE}(x + 13)
    f === :wSensorID && return Ptr{WORD}(x + 14)
    f === :wSizeImgMem_MB && return Ptr{WORD}(x + 16)
    f === :reserved_1 && return Ptr{NTuple{2, BYTE}}(x + 18)
    f === :dwVerStarterFirmware && return Ptr{DWORD}(x + 20)
    f === :dwVerRuntimeFirmware && return Ptr{DWORD}(x + 24)
    f === :dwStatus && return Ptr{DWORD}(x + 28)
    f === :reserved_2 && return Ptr{NTuple{4, BYTE}}(x + 32)
    f === :wTemperature && return Ptr{WORD}(x + 36)
    f === :wLinkSpeed_Mb && return Ptr{WORD}(x + 38)
    f === :macDevice && return Ptr{UC480_ETH_ADDR_MAC}(x + 40)
    f === :wComportOffset && return Ptr{WORD}(x + 46)
    f === :ipcfgPersistentIpCfg && return Ptr{UC480_ETH_IP_CONFIGURATION}(x + 48)
    f === :ipcfgCurrentIpCfg && return Ptr{UC480_ETH_IP_CONFIGURATION}(x + 60)
    f === :macPairedHost && return Ptr{UC480_ETH_ADDR_MAC}(x + 72)
    f === :reserved_4 && return Ptr{NTuple{2, BYTE}}(x + 78)
    f === :ipPairedHostIp && return Ptr{UC480_ETH_ADDR_IPV4}(x + 80)
    f === :ipAutoCfgIpRangeBegin && return Ptr{UC480_ETH_ADDR_IPV4}(x + 84)
    f === :ipAutoCfgIpRangeEnd && return Ptr{UC480_ETH_ADDR_IPV4}(x + 88)
    f === :abyUserSpace && return Ptr{NTuple{8, BYTE}}(x + 92)
    f === :reserved_5 && return Ptr{NTuple{84, BYTE}}(x + 100)
    f === :reserved_6 && return Ptr{NTuple{64, BYTE}}(x + 184)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_DEVICE_INFO_HEARTBEAT, f::Symbol)
    r = Ref{_UC480_ETH_DEVICE_INFO_HEARTBEAT}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_DEVICE_INFO_HEARTBEAT}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_DEVICE_INFO_HEARTBEAT}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_DEVICE_INFO_HEARTBEAT = _UC480_ETH_DEVICE_INFO_HEARTBEAT

const PUC480_ETH_DEVICE_INFO_HEARTBEAT = Ptr{_UC480_ETH_DEVICE_INFO_HEARTBEAT}

@cenum _UC480_ETH_CONTROLSTATUS::UInt32 begin
    IS_ETH_CTRLSTATUS_AVAILABLE = 1
    IS_ETH_CTRLSTATUS_ACCESSIBLE1 = 2
    IS_ETH_CTRLSTATUS_ACCESSIBLE2 = 4
    IS_ETH_CTRLSTATUS_PERSISTENT_IP_USED = 16
    IS_ETH_CTRLSTATUS_COMPATIBLE = 32
    IS_ETH_CTRLSTATUS_ADAPTER_ON_DHCP = 64
    IS_ETH_CTRLSTATUS_ADAPTER_SETUP_OK = 128
    IS_ETH_CTRLSTATUS_UNPAIRING_IN_PROGRESS = 256
    IS_ETH_CTRLSTATUS_PAIRING_IN_PROGRESS = 512
    IS_ETH_CTRLSTATUS_PAIRED = 4096
    IS_ETH_CTRLSTATUS_OPENED = 16384
    IS_ETH_CTRLSTATUS_FW_UPLOAD_STARTER = 65536
    IS_ETH_CTRLSTATUS_FW_UPLOAD_RUNTIME = 131072
    IS_ETH_CTRLSTATUS_REBOOTING = 1048576
    IS_ETH_CTRLSTATUS_BOOTBOOST_ENABLED = 16777216
    IS_ETH_CTRLSTATUS_BOOTBOOST_ACTIVE = 33554432
    IS_ETH_CTRLSTATUS_INITIALIZED = 134217728
    IS_ETH_CTRLSTATUS_TO_BE_DELETED = 1073741824
    IS_ETH_CTRLSTATUS_TO_BE_REMOVED = 0x0000000080000000
end

const UC480_ETH_CONTROLSTATUS = _UC480_ETH_CONTROLSTATUS

struct _UC480_ETH_DEVICE_INFO_CONTROL
    data::NTuple{152, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_DEVICE_INFO_CONTROL}, f::Symbol)
    f === :dwDeviceID && return Ptr{DWORD}(x + 0)
    f === :dwControlStatus && return Ptr{DWORD}(x + 4)
    f === :reserved_1 && return Ptr{NTuple{80, BYTE}}(x + 8)
    f === :reserved_2 && return Ptr{NTuple{64, BYTE}}(x + 88)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_DEVICE_INFO_CONTROL, f::Symbol)
    r = Ref{_UC480_ETH_DEVICE_INFO_CONTROL}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_DEVICE_INFO_CONTROL}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_DEVICE_INFO_CONTROL}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_DEVICE_INFO_CONTROL = _UC480_ETH_DEVICE_INFO_CONTROL

const PUC480_ETH_DEVICE_INFO_CONTROL = Ptr{_UC480_ETH_DEVICE_INFO_CONTROL}

struct _UC480_ETH_ETHERNET_CONFIGURATION
    data::NTuple{18, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_ETHERNET_CONFIGURATION}, f::Symbol)
    f === :ipcfg && return Ptr{UC480_ETH_IP_CONFIGURATION}(x + 0)
    f === :mac && return Ptr{UC480_ETH_ADDR_MAC}(x + 12)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_ETHERNET_CONFIGURATION, f::Symbol)
    r = Ref{_UC480_ETH_ETHERNET_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_ETHERNET_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_ETHERNET_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_ETHERNET_CONFIGURATION = _UC480_ETH_ETHERNET_CONFIGURATION

const PUC480_ETH_ETHERNET_CONFIGURATION = Ptr{_UC480_ETH_ETHERNET_CONFIGURATION}

struct _UC480_ETH_AUTOCFG_IP_SETUP
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_AUTOCFG_IP_SETUP}, f::Symbol)
    f === :ipAutoCfgIpRangeBegin && return Ptr{UC480_ETH_ADDR_IPV4}(x + 0)
    f === :ipAutoCfgIpRangeEnd && return Ptr{UC480_ETH_ADDR_IPV4}(x + 4)
    f === :reserved && return Ptr{NTuple{4, BYTE}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_AUTOCFG_IP_SETUP, f::Symbol)
    r = Ref{_UC480_ETH_AUTOCFG_IP_SETUP}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_AUTOCFG_IP_SETUP}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_AUTOCFG_IP_SETUP}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_AUTOCFG_IP_SETUP = _UC480_ETH_AUTOCFG_IP_SETUP

const PUC480_ETH_AUTOCFG_IP_SETUP = Ptr{_UC480_ETH_AUTOCFG_IP_SETUP}

@cenum _UC480_ETH_PACKETFILTER_SETUP::UInt32 begin
    IS_ETH_PCKTFLT_PASSALL = 0
    IS_ETH_PCKTFLT_BLOCKUEGET = 1
    IS_ETH_PCKTFLT_BLOCKALL = 2
end

const UC480_ETH_PACKETFILTER_SETUP = _UC480_ETH_PACKETFILTER_SETUP

@cenum _UC480_ETH_LINKSPEED_SETUP::UInt32 begin
    IS_ETH_LINKSPEED_100MB = 100
    IS_ETH_LINKSPEED_1000MB = 1000
end

const UC480_ETH_LINKSPEED_SETUP = _UC480_ETH_LINKSPEED_SETUP

struct _UC480_ETH_ADAPTER_INFO
    data::NTuple{160, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_ADAPTER_INFO}, f::Symbol)
    f === :dwAdapterID && return Ptr{DWORD}(x + 0)
    f === :dwDeviceLinkspeed && return Ptr{DWORD}(x + 4)
    f === :ethcfg && return Ptr{UC480_ETH_ETHERNET_CONFIGURATION}(x + 8)
    f === :reserved_2 && return Ptr{NTuple{2, BYTE}}(x + 26)
    f === :bIsEnabledDHCP && return Ptr{BOOL}(x + 28)
    f === :autoCfgIp && return Ptr{UC480_ETH_AUTOCFG_IP_SETUP}(x + 32)
    f === :bIsValidAutoCfgIpRange && return Ptr{BOOL}(x + 44)
    f === :dwCntDevicesKnown && return Ptr{DWORD}(x + 48)
    f === :dwCntDevicesPaired && return Ptr{DWORD}(x + 52)
    f === :wPacketFilter && return Ptr{WORD}(x + 56)
    f === :reserved_3 && return Ptr{NTuple{38, BYTE}}(x + 58)
    f === :reserved_4 && return Ptr{NTuple{64, BYTE}}(x + 96)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_ADAPTER_INFO, f::Symbol)
    r = Ref{_UC480_ETH_ADAPTER_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_ADAPTER_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_ADAPTER_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_ADAPTER_INFO = _UC480_ETH_ADAPTER_INFO

const PUC480_ETH_ADAPTER_INFO = Ptr{_UC480_ETH_ADAPTER_INFO}

struct _UC480_ETH_DRIVER_INFO
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_DRIVER_INFO}, f::Symbol)
    f === :dwMinVerStarterFirmware && return Ptr{DWORD}(x + 0)
    f === :dwMaxVerStarterFirmware && return Ptr{DWORD}(x + 4)
    f === :reserved_1 && return Ptr{NTuple{8, BYTE}}(x + 8)
    f === :reserved_2 && return Ptr{NTuple{64, BYTE}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_DRIVER_INFO, f::Symbol)
    r = Ref{_UC480_ETH_DRIVER_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_DRIVER_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_DRIVER_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_DRIVER_INFO = _UC480_ETH_DRIVER_INFO

const PUC480_ETH_DRIVER_INFO = Ptr{_UC480_ETH_DRIVER_INFO}

struct _UC480_ETH_DEVICE_INFO
    data::NTuple{640, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_ETH_DEVICE_INFO}, f::Symbol)
    f === :infoDevHeartbeat && return Ptr{UC480_ETH_DEVICE_INFO_HEARTBEAT}(x + 0)
    f === :infoDevControl && return Ptr{UC480_ETH_DEVICE_INFO_CONTROL}(x + 248)
    f === :infoAdapter && return Ptr{UC480_ETH_ADAPTER_INFO}(x + 400)
    f === :infoDriver && return Ptr{UC480_ETH_DRIVER_INFO}(x + 560)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_ETH_DEVICE_INFO, f::Symbol)
    r = Ref{_UC480_ETH_DEVICE_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_ETH_DEVICE_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_ETH_DEVICE_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_ETH_DEVICE_INFO = _UC480_ETH_DEVICE_INFO

const PUC480_ETH_DEVICE_INFO = Ptr{_UC480_ETH_DEVICE_INFO}

struct _UC480_COMPORT_CONFIGURATION
    data::NTuple{2, UInt8}
end

function Base.getproperty(x::Ptr{_UC480_COMPORT_CONFIGURATION}, f::Symbol)
    f === :wComportNumber && return Ptr{WORD}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::_UC480_COMPORT_CONFIGURATION, f::Symbol)
    r = Ref{_UC480_COMPORT_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{_UC480_COMPORT_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{_UC480_COMPORT_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const UC480_COMPORT_CONFIGURATION = _UC480_COMPORT_CONFIGURATION

const PUC480_COMPORT_CONFIGURATION = Ptr{_UC480_COMPORT_CONFIGURATION}

@cenum E_IPCONFIG_CAPABILITY_FLAGS::UInt32 begin
    IPCONFIG_CAP_PERSISTENT_IP_SUPPORTED = 1
    IPCONFIG_CAP_AUTOCONFIG_IP_SUPPORTED = 4
end

const IPCONFIG_CAPABILITY_FLAGS = E_IPCONFIG_CAPABILITY_FLAGS

@cenum E_IPCONFIG_CMD::UInt32 begin
    IPCONFIG_CMD_QUERY_CAPABILITIES = 0
    IPCONFIG_CMD_SET_PERSISTENT_IP = 16842752
    IPCONFIG_CMD_SET_AUTOCONFIG_IP = 17039360
    IPCONFIG_CMD_SET_AUTOCONFIG_IP_BYDEVICE = 17039616
    IPCONFIG_CMD_RESERVED1 = 17301504
    IPCONFIG_CMD_GET_PERSISTENT_IP = 33619968
    IPCONFIG_CMD_GET_AUTOCONFIG_IP = 33816576
    IPCONFIG_CMD_GET_AUTOCONFIG_IP_BYDEVICE = 33816832
end

const IPCONFIG_CMD = E_IPCONFIG_CMD

@cenum E_CONFIGURATION_SEL::UInt32 begin
    IS_CONFIG_CPU_IDLE_STATES_BIT_AC_VALUE = 1
    IS_CONFIG_CPU_IDLE_STATES_BIT_DC_VALUE = 2
    IS_CONFIG_IPO_NOT_ALLOWED = 0
    IS_CONFIG_IPO_ALLOWED = 1
    IS_CONFIG_OPEN_MP_DISABLE = 0
    IS_CONFIG_OPEN_MP_ENABLE = 1
    IS_CONFIG_INITIAL_PARAMETERSET_NONE = 0
    IS_CONFIG_INITIAL_PARAMETERSET_1 = 1
    IS_CONFIG_INITIAL_PARAMETERSET_2 = 2
    IS_CONFIG_ETH_CONFIGURATION_MODE_OFF = 0
    IS_CONFIG_ETH_CONFIGURATION_MODE_ON = 1
    IS_CONFIG_TRUSTED_PAIRING_OFF = 0
    IS_CONFIG_TRUSTED_PAIRING_ON = 1
end

const CONFIGURATION_SEL = E_CONFIGURATION_SEL

@cenum E_CONFIGURATION_CMD::UInt32 begin
    IS_CONFIG_CMD_GET_CAPABILITIES = 1
    IS_CONFIG_CPU_IDLE_STATES_CMD_GET_ENABLE = 2
    IS_CONFIG_CPU_IDLE_STATES_CMD_SET_DISABLE_ON_OPEN = 4
    IS_CONFIG_CPU_IDLE_STATES_CMD_GET_DISABLE_ON_OPEN = 5
    IS_CONFIG_OPEN_MP_CMD_GET_ENABLE = 6
    IS_CONFIG_OPEN_MP_CMD_SET_ENABLE = 7
    IS_CONFIG_OPEN_MP_CMD_GET_ENABLE_DEFAULT = 8
    IS_CONFIG_INITIAL_PARAMETERSET_CMD_SET = 9
    IS_CONFIG_INITIAL_PARAMETERSET_CMD_GET = 10
    IS_CONFIG_ETH_CONFIGURATION_MODE_CMD_SET_ENABLE = 11
    IS_CONFIG_ETH_CONFIGURATION_MODE_CMD_GET_ENABLE = 12
    IS_CONFIG_IPO_CMD_GET_ALLOWED = 13
    IS_CONFIG_IPO_CMD_SET_ALLOWED = 14
    IS_CONFIG_CMD_TRUSTED_PAIRING_SET = 15
    IS_CONFIG_CMD_TRUSTED_PAIRING_GET = 16
    IS_CONFIG_CMD_TRUSTED_PAIRING_GET_DEFAULT = 17
    IS_CONFIG_CMD_RESERVED_1 = 18
end

const CONFIGURATION_CMD = E_CONFIGURATION_CMD

@cenum E_CONFIGURATION_CAPS::UInt32 begin
    IS_CONFIG_CPU_IDLE_STATES_CAP_SUPPORTED = 1
    IS_CONFIG_OPEN_MP_CAP_SUPPORTED = 2
    IS_CONFIG_INITIAL_PARAMETERSET_CAP_SUPPORTED = 4
    IS_CONFIG_IPO_CAP_SUPPORTED = 8
    IS_CONFIG_TRUSTED_PAIRING_CAP_SUPPORTED = 16
end

const CONFIGURATION_CAPS = E_CONFIGURATION_CAPS

struct S_IO_FLASH_PARAMS
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{S_IO_FLASH_PARAMS}, f::Symbol)
    f === :s32Delay && return Ptr{INT}(x + 0)
    f === :u32Duration && return Ptr{UINT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::S_IO_FLASH_PARAMS, f::Symbol)
    r = Ref{S_IO_FLASH_PARAMS}(x)
    ptr = Base.unsafe_convert(Ptr{S_IO_FLASH_PARAMS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IO_FLASH_PARAMS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IO_FLASH_PARAMS = S_IO_FLASH_PARAMS

struct S_IO_PWM_PARAMS
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{S_IO_PWM_PARAMS}, f::Symbol)
    f === :dblFrequency_Hz && return Ptr{Cdouble}(x + 0)
    f === :dblDutyCycle && return Ptr{Cdouble}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::S_IO_PWM_PARAMS, f::Symbol)
    r = Ref{S_IO_PWM_PARAMS}(x)
    ptr = Base.unsafe_convert(Ptr{S_IO_PWM_PARAMS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IO_PWM_PARAMS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IO_PWM_PARAMS = S_IO_PWM_PARAMS

struct S_IO_GPIO_CONFIGURATION
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{S_IO_GPIO_CONFIGURATION}, f::Symbol)
    f === :u32Gpio && return Ptr{UINT}(x + 0)
    f === :u32Caps && return Ptr{UINT}(x + 4)
    f === :u32Configuration && return Ptr{UINT}(x + 8)
    f === :u32State && return Ptr{UINT}(x + 12)
    f === :u32Reserved && return Ptr{NTuple{12, UINT}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::S_IO_GPIO_CONFIGURATION, f::Symbol)
    r = Ref{S_IO_GPIO_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{S_IO_GPIO_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IO_GPIO_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IO_GPIO_CONFIGURATION = S_IO_GPIO_CONFIGURATION

@cenum E_IO_CMD::UInt32 begin
    IS_IO_CMD_GPIOS_GET_SUPPORTED = 1
    IS_IO_CMD_GPIOS_GET_SUPPORTED_INPUTS = 2
    IS_IO_CMD_GPIOS_GET_SUPPORTED_OUTPUTS = 3
    IS_IO_CMD_GPIOS_GET_DIRECTION = 4
    IS_IO_CMD_GPIOS_SET_DIRECTION = 5
    IS_IO_CMD_GPIOS_GET_STATE = 6
    IS_IO_CMD_GPIOS_SET_STATE = 7
    IS_IO_CMD_LED_GET_STATE = 8
    IS_IO_CMD_LED_SET_STATE = 9
    IS_IO_CMD_LED_TOGGLE_STATE = 10
    IS_IO_CMD_FLASH_GET_GLOBAL_PARAMS = 11
    IS_IO_CMD_FLASH_APPLY_GLOBAL_PARAMS = 12
    IS_IO_CMD_FLASH_GET_SUPPORTED_GPIOS = 13
    IS_IO_CMD_FLASH_GET_PARAMS_MIN = 14
    IS_IO_CMD_FLASH_GET_PARAMS_MAX = 15
    IS_IO_CMD_FLASH_GET_PARAMS_INC = 16
    IS_IO_CMD_FLASH_GET_PARAMS = 17
    IS_IO_CMD_FLASH_SET_PARAMS = 18
    IS_IO_CMD_FLASH_GET_MODE = 19
    IS_IO_CMD_FLASH_SET_MODE = 20
    IS_IO_CMD_PWM_GET_SUPPORTED_GPIOS = 21
    IS_IO_CMD_PWM_GET_PARAMS_MIN = 22
    IS_IO_CMD_PWM_GET_PARAMS_MAX = 23
    IS_IO_CMD_PWM_GET_PARAMS_INC = 24
    IS_IO_CMD_PWM_GET_PARAMS = 25
    IS_IO_CMD_PWM_SET_PARAMS = 26
    IS_IO_CMD_PWM_GET_MODE = 27
    IS_IO_CMD_PWM_SET_MODE = 28
    IS_IO_CMD_GPIOS_GET_CONFIGURATION = 29
    IS_IO_CMD_GPIOS_SET_CONFIGURATION = 30
    IS_IO_CMD_FLASH_GET_GPIO_PARAMS_MIN = 31
    IS_IO_CMD_FLASH_SET_GPIO_PARAMS = 32
    IS_IO_CMD_FLASH_GET_AUTO_FREERUN_DEFAULT = 33
    IS_IO_CMD_FLASH_GET_AUTO_FREERUN = 34
    IS_IO_CMD_FLASH_SET_AUTO_FREERUN = 35
end

const IO_CMD = E_IO_CMD

@cenum E_AUTOPARAMETER_CMD::UInt32 begin
    IS_AWB_CMD_GET_SUPPORTED_TYPES = 1
    IS_AWB_CMD_GET_TYPE = 2
    IS_AWB_CMD_SET_TYPE = 3
    IS_AWB_CMD_GET_ENABLE = 4
    IS_AWB_CMD_SET_ENABLE = 5
    IS_AWB_CMD_GET_SUPPORTED_RGB_COLOR_MODELS = 6
    IS_AWB_CMD_GET_RGB_COLOR_MODEL = 7
    IS_AWB_CMD_SET_RGB_COLOR_MODEL = 8
    IS_AES_CMD_GET_SUPPORTED_TYPES = 9
    IS_AES_CMD_SET_ENABLE = 10
    IS_AES_CMD_GET_ENABLE = 11
    IS_AES_CMD_SET_TYPE = 12
    IS_AES_CMD_GET_TYPE = 13
    IS_AES_CMD_SET_CONFIGURATION = 14
    IS_AES_CMD_GET_CONFIGURATION = 15
    IS_AES_CMD_GET_CONFIGURATION_DEFAULT = 16
    IS_AES_CMD_GET_CONFIGURATION_RANGE = 17
end

const AUTOPARAMETER_CMD = E_AUTOPARAMETER_CMD

@cenum E_AES_MODE::UInt32 begin
    IS_AES_MODE_PEAK = 1
    IS_AES_MODE_MEAN = 2
end

const AES_MODE = E_AES_MODE

struct AES_CONFIGURATION
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{AES_CONFIGURATION}, f::Symbol)
    f === :nMode && return Ptr{INT}(x + 0)
    f === :pConfiguration && return Ptr{NTuple{1, CHAR}}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::AES_CONFIGURATION, f::Symbol)
    r = Ref{AES_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{AES_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{AES_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct AES_PEAK_WHITE_CONFIGURATION
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{AES_PEAK_WHITE_CONFIGURATION}, f::Symbol)
    f === :rectUserAOI && return Ptr{IS_RECT}(x + 0)
    f === :nFrameSkip && return Ptr{UINT}(x + 16)
    f === :nHysteresis && return Ptr{UINT}(x + 20)
    f === :nReference && return Ptr{UINT}(x + 24)
    f === :nChannel && return Ptr{UINT}(x + 28)
    f === :f64Maximum && return Ptr{Cdouble}(x + 32)
    f === :f64Minimum && return Ptr{Cdouble}(x + 40)
    f === :reserved && return Ptr{NTuple{32, CHAR}}(x + 48)
    return getfield(x, f)
end

function Base.getproperty(x::AES_PEAK_WHITE_CONFIGURATION, f::Symbol)
    r = Ref{AES_PEAK_WHITE_CONFIGURATION}(x)
    ptr = Base.unsafe_convert(Ptr{AES_PEAK_WHITE_CONFIGURATION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{AES_PEAK_WHITE_CONFIGURATION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct AES_PEAK_WHITE_CONFIGURATION_RANGE
    data::NTuple{68, UInt8}
end

function Base.getproperty(x::Ptr{AES_PEAK_WHITE_CONFIGURATION_RANGE}, f::Symbol)
    f === :rangeFrameSkip && return Ptr{IS_RANGE_S32}(x + 0)
    f === :rangeHysteresis && return Ptr{IS_RANGE_S32}(x + 12)
    f === :rangeReference && return Ptr{IS_RANGE_S32}(x + 24)
    f === :reserved && return Ptr{NTuple{32, CHAR}}(x + 36)
    return getfield(x, f)
end

function Base.getproperty(x::AES_PEAK_WHITE_CONFIGURATION_RANGE, f::Symbol)
    r = Ref{AES_PEAK_WHITE_CONFIGURATION_RANGE}(x)
    ptr = Base.unsafe_convert(Ptr{AES_PEAK_WHITE_CONFIGURATION_RANGE}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{AES_PEAK_WHITE_CONFIGURATION_RANGE}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum E_AES_CHANNEL::UInt32 begin
    IS_AES_CHANNEL_MONO = 1
    IS_AES_CHANNEL_RED = 1
    IS_AES_CHANNEL_GREEN = 2
    IS_AES_CHANNEL_BLUE = 4
end

const AES_CHANNEL = E_AES_CHANNEL

struct BUFFER_CONVERSION_PARAMS
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{BUFFER_CONVERSION_PARAMS}, f::Symbol)
    f === :pSourceBuffer && return Ptr{Ptr{Cchar}}(x + 0)
    f === :pDestBuffer && return Ptr{Ptr{Cchar}}(x + 8)
    f === :nDestPixelFormat && return Ptr{INT}(x + 16)
    f === :nDestPixelConverter && return Ptr{INT}(x + 20)
    f === :nDestGamma && return Ptr{INT}(x + 24)
    f === :nDestEdgeEnhancement && return Ptr{INT}(x + 28)
    f === :nDestColorCorrectionMode && return Ptr{INT}(x + 32)
    f === :nDestSaturationU && return Ptr{INT}(x + 36)
    f === :nDestSaturationV && return Ptr{INT}(x + 40)
    f === :reserved && return Ptr{NTuple{32, BYTE}}(x + 44)
    return getfield(x, f)
end

function Base.getproperty(x::BUFFER_CONVERSION_PARAMS, f::Symbol)
    r = Ref{BUFFER_CONVERSION_PARAMS}(x)
    ptr = Base.unsafe_convert(Ptr{BUFFER_CONVERSION_PARAMS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{BUFFER_CONVERSION_PARAMS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum E_CONVERT_CMD::UInt32 begin
    IS_CONVERT_CMD_APPLY_PARAMS_AND_CONVERT_BUFFER = 1
end

const CONVERT_CMD = E_CONVERT_CMD

@cenum E_PARAMETERSET_CMD::UInt32 begin
    IS_PARAMETERSET_CMD_LOAD_EEPROM = 1
    IS_PARAMETERSET_CMD_LOAD_FILE = 2
    IS_PARAMETERSET_CMD_SAVE_EEPROM = 3
    IS_PARAMETERSET_CMD_SAVE_FILE = 4
    IS_PARAMETERSET_CMD_GET_NUMBER_SUPPORTED = 5
    IS_PARAMETERSET_CMD_GET_HW_PARAMETERSET_AVAILABLE = 6
    IS_PARAMETERSET_CMD_ERASE_HW_PARAMETERSET = 7
end

const PARAMETERSET_CMD = E_PARAMETERSET_CMD

@cenum E_EDGE_ENHANCEMENT_CMD::UInt32 begin
    IS_EDGE_ENHANCEMENT_CMD_GET_RANGE = 1
    IS_EDGE_ENHANCEMENT_CMD_GET_DEFAULT = 2
    IS_EDGE_ENHANCEMENT_CMD_GET = 3
    IS_EDGE_ENHANCEMENT_CMD_SET = 4
end

const EDGE_ENHANCEMENT_CMD = E_EDGE_ENHANCEMENT_CMD

@cenum E_PIXELCLOCK_CMD::UInt32 begin
    IS_PIXELCLOCK_CMD_GET_NUMBER = 1
    IS_PIXELCLOCK_CMD_GET_LIST = 2
    IS_PIXELCLOCK_CMD_GET_RANGE = 3
    IS_PIXELCLOCK_CMD_GET_DEFAULT = 4
    IS_PIXELCLOCK_CMD_GET = 5
    IS_PIXELCLOCK_CMD_SET = 6
end

const PIXELCLOCK_CMD = E_PIXELCLOCK_CMD

struct IMAGE_FILE_PARAMS
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{IMAGE_FILE_PARAMS}, f::Symbol)
    f === :pwchFileName && return Ptr{Ptr{Cwchar_t}}(x + 0)
    f === :nFileType && return Ptr{UINT}(x + 8)
    f === :nQuality && return Ptr{UINT}(x + 12)
    f === :ppcImageMem && return Ptr{Ptr{Ptr{Cchar}}}(x + 16)
    f === :pnImageID && return Ptr{Ptr{UINT}}(x + 24)
    f === :reserved && return Ptr{NTuple{32, BYTE}}(x + 32)
    return getfield(x, f)
end

function Base.getproperty(x::IMAGE_FILE_PARAMS, f::Symbol)
    r = Ref{IMAGE_FILE_PARAMS}(x)
    ptr = Base.unsafe_convert(Ptr{IMAGE_FILE_PARAMS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IMAGE_FILE_PARAMS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum E_IMAGE_FILE_CMD::UInt32 begin
    IS_IMAGE_FILE_CMD_LOAD = 1
    IS_IMAGE_FILE_CMD_SAVE = 2
end

const IMAGE_FILE_CMD = E_IMAGE_FILE_CMD

@cenum E_BLACKLEVEL_MODES::UInt32 begin
    IS_AUTO_BLACKLEVEL_OFF = 0
    IS_AUTO_BLACKLEVEL_ON = 1
end

const BLACKLEVEL_MODES = E_BLACKLEVEL_MODES

@cenum E_BLACKLEVEL_CAPS::UInt32 begin
    IS_BLACKLEVEL_CAP_SET_AUTO_BLACKLEVEL = 1
    IS_BLACKLEVEL_CAP_SET_OFFSET = 2
end

const BLACKLEVEL_CAPS = E_BLACKLEVEL_CAPS

@cenum E_BLACKLEVEL_CMD::UInt32 begin
    IS_BLACKLEVEL_CMD_GET_CAPS = 1
    IS_BLACKLEVEL_CMD_GET_MODE_DEFAULT = 2
    IS_BLACKLEVEL_CMD_GET_MODE = 3
    IS_BLACKLEVEL_CMD_SET_MODE = 4
    IS_BLACKLEVEL_CMD_GET_OFFSET_DEFAULT = 5
    IS_BLACKLEVEL_CMD_GET_OFFSET_RANGE = 6
    IS_BLACKLEVEL_CMD_GET_OFFSET = 7
    IS_BLACKLEVEL_CMD_SET_OFFSET = 8
end

const BLACKLEVEL_CMD = E_BLACKLEVEL_CMD

@cenum E_IMGBUF_CMD::UInt32 begin
    IS_IMGBUF_DEVMEM_CMD_GET_AVAILABLE_ITERATIONS = 1
    IS_IMGBUF_DEVMEM_CMD_GET_ITERATION_INFO = 2
    IS_IMGBUF_DEVMEM_CMD_TRANSFER_IMAGE = 3
    IS_IMGBUF_DEVMEM_CMD_RELEASE_ITERATIONS = 4
end

const IMGBUF_CMD = E_IMGBUF_CMD

struct S_ID_RANGE
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{S_ID_RANGE}, f::Symbol)
    f === :s32First && return Ptr{INT}(x + 0)
    f === :s32Last && return Ptr{INT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::S_ID_RANGE, f::Symbol)
    r = Ref{S_ID_RANGE}(x)
    ptr = Base.unsafe_convert(Ptr{S_ID_RANGE}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_ID_RANGE}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const ID_RANGE = S_ID_RANGE

struct S_IMGBUF_ITERATION_INFO
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{S_IMGBUF_ITERATION_INFO}, f::Symbol)
    f === :u32IterationID && return Ptr{UINT}(x + 0)
    f === :rangeImageID && return Ptr{ID_RANGE}(x + 4)
    f === :bReserved && return Ptr{NTuple{52, BYTE}}(x + 12)
    return getfield(x, f)
end

function Base.getproperty(x::S_IMGBUF_ITERATION_INFO, f::Symbol)
    r = Ref{S_IMGBUF_ITERATION_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{S_IMGBUF_ITERATION_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IMGBUF_ITERATION_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IMGBUF_ITERATION_INFO = S_IMGBUF_ITERATION_INFO

struct S_IMGBUF_ITEM
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{S_IMGBUF_ITEM}, f::Symbol)
    f === :u32IterationID && return Ptr{UINT}(x + 0)
    f === :s32ImageID && return Ptr{INT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::S_IMGBUF_ITEM, f::Symbol)
    r = Ref{S_IMGBUF_ITEM}(x)
    ptr = Base.unsafe_convert(Ptr{S_IMGBUF_ITEM}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_IMGBUF_ITEM}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IMGBUF_ITEM = S_IMGBUF_ITEM

struct S_MEASURE_SHARPNESS_AOI_INFO
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{S_MEASURE_SHARPNESS_AOI_INFO}, f::Symbol)
    f === :u32NumberAOI && return Ptr{UINT}(x + 0)
    f === :u32SharpnessValue && return Ptr{UINT}(x + 4)
    f === :rcAOI && return Ptr{IS_RECT}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::S_MEASURE_SHARPNESS_AOI_INFO, f::Symbol)
    r = Ref{S_MEASURE_SHARPNESS_AOI_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{S_MEASURE_SHARPNESS_AOI_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{S_MEASURE_SHARPNESS_AOI_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const MEASURE_SHARPNESS_AOI_INFO = S_MEASURE_SHARPNESS_AOI_INFO

@cenum E_MEASURE_CMD::UInt32 begin
    IS_MEASURE_CMD_SHARPNESS_AOI_SET = 1
    IS_MEASURE_CMD_SHARPNESS_AOI_INQUIRE = 2
    IS_MEASURE_CMD_SHARPNESS_AOI_SET_PRESET = 3
end

const MEASURE_CMD = E_MEASURE_CMD

@cenum E_MEASURE_SHARPNESS_AOI_PRESETS::UInt32 begin
    IS_MEASURE_SHARPNESS_AOI_PRESET_1 = 1
end

const MEASURE_SHARPNESS_AOI_PRESETS = E_MEASURE_SHARPNESS_AOI_PRESETS

const IS_LUT_PRESET = INT

struct IS_LUT_CONFIGURATION_64
    data::NTuple{1544, UInt8}
end

function Base.getproperty(x::Ptr{IS_LUT_CONFIGURATION_64}, f::Symbol)
    f === :dblValues && return Ptr{NTuple{3, NTuple{64, Cdouble}}}(x + 0)
    f === :bAllChannelsAreEqual && return Ptr{BOOL}(x + 1536)
    return getfield(x, f)
end

function Base.getproperty(x::IS_LUT_CONFIGURATION_64, f::Symbol)
    r = Ref{IS_LUT_CONFIGURATION_64}(x)
    ptr = Base.unsafe_convert(Ptr{IS_LUT_CONFIGURATION_64}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_LUT_CONFIGURATION_64}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_LUT_CONFIGURATION_PRESET_64
    data::NTuple{1552, UInt8}
end

function Base.getproperty(x::Ptr{IS_LUT_CONFIGURATION_PRESET_64}, f::Symbol)
    f === :predefinedLutID && return Ptr{IS_LUT_PRESET}(x + 0)
    f === :lutConfiguration && return Ptr{IS_LUT_CONFIGURATION_64}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::IS_LUT_CONFIGURATION_PRESET_64, f::Symbol)
    r = Ref{IS_LUT_CONFIGURATION_PRESET_64}(x)
    ptr = Base.unsafe_convert(Ptr{IS_LUT_CONFIGURATION_PRESET_64}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_LUT_CONFIGURATION_PRESET_64}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const IS_LUT_ENABLED_STATE = INT

const IS_LUT_MODE = INT

struct IS_LUT_STATE
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{IS_LUT_STATE}, f::Symbol)
    f === :bLUTEnabled && return Ptr{BOOL}(x + 0)
    f === :nLUTStateID && return Ptr{INT}(x + 4)
    f === :nLUTModeID && return Ptr{INT}(x + 8)
    f === :nLUTBits && return Ptr{INT}(x + 12)
    return getfield(x, f)
end

function Base.getproperty(x::IS_LUT_STATE, f::Symbol)
    r = Ref{IS_LUT_STATE}(x)
    ptr = Base.unsafe_convert(Ptr{IS_LUT_STATE}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_LUT_STATE}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_LUT_SUPPORT_INFO
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{IS_LUT_SUPPORT_INFO}, f::Symbol)
    f === :bSupportLUTHardware && return Ptr{BOOL}(x + 0)
    f === :bSupportLUTSoftware && return Ptr{BOOL}(x + 4)
    f === :nBitsHardware && return Ptr{INT}(x + 8)
    f === :nBitsSoftware && return Ptr{INT}(x + 12)
    f === :nChannelsHardware && return Ptr{INT}(x + 16)
    f === :nChannelsSoftware && return Ptr{INT}(x + 20)
    return getfield(x, f)
end

function Base.getproperty(x::IS_LUT_SUPPORT_INFO, f::Symbol)
    r = Ref{IS_LUT_SUPPORT_INFO}(x)
    ptr = Base.unsafe_convert(Ptr{IS_LUT_SUPPORT_INFO}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_LUT_SUPPORT_INFO}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum E_IS_MEMORY_CMD::UInt32 begin
    IS_MEMORY_GET_SIZE = 1
    IS_MEMORY_READ = 2
    IS_MEMORY_WRITE = 3
end

const IS_MEMORY_CMD = E_IS_MEMORY_CMD

@cenum E_IS_MEMORY_DESCRIPTION::UInt32 begin
    IS_MEMORY_USER_1 = 1
    IS_MEMORY_USER_2 = 2
end

const IS_MEMORY_DESCRIPTION = E_IS_MEMORY_DESCRIPTION

struct IS_MEMORY_ACCESS
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{IS_MEMORY_ACCESS}, f::Symbol)
    f === :u32Description && return Ptr{UINT}(x + 0)
    f === :u32Offset && return Ptr{UINT}(x + 4)
    f === :pu8Data && return Ptr{Ptr{Cuchar}}(x + 8)
    f === :u32SizeOfData && return Ptr{UINT}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::IS_MEMORY_ACCESS, f::Symbol)
    r = Ref{IS_MEMORY_ACCESS}(x)
    ptr = Base.unsafe_convert(Ptr{IS_MEMORY_ACCESS}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_MEMORY_ACCESS}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_MEMORY_SIZE
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{IS_MEMORY_SIZE}, f::Symbol)
    f === :u32Description && return Ptr{UINT}(x + 0)
    f === :u32SizeBytes && return Ptr{UINT}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::IS_MEMORY_SIZE, f::Symbol)
    r = Ref{IS_MEMORY_SIZE}(x)
    ptr = Base.unsafe_convert(Ptr{IS_MEMORY_SIZE}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_MEMORY_SIZE}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_MULTI_AOI_DESCRIPTOR
    data::NTuple{20, UInt8}
end

function Base.getproperty(x::Ptr{IS_MULTI_AOI_DESCRIPTOR}, f::Symbol)
    f === :nPosX && return Ptr{UINT}(x + 0)
    f === :nPosY && return Ptr{UINT}(x + 4)
    f === :nWidth && return Ptr{UINT}(x + 8)
    f === :nHeight && return Ptr{UINT}(x + 12)
    f === :nStatus && return Ptr{UINT}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::IS_MULTI_AOI_DESCRIPTOR, f::Symbol)
    r = Ref{IS_MULTI_AOI_DESCRIPTOR}(x)
    ptr = Base.unsafe_convert(Ptr{IS_MULTI_AOI_DESCRIPTOR}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_MULTI_AOI_DESCRIPTOR}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_MULTI_AOI_CONTAINER
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{IS_MULTI_AOI_CONTAINER}, f::Symbol)
    f === :nNumberOfAOIs && return Ptr{UINT}(x + 0)
    f === :pMultiAOIList && return Ptr{Ptr{IS_MULTI_AOI_DESCRIPTOR}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::IS_MULTI_AOI_CONTAINER, f::Symbol)
    r = Ref{IS_MULTI_AOI_CONTAINER}(x)
    ptr = Base.unsafe_convert(Ptr{IS_MULTI_AOI_CONTAINER}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_MULTI_AOI_CONTAINER}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IS_PMC_READONLYDEVICEDESCRIPTOR
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{IS_PMC_READONLYDEVICEDESCRIPTOR}, f::Symbol)
    f === :ipCamera && return Ptr{UC480_ETH_ADDR_IPV4}(x + 0)
    f === :ipMulticast && return Ptr{UC480_ETH_ADDR_IPV4}(x + 4)
    f === :u32CameraId && return Ptr{UINT}(x + 8)
    f === :u32ErrorHandlingMode && return Ptr{UINT}(x + 12)
    return getfield(x, f)
end

function Base.getproperty(x::IS_PMC_READONLYDEVICEDESCRIPTOR, f::Symbol)
    r = Ref{IS_PMC_READONLYDEVICEDESCRIPTOR}(x)
    ptr = Base.unsafe_convert(Ptr{IS_PMC_READONLYDEVICEDESCRIPTOR}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IS_PMC_READONLYDEVICEDESCRIPTOR}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct var"struct (unnamed at uc480.h:3981:7)"
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{var"struct (unnamed at uc480.h:3981:7)"}, f::Symbol)
    f === :by1 && return Ptr{BYTE}(x + 0)
    f === :by2 && return Ptr{BYTE}(x + 1)
    f === :by3 && return Ptr{BYTE}(x + 2)
    f === :by4 && return Ptr{BYTE}(x + 3)
    return getfield(x, f)
end

function Base.getproperty(x::var"struct (unnamed at uc480.h:3981:7)", f::Symbol)
    r = Ref{var"struct (unnamed at uc480.h:3981:7)"}(x)
    ptr = Base.unsafe_convert(Ptr{var"struct (unnamed at uc480.h:3981:7)"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"struct (unnamed at uc480.h:3981:7)"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function UC480_VERSION(major::Int64, minor::Int64, build::Int64)
    return (major << 24) + (minor << 16) + build
end


const BOOL = Cuint

const UC480_VERSION_CODE = UC480_VERSION(4, 80, 0)

const DRIVER_DLL_NAME = "uc480_64.dll"

const IS_COLORMODE_INVALID = 0

const IS_COLORMODE_MONOCHROME = 1

const IS_COLORMODE_BAYER = 2

const IS_COLORMODE_CBYCRY = 4

const IS_COLORMODE_JPEG = 8

const IS_SENSOR_INVALID = 0x0000

const IS_SENSOR_C0640R13M = 0x0001

const IS_SENSOR_C0640R13C = 0x0002

const IS_SENSOR_C1280R23M = 0x0003

const IS_SENSOR_C1280R23C = 0x0004

const IS_SENSOR_C1280R12M = 0x0030

const IS_SENSOR_C1280R12C = 0x0031

const IS_SENSOR_C1600R12C = 0x0008

const IS_SENSOR_C2048R12C = 0x000a

const IS_SENSOR_C2592R12M = 0x000b

const IS_SENSOR_C2592R12C = 0x000c

const IS_SENSOR_C0640G12M = 0x0010

const IS_SENSOR_C0640G12C = 0x0011

const IS_SENSOR_C0752G13M = 0x0012

const IS_SENSOR_C0752G13C = 0x0013

const IS_SENSOR_C1282R13C = 0x0015

const IS_SENSOR_C1601R13C = 0x0017

const IS_SENSOR_C0753G13M = 0x0018

const IS_SENSOR_C0753G13C = 0x0019

const IS_SENSOR_C3840R12M = 0x003e

const IS_SENSOR_C3840R12C = 0x003f

const IS_SENSOR_C0754G13M = 0x0022

const IS_SENSOR_C0754G13C = 0x0023

const IS_SENSOR_C1284R13C = 0x0025

const IS_SENSOR_C1604R13C = 0x0027

const IS_SENSOR_C1285R12M = 0x0028

const IS_SENSOR_C1285R12C = 0x0029

const IS_SENSOR_C1605R12C = 0x002b

const IS_SENSOR_C2055R12C = 0x002d

const IS_SENSOR_C2595R12M = 0x002e

const IS_SENSOR_C2595R12C = 0x002f

const IS_SENSOR_C3845R12M = 0x0040

const IS_SENSOR_C3845R12C = 0x0041

const IS_SENSOR_C0768R12M = 0x004a

const IS_SENSOR_C0768R12C = 0x004b

const IS_SENSOR_C2592R14C = 0x020b

const IS_SENSOR_C1280G12M = 0x0050

const IS_SENSOR_C1280G12C = 0x0051

const IS_SENSOR_C1280G12N = 0x0062

const IS_SENSOR_C1283G12M = 0x0054

const IS_SENSOR_C1283G12C = 0x0055

const IS_SENSOR_C1283G12N = 0x0064

const IS_SENSOR_C1284G12M = 0x0066

const IS_SENSOR_C1284G12C = 0x0067

const IS_SENSOR_C1284G12N = 0x0200

const IS_SENSOR_C1283R12M = 0x0032

const IS_SENSOR_C1283R12C = 0x0033

const IS_SENSOR_C1286R12M = 0x003a

const IS_SENSOR_C1286R12C = 0x003b

const IS_SENSOR_C1283R12M_WO = 0x003c

const IS_SENSOR_C1283R12C_WO = 0x003d

const IS_SENSOR_C1603R12C = 0x0035

const IS_SENSOR_C2053R12C = 0x0037

const IS_SENSOR_C2593R12M = 0x0038

const IS_SENSOR_C2593R12C = 0x0039

const IS_SENSOR_C2057R12M_WO = 0x0044

const IS_SENSOR_C2053R12C_WO = 0x0045

const IS_SENSOR_C2593R12M_WO = 0x0048

const IS_SENSOR_C2593R12C_WO = 0x0049

const IS_SENSOR_C2048G23M = 0x0068

const IS_SENSOR_C2048G23C = 0x0069

const IS_SENSOR_C2048G23N = 0x0212

const IS_SENSOR_C2048G11M = 0x006a

const IS_SENSOR_C2048G11C = 0x006b

const IS_SENSOR_C2048G11N = 0x0214

const IS_SENSOR_C1600G12M = 0x006c

const IS_SENSOR_C1600G12C = 0x006d

const IS_SENSOR_C1600G12N = 0x006e

const IS_SENSOR_C1603G12M = 0x0070

const IS_SENSOR_C1603G12C = 0x0071

const IS_SENSOR_C1603G12N = 0x0072

const IS_SENSOR_C1604G12M = 0x0074

const IS_SENSOR_C1604G12C = 0x0075

const IS_SENSOR_C1604G12N = 0x0202

const IS_SENSOR_C1920G11M = 0x021a

const IS_SENSOR_C1920G11C = 0x021b

const IS_SENSOR_C4216R12C = 0x021d

const IS_SENSOR_C4912R12M = 0x0222

const IS_SENSOR_C4912R12C = 0x0223

const IS_SENSOR_C1936G11M = 0x0226

const IS_SENSOR_C1936G11C = 0x0227

const IS_SENSOR_C0800G13M = 0x022a

const IS_SENSOR_C0800G13C = 0x022b

const IS_SENSOR_C1920G23M = 0x022c

const IS_SENSOR_C1920G23C = 0x022d

const IS_SENSOR_C2592G10M = 0x022e

const IS_SENSOR_C2592G10C = 0x022f

const IS_SENSOR_D1024G13M = 0x0080

const IS_SENSOR_D1024G13C = 0x0081

const IS_SENSOR_D0640G13M = 0x0082

const IS_SENSOR_D0640G13C = 0x0083

const IS_SENSOR_D1281G12M = 0x0084

const IS_SENSOR_D1281G12C = 0x0085

const IS_SENSOR_D0640G12M = 0x0088

const IS_SENSOR_D0640G12C = 0x0089

const IS_SENSOR_D0640G14M = 0x0090

const IS_SENSOR_D0640G14C = 0x0091

const IS_SENSOR_D0768G12M = 0x0092

const IS_SENSOR_D0768G12C = 0x0093

const IS_SENSOR_D1280G12M = 0x0096

const IS_SENSOR_D1280G12C = 0x0097

const IS_SENSOR_D1600G12M = 0x0098

const IS_SENSOR_D1600G12C = 0x0099

const IS_SENSOR_D1280G13M = 0x009a

const IS_SENSOR_D1280G13C = 0x009b

const IS_SENSOR_D0640G13M_R2 = 0x0182

const IS_SENSOR_D0640G13C_R2 = 0x0183

const IS_SENSOR_PASSIVE_MULTICAST = 0x0f00

const IS_NO_SUCCESS = -1

const IS_SUCCESS = 0

const IS_INVALID_CAMERA_HANDLE = 1

const IS_INVALID_HANDLE = 1

const IS_IO_REQUEST_FAILED = 2

const IS_CANT_OPEN_DEVICE = 3

const IS_CANT_CLOSE_DEVICE = 4

const IS_CANT_SETUP_MEMORY = 5

const IS_NO_HWND_FOR_ERROR_REPORT = 6

const IS_ERROR_MESSAGE_NOT_CREATED = 7

const IS_ERROR_STRING_NOT_FOUND = 8

const IS_HOOK_NOT_CREATED = 9

const IS_TIMER_NOT_CREATED = 10

const IS_CANT_OPEN_REGISTRY = 11

const IS_CANT_READ_REGISTRY = 12

const IS_CANT_VALIDATE_BOARD = 13

const IS_CANT_GIVE_BOARD_ACCESS = 14

const IS_NO_IMAGE_MEM_ALLOCATED = 15

const IS_CANT_CLEANUP_MEMORY = 16

const IS_CANT_COMMUNICATE_WITH_DRIVER = 17

const IS_FUNCTION_NOT_SUPPORTED_YET = 18

const IS_OPERATING_SYSTEM_NOT_SUPPORTED = 19

const IS_INVALID_VIDEO_IN = 20

const IS_INVALID_IMG_SIZE = 21

const IS_INVALID_ADDRESS = 22

const IS_INVALID_VIDEO_MODE = 23

const IS_INVALID_AGC_MODE = 24

const IS_INVALID_GAMMA_MODE = 25

const IS_INVALID_SYNC_LEVEL = 26

const IS_INVALID_CBARS_MODE = 27

const IS_INVALID_COLOR_MODE = 28

const IS_INVALID_SCALE_FACTOR = 29

const IS_INVALID_IMAGE_SIZE = 30

const IS_INVALID_IMAGE_POS = 31

const IS_INVALID_CAPTURE_MODE = 32

const IS_INVALID_RISC_PROGRAM = 33

const IS_INVALID_BRIGHTNESS = 34

const IS_INVALID_CONTRAST = 35

const IS_INVALID_SATURATION_U = 36

const IS_INVALID_SATURATION_V = 37

const IS_INVALID_HUE = 38

const IS_INVALID_HOR_FILTER_STEP = 39

const IS_INVALID_VERT_FILTER_STEP = 40

const IS_INVALID_EEPROM_READ_ADDRESS = 41

const IS_INVALID_EEPROM_WRITE_ADDRESS = 42

const IS_INVALID_EEPROM_READ_LENGTH = 43

const IS_INVALID_EEPROM_WRITE_LENGTH = 44

const IS_INVALID_BOARD_INFO_POINTER = 45

const IS_INVALID_DISPLAY_MODE = 46

const IS_INVALID_ERR_REP_MODE = 47

const IS_INVALID_BITS_PIXEL = 48

const IS_INVALID_MEMORY_POINTER = 49

const IS_FILE_WRITE_OPEN_ERROR = 50

const IS_FILE_READ_OPEN_ERROR = 51

const IS_FILE_READ_INVALID_BMP_ID = 52

const IS_FILE_READ_INVALID_BMP_SIZE = 53

const IS_FILE_READ_INVALID_BIT_COUNT = 54

const IS_WRONG_KERNEL_VERSION = 55

const IS_RISC_INVALID_XLENGTH = 60

const IS_RISC_INVALID_YLENGTH = 61

const IS_RISC_EXCEED_IMG_SIZE = 62

const IS_DD_MAIN_FAILED = 70

const IS_DD_PRIMSURFACE_FAILED = 71

const IS_DD_SCRN_SIZE_NOT_SUPPORTED = 72

const IS_DD_CLIPPER_FAILED = 73

const IS_DD_CLIPPER_HWND_FAILED = 74

const IS_DD_CLIPPER_CONNECT_FAILED = 75

const IS_DD_BACKSURFACE_FAILED = 76

const IS_DD_BACKSURFACE_IN_SYSMEM = 77

const IS_DD_MDL_MALLOC_ERR = 78

const IS_DD_MDL_SIZE_ERR = 79

const IS_DD_CLIP_NO_CHANGE = 80

const IS_DD_PRIMMEM_NULL = 81

const IS_DD_BACKMEM_NULL = 82

const IS_DD_BACKOVLMEM_NULL = 83

const IS_DD_OVERLAYSURFACE_FAILED = 84

const IS_DD_OVERLAYSURFACE_IN_SYSMEM = 85

const IS_DD_OVERLAY_NOT_ALLOWED = 86

const IS_DD_OVERLAY_COLKEY_ERR = 87

const IS_DD_OVERLAY_NOT_ENABLED = 88

const IS_DD_GET_DC_ERROR = 89

const IS_DD_DDRAW_DLL_NOT_LOADED = 90

const IS_DD_THREAD_NOT_CREATED = 91

const IS_DD_CANT_GET_CAPS = 92

const IS_DD_NO_OVERLAYSURFACE = 93

const IS_DD_NO_OVERLAYSTRETCH = 94

const IS_DD_CANT_CREATE_OVERLAYSURFACE = 95

const IS_DD_CANT_UPDATE_OVERLAYSURFACE = 96

const IS_DD_INVALID_STRETCH = 97

const IS_EV_INVALID_EVENT_NUMBER = 100

const IS_INVALID_MODE = 101

const IS_CANT_FIND_FALCHOOK = 102

const IS_CANT_FIND_HOOK = 102

const IS_CANT_GET_HOOK_PROC_ADDR = 103

const IS_CANT_CHAIN_HOOK_PROC = 104

const IS_CANT_SETUP_WND_PROC = 105

const IS_HWND_NULL = 106

const IS_INVALID_UPDATE_MODE = 107

const IS_NO_ACTIVE_IMG_MEM = 108

const IS_CANT_INIT_EVENT = 109

const IS_FUNC_NOT_AVAIL_IN_OS = 110

const IS_CAMERA_NOT_CONNECTED = 111

const IS_SEQUENCE_LIST_EMPTY = 112

const IS_CANT_ADD_TO_SEQUENCE = 113

const IS_LOW_OF_SEQUENCE_RISC_MEM = 114

const IS_IMGMEM2FREE_USED_IN_SEQ = 115

const IS_IMGMEM_NOT_IN_SEQUENCE_LIST = 116

const IS_SEQUENCE_BUF_ALREADY_LOCKED = 117

const IS_INVALID_DEVICE_ID = 118

const IS_INVALID_BOARD_ID = 119

const IS_ALL_DEVICES_BUSY = 120

const IS_HOOK_BUSY = 121

const IS_TIMED_OUT = 122

const IS_NULL_POINTER = 123

const IS_WRONG_HOOK_VERSION = 124

const IS_INVALID_PARAMETER = 125

const IS_NOT_ALLOWED = 126

const IS_OUT_OF_MEMORY = 127

const IS_INVALID_WHILE_LIVE = 128

const IS_ACCESS_VIOLATION = 129

const IS_UNKNOWN_ROP_EFFECT = 130

const IS_INVALID_RENDER_MODE = 131

const IS_INVALID_THREAD_CONTEXT = 132

const IS_NO_HARDWARE_INSTALLED = 133

const IS_INVALID_WATCHDOG_TIME = 134

const IS_INVALID_WATCHDOG_MODE = 135

const IS_INVALID_PASSTHROUGH_IN = 136

const IS_ERROR_SETTING_PASSTHROUGH_IN = 137

const IS_FAILURE_ON_SETTING_WATCHDOG = 138

const IS_NO_USB20 = 139

const IS_CAPTURE_RUNNING = 140

const IS_MEMORY_BOARD_ACTIVATED = 141

const IS_MEMORY_BOARD_DEACTIVATED = 142

const IS_NO_MEMORY_BOARD_CONNECTED = 143

const IS_TOO_LESS_MEMORY = 144

const IS_IMAGE_NOT_PRESENT = 145

const IS_MEMORY_MODE_RUNNING = 146

const IS_MEMORYBOARD_DISABLED = 147

const IS_TRIGGER_ACTIVATED = 148

const IS_WRONG_KEY = 150

const IS_CRC_ERROR = 151

const IS_NOT_YET_RELEASED = 152

const IS_NOT_CALIBRATED = 153

const IS_WAITING_FOR_KERNEL = 154

const IS_NOT_SUPPORTED = 155

const IS_TRIGGER_NOT_ACTIVATED = 156

const IS_OPERATION_ABORTED = 157

const IS_BAD_STRUCTURE_SIZE = 158

const IS_INVALID_BUFFER_SIZE = 159

const IS_INVALID_PIXEL_CLOCK = 160

const IS_INVALID_EXPOSURE_TIME = 161

const IS_AUTO_EXPOSURE_RUNNING = 162

const IS_CANNOT_CREATE_BB_SURF = 163

const IS_CANNOT_CREATE_BB_MIX = 164

const IS_BB_OVLMEM_NULL = 165

const IS_CANNOT_CREATE_BB_OVL = 166

const IS_NOT_SUPP_IN_OVL_SURF_MODE = 167

const IS_INVALID_SURFACE = 168

const IS_SURFACE_LOST = 169

const IS_RELEASE_BB_OVL_DC = 170

const IS_BB_TIMER_NOT_CREATED = 171

const IS_BB_OVL_NOT_EN = 172

const IS_ONLY_IN_BB_MODE = 173

const IS_INVALID_COLOR_FORMAT = 174

const IS_INVALID_WB_BINNING_MODE = 175

const IS_INVALID_I2C_DEVICE_ADDRESS = 176

const IS_COULD_NOT_CONVERT = 177

const IS_TRANSFER_ERROR = 178

const IS_PARAMETER_SET_NOT_PRESENT = 179

const IS_INVALID_CAMERA_TYPE = 180

const IS_INVALID_HOST_IP_HIBYTE = 181

const IS_CM_NOT_SUPP_IN_CURR_DISPLAYMODE = 182

const IS_NO_IR_FILTER = 183

const IS_STARTER_FW_UPLOAD_NEEDED = 184

const IS_DR_LIBRARY_NOT_FOUND = 185

const IS_DR_DEVICE_OUT_OF_MEMORY = 186

const IS_DR_CANNOT_CREATE_SURFACE = 187

const IS_DR_CANNOT_CREATE_VERTEX_BUFFER = 188

const IS_DR_CANNOT_CREATE_TEXTURE = 189

const IS_DR_CANNOT_LOCK_OVERLAY_SURFACE = 190

const IS_DR_CANNOT_UNLOCK_OVERLAY_SURFACE = 191

const IS_DR_CANNOT_GET_OVERLAY_DC = 192

const IS_DR_CANNOT_RELEASE_OVERLAY_DC = 193

const IS_DR_DEVICE_CAPS_INSUFFICIENT = 194

const IS_INCOMPATIBLE_SETTING = 195

const IS_DR_NOT_ALLOWED_WHILE_DC_IS_ACTIVE = 196

const IS_DEVICE_ALREADY_PAIRED = 197

const IS_SUBNETMASK_MISMATCH = 198

const IS_SUBNET_MISMATCH = 199

const IS_INVALID_IP_CONFIGURATION = 200

const IS_DEVICE_NOT_COMPATIBLE = 201

const IS_NETWORK_FRAME_SIZE_INCOMPATIBLE = 202

const IS_NETWORK_CONFIGURATION_INVALID = 203

const IS_ERROR_CPU_IDLE_STATES_CONFIGURATION = 204

const IS_DEVICE_BUSY = 205

const IS_SENSOR_INITIALIZATION_FAILED = 206

const IS_OFF = 0

const IS_ON = 1

const IS_IGNORE_PARAMETER = -1

const IS_USE_DEVICE_ID = 0x8000

const IS_ALLOW_STARTER_FW_UPLOAD = 0x00010000

const IS_GET_AUTO_EXIT_ENABLED = 0x8000

const IS_DISABLE_AUTO_EXIT = 0

const IS_ENABLE_AUTO_EXIT = 1

const IS_GET_LIVE = 0x8000

const IS_WAIT = 0x0001

const IS_DONT_WAIT = 0x0000

const IS_FORCE_VIDEO_STOP = 0x4000

const IS_FORCE_VIDEO_START = 0x4000

const IS_USE_NEXT_MEM = 0x8000

const IS_VIDEO_NOT_FINISH = 0

const IS_VIDEO_FINISH = 1

const IS_GET_RENDER_MODE = 0x8000

const IS_RENDER_DISABLED = 0x0000

const IS_RENDER_NORMAL = 0x0001

const IS_RENDER_FIT_TO_WINDOW = 0x0002

const IS_RENDER_DOWNSCALE_1_2 = 0x0004

const IS_RENDER_MIRROR_UPDOWN = 0x0010

const IS_RENDER_PLANAR_COLOR_RED = 0x0080

const IS_RENDER_PLANAR_COLOR_GREEN = 0x0100

const IS_RENDER_PLANAR_COLOR_BLUE = 0x0200

const IS_RENDER_PLANAR_MONO_RED = 0x0400

const IS_RENDER_PLANAR_MONO_GREEN = 0x0800

const IS_RENDER_PLANAR_MONO_BLUE = 0x1000

const IS_RENDER_ROTATE_90 = 0x0020

const IS_RENDER_ROTATE_180 = 0x0040

const IS_RENDER_ROTATE_270 = 0x2000

const IS_USE_AS_DC_STRUCTURE = 0x4000

const IS_USE_AS_DC_HANDLE = 0x8000

const IS_GET_EXTERNALTRIGGER = 0x8000

const IS_GET_TRIGGER_STATUS = 0x8001

const IS_GET_TRIGGER_MASK = 0x8002

const IS_GET_TRIGGER_INPUTS = 0x8003

const IS_GET_SUPPORTED_TRIGGER_MODE = 0x8004

const IS_GET_TRIGGER_COUNTER = 0x8000

const IS_SET_TRIGGER_MASK = 0x0100

const IS_SET_TRIGGER_CONTINUOUS = 0x1000

const IS_SET_TRIGGER_OFF = 0x0000

const IS_SET_TRIGGER_HI_LO = IS_SET_TRIGGER_CONTINUOUS | 0x0001

const IS_SET_TRIGGER_LO_HI = IS_SET_TRIGGER_CONTINUOUS | 0x0002

const IS_SET_TRIGGER_SOFTWARE = IS_SET_TRIGGER_CONTINUOUS | 0x0008

const IS_SET_TRIGGER_HI_LO_SYNC = 0x0010

const IS_SET_TRIGGER_LO_HI_SYNC = 0x0020

const IS_SET_TRIGGER_PRE_HI_LO = IS_SET_TRIGGER_CONTINUOUS | 0x0040

const IS_SET_TRIGGER_PRE_LO_HI = IS_SET_TRIGGER_CONTINUOUS | 0x0080

const IS_GET_TRIGGER_DELAY = 0x8000

const IS_GET_MIN_TRIGGER_DELAY = 0x8001

const IS_GET_MAX_TRIGGER_DELAY = 0x8002

const IS_GET_TRIGGER_DELAY_GRANULARITY = 0x8003

const IS_GET_PIXEL_CLOCK = 0x8000

const IS_GET_DEFAULT_PIXEL_CLK = 0x8001

const IS_GET_PIXEL_CLOCK_INC = 0x8005

const IS_GET_FRAMERATE = 0x8000

const IS_GET_DEFAULT_FRAMERATE = 0x8001

const IS_GET_MASTER_GAIN = 0x8000

const IS_GET_RED_GAIN = 0x8001

const IS_GET_GREEN_GAIN = 0x8002

const IS_GET_BLUE_GAIN = 0x8003

const IS_GET_DEFAULT_MASTER = 0x8004

const IS_GET_DEFAULT_RED = 0x8005

const IS_GET_DEFAULT_GREEN = 0x8006

const IS_GET_DEFAULT_BLUE = 0x8007

const IS_GET_GAINBOOST = 0x8008

const IS_SET_GAINBOOST_ON = 0x0001

const IS_SET_GAINBOOST_OFF = 0x0000

const IS_GET_SUPPORTED_GAINBOOST = 0x0002

const IS_MIN_GAIN = 0

const IS_MAX_GAIN = 100

const IS_GET_MASTER_GAIN_FACTOR = 0x8000

const IS_GET_RED_GAIN_FACTOR = 0x8001

const IS_GET_GREEN_GAIN_FACTOR = 0x8002

const IS_GET_BLUE_GAIN_FACTOR = 0x8003

const IS_SET_MASTER_GAIN_FACTOR = 0x8004

const IS_SET_RED_GAIN_FACTOR = 0x8005

const IS_SET_GREEN_GAIN_FACTOR = 0x8006

const IS_SET_BLUE_GAIN_FACTOR = 0x8007

const IS_GET_DEFAULT_MASTER_GAIN_FACTOR = 0x8008

const IS_GET_DEFAULT_RED_GAIN_FACTOR = 0x8009

const IS_GET_DEFAULT_GREEN_GAIN_FACTOR = 0x800a

const IS_GET_DEFAULT_BLUE_GAIN_FACTOR = 0x800b

const IS_INQUIRE_MASTER_GAIN_FACTOR = 0x800c

const IS_INQUIRE_RED_GAIN_FACTOR = 0x800d

const IS_INQUIRE_GREEN_GAIN_FACTOR = 0x800e

const IS_INQUIRE_BLUE_GAIN_FACTOR = 0x800f

const IS_SET_GLOBAL_SHUTTER_ON = 0x0001

const IS_SET_GLOBAL_SHUTTER_OFF = 0x0000

const IS_GET_GLOBAL_SHUTTER = 0x0010

const IS_GET_SUPPORTED_GLOBAL_SHUTTER = 0x0020

const IS_GET_BL_COMPENSATION = 0x8000

const IS_GET_BL_OFFSET = 0x8001

const IS_GET_BL_DEFAULT_MODE = 0x8002

const IS_GET_BL_DEFAULT_OFFSET = 0x8003

const IS_GET_BL_SUPPORTED_MODE = 0x8004

const IS_BL_COMPENSATION_DISABLE = 0

const IS_BL_COMPENSATION_ENABLE = 1

const IS_BL_COMPENSATION_OFFSET = 32

const IS_MIN_BL_OFFSET = 0

const IS_MAX_BL_OFFSET = 255

const IS_GET_HW_GAMMA = 0x8000

const IS_GET_HW_SUPPORTED_GAMMA = 0x8001

const IS_SET_HW_GAMMA_OFF = 0x0000

const IS_SET_HW_GAMMA_ON = 0x0001

const IS_GET_SATURATION_U = 0x8000

const IS_MIN_SATURATION_U = 0

const IS_MAX_SATURATION_U = 200

const IS_DEFAULT_SATURATION_U = 100

const IS_GET_SATURATION_V = 0x8001

const IS_MIN_SATURATION_V = 0

const IS_MAX_SATURATION_V = 200

const IS_DEFAULT_SATURATION_V = 100

const IS_AOI_IMAGE_SET_AOI = 0x0001

const IS_AOI_IMAGE_GET_AOI = 0x0002

const IS_AOI_IMAGE_SET_POS = 0x0003

const IS_AOI_IMAGE_GET_POS = 0x0004

const IS_AOI_IMAGE_SET_SIZE = 0x0005

const IS_AOI_IMAGE_GET_SIZE = 0x0006

const IS_AOI_IMAGE_GET_POS_MIN = 0x0007

const IS_AOI_IMAGE_GET_SIZE_MIN = 0x0008

const IS_AOI_IMAGE_GET_POS_MAX = 0x0009

const IS_AOI_IMAGE_GET_SIZE_MAX = 0x0010

const IS_AOI_IMAGE_GET_POS_INC = 0x0011

const IS_AOI_IMAGE_GET_SIZE_INC = 0x0012

const IS_AOI_IMAGE_GET_POS_X_ABS = 0x0013

const IS_AOI_IMAGE_GET_POS_Y_ABS = 0x0014

const IS_AOI_IMAGE_GET_ORIGINAL_AOI = 0x0015

const IS_AOI_IMAGE_POS_ABSOLUTE = 0x10000000

const IS_AOI_IMAGE_SET_POS_FAST = 0x0020

const IS_AOI_IMAGE_GET_POS_FAST_SUPPORTED = 0x0021

const IS_AOI_AUTO_BRIGHTNESS_SET_AOI = 0x0030

const IS_AOI_AUTO_BRIGHTNESS_GET_AOI = 0x0031

const IS_AOI_AUTO_WHITEBALANCE_SET_AOI = 0x0032

const IS_AOI_AUTO_WHITEBALANCE_GET_AOI = 0x0033

const IS_AOI_MULTI_GET_SUPPORTED_MODES = 0x0100

const IS_AOI_MULTI_SET_AOI = 0x0200

const IS_AOI_MULTI_GET_AOI = 0x0400

const IS_AOI_MULTI_DISABLE_AOI = 0x0800

const IS_AOI_MULTI_MODE_X_Y_AXES = 0x0001

const IS_AOI_MULTI_MODE_Y_AXES = 0x0002

const IS_AOI_MULTI_MODE_GET_MAX_NUMBER = 0x0003

const IS_AOI_MULTI_MODE_GET_DEFAULT = 0x0004

const IS_AOI_MULTI_MODE_ONLY_VERIFY_AOIS = 0x0005

const IS_AOI_MULTI_MODE_GET_MINIMUM_SIZE = 0x0006

const IS_AOI_MULTI_MODE_GET_ENABLED = 0x0007

const IS_AOI_MULTI_STATUS_SETBYUSER = 0x00000001

const IS_AOI_MULTI_STATUS_COMPLEMENT = 0x00000002

const IS_AOI_MULTI_STATUS_VALID = 0x00000004

const IS_AOI_MULTI_STATUS_CONFLICT = 0x00000008

const IS_AOI_MULTI_STATUS_ERROR = 0x00000010

const IS_AOI_MULTI_STATUS_UNUSED = 0x00000020

const IS_AOI_SEQUENCE_GET_SUPPORTED = 0x0050

const IS_AOI_SEQUENCE_SET_PARAMS = 0x0051

const IS_AOI_SEQUENCE_GET_PARAMS = 0x0052

const IS_AOI_SEQUENCE_SET_ENABLE = 0x0053

const IS_AOI_SEQUENCE_GET_ENABLE = 0x0054

const IS_AOI_SEQUENCE_INDEX_AOI_1 = 0

const IS_AOI_SEQUENCE_INDEX_AOI_2 = 1

const IS_AOI_SEQUENCE_INDEX_AOI_3 = 2

const IS_AOI_SEQUENCE_INDEX_AOI_4 = 4

const IS_GET_ROP_EFFECT = 0x8000

const IS_GET_SUPPORTED_ROP_EFFECT = 0x8001

const IS_SET_ROP_NONE = 0

const IS_SET_ROP_MIRROR_UPDOWN = 8

const IS_SET_ROP_MIRROR_UPDOWN_ODD = 16

const IS_SET_ROP_MIRROR_UPDOWN_EVEN = 32

const IS_SET_ROP_MIRROR_LEFTRIGHT = 64

const IS_GET_SUBSAMPLING = 0x8000

const IS_GET_SUPPORTED_SUBSAMPLING = 0x8001

const IS_GET_SUBSAMPLING_TYPE = 0x8002

const IS_GET_SUBSAMPLING_FACTOR_HORIZONTAL = 0x8004

const IS_GET_SUBSAMPLING_FACTOR_VERTICAL = 0x8008

const IS_SUBSAMPLING_DISABLE = 0x00

const IS_SUBSAMPLING_2X_VERTICAL = 0x0001

const IS_SUBSAMPLING_2X_HORIZONTAL = 0x0002

const IS_SUBSAMPLING_4X_VERTICAL = 0x0004

const IS_SUBSAMPLING_4X_HORIZONTAL = 0x0008

const IS_SUBSAMPLING_3X_VERTICAL = 0x0010

const IS_SUBSAMPLING_3X_HORIZONTAL = 0x0020

const IS_SUBSAMPLING_5X_VERTICAL = 0x0040

const IS_SUBSAMPLING_5X_HORIZONTAL = 0x0080

const IS_SUBSAMPLING_6X_VERTICAL = 0x0100

const IS_SUBSAMPLING_6X_HORIZONTAL = 0x0200

const IS_SUBSAMPLING_8X_VERTICAL = 0x0400

const IS_SUBSAMPLING_8X_HORIZONTAL = 0x0800

const IS_SUBSAMPLING_16X_VERTICAL = 0x1000

const IS_SUBSAMPLING_16X_HORIZONTAL = 0x2000

const IS_SUBSAMPLING_COLOR = 0x01

const IS_SUBSAMPLING_MONO = 0x02

const IS_SUBSAMPLING_MASK_VERTICAL = (((((IS_SUBSAMPLING_2X_VERTICAL | IS_SUBSAMPLING_4X_VERTICAL) | IS_SUBSAMPLING_3X_VERTICAL) | IS_SUBSAMPLING_5X_VERTICAL) | IS_SUBSAMPLING_6X_VERTICAL) | IS_SUBSAMPLING_8X_VERTICAL) | IS_SUBSAMPLING_16X_VERTICAL

const IS_SUBSAMPLING_MASK_HORIZONTAL = (((((IS_SUBSAMPLING_2X_HORIZONTAL | IS_SUBSAMPLING_4X_HORIZONTAL) | IS_SUBSAMPLING_3X_HORIZONTAL) | IS_SUBSAMPLING_5X_HORIZONTAL) | IS_SUBSAMPLING_6X_HORIZONTAL) | IS_SUBSAMPLING_8X_HORIZONTAL) | IS_SUBSAMPLING_16X_HORIZONTAL

const IS_GET_BINNING = 0x8000

const IS_GET_SUPPORTED_BINNING = 0x8001

const IS_GET_BINNING_TYPE = 0x8002

const IS_GET_BINNING_FACTOR_HORIZONTAL = 0x8004

const IS_GET_BINNING_FACTOR_VERTICAL = 0x8008

const IS_BINNING_DISABLE = 0x00

const IS_BINNING_2X_VERTICAL = 0x0001

const IS_BINNING_2X_HORIZONTAL = 0x0002

const IS_BINNING_4X_VERTICAL = 0x0004

const IS_BINNING_4X_HORIZONTAL = 0x0008

const IS_BINNING_3X_VERTICAL = 0x0010

const IS_BINNING_3X_HORIZONTAL = 0x0020

const IS_BINNING_5X_VERTICAL = 0x0040

const IS_BINNING_5X_HORIZONTAL = 0x0080

const IS_BINNING_6X_VERTICAL = 0x0100

const IS_BINNING_6X_HORIZONTAL = 0x0200

const IS_BINNING_8X_VERTICAL = 0x0400

const IS_BINNING_8X_HORIZONTAL = 0x0800

const IS_BINNING_16X_VERTICAL = 0x1000

const IS_BINNING_16X_HORIZONTAL = 0x2000

const IS_BINNING_COLOR = 0x01

const IS_BINNING_MONO = 0x02

const IS_BINNING_MASK_VERTICAL = (((((IS_BINNING_2X_VERTICAL | IS_BINNING_3X_VERTICAL) | IS_BINNING_4X_VERTICAL) | IS_BINNING_5X_VERTICAL) | IS_BINNING_6X_VERTICAL) | IS_BINNING_8X_VERTICAL) | IS_BINNING_16X_VERTICAL

const IS_BINNING_MASK_HORIZONTAL = (((((IS_BINNING_2X_HORIZONTAL | IS_BINNING_3X_HORIZONTAL) | IS_BINNING_4X_HORIZONTAL) | IS_BINNING_5X_HORIZONTAL) | IS_BINNING_6X_HORIZONTAL) | IS_BINNING_8X_HORIZONTAL) | IS_BINNING_16X_HORIZONTAL

const IS_SET_ENABLE_AUTO_GAIN = 0x8800

const IS_GET_ENABLE_AUTO_GAIN = 0x8801

const IS_SET_ENABLE_AUTO_SHUTTER = 0x8802

const IS_GET_ENABLE_AUTO_SHUTTER = 0x8803

const IS_SET_ENABLE_AUTO_WHITEBALANCE = 0x8804

const IS_GET_ENABLE_AUTO_WHITEBALANCE = 0x8805

const IS_SET_ENABLE_AUTO_FRAMERATE = 0x8806

const IS_GET_ENABLE_AUTO_FRAMERATE = 0x8807

const IS_SET_ENABLE_AUTO_SENSOR_GAIN = 0x8808

const IS_GET_ENABLE_AUTO_SENSOR_GAIN = 0x8809

const IS_SET_ENABLE_AUTO_SENSOR_SHUTTER = 0x8810

const IS_GET_ENABLE_AUTO_SENSOR_SHUTTER = 0x8811

const IS_SET_ENABLE_AUTO_SENSOR_GAIN_SHUTTER = 0x8812

const IS_GET_ENABLE_AUTO_SENSOR_GAIN_SHUTTER = 0x8813

const IS_SET_ENABLE_AUTO_SENSOR_FRAMERATE = 0x8814

const IS_GET_ENABLE_AUTO_SENSOR_FRAMERATE = 0x8815

const IS_SET_ENABLE_AUTO_SENSOR_WHITEBALANCE = 0x8816

const IS_GET_ENABLE_AUTO_SENSOR_WHITEBALANCE = 0x8817

const IS_SET_AUTO_REFERENCE = 0x8000

const IS_GET_AUTO_REFERENCE = 0x8001

const IS_SET_AUTO_GAIN_MAX = 0x8002

const IS_GET_AUTO_GAIN_MAX = 0x8003

const IS_SET_AUTO_SHUTTER_MAX = 0x8004

const IS_GET_AUTO_SHUTTER_MAX = 0x8005

const IS_SET_AUTO_SPEED = 0x8006

const IS_GET_AUTO_SPEED = 0x8007

const IS_SET_AUTO_WB_OFFSET = 0x8008

const IS_GET_AUTO_WB_OFFSET = 0x8009

const IS_SET_AUTO_WB_GAIN_RANGE = 0x800a

const IS_GET_AUTO_WB_GAIN_RANGE = 0x800b

const IS_SET_AUTO_WB_SPEED = 0x800c

const IS_GET_AUTO_WB_SPEED = 0x800d

const IS_SET_AUTO_WB_ONCE = 0x800e

const IS_GET_AUTO_WB_ONCE = 0x800f

const IS_SET_AUTO_BRIGHTNESS_ONCE = 0x8010

const IS_GET_AUTO_BRIGHTNESS_ONCE = 0x8011

const IS_SET_AUTO_HYSTERESIS = 0x8012

const IS_GET_AUTO_HYSTERESIS = 0x8013

const IS_GET_AUTO_HYSTERESIS_RANGE = 0x8014

const IS_SET_AUTO_WB_HYSTERESIS = 0x8015

const IS_GET_AUTO_WB_HYSTERESIS = 0x8016

const IS_GET_AUTO_WB_HYSTERESIS_RANGE = 0x8017

const IS_SET_AUTO_SKIPFRAMES = 0x8018

const IS_GET_AUTO_SKIPFRAMES = 0x8019

const IS_GET_AUTO_SKIPFRAMES_RANGE = 0x801a

const IS_SET_AUTO_WB_SKIPFRAMES = 0x801b

const IS_GET_AUTO_WB_SKIPFRAMES = 0x801c

const IS_GET_AUTO_WB_SKIPFRAMES_RANGE = 0x801d

const IS_SET_SENS_AUTO_SHUTTER_PHOTOM = 0x801e

const IS_SET_SENS_AUTO_GAIN_PHOTOM = 0x801f

const IS_GET_SENS_AUTO_SHUTTER_PHOTOM = 0x8020

const IS_GET_SENS_AUTO_GAIN_PHOTOM = 0x8021

const IS_GET_SENS_AUTO_SHUTTER_PHOTOM_DEF = 0x8022

const IS_GET_SENS_AUTO_GAIN_PHOTOM_DEF = 0x8023

const IS_SET_SENS_AUTO_CONTRAST_CORRECTION = 0x8024

const IS_GET_SENS_AUTO_CONTRAST_CORRECTION = 0x8025

const IS_GET_SENS_AUTO_CONTRAST_CORRECTION_RANGE = 0x8026

const IS_GET_SENS_AUTO_CONTRAST_CORRECTION_INC = 0x8027

const IS_GET_SENS_AUTO_CONTRAST_CORRECTION_DEF = 0x8028

const IS_SET_SENS_AUTO_CONTRAST_FDT_AOI_ENABLE = 0x8029

const IS_GET_SENS_AUTO_CONTRAST_FDT_AOI_ENABLE = 0x8030

const IS_SET_SENS_AUTO_BACKLIGHT_COMP = 0x8031

const IS_GET_SENS_AUTO_BACKLIGHT_COMP = 0x8032

const IS_GET_SENS_AUTO_BACKLIGHT_COMP_RANGE = 0x8033

const IS_GET_SENS_AUTO_BACKLIGHT_COMP_INC = 0x8034

const IS_GET_SENS_AUTO_BACKLIGHT_COMP_DEF = 0x8035

const IS_SET_ANTI_FLICKER_MODE = 0x8036

const IS_GET_ANTI_FLICKER_MODE = 0x8037

const IS_GET_ANTI_FLICKER_MODE_DEF = 0x8038

const IS_GET_AUTO_REFERENCE_DEF = 0x8039

const IS_GET_AUTO_WB_OFFSET_DEF = 0x803a

const IS_GET_AUTO_WB_OFFSET_MIN = 0x803b

const IS_GET_AUTO_WB_OFFSET_MAX = 0x803c

const IS_MIN_AUTO_BRIGHT_REFERENCE = 0

const IS_MAX_AUTO_BRIGHT_REFERENCE = 255

const IS_DEFAULT_AUTO_BRIGHT_REFERENCE = 128

const IS_MIN_AUTO_SPEED = 0

const IS_MAX_AUTO_SPEED = 100

const IS_DEFAULT_AUTO_SPEED = 50

const IS_DEFAULT_AUTO_WB_OFFSET = 0

const IS_MIN_AUTO_WB_OFFSET = -50

const IS_MAX_AUTO_WB_OFFSET = 50

const IS_DEFAULT_AUTO_WB_SPEED = 50

const IS_MIN_AUTO_WB_SPEED = 0

const IS_MAX_AUTO_WB_SPEED = 100

const IS_MIN_AUTO_WB_REFERENCE = 0

const IS_MAX_AUTO_WB_REFERENCE = 255

const IS_SET_AUTO_BRIGHT_AOI = 0x8000

const IS_GET_AUTO_BRIGHT_AOI = 0x8001

const IS_SET_IMAGE_AOI = 0x8002

const IS_GET_IMAGE_AOI = 0x8003

const IS_SET_AUTO_WB_AOI = 0x8004

const IS_GET_AUTO_WB_AOI = 0x8005

const IS_GET_COLOR_MODE = 0x8000

const IS_CM_FORMAT_PLANAR = 0x2000

const IS_CM_FORMAT_MASK = 0x2000

const IS_CM_ORDER_BGR = 0x0000

const IS_CM_ORDER_RGB = 0x0080

const IS_CM_ORDER_MASK = 0x0080

const IS_CM_PREFER_PACKED_SOURCE_FORMAT = 0x4000

const IS_CM_SENSOR_RAW8 = 11

const IS_CM_SENSOR_RAW10 = 33

const IS_CM_SENSOR_RAW12 = 27

const IS_CM_SENSOR_RAW16 = 29

const IS_CM_MONO8 = 6

const IS_CM_MONO10 = 34

const IS_CM_MONO12 = 26

const IS_CM_MONO16 = 28

const IS_CM_BGR5_PACKED = 3 | IS_CM_ORDER_BGR

const IS_CM_BGR565_PACKED = 2 | IS_CM_ORDER_BGR

const IS_CM_RGB8_PACKED = 1 | IS_CM_ORDER_RGB

const IS_CM_BGR8_PACKED = 1 | IS_CM_ORDER_BGR

const IS_CM_RGBA8_PACKED = 0 | IS_CM_ORDER_RGB

const IS_CM_BGRA8_PACKED = 0 | IS_CM_ORDER_BGR

const IS_CM_RGBY8_PACKED = 24 | IS_CM_ORDER_RGB

const IS_CM_BGRY8_PACKED = 24 | IS_CM_ORDER_BGR

const IS_CM_RGB10_PACKED = 25 | IS_CM_ORDER_RGB

const IS_CM_BGR10_PACKED = 25 | IS_CM_ORDER_BGR

const IS_CM_RGB10_UNPACKED = 35 | IS_CM_ORDER_RGB

const IS_CM_BGR10_UNPACKED = 35 | IS_CM_ORDER_BGR

const IS_CM_RGB12_UNPACKED = 30 | IS_CM_ORDER_RGB

const IS_CM_BGR12_UNPACKED = 30 | IS_CM_ORDER_BGR

const IS_CM_RGBA12_UNPACKED = 31 | IS_CM_ORDER_RGB

const IS_CM_BGRA12_UNPACKED = 31 | IS_CM_ORDER_BGR

const IS_CM_JPEG = 32

const IS_CM_UYVY_PACKED = 12

const IS_CM_UYVY_MONO_PACKED = 13

const IS_CM_UYVY_BAYER_PACKED = 14

const IS_CM_CBYCRY_PACKED = 23

const IS_CM_RGB8_PLANAR = (1 | IS_CM_ORDER_RGB) | IS_CM_FORMAT_PLANAR

const IS_CM_ALL_POSSIBLE = 0xffff

const IS_CM_MODE_MASK = 0x007f

const IS_HOTPIXEL_DISABLE_CORRECTION = 0x0000

const IS_HOTPIXEL_ENABLE_SENSOR_CORRECTION = 0x0001

const IS_HOTPIXEL_ENABLE_CAMERA_CORRECTION = 0x0002

const IS_HOTPIXEL_ENABLE_SOFTWARE_USER_CORRECTION = 0x0004

const IS_HOTPIXEL_DISABLE_SENSOR_CORRECTION = 0x0008

const IS_HOTPIXEL_GET_CORRECTION_MODE = 0x8000

const IS_HOTPIXEL_GET_SUPPORTED_CORRECTION_MODES = 0x8001

const IS_HOTPIXEL_GET_SOFTWARE_USER_LIST_EXISTS = 0x8100

const IS_HOTPIXEL_GET_SOFTWARE_USER_LIST_NUMBER = 0x8101

const IS_HOTPIXEL_GET_SOFTWARE_USER_LIST = 0x8102

const IS_HOTPIXEL_SET_SOFTWARE_USER_LIST = 0x8103

const IS_HOTPIXEL_SAVE_SOFTWARE_USER_LIST = 0x8104

const IS_HOTPIXEL_LOAD_SOFTWARE_USER_LIST = 0x8105

const IS_HOTPIXEL_GET_CAMERA_FACTORY_LIST_EXISTS = 0x8106

const IS_HOTPIXEL_GET_CAMERA_FACTORY_LIST_NUMBER = 0x8107

const IS_HOTPIXEL_GET_CAMERA_FACTORY_LIST = 0x8108

const IS_HOTPIXEL_GET_CAMERA_USER_LIST_EXISTS = 0x8109

const IS_HOTPIXEL_GET_CAMERA_USER_LIST_NUMBER = 0x810a

const IS_HOTPIXEL_GET_CAMERA_USER_LIST = 0x810b

const IS_HOTPIXEL_SET_CAMERA_USER_LIST = 0x810c

const IS_HOTPIXEL_GET_CAMERA_USER_LIST_MAX_NUMBER = 0x810d

const IS_HOTPIXEL_DELETE_CAMERA_USER_LIST = 0x810e

const IS_HOTPIXEL_GET_MERGED_CAMERA_LIST_NUMBER = 0x810f

const IS_HOTPIXEL_GET_MERGED_CAMERA_LIST = 0x8110

const IS_HOTPIXEL_SAVE_SOFTWARE_USER_LIST_UNICODE = 0x8111

const IS_HOTPIXEL_LOAD_SOFTWARE_USER_LIST_UNICODE = 0x8112

const IS_GET_CCOR_MODE = 0x8000

const IS_GET_SUPPORTED_CCOR_MODE = 0x8001

const IS_GET_DEFAULT_CCOR_MODE = 0x8002

const IS_GET_CCOR_FACTOR = 0x8003

const IS_GET_CCOR_FACTOR_MIN = 0x8004

const IS_GET_CCOR_FACTOR_MAX = 0x8005

const IS_GET_CCOR_FACTOR_DEFAULT = 0x8006

const IS_CCOR_DISABLE = 0x0000

const IS_CCOR_ENABLE = 0x0001

const IS_CCOR_ENABLE_NORMAL = IS_CCOR_ENABLE

const IS_CCOR_ENABLE_BG40_ENHANCED = 0x0002

const IS_CCOR_ENABLE_HQ_ENHANCED = 0x0004

const IS_CCOR_SET_IR_AUTOMATIC = 0x0080

const IS_CCOR_FACTOR = 0x0100

const IS_CCOR_ENABLE_MASK = (IS_CCOR_ENABLE_NORMAL | IS_CCOR_ENABLE_BG40_ENHANCED) | IS_CCOR_ENABLE_HQ_ENHANCED

const IS_GET_BAYER_CV_MODE = 0x8000

const IS_SET_BAYER_CV_NORMAL = 0x0000

const IS_SET_BAYER_CV_BETTER = 0x0001

const IS_SET_BAYER_CV_BEST = 0x0002

const IS_CONV_MODE_NONE = 0x0000

const IS_CONV_MODE_SOFTWARE = 0x0001

const IS_CONV_MODE_SOFTWARE_3X3 = 0x0002

const IS_CONV_MODE_SOFTWARE_5X5 = 0x0004

const IS_CONV_MODE_HARDWARE_3X3 = 0x0008

const IS_CONV_MODE_OPENCL_3X3 = 0x0020

const IS_CONV_MODE_OPENCL_5X5 = 0x0040

const IS_CONV_MODE_JPEG = 0x0100

const IS_GET_EDGE_ENHANCEMENT = 0x8000

const IS_EDGE_EN_DISABLE = 0

const IS_EDGE_EN_STRONG = 1

const IS_EDGE_EN_WEAK = 2

const IS_GET_WB_MODE = 0x8000

const IS_SET_WB_DISABLE = 0x0000

const IS_SET_WB_USER = 0x0001

const IS_SET_WB_AUTO_ENABLE = 0x0002

const IS_SET_WB_AUTO_ENABLE_ONCE = 0x0004

const IS_SET_WB_DAYLIGHT_65 = 0x0101

const IS_SET_WB_COOL_WHITE = 0x0102

const IS_SET_WB_U30 = 0x0103

const IS_SET_WB_ILLUMINANT_A = 0x0104

const IS_SET_WB_HORIZON = 0x0105

const IS_EEPROM_MIN_USER_ADDRESS = 0

const IS_EEPROM_MAX_USER_ADDRESS = 63

const IS_EEPROM_MAX_USER_SPACE = 64

const IS_GET_ERR_REP_MODE = 0x8000

const IS_ENABLE_ERR_REP = 1

const IS_DISABLE_ERR_REP = 0

const IS_GET_DISPLAY_MODE = 0x8000

const IS_SET_DM_DIB = 1

const IS_SET_DM_DIRECT3D = 4

const IS_SET_DM_OPENGL = 8

const IS_SET_DM_MONO = 0x0800

const IS_SET_DM_BAYER = 0x1000

const IS_SET_DM_YCBCR = 0x4000

const DR_GET_OVERLAY_DC = 1

const DR_GET_MAX_OVERLAY_SIZE = 2

const DR_GET_OVERLAY_KEY_COLOR = 3

const DR_RELEASE_OVERLAY_DC = 4

const DR_SHOW_OVERLAY = 5

const DR_HIDE_OVERLAY = 6

const DR_SET_OVERLAY_SIZE = 7

const DR_SET_OVERLAY_POSITION = 8

const DR_SET_OVERLAY_KEY_COLOR = 9

const DR_SET_HWND = 10

const DR_ENABLE_SCALING = 11

const DR_DISABLE_SCALING = 12

const DR_CLEAR_OVERLAY = 13

const DR_ENABLE_SEMI_TRANSPARENT_OVERLAY = 14

const DR_DISABLE_SEMI_TRANSPARENT_OVERLAY = 15

const DR_CHECK_COMPATIBILITY = 16

const DR_SET_VSYNC_OFF = 17

const DR_SET_VSYNC_AUTO = 18

const DR_SET_USER_SYNC = 19

const DR_GET_USER_SYNC_POSITION_RANGE = 20

const DR_LOAD_OVERLAY_FROM_FILE = 21

const DR_STEAL_NEXT_FRAME = 22

const DR_SET_STEAL_FORMAT = 23

const DR_GET_STEAL_FORMAT = 24

const DR_ENABLE_IMAGE_SCALING = 25

const DR_GET_OVERLAY_SIZE = 26

const DR_CHECK_COLOR_MODE_SUPPORT = 27

const DR_GET_OVERLAY_DATA = 28

const DR_UPDATE_OVERLAY_DATA = 29

const DR_GET_SUPPORTED = 30

const IS_SAVE_USE_ACTUAL_IMAGE_SIZE = 0x00010000

const IS_RENUM_BY_CAMERA = 0

const IS_RENUM_BY_HOST = 1

const IS_SET_EVENT_ODD = 0

const IS_SET_EVENT_EVEN = 1

const IS_SET_EVENT_FRAME = 2

const IS_SET_EVENT_EXTTRIG = 3

const IS_SET_EVENT_VSYNC = 4

const IS_SET_EVENT_SEQ = 5

const IS_SET_EVENT_STEAL = 6

const IS_SET_EVENT_VPRES = 7

const IS_SET_EVENT_CAPTURE_STATUS = 8

const IS_SET_EVENT_TRANSFER_FAILED = IS_SET_EVENT_CAPTURE_STATUS

const IS_SET_EVENT_DEVICE_RECONNECTED = 9

const IS_SET_EVENT_MEMORY_MODE_FINISH = 10

const IS_SET_EVENT_FRAME_RECEIVED = 11

const IS_SET_EVENT_WB_FINISHED = 12

const IS_SET_EVENT_AUTOBRIGHTNESS_FINISHED = 13

const IS_SET_EVENT_OVERLAY_DATA_LOST = 16

const IS_SET_EVENT_CAMERA_MEMORY = 17

const IS_SET_EVENT_CONNECTIONSPEED_CHANGED = 18

const IS_SET_EVENT_AUTOFOCUS_FINISHED = 19

const IS_SET_EVENT_FIRST_PACKET_RECEIVED = 20

const IS_SET_EVENT_PMC_IMAGE_PARAMS_CHANGED = 21

const IS_SET_EVENT_DEVICE_PLUGGED_IN = 22

const IS_SET_EVENT_DEVICE_UNPLUGGED = 23

const IS_SET_EVENT_TEMPERATURE_STATUS = 24

const IS_SET_EVENT_REMOVE = 128

const IS_SET_EVENT_REMOVAL = 129

const IS_SET_EVENT_NEW_DEVICE = 130

const IS_SET_EVENT_STATUS_CHANGED = 131

const WM_USER = 0x400

const IS_UC480_MESSAGE = WM_USER + 0x0100

const IS_FRAME = 0x0000

const IS_SEQUENCE = 0x0001

const IS_TRIGGER = 0x0002

const IS_CAPTURE_STATUS = 0x0003

const IS_TRANSFER_FAILED = IS_CAPTURE_STATUS

const IS_DEVICE_RECONNECTED = 0x0004

const IS_MEMORY_MODE_FINISH = 0x0005

const IS_FRAME_RECEIVED = 0x0006

const IS_GENERIC_ERROR = 0x0007

const IS_STEAL_VIDEO = 0x0008

const IS_WB_FINISHED = 0x0009

const IS_AUTOBRIGHTNESS_FINISHED = 0x000a

const IS_OVERLAY_DATA_LOST = 0x000b

const IS_CAMERA_MEMORY = 0x000c

const IS_CONNECTIONSPEED_CHANGED = 0x000d

const IS_AUTOFOCUS_FINISHED = 0x000e

const IS_FIRST_PACKET_RECEIVED = 0x000f

const IS_PMC_IMAGE_PARAMS_CHANGED = 0x0010

const IS_DEVICE_PLUGGED_IN = 0x0011

const IS_DEVICE_UNPLUGGED = 0x0012

const IS_TEMPERATURE_STATUS = 0x0013

const IS_DEVICE_REMOVED = 0x1000

const IS_DEVICE_REMOVAL = 0x1001

const IS_NEW_DEVICE = 0x1002

const IS_DEVICE_STATUS_CHANGED = 0x1003

const IS_GET_CAMERA_ID = 0x8000

const IS_GET_STATUS = 0x8000

const IS_EXT_TRIGGER_EVENT_CNT = 0

const IS_FIFO_OVR_CNT = 1

const IS_SEQUENCE_CNT = 2

const IS_LAST_FRAME_FIFO_OVR = 3

const IS_SEQUENCE_SIZE = 4

const IS_VIDEO_PRESENT = 5

const IS_STEAL_FINISHED = 6

const IS_STORE_FILE_PATH = 7

const IS_LUMA_BANDWIDTH_FILTER = 8

const IS_BOARD_REVISION = 9

const IS_MIRROR_BITMAP_UPDOWN = 10

const IS_BUS_OVR_CNT = 11

const IS_STEAL_ERROR_CNT = 12

const IS_LOW_COLOR_REMOVAL = 13

const IS_CHROMA_COMB_FILTER = 14

const IS_CHROMA_AGC = 15

const IS_WATCHDOG_ON_BOARD = 16

const IS_PASSTHROUGH_ON_BOARD = 17

const IS_EXTERNAL_VREF_MODE = 18

const IS_WAIT_TIMEOUT = 19

const IS_TRIGGER_MISSED = 20

const IS_LAST_CAPTURE_ERROR = 21

const IS_PARAMETER_SET_1 = 22

const IS_PARAMETER_SET_2 = 23

const IS_STANDBY = 24

const IS_STANDBY_SUPPORTED = 25

const IS_QUEUED_IMAGE_EVENT_CNT = 26

const IS_PARAMETER_EXT = 27

const IS_INTERFACE_TYPE_USB = 0x40

const IS_INTERFACE_TYPE_USB3 = 0x60

const IS_INTERFACE_TYPE_ETH = 0x80

const IS_INTERFACE_TYPE_PMC = 0xf0

const IS_BOARD_TYPE_UC480_USB = IS_INTERFACE_TYPE_USB + 0

const IS_BOARD_TYPE_UC480_USB_SE = IS_BOARD_TYPE_UC480_USB

const IS_BOARD_TYPE_UC480_USB_RE = IS_BOARD_TYPE_UC480_USB

const IS_BOARD_TYPE_UC480_USB_ME = IS_INTERFACE_TYPE_USB + 0x01

const IS_BOARD_TYPE_UC480_USB_LE = IS_INTERFACE_TYPE_USB + 0x02

const IS_BOARD_TYPE_UC480_USB_XS = IS_INTERFACE_TYPE_USB + 0x03

const IS_BOARD_TYPE_UC480_USB_ML = IS_INTERFACE_TYPE_USB + 0x05

const IS_BOARD_TYPE_UC480_USB3_LE = IS_INTERFACE_TYPE_USB3 + 0x02

const IS_BOARD_TYPE_UC480_USB3_XC = IS_INTERFACE_TYPE_USB3 + 0x03

const IS_BOARD_TYPE_UC480_USB3_CP = IS_INTERFACE_TYPE_USB3 + 0x04

const IS_BOARD_TYPE_UC480_USB3_ML = IS_INTERFACE_TYPE_USB3 + 0x05

const IS_BOARD_TYPE_UC480_ETH = IS_INTERFACE_TYPE_ETH

const IS_BOARD_TYPE_UC480_ETH_HE = IS_BOARD_TYPE_UC480_ETH

const IS_BOARD_TYPE_UC480_ETH_SE = IS_INTERFACE_TYPE_ETH + 0x01

const IS_BOARD_TYPE_UC480_ETH_RE = IS_BOARD_TYPE_UC480_ETH_SE

const IS_BOARD_TYPE_UC480_ETH_LE = IS_INTERFACE_TYPE_ETH + 0x02

const IS_BOARD_TYPE_UC480_ETH_CP = IS_INTERFACE_TYPE_ETH + 0x04

const IS_BOARD_TYPE_UC480_ETH_SEP = IS_INTERFACE_TYPE_ETH + 0x06

const IS_BOARD_TYPE_UC480_ETH_REP = IS_BOARD_TYPE_UC480_ETH_SEP

const IS_BOARD_TYPE_UC480_ETH_LEET = IS_INTERFACE_TYPE_ETH + 0x07

const IS_BOARD_TYPE_UC480_ETH_TE = IS_INTERFACE_TYPE_ETH + 0x08

const IS_CAMERA_TYPE_UC480_USB = IS_BOARD_TYPE_UC480_USB_SE

const IS_CAMERA_TYPE_UC480_USB_SE = IS_BOARD_TYPE_UC480_USB_SE

const IS_CAMERA_TYPE_UC480_USB_RE = IS_BOARD_TYPE_UC480_USB_RE

const IS_CAMERA_TYPE_UC480_USB_ME = IS_BOARD_TYPE_UC480_USB_ME

const IS_CAMERA_TYPE_UC480_USB_LE = IS_BOARD_TYPE_UC480_USB_LE

const IS_CAMERA_TYPE_UC480_USB_ML = IS_BOARD_TYPE_UC480_USB_ML

const IS_CAMERA_TYPE_UC480_USB3_LE = IS_BOARD_TYPE_UC480_USB3_LE

const IS_CAMERA_TYPE_UC480_USB3_XC = IS_BOARD_TYPE_UC480_USB3_XC

const IS_CAMERA_TYPE_UC480_USB3_CP = IS_BOARD_TYPE_UC480_USB3_CP

const IS_CAMERA_TYPE_UC480_USB3_ML = IS_BOARD_TYPE_UC480_USB3_ML

const IS_CAMERA_TYPE_UC480_ETH = IS_BOARD_TYPE_UC480_ETH_HE

const IS_CAMERA_TYPE_UC480_ETH_HE = IS_BOARD_TYPE_UC480_ETH_HE

const IS_CAMERA_TYPE_UC480_ETH_SE = IS_BOARD_TYPE_UC480_ETH_SE

const IS_CAMERA_TYPE_UC480_ETH_RE = IS_BOARD_TYPE_UC480_ETH_RE

const IS_CAMERA_TYPE_UC480_ETH_LE = IS_BOARD_TYPE_UC480_ETH_LE

const IS_CAMERA_TYPE_UC480_ETH_CP = IS_BOARD_TYPE_UC480_ETH_CP

const IS_CAMERA_TYPE_UC480_ETH_SEP = IS_BOARD_TYPE_UC480_ETH_SEP

const IS_CAMERA_TYPE_UC480_ETH_REP = IS_BOARD_TYPE_UC480_ETH_REP

const IS_CAMERA_TYPE_UC480_ETH_LEET = IS_BOARD_TYPE_UC480_ETH_LEET

const IS_CAMERA_TYPE_UC480_ETH_TE = IS_BOARD_TYPE_UC480_ETH_TE

const IS_CAMERA_TYPE_UC480_PMC = IS_INTERFACE_TYPE_PMC + 0x01

const IS_OS_UNDETERMINED = 0

const IS_OS_WIN95 = 1

const IS_OS_WINNT40 = 2

const IS_OS_WIN98 = 3

const IS_OS_WIN2000 = 4

const IS_OS_WINXP = 5

const IS_OS_WINME = 6

const IS_OS_WINNET = 7

const IS_OS_WINSERVER2003 = 8

const IS_OS_WINVISTA = 9

const IS_OS_LINUX24 = 10

const IS_OS_LINUX26 = 11

const IS_OS_WIN7 = 12

const IS_OS_WIN8 = 13

const IS_OS_WIN8SERVER = 14

const IS_OS_GREATER_THAN_WIN8 = 15

const IS_USB_10 = 0x0001

const IS_USB_11 = 0x0002

const IS_USB_20 = 0x0004

const IS_USB_30 = 0x0008

const IS_ETHERNET_10 = 0x0080

const IS_ETHERNET_100 = 0x0100

const IS_ETHERNET_1000 = 0x0200

const IS_ETHERNET_10000 = 0x0400

const IS_USB_LOW_SPEED = 1

const IS_USB_FULL_SPEED = 12

const IS_USB_HIGH_SPEED = 480

const IS_USB_SUPER_SPEED = 4000

const IS_ETHERNET_10Base = 10

const IS_ETHERNET_100Base = 100

const IS_ETHERNET_1000Base = 1000

const IS_ETHERNET_10GBase = 10000

const IS_HDR_NOT_SUPPORTED = 0

const IS_HDR_KNEEPOINTS = 1

const IS_DISABLE_HDR = 0

const IS_ENABLE_HDR = 1

const IS_TEST_IMAGE_NONE = 0x00000000

const IS_TEST_IMAGE_WHITE = 0x00000001

const IS_TEST_IMAGE_BLACK = 0x00000002

const IS_TEST_IMAGE_HORIZONTAL_GREYSCALE = 0x00000004

const IS_TEST_IMAGE_VERTICAL_GREYSCALE = 0x00000008

const IS_TEST_IMAGE_DIAGONAL_GREYSCALE = 0x00000010

const IS_TEST_IMAGE_WEDGE_GRAY = 0x00000020

const IS_TEST_IMAGE_WEDGE_COLOR = 0x00000040

const IS_TEST_IMAGE_ANIMATED_WEDGE_GRAY = 0x00000080

const IS_TEST_IMAGE_ANIMATED_WEDGE_COLOR = 0x00000100

const IS_TEST_IMAGE_MONO_BARS = 0x00000200

const IS_TEST_IMAGE_COLOR_BARS1 = 0x00000400

const IS_TEST_IMAGE_COLOR_BARS2 = 0x00000800

const IS_TEST_IMAGE_GREYSCALE1 = 0x00001000

const IS_TEST_IMAGE_GREY_AND_COLOR_BARS = 0x00002000

const IS_TEST_IMAGE_MOVING_GREY_AND_COLOR_BARS = 0x00004000

const IS_TEST_IMAGE_ANIMATED_LINE = 0x00008000

const IS_TEST_IMAGE_ALTERNATE_PATTERN = 0x00010000

const IS_TEST_IMAGE_VARIABLE_GREY = 0x00020000

const IS_TEST_IMAGE_MONOCHROME_HORIZONTAL_BARS = 0x00040000

const IS_TEST_IMAGE_MONOCHROME_VERTICAL_BARS = 0x00080000

const IS_TEST_IMAGE_CURSOR_V = 0x00200000

const IS_TEST_IMAGE_COLDPIXEL_GRID = 0x00400000

const IS_TEST_IMAGE_HOTPIXEL_GRID = 0x00800000

const IS_TEST_IMAGE_VARIABLE_RED_PART = 0x01000000

const IS_TEST_IMAGE_VARIABLE_GREEN_PART = 0x02000000

const IS_TEST_IMAGE_VARIABLE_BLUE_PART = 0x04000000

const IS_TEST_IMAGE_SHADING_IMAGE = 0x08000000

const IS_TEST_IMAGE_WEDGE_GRAY_SENSOR = 0x10000000

const IS_TEST_IMAGE_ANIMATED_WEDGE_GRAY_SENSOR = 0x20000000

const IS_TEST_IMAGE_RAMPING_PATTERN = 0x40000000

const IS_TEST_IMAGE_CHESS_PATTERN = 0x80000000

const IS_DISABLE_SENSOR_SCALER = 0

const IS_ENABLE_SENSOR_SCALER = 1

const IS_ENABLE_ANTI_ALIASING = 2

const IS_TRIGGER_TIMEOUT = 0

const IS_BEST_PCLK_RUN_ONCE = 0

const IS_LOCK_LAST_BUFFER = 0x8002

const IS_GET_ALLOC_ID_OF_THIS_BUF = 0x8004

const IS_GET_ALLOC_ID_OF_LAST_BUF = 0x8008

const IS_USE_ALLOC_ID = 0x8000

const IS_USE_CURRENT_IMG_SIZE = 0xc000

const IS_GET_D3D_MEM = 0x8000

const IS_IMG_BMP = 0

const IS_IMG_JPG = 1

const IS_IMG_PNG = 2

const IS_IMG_RAW = 4

const IS_IMG_TIF = 8

const IS_I2C_16_BIT_REGISTER = 0x10000000

const IS_I2C_0_BIT_REGISTER = 0x20000000

const IS_I2C_DONT_WAIT = 0x00800000

const IS_GET_GAMMA_MODE = 0x8000

const IS_SET_GAMMA_OFF = 0

const IS_SET_GAMMA_ON = 1

const IS_GET_CAPTURE_MODE = 0x8000

const IS_SET_CM_ODD = 0x0001

const IS_SET_CM_EVEN = 0x0002

const IS_SET_CM_FRAME = 0x0004

const IS_SET_CM_NONINTERLACED = 0x0008

const IS_SET_CM_NEXT_FRAME = 0x0010

const IS_SET_CM_NEXT_FIELD = 0x0020

const IS_SET_CM_BOTHFIELDS = (IS_SET_CM_ODD | IS_SET_CM_EVEN) | IS_SET_CM_NONINTERLACED

const IS_SET_CM_FRAME_STEREO = 0x2004

# Skipping MacroDefinition: USBCAMEXP extern __declspec ( dllimport ) INT __cdecl

# Skipping MacroDefinition: USBCAMEXPUL extern __declspec ( dllimport ) ULONG __cdecl

const IS_INVALID_HCAM = HCAM(0)

const IS_INVALID_HFALC = HCAM(0)

const FALCINFO = BOARDINFO

const PFALCINFO = PBOARDINFO

const CAMINFO = BOARDINFO

const PCAMINFO = PBOARDINFO

const FIRMWARE_DOWNLOAD_NOT_SUPPORTED = 0x00000001

const INTERFACE_SPEED_NOT_SUPPORTED = 0x00000002

const INVALID_SENSOR_DETECTED = 0x00000004

const AUTHORIZATION_FAILED = 0x00000008

const DEVSTS_INCLUDED_STARTER_FIRMWARE_INCOMPATIBLE = 0x00000010

const AC_SHUTTER = 0x00000001

const AC_GAIN = 0x00000002

const AC_WHITEBAL = 0x00000004

const AC_WB_RED_CHANNEL = 0x00000008

const AC_WB_GREEN_CHANNEL = 0x00000010

const AC_WB_BLUE_CHANNEL = 0x00000020

const AC_FRAMERATE = 0x00000040

const AC_SENSOR_SHUTTER = 0x00000080

const AC_SENSOR_GAIN = 0x00000100

const AC_SENSOR_GAIN_SHUTTER = 0x00000200

const AC_SENSOR_FRAMERATE = 0x00000400

const AC_SENSOR_WB = 0x00000800

const AC_SENSOR_AUTO_REFERENCE = 0x00001000

const AC_SENSOR_AUTO_SPEED = 0x00002000

const AC_SENSOR_AUTO_HYSTERESIS = 0x00004000

const AC_SENSOR_AUTO_SKIPFRAMES = 0x00008000

const AC_SENSOR_AUTO_CONTRAST_CORRECTION = 0x00010000

const AC_SENSOR_AUTO_CONTRAST_FDT_AOI = 0x00020000

const AC_SENSOR_AUTO_BACKLIGHT_COMP = 0x00040000

const ACS_ADJUSTING = 0x00000001

const ACS_FINISHED = 0x00000002

const ACS_DISABLED = 0x00000004

const IS_BOOTBOOST_ID_MIN = 1

const IS_BOOTBOOST_ID_MAX = 254

const IS_BOOTBOOST_ID_NONE = 0

const IS_BOOTBOOST_ID_ALL = 255

const IS_BOOTBOOST_DEFAULT_WAIT_TIMEOUT_SEC = 60

# Skipping MacroDefinition: IS_BOOTBOOST_IDLIST_HEADERSIZE ( sizeof ( DWORD ) )

# Skipping MacroDefinition: IS_BOOTBOOST_IDLIST_ELEMENTSIZE ( sizeof ( IS_BOOTBOOST_ID ) )

const IO_LED_STATE_1 = 0

const IO_LED_STATE_2 = 1

const IO_FLASH_MODE_OFF = 0

const IO_FLASH_MODE_TRIGGER_LO_ACTIVE = 1

const IO_FLASH_MODE_TRIGGER_HI_ACTIVE = 2

const IO_FLASH_MODE_CONSTANT_HIGH = 3

const IO_FLASH_MODE_CONSTANT_LOW = 4

const IO_FLASH_MODE_FREERUN_LO_ACTIVE = 5

const IO_FLASH_MODE_FREERUN_HI_ACTIVE = 6

const IS_FLASH_MODE_PWM = 0x8000

const IO_FLASH_MODE_GPIO_1 = 0x0010

const IO_FLASH_MODE_GPIO_2 = 0x0020

const IO_FLASH_MODE_GPIO_3 = 0x0040

const IO_FLASH_MODE_GPIO_4 = 0x0080

const IO_FLASH_MODE_GPIO_5 = 0x0100

const IO_FLASH_MODE_GPIO_6 = 0x0200

const IO_FLASH_GPIO_PORT_MASK = ((((IO_FLASH_MODE_GPIO_1 | IO_FLASH_MODE_GPIO_2) | IO_FLASH_MODE_GPIO_3) | IO_FLASH_MODE_GPIO_4) | IO_FLASH_MODE_GPIO_5) | IO_FLASH_MODE_GPIO_6

const IO_GPIO_1 = 0x0001

const IO_GPIO_2 = 0x0002

const IO_GPIO_3 = 0x0004

const IO_GPIO_4 = 0x0008

const IO_GPIO_5 = 0x0010

const IO_GPIO_6 = 0x0020

const IS_GPIO_INPUT = 0x0001

const IS_GPIO_OUTPUT = 0x0002

const IS_GPIO_FLASH = 0x0004

const IS_GPIO_PWM = 0x0008

const IS_GPIO_COMPORT_RX = 0x0010

const IS_GPIO_COMPORT_TX = 0x0020

const IS_GPIO_MULTI_INTEGRATION_MODE = 0x0040

const IS_GPIO_TRIGGER = 0x0080

const IS_GPIO_I2C = 0x0100

const IS_FLASH_AUTO_FREERUN_OFF = 0

const IS_FLASH_AUTO_FREERUN_ON = 1

const IS_AWB_GREYWORLD = 0x0001

const IS_AWB_COLOR_TEMPERATURE = 0x0002

const IS_AUTOPARAMETER_DISABLE = 0

const IS_AUTOPARAMETER_ENABLE = 1

const IS_AUTOPARAMETER_ENABLE_RUNONCE = 2

const IS_LUT_64 = 64

const IS_LUT_128 = 128

const IS_LUT_PRESET_ID_IDENTITY = 0

const IS_LUT_PRESET_ID_NEGATIVE = 1

const IS_LUT_PRESET_ID_GLOW1 = 2

const IS_LUT_PRESET_ID_GLOW2 = 3

const IS_LUT_PRESET_ID_ASTRO1 = 4

const IS_LUT_PRESET_ID_RAINBOW1 = 5

const IS_LUT_PRESET_ID_MAP1 = 6

const IS_LUT_PRESET_ID_HOT = 7

const IS_LUT_PRESET_ID_SEPIC = 8

const IS_LUT_PRESET_ID_ONLY_RED = 9

const IS_LUT_PRESET_ID_ONLY_GREEN = 10

const IS_LUT_PRESET_ID_ONLY_BLUE = 11

const IS_LUT_PRESET_ID_DIGITAL_GAIN_2X = 12

const IS_LUT_PRESET_ID_DIGITAL_GAIN_4X = 13

const IS_LUT_PRESET_ID_DIGITAL_GAIN_8X = 14

const IS_LUT_CMD_SET_ENABLED = 0x0001

const IS_LUT_CMD_SET_MODE = 0x0002

const IS_LUT_CMD_GET_STATE = 0x0005

const IS_LUT_CMD_GET_SUPPORT_INFO = 0x0006

const IS_LUT_CMD_SET_USER_LUT = 0x0010

const IS_LUT_CMD_GET_USER_LUT = 0x0011

const IS_LUT_CMD_GET_COMPLETE_LUT = 0x0012

const IS_LUT_CMD_GET_PRESET_LUT = 0x0013

const IS_LUT_CMD_LOAD_FILE = 0x0100

const IS_LUT_CMD_SAVE_FILE = 0x0101

const IS_LUT_STATE_ID_FLAG_HARDWARE = 0x0010

const IS_LUT_STATE_ID_FLAG_SOFTWARE = 0x0020

const IS_LUT_STATE_ID_FLAG_GAMMA = 0x0100

const IS_LUT_STATE_ID_FLAG_LUT = 0x0200

const IS_LUT_STATE_ID_INACTIVE = 0x0000

const IS_LUT_STATE_ID_NOT_SUPPORTED = 0x0001

const IS_LUT_STATE_ID_HARDWARE_LUT = IS_LUT_STATE_ID_FLAG_HARDWARE | IS_LUT_STATE_ID_FLAG_LUT

const IS_LUT_STATE_ID_HARDWARE_GAMMA = IS_LUT_STATE_ID_FLAG_HARDWARE | IS_LUT_STATE_ID_FLAG_GAMMA

const IS_LUT_STATE_ID_HARDWARE_LUTANDGAMMA = (IS_LUT_STATE_ID_FLAG_HARDWARE | IS_LUT_STATE_ID_FLAG_LUT) | IS_LUT_STATE_ID_FLAG_GAMMA

const IS_LUT_STATE_ID_SOFTWARE_LUT = IS_LUT_STATE_ID_FLAG_SOFTWARE | IS_LUT_STATE_ID_FLAG_LUT

const IS_LUT_STATE_ID_SOFTWARE_GAMMA = IS_LUT_STATE_ID_FLAG_SOFTWARE | IS_LUT_STATE_ID_FLAG_GAMMA

const IS_LUT_STATE_ID_SOFTWARE_LUTANDGAMMA = (IS_LUT_STATE_ID_FLAG_SOFTWARE | IS_LUT_STATE_ID_FLAG_LUT) | IS_LUT_STATE_ID_FLAG_GAMMA

const IS_LUT_MODE_ID_DEFAULT = 0

const IS_LUT_MODE_ID_FORCE_HARDWARE = 1

const IS_LUT_MODE_ID_FORCE_SOFTWARE = 2

const IS_LUT_DISABLED = 0

const IS_LUT_ENABLED = 1

const IS_GAMMA_CMD_SET = 0x0001

const IS_GAMMA_CMD_GET_DEFAULT = 0x0002

const IS_GAMMA_CMD_GET = 0x0003

const IS_GAMMA_VALUE_MIN = 1

const IS_GAMMA_VALUE_MAX = 1000

const IS_MC_CMD_FLAG_ACTIVE = 0x1000

const IS_MC_CMD_FLAG_PASSIVE = 0x2000

const IS_PMC_CMD_INITIALIZE = 0x0001 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_DEINITIALIZE = 0x0002 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_ADDMCDEVICE = 0x0003 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_REMOVEMCDEVICE = 0x0004 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_STOREDEVICES = 0x0005 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_LOADDEVICES = 0x0006 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_SYSTEM_SET_ENABLE = 0x0007 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_SYSTEM_GET_ENABLE = 0x0008 | IS_MC_CMD_FLAG_PASSIVE

const IS_PMC_CMD_REMOVEALLMCDEVICES = 0x0009 | IS_MC_CMD_FLAG_PASSIVE

const IS_AMC_CMD_SET_MC_IP = 0x0010 | IS_MC_CMD_FLAG_ACTIVE

const IS_AMC_CMD_GET_MC_IP = 0x0011 | IS_MC_CMD_FLAG_ACTIVE

const IS_AMC_CMD_SET_MC_ENABLED = 0x0012 | IS_MC_CMD_FLAG_ACTIVE

const IS_AMC_CMD_GET_MC_ENABLED = 0x0013 | IS_MC_CMD_FLAG_ACTIVE

const IS_AMC_CMD_GET_MC_SUPPORTED = 0x0014 | IS_MC_CMD_FLAG_ACTIVE

const IS_AMC_SUPPORTED_FLAG_DEVICE = 0x0001

const IS_AMC_SUPPORTED_FLAG_FIRMWARE = 0x0002

const IS_PMC_ERRORHANDLING_REJECT_IMAGES = 0x01

const IS_PMC_ERRORHANDLING_IGNORE_MISSING_PARTS = 0x02

const IS_PMC_ERRORHANDLING_MERGE_IMAGES_RELEASE_ON_COMPLETE = 0x03

const IS_PMC_ERRORHANDLING_MERGE_IMAGES_RELEASE_ON_RECEIVED_IMGLEN = 0x04

