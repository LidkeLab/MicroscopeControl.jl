@cenum peak_status::UInt32 begin
    PEAK_STATUS_SUCCESS = 0
    PEAK_STATUS_WARNING = 16384
    PEAK_STATUS_VALUE_ADJUSTED = 16385
    PEAK_STATUS_WARNING_OVERFLOW = 16386
    PEAK_STATUS_WARNING_OPERATION = 16387
    PEAK_STATUS_ERROR = 32768
    PEAK_STATUS_NOT_INITIALIZED = 32769
    PEAK_STATUS_NOT_IMPLEMENTED = 32770
    PEAK_STATUS_ACCESS_DENIED = 32771
    PEAK_STATUS_CAMERA_NOT_FOUND = 32772
    PEAK_STATUS_CAMERA_NOT_AVAILABLE = 32773
    PEAK_STATUS_INVALID_HANDLE = 32774
    PEAK_STATUS_INVALID_PARAMETER = 32775
    PEAK_STATUS_OUT_OF_RANGE = 32776
    PEAK_STATUS_BUFFER_TOO_SMALL = 32777
    PEAK_STATUS_INVALID_CONFIGURATION = 32778
    PEAK_STATUS_TIMEOUT = 32779
    PEAK_STATUS_ABORTED = 32780
    PEAK_STATUS_NO_DATA = 32781
    PEAK_STATUS_INVALID_PEAK_INSTALLATION = 32782
    PEAK_STATUS_BUSY = 32783
    PEAK_STATUS_OUT_OF_MEMORY = 32784
    PEAK_STATUS_IO = 32785
    PEAK_STATUS_NOT_SUPPORTED = 32786
end

@cenum peak_access_status::UInt32 begin
    PEAK_ACCESS_INVALID = 0
    PEAK_ACCESS_NOT_SUPPORTED = 1
    PEAK_ACCESS_NONE = 257
    PEAK_ACCESS_GFA_LOCK = 513
    PEAK_ACCESS_READONLY = 4353
    PEAK_ACCESS_WRITEONLY = 8449
    PEAK_ACCESS_READWRITE = 12545
end

const peak_bool = UInt8

const peak_camera_id = UInt64

mutable struct peak_camera end

mutable struct peak_frame end

mutable struct peak_video end

mutable struct peak_inference end

mutable struct peak_inference_result end

mutable struct peak_message_queue end

mutable struct peak_message end

mutable struct peak_i2c end

mutable struct peak_imagewriter end

mutable struct peak_histogram end

struct peak_buffer
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{peak_buffer}, f::Symbol)
    f === :memoryAddress && return Ptr{Ptr{UInt8}}(x + 0)
    f === :memorySize && return Ptr{Csize_t}(x + 8)
    f === :userContext && return Ptr{Ptr{Cvoid}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::peak_buffer, f::Symbol)
    r = Ref{peak_buffer}(x)
    ptr = Base.unsafe_convert(Ptr{peak_buffer}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_buffer}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_buffer, private::Bool = false)
    (:memoryAddress, :memorySize, :userContext, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_size
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{peak_size}, f::Symbol)
    f === :width && return Ptr{UInt32}(x + 0)
    f === :height && return Ptr{UInt32}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::peak_size, f::Symbol)
    r = Ref{peak_size}(x)
    ptr = Base.unsafe_convert(Ptr{peak_size}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_size}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_size, private::Bool = false)
    (:width, :height, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_position
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{peak_position}, f::Symbol)
    f === :x && return Ptr{UInt32}(x + 0)
    f === :y && return Ptr{UInt32}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::peak_position, f::Symbol)
    r = Ref{peak_position}(x)
    ptr = Base.unsafe_convert(Ptr{peak_position}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_position}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_position, private::Bool = false)
    (:x, :y, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_roi
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{peak_roi}, f::Symbol)
    f === :offset && return Ptr{peak_position}(x + 0)
    f === :size && return Ptr{peak_size}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::peak_roi, f::Symbol)
    r = Ref{peak_roi}(x)
    ptr = Base.unsafe_convert(Ptr{peak_roi}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_roi}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_roi, private::Bool = false)
    (:offset, :size, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_matrix
    data::NTuple{72, UInt8}
end

function Base.getproperty(x::Ptr{peak_matrix}, f::Symbol)
    f === :elements && return Ptr{var"##Ctag#230"}(x + 0)
    f === :elementArray && return Ptr{NTuple{3, NTuple{3, Cdouble}}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::peak_matrix, f::Symbol)
    r = Ref{peak_matrix}(x)
    ptr = Base.unsafe_convert(Ptr{peak_matrix}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_matrix}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_matrix, private::Bool = false)
    (:elements, :elementArray, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_interface_technology::UInt32 begin
    PEAK_INTERFACE_TECHNOLOGY_INVALID = 0
    PEAK_INTERFACE_TECHNOLOGY_GEV = 1
    PEAK_INTERFACE_TECHNOLOGY_U3V = 2
    PEAK_INTERFACE_TECHNOLOGY_UEYE = 3
    peak_interface_technology_INVALID = 0
    peak_interface_technology_GEV = 1
    peak_interface_technology_U3V = 2
    peak_interface_technology_UEYE = 3
end

@cenum peak_camera_type::UInt32 begin
    PEAK_CAMERA_TYPE_INVALID = 0
    PEAK_CAMERA_TYPE_UEYE_USB = 4353
    PEAK_CAMERA_TYPE_UEYE_ETH = 4610
    PEAK_CAMERA_TYPE_UEYE_PLUS_U3V = 8449
    PEAK_CAMERA_TYPE_UEYE_PLUS_GEV = 8706
end

const peak_camera_handle = Ptr{peak_camera}

struct peak_camera_descriptor
    data::NTuple{652, UInt8}
end

function Base.getproperty(x::Ptr{peak_camera_descriptor}, f::Symbol)
    f === :cameraID && return Ptr{peak_camera_id}(x + 0)
    f === :cameraType && return Ptr{peak_camera_type}(x + 8)
    f === :modelName && return Ptr{NTuple{64, Cchar}}(x + 12)
    f === :serialNumber && return Ptr{NTuple{64, Cchar}}(x + 76)
    f === :userDefinedName && return Ptr{NTuple{64, Cchar}}(x + 140)
    f === :interfaceTechnology && return Ptr{peak_interface_technology}(x + 204)
    f === :reserved && return Ptr{NTuple{444, UInt8}}(x + 208)
    return getfield(x, f)
end

function Base.getproperty(x::peak_camera_descriptor, f::Symbol)
    r = Ref{peak_camera_descriptor}(x)
    ptr = Base.unsafe_convert(Ptr{peak_camera_descriptor}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_camera_descriptor}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_camera_descriptor, private::Bool = false)
    (:cameraID, :cameraType, :modelName, :serialNumber, :userDefinedName, :interfaceTechnology, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_reconnect_information
    isReconnectSuccessful::peak_bool
    isAcquisitionRunning::peak_bool
    isConfigurationRestored::peak_bool
    reserved::NTuple{64, UInt8}
end

struct peak_mac_address
    data::NTuple{6, UInt8}
end

function Base.getproperty(x::Ptr{peak_mac_address}, f::Symbol)
    f === :octets && return Ptr{NTuple{6, UInt8}}(x + 0)
    f === :parts && return Ptr{var"##Ctag#231"}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::peak_mac_address, f::Symbol)
    r = Ref{peak_mac_address}(x)
    ptr = Base.unsafe_convert(Ptr{peak_mac_address}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_mac_address}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_mac_address, private::Bool = false)
    (:octets, :parts, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_ip_address
    data::NTuple{4, UInt8}
end

function Base.getproperty(x::Ptr{peak_ip_address}, f::Symbol)
    f === :addr && return Ptr{UInt32}(x + 0)
    f === :parts && return Ptr{NTuple{4, UInt8}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::peak_ip_address, f::Symbol)
    r = Ref{peak_ip_address}(x)
    ptr = Base.unsafe_convert(Ptr{peak_ip_address}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_ip_address}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_ip_address, private::Bool = false)
    (:addr, :parts, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_ip_config
    data::NTuple{12, UInt8}
end

function Base.getproperty(x::Ptr{peak_ip_config}, f::Symbol)
    f === :address && return Ptr{peak_ip_address}(x + 0)
    f === :subnetMask && return Ptr{peak_ip_address}(x + 4)
    f === :reserved && return Ptr{NTuple{4, UInt8}}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::peak_ip_config, f::Symbol)
    r = Ref{peak_ip_config}(x)
    ptr = Base.unsafe_convert(Ptr{peak_ip_config}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_ip_config}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_ip_config, private::Bool = false)
    (:address, :subnetMask, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_ethernet_status::UInt32 begin
    PEAK_ETHERNET_STATUS_INVALID = 0
    PEAK_ETHERNET_STATUS_OK = 1
    PEAK_ETHERNET_STATUS_NOK = 32769
    PEAK_ETHERNET_STATUS_SUBNET_MISMATCH = 32770
    PEAK_ETHERNET_STATUS_INAPPLICABLE_IP = 32771
end

struct peak_ethernet_info
    data::NTuple{181, UInt8}
end

function Base.getproperty(x::Ptr{peak_ethernet_info}, f::Symbol)
    f === :cameraMAC && return Ptr{peak_mac_address}(x + 0)
    f === :cameraIP && return Ptr{peak_ip_config}(x + 6)
    f === :cameraDHCPEnabled && return Ptr{peak_bool}(x + 18)
    f === :cameraPersistentIP && return Ptr{peak_ip_config}(x + 19)
    f === :cameraEthernetStatus && return Ptr{peak_ethernet_status}(x + 31)
    f === :reservedCamera && return Ptr{NTuple{64, UInt8}}(x + 35)
    f === :hostIP && return Ptr{peak_ip_config}(x + 99)
    f === :hostMAC && return Ptr{peak_mac_address}(x + 111)
    f === :reserved && return Ptr{NTuple{64, UInt8}}(x + 117)
    return getfield(x, f)
end

function Base.getproperty(x::peak_ethernet_info, f::Symbol)
    r = Ref{peak_ethernet_info}(x)
    ptr = Base.unsafe_convert(Ptr{peak_ethernet_info}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_ethernet_info}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_ethernet_info, private::Bool = false)
    (:cameraMAC, :cameraIP, :cameraDHCPEnabled, :cameraPersistentIP, :cameraEthernetStatus, :reservedCamera, :hostIP, :hostMAC, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

const peak_frame_handle = Ptr{peak_frame}

struct peak_acquisition_info
    data::NTuple{276, UInt8}
end

function Base.getproperty(x::Ptr{peak_acquisition_info}, f::Symbol)
    f === :numUnderrun && return Ptr{UInt32}(x + 0)
    f === :numDropped && return Ptr{UInt32}(x + 4)
    f === :numIncomplete && return Ptr{UInt32}(x + 8)
    f === :fps && return Ptr{Cdouble}(x + 12)
    f === :reserved && return Ptr{NTuple{256, UInt8}}(x + 20)
    return getfield(x, f)
end

function Base.getproperty(x::peak_acquisition_info, f::Symbol)
    r = Ref{peak_acquisition_info}(x)
    ptr = Base.unsafe_convert(Ptr{peak_acquisition_info}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_acquisition_info}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_acquisition_info, private::Bool = false)
    (:numUnderrun, :numDropped, :numIncomplete, :fps, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_buffer_handling_mode::UInt32 begin
    PEAK_BUFFER_HANDLING_MODE_INVALID = 0
    PEAK_BUFFER_HANDLING_MODE_OLDEST_FIRST = 1
    PEAK_BUFFER_HANDLING_MODE_NEWEST_ONLY = 2
    PEAK_BUFFER_HANDLING_MODE_OLDEST_FIRST_SINGLE_BUFFER = 3
    PEAK_BUFFER_HANDLING_MODE_OLDEST_FIRST_DEPEND_ON_CAMERA_FIFO = 4
end

@cenum peak_loss_handling_mode::UInt32 begin
    PEAK_LOSS_HANDLING_MODE_INVALID = 0
    PEAK_LOSS_HANDLING_MODE_OFF = 1
    PEAK_LOSS_HANDLING_MODE_LIMITED = 2
    PEAK_LOSS_HANDLING_MODE_UNLIMITED = 3
end

@cenum peak_pixel_format::UInt32 begin
    PEAK_PIXEL_FORMAT_INVALID = 0
    PEAK_PIXEL_FORMAT_BAYER_GR8 = 17301512
    PEAK_PIXEL_FORMAT_BAYER_GR10 = 17825804
    PEAK_PIXEL_FORMAT_BAYER_GR12 = 17825808
    PEAK_PIXEL_FORMAT_BAYER_RG8 = 17301513
    PEAK_PIXEL_FORMAT_BAYER_RG10 = 17825805
    PEAK_PIXEL_FORMAT_BAYER_RG12 = 17825809
    PEAK_PIXEL_FORMAT_BAYER_GB8 = 17301514
    PEAK_PIXEL_FORMAT_BAYER_GB10 = 17825806
    PEAK_PIXEL_FORMAT_BAYER_GB12 = 17825810
    PEAK_PIXEL_FORMAT_BAYER_BG8 = 17301515
    PEAK_PIXEL_FORMAT_BAYER_BG10 = 17825807
    PEAK_PIXEL_FORMAT_BAYER_BG12 = 17825811
    PEAK_PIXEL_FORMAT_MONO8 = 17301505
    PEAK_PIXEL_FORMAT_MONO10 = 17825795
    PEAK_PIXEL_FORMAT_MONO12 = 17825797
    PEAK_PIXEL_FORMAT_RGB8 = 35127316
    PEAK_PIXEL_FORMAT_RGB10 = 36700184
    PEAK_PIXEL_FORMAT_RGB12 = 36700186
    PEAK_PIXEL_FORMAT_BGR8 = 35127317
    PEAK_PIXEL_FORMAT_BGR10 = 36700185
    PEAK_PIXEL_FORMAT_BGR12 = 36700187
    PEAK_PIXEL_FORMAT_RGBA8 = 35651606
    PEAK_PIXEL_FORMAT_RGBA10 = 37748831
    PEAK_PIXEL_FORMAT_RGBA12 = 37748833
    PEAK_PIXEL_FORMAT_BGRA8 = 35651607
    PEAK_PIXEL_FORMAT_BGRA10 = 37748812
    PEAK_PIXEL_FORMAT_BGRA12 = 37748814
    PEAK_PIXEL_FORMAT_BAYER_GR10P = 17432662
    PEAK_PIXEL_FORMAT_BAYER_GR12P = 17563735
    PEAK_PIXEL_FORMAT_BAYER_RG10P = 17432664
    PEAK_PIXEL_FORMAT_BAYER_RG12P = 17563737
    PEAK_PIXEL_FORMAT_BAYER_GB10P = 17432660
    PEAK_PIXEL_FORMAT_BAYER_GB12P = 17563733
    PEAK_PIXEL_FORMAT_BAYER_BG10P = 17432658
    PEAK_PIXEL_FORMAT_BAYER_BG12P = 17563731
    PEAK_PIXEL_FORMAT_MONO10P = 17432646
    PEAK_PIXEL_FORMAT_MONO12P = 17563719
    PEAK_PIXEL_FORMAT_YUV422_8_UYVY = 34603039
    PEAK_PIXEL_FORMAT_RGB10P32 = 35651613
    PEAK_PIXEL_FORMAT_BGR10P32 = 35651614
    PEAK_PIXEL_FORMAT_BAYER_GR10G40_IDS = 1073741827
    PEAK_PIXEL_FORMAT_BAYER_RG10G40_IDS = 1073741825
    PEAK_PIXEL_FORMAT_BAYER_GB10G40_IDS = 1073741826
    PEAK_PIXEL_FORMAT_BAYER_BG10G40_IDS = 1073741828
    PEAK_PIXEL_FORMAT_BAYER_GR12G24_IDS = 1073741843
    PEAK_PIXEL_FORMAT_BAYER_RG12G24_IDS = 1073741841
    PEAK_PIXEL_FORMAT_BAYER_GB12G24_IDS = 1073741842
    PEAK_PIXEL_FORMAT_BAYER_BG12G24_IDS = 1073741844
    PEAK_PIXEL_FORMAT_MONO10G40_IDS = 1073741839
    PEAK_PIXEL_FORMAT_MONO12G24_IDS = 1073741855
end

struct peak_pixel_format_info
    data::NTuple{88, UInt8}
end

function Base.getproperty(x::Ptr{peak_pixel_format_info}, f::Symbol)
    f === :numBitsPerPixel && return Ptr{UInt32}(x + 0)
    f === :numSignificantBitsPerPixel && return Ptr{UInt32}(x + 4)
    f === :numChannels && return Ptr{UInt32}(x + 8)
    f === :numBitsPerChannel && return Ptr{UInt32}(x + 12)
    f === :numSignificantBitsPerChannel && return Ptr{UInt32}(x + 16)
    f === :maxValuePerChannel && return Ptr{UInt32}(x + 20)
    f === :reserved && return Ptr{NTuple{64, UInt8}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::peak_pixel_format_info, f::Symbol)
    r = Ref{peak_pixel_format_info}(x)
    ptr = Base.unsafe_convert(Ptr{peak_pixel_format_info}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_pixel_format_info}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_pixel_format_info, private::Bool = false)
    (:numBitsPerPixel, :numSignificantBitsPerPixel, :numChannels, :numBitsPerChannel, :numSignificantBitsPerChannel, :maxValuePerChannel, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_frame_type::UInt32 begin
    PEAK_FRAME_TYPE_INVALID = 0
    PEAK_FRAME_TYPE_IMAGE = 4097
end

struct peak_frame_info
    data::NTuple{341, UInt8}
end

function Base.getproperty(x::Ptr{peak_frame_info}, f::Symbol)
    f === :type && return Ptr{peak_frame_type}(x + 0)
    f === :buffer && return Ptr{peak_buffer}(x + 4)
    f === :frameID && return Ptr{UInt64}(x + 28)
    f === :timestamp_ns && return Ptr{UInt64}(x + 36)
    f === :roi && return Ptr{peak_roi}(x + 44)
    f === :pixelFormat && return Ptr{peak_pixel_format}(x + 60)
    f === :isComplete && return Ptr{peak_bool}(x + 64)
    f === :bytesExpected && return Ptr{Csize_t}(x + 65)
    f === :bytesWritten && return Ptr{Csize_t}(x + 73)
    f === :processingTime_ms && return Ptr{UInt32}(x + 81)
    f === :reserved && return Ptr{NTuple{256, UInt8}}(x + 85)
    return getfield(x, f)
end

function Base.getproperty(x::peak_frame_info, f::Symbol)
    r = Ref{peak_frame_info}(x)
    ptr = Base.unsafe_convert(Ptr{peak_frame_info}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_frame_info}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_frame_info, private::Bool = false)
    (:type, :buffer, :frameID, :timestamp_ns, :roi, :pixelFormat, :isComplete, :bytesExpected, :bytesWritten, :processingTime_ms, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_parameter_set::UInt32 begin
    PEAK_PARAMETER_SET_INVALID = 0
    PEAK_PARAMETER_SET_DEFAULT = 4097
    PEAK_PARAMETER_SET_LINESCAN = 4098
    PEAK_PARAMETER_SET_LONG_EXPOSURE = 4099
    PEAK_PARAMETER_SET_USER_1 = 8193
    PEAK_PARAMETER_SET_USER_2 = 8194
end

@cenum peak_shutter_mode::UInt32 begin
    PEAK_SHUTTER_MODE_UNKNOWN = 0
    PEAK_SHUTTER_MODE_ROLLING = 1
    PEAK_SHUTTER_MODE_GLOBAL = 2
    PEAK_SHUTTER_MODE_GLOBAL_RESET = 3
end

@cenum peak_io_channel::UInt32 begin
    PEAK_IO_CHANNEL_INVALID = 0
    PEAK_IO_CHANNEL_NONE = 1
    PEAK_IO_CHANNEL_SOFTWARE = 4353
    PEAK_IO_CHANNEL_TRIGGER_INPUT = 8449
    PEAK_IO_CHANNEL_FLASH_OUTPUT = 8705
    PEAK_IO_CHANNEL_GPIO_1 = 25345
    PEAK_IO_CHANNEL_GPIO_2 = 25346
    PEAK_IO_CHANNEL_LINE_0 = 32768
    PEAK_IO_CHANNEL_LINE_1 = 32769
    PEAK_IO_CHANNEL_LINE_2 = 32770
    PEAK_IO_CHANNEL_LINE_3 = 32771
    PEAK_IO_CHANNEL_LINE_4 = 32772
    PEAK_IO_CHANNEL_LINE_5 = 32773
    PEAK_IO_CHANNEL_LINE_6 = 32774
    PEAK_IO_CHANNEL_LINE_7 = 32775
end

@cenum peak_io_direction::UInt32 begin
    PEAK_IO_DIRECTION_UNKNOWN = 0
    PEAK_IO_DIRECTION_INPUT = 1
    PEAK_IO_DIRECTION_OUTPUT = 2
    PEAK_IO_DIRECTION_ANY = 16
end

@cenum peak_io_type::UInt32 begin
    PEAK_IO_TYPE_INVALID = 0
    PEAK_IO_TYPE_UNKNOWN = 1
    PEAK_IO_TYPE_TRI_STATE = 2
    PEAK_IO_TYPE_OPTO_COUPLED = 3
    PEAK_IO_TYPE_LVTTL = 4
end

@cenum peak_trigger_target::UInt32 begin
    PEAK_TRIGGER_TARGET_INVALID = 0
    PEAK_TRIGGER_TARGET_FRAME_START = 4097
    PEAK_TRIGGER_TARGET_LEVEL_CONTROLLED_EXPOSURE = 8193
end

struct peak_trigger_mode
    triggerTarget::peak_trigger_target
    ioChannel::peak_io_channel
end

@cenum peak_trigger_edge::UInt32 begin
    PEAK_TRIGGER_EDGE_INVALID = 0
    PEAK_TRIGGER_EDGE_RISING = 1
    PEAK_TRIGGER_EDGE_FALLING = 2
    PEAK_TRIGGER_EDGE_ANY = 3
end

@cenum peak_flash_reference::UInt32 begin
    PEAK_FLASH_REFERENCE_INVALID = 0
    PEAK_FLASH_REFERENCE_LINE_1_SIGNAL = 1
    PEAK_FLASH_REFERENCE_EXPOSURE_ACTIVE = 4097
    PEAK_FLASH_REFERENCE_GLOBAL_START_WINDOW = 4098
    PEAK_FLASH_REFERENCE_ACQUISITION_ACTIVE = 8193
end

struct peak_flash_mode
    flashReference::peak_flash_reference
    ioChannel::peak_io_channel
end

@cenum peak_gain_type::UInt32 begin
    PEAK_GAIN_TYPE_INVALID = 0
    PEAK_GAIN_TYPE_ANALOG = 4097
    PEAK_GAIN_TYPE_DIGITAL = 8193
    PEAK_GAIN_TYPE_COMBINED = 12289
end

@cenum peak_gain_channel::UInt32 begin
    PEAK_GAIN_CHANNEL_INVALID = 0
    PEAK_GAIN_CHANNEL_RED = 1
    PEAK_GAIN_CHANNEL_GREEN = 2
    PEAK_GAIN_CHANNEL_BLUE = 4
    PEAK_GAIN_CHANNEL_MASTER = 7
end

@cenum peak_color_correction_mode::UInt32 begin
    PEAK_COLOR_CORRECTION_MODE_INVALID = 0
    PEAK_COLOR_CORRECTION_MODE_HQ = 4097
    PEAK_COLOR_CORRECTION_MODE_USER_1 = 8193
end

@cenum peak_auto_feature_mode::UInt32 begin
    PEAK_AUTO_FEATURE_MODE_INVALID = 0
    PEAK_AUTO_FEATURE_MODE_OFF = 1
    PEAK_AUTO_FEATURE_MODE_ONCE = 4097
    PEAK_AUTO_FEATURE_MODE_CONTINUOUS = 4098
end

@cenum peak_auto_feature_brightness_algorithm::UInt32 begin
    PEAK_AUTO_FEATURE_BRIGHTNESS_ALGORITHM_INVALID = 0
    PEAK_AUTO_FEATURE_BRIGHTNESS_ALGORITHM_MEDIAN = 1
    PEAK_AUTO_FEATURE_BRIGHTNESS_ALGORITHM_MEAN = 2
end

@cenum peak_auto_feature_roi_mode::UInt32 begin
    PEAK_AUTO_FEATURE_ROI_MODE_INVALID = 0
    PEAK_AUTO_FEATURE_ROI_MODE_FULL_IMAGE = 4097
    PEAK_AUTO_FEATURE_ROI_MODE_MANUAL = 8193
end

@cenum peak_subsampling_engine::UInt32 begin
    PEAK_SUBSAMPLING_ENGINE_INVALID = 0
    PEAK_SUBSAMPLING_ENGINE_FPGA = 1
    PEAK_SUBSAMPLING_ENGINE_SENSOR = 2
    PEAK_SUBSAMPLING_ENGINE_UEYE = 3
end

@cenum peak_camera_memory_area::UInt32 begin
    PEAK_CAMERA_MEMORY_AREA_INVALID = 0
    PEAK_CAMERA_MEMORY_AREA_USER_DATA_1 = 1
    PEAK_CAMERA_MEMORY_AREA_USER_DATA_2 = 2
end

@cenum peak_gfa_module::UInt32 begin
    PEAK_GFA_MODULE_INVALID = 0
    PEAK_GFA_MODULE_SYSTEM = 1
    PEAK_GFA_MODULE_INTERFACE = 2
    PEAK_GFA_MODULE_LOCAL_DEVICE = 3
    PEAK_GFA_MODULE_REMOTE_DEVICE = 4099
    PEAK_GFA_MODULE_DATA_STREAM = 4
end

struct peak_gfa_enumeration_entry
    symbolicValue::NTuple{64, Cchar}
    integerValue::Int64
end

@cenum peak_chromatic_adaption_algorithm::UInt32 begin
    PEAK_CHROMATIC_ADAPTION_ALGORITHM_INVALID = 0
    PEAK_CHROMATIC_ADAPTION_ALGORITHM_LEGACY = 1
    PEAK_CHROMATIC_ADAPTION_ALGORITHM_BRADFORD = 2
end

@cenum peak_chromatic_adaption_color_space::UInt32 begin
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_INVALID = 0
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_SRGB_D50 = 1
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_SRGB_D65 = 2
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_CIE_RGB_E = 3
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_ECI_RGB_D50 = 4
    PEAK_CHROMATIC_ADAPTION_COLOR_SPACE_ADOBE_RGB_D65 = 5
end

struct peak_double_limit
    min::Cdouble
    max::Cdouble
end

@cenum peak_focus_roi_weight::UInt32 begin
    PEAK_FOCUS_ROI_WEIGHT_INVALID = 0
    PEAK_FOCUS_ROI_WEIGHT_WEAK = 1
    PEAK_FOCUS_ROI_WEIGHT_MEDIUM = 2
    PEAK_FOCUS_ROI_WEIGHT_STRONG = 3
end

struct peak_focus_roi
    data::NTuple{20, UInt8}
end

function Base.getproperty(x::Ptr{peak_focus_roi}, f::Symbol)
    f === :roi && return Ptr{peak_roi}(x + 0)
    f === :weight && return Ptr{peak_focus_roi_weight}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::peak_focus_roi, f::Symbol)
    r = Ref{peak_focus_roi}(x)
    ptr = Base.unsafe_convert(Ptr{peak_focus_roi}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_focus_roi}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_focus_roi, private::Bool = false)
    (:roi, :weight, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_auto_focus_search_algorithm::UInt32 begin
    PEAK_AUTO_FOCUS_SEARCH_ALGORITHM_INVALID = 0
    PEAK_AUTO_FOCUS_SEARCH_ALGORITHM_GOLDEN_RATIO = 1
    PEAK_AUTO_FOCUS_SEARCH_ALGORITHM_HILL_CLIMBING = 2
    PEAK_AUTO_FOCUS_SEARCH_ALGORITHM_FULL_SCAN = 3
    PEAK_AUTO_FOCUS_SEARCH_ALGORITHM_GLOBAL_SEARCH = 4
end

@cenum peak_sharpness_algorithm::UInt32 begin
    PEAK_SHARPNESS_ALGORITHM_INVALID = 0
    PEAK_SHARPNESS_ALGORITHM_TENENGRAD = 1
    PEAK_SHARPNESS_ALGORITHM_SOBEL = 2
    PEAK_SHARPNESS_ALGORITHM_MEAN_SCORE = 3
    PEAK_SHARPNESS_ALGORITHM_HISTOGRAM_VARIANCE = 4
end

@cenum peak_hotpixel_correction_sensitivity::UInt32 begin
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_INVALID = 0
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_LEVEL_1 = 1
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_LEVEL_2 = 2
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_LEVEL_3 = 3
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_LEVEL_4 = 4
    PEAK_HOTPIXEL_CORRECTION_SENSITIVITY_LEVEL_5 = 5
end

struct peak_histogram_channel_info
    pixelSum::UInt64
    pixelCount::UInt64
    binSize::Csize_t
    reserved::NTuple{64, UInt8}
end

const peak_histogram_handle = Ptr{peak_histogram}

const peak_video_handle = Ptr{peak_video}

@cenum peak_video_encoder::UInt32 begin
    PEAK_VIDEO_ENCODER_INVALID = 0
    PEAK_VIDEO_ENCODER_MJPEG = 1
end

@cenum peak_video_container::UInt32 begin
    PEAK_VIDEO_CONTAINER_INVALID = 0
    PEAK_VIDEO_CONTAINER_AVI = 1
end

struct peak_video_info
    encodedFrames::UInt64
    droppedFrames::UInt64
    fileSize::UInt64
    reserved::NTuple{256, UInt8}
end

@cenum peak_video_container_option::UInt32 begin
    PEAK_VIDEO_CONTAINER_OPTION_INVALID = 0
    PEAK_VIDEO_CONTAINER_OPTION_FRAMERATE = 1
end

@cenum peak_video_encoder_option::UInt32 begin
    PEAK_VIDEO_ENCODER_OPTION_INVALID = 0
    PEAK_VIDEO_ENCODER_OPTION_QUALITY = 1
end

const peak_inference_handle = Ptr{peak_inference}

const peak_inference_result_handle = Ptr{peak_inference_result}

@cenum peak_inference_type::UInt32 begin
    PEAK_INFERENCE_TYPE_INVALID = 0
    PEAK_INFERENCE_TYPE_DETECTION = 1
    PEAK_INFERENCE_TYPE_CLASSIFICATION = 2
end

@cenum peak_inference_preprocessing_mode::UInt32 begin
    PEAK_INFERENCE_PREPROCESSING_MODE_INVALID = 0
    PEAK_INFERENCE_PREPROCESSING_MODE_CAFFE = 1
    PEAK_INFERENCE_PREPROCESSING_MODE_TENSORFLOW = 2
end

struct peak_inference_result_detection
    data::NTuple{280, UInt8}
end

function Base.getproperty(x::Ptr{peak_inference_result_detection}, f::Symbol)
    f === :type && return Ptr{peak_inference_type}(x + 0)
    f === :score && return Ptr{Cfloat}(x + 4)
    f === :label && return Ptr{NTuple{256, Cchar}}(x + 8)
    f === :rect && return Ptr{peak_roi}(x + 264)
    return getfield(x, f)
end

function Base.getproperty(x::peak_inference_result_detection, f::Symbol)
    r = Ref{peak_inference_result_detection}(x)
    ptr = Base.unsafe_convert(Ptr{peak_inference_result_detection}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_inference_result_detection}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_inference_result_detection, private::Bool = false)
    (:type, :score, :label, :rect, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_inference_result_classification
    type::peak_inference_type
    score::Cfloat
    label::NTuple{256, Cchar}
end

struct peak_inference_result_data
    type::peak_inference_type
    frameHandle::peak_frame_handle
    preprocessing_time_us::UInt32
    inference_time_us::UInt32
    reserved::NTuple{256, Cchar}
end

struct peak_version
    major::UInt32
    minor::UInt32
    subMinor::UInt32
    patch::UInt32
end

struct peak_inference_info
    fileVersion::peak_version
    lighthouseID::NTuple{256, Cchar}
    creationTime_s::UInt64
    projectName::NTuple{256, Cchar}
    networkName::NTuple{256, Cchar}
    inferenceType::peak_inference_type
    inputWidth::Csize_t
    inputHeight::Csize_t
    inputPixelFormat::peak_pixel_format
    preprocessingMode::peak_inference_preprocessing_mode
    numberOfClasses::Csize_t
    reserved::NTuple{256, UInt8}
end

struct peak_inference_statistics
    numInferencesSuccessful::UInt32
    numInferencesFailed::UInt32
    reserved::NTuple{256, Cchar}
end

@cenum peak_message_queue_mode::UInt32 begin
    PEAK_QUEUE_MODE_INVALID = 0
    PEAK_QUEUE_MODE_OLDEST_FIRST = 1
    PEAK_QUEUE_MODE_NEWEST_ONLY = 2
end

@cenum peak_message_type::UInt32 begin
    PEAK_MESSAGE_TYPE_INVALID = 0
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_CRITICAL_ERROR = 36881
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_ERROR = 36880
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_EVENT_DROPPED = 36882
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_EXPOSURE_START = 36864
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_EXPOSURE_END = 36865
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_FRAME_START = 36866
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_FRAME_DROPPED = 36875
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_MISSED_TRIGGER_EXPOSURE = 36876
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_MISSED_TRIGGER_LINE = 36877
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_PTP_MASTER_SYNC_LOST = 36883
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_TEMPERATURE = 36878
    PEAK_MESSAGE_TYPE_REMOTE_DEVICE_TEST = 20479
    PEAK_MESSAGE_TYPE_DEVICE_FOUND = 65537
    PEAK_MESSAGE_TYPE_DEVICE_LOST = 65538
    PEAK_MESSAGE_TYPE_DEVICE_RECONNECTED = 65539
    PEAK_MESSAGE_TYPE_DEVICE_DISCONNECTED = 65540
    PEAK_MESSAGE_TYPE_AUTO_FOCUS_ONCE_FINISHED = 131072
    PEAK_MESSAGE_TYPE_AUTO_FOCUS_NEW_DATA = 131073
    PEAK_MESSAGE_TYPE_AUTO_WHITEBALANCE_ONCE_FINISHED = 131074
    PEAK_MESSAGE_TYPE_AUTO_BRIGHTNESS_GAIN_ONCE_FINISHED = 131075
    PEAK_MESSAGE_TYPE_AUTO_BRIGHTNESS_EXPOSURE_ONCE_FINISHED = 131076
    PEAK_MESSAGE_TYPE_AUTO_BRIGHTNESS_ONCE_FINISHED = 131077
    PEAK_MESSAGE_TYPE_FIRMWARE_UPDATE = 196608
end

@cenum peak_message_data_type::UInt32 begin
    PEAK_MESSAGE_DATA_TYPE_INVALID = 0
    PEAK_MESSAGE_DATA_TYPE_NO_DATA = 1
    PEAK_MESSAGE_DATA_TYPE_REMOTE_DEVICE = 2
    PEAK_MESSAGE_DATA_TYPE_REMOTE_DEVICE_ERROR = 3
    PEAK_MESSAGE_DATA_TYPE_REMOTE_DEVICE_DROPPED = 4
    PEAK_MESSAGE_DATA_TYPE_REMOTE_DEVICE_FRAME = 5
    PEAK_MESSAGE_DATA_TYPE_REMOTE_DEVICE_TEMPERATURE = 6
    PEAK_MESSAGE_DATA_TYPE_AUTOFOCUS_DATA = 7
    PEAK_MESSAGE_DATA_TYPE_DEVICE_FOUND = 8
    PEAK_MESSAGE_DATA_TYPE_DEVICE_LOST = 9
    PEAK_MESSAGE_DATA_TYPE_DEVICE_RECONNECTED = 10
    PEAK_MESSAGE_DATA_TYPE_DEVICE_DISCONNECTED = 11
    PEAK_MESSAGE_DATA_TYPE_FIRMWARE_UPDATE = 12
end

struct peak_message_data_remote_device
    timestamp_ns::Int64
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_remote_device_error
    timestamp_ns::Int64
    error_type::Int64
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_remote_device_dropped
    timestamp_ns::Int64
    count::Int64
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_remote_device_frame
    timestamp_ns::Int64
    frameId::Int64
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_remote_device_temperature
    timestamp_ns::Int64
    temperature::Cdouble
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_autofocus
    focusValue::Int32
    sharpnessValue::Int32
    reserved::NTuple{32, UInt8}
end

struct peak_message_data_device_found
    data::NTuple{684, UInt8}
end

function Base.getproperty(x::Ptr{peak_message_data_device_found}, f::Symbol)
    f === :cameraDescriptor && return Ptr{peak_camera_descriptor}(x + 0)
    f === :reserved && return Ptr{NTuple{32, UInt8}}(x + 652)
    return getfield(x, f)
end

function Base.getproperty(x::peak_message_data_device_found, f::Symbol)
    r = Ref{peak_message_data_device_found}(x)
    ptr = Base.unsafe_convert(Ptr{peak_message_data_device_found}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_message_data_device_found}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_message_data_device_found, private::Bool = false)
    (:cameraDescriptor, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_message_data_device_lost
    data::NTuple{684, UInt8}
end

function Base.getproperty(x::Ptr{peak_message_data_device_lost}, f::Symbol)
    f === :cameraDescriptor && return Ptr{peak_camera_descriptor}(x + 0)
    f === :reserved && return Ptr{NTuple{32, UInt8}}(x + 652)
    return getfield(x, f)
end

function Base.getproperty(x::peak_message_data_device_lost, f::Symbol)
    r = Ref{peak_message_data_device_lost}(x)
    ptr = Base.unsafe_convert(Ptr{peak_message_data_device_lost}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_message_data_device_lost}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_message_data_device_lost, private::Bool = false)
    (:cameraDescriptor, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_message_data_device_reconnected
    data::NTuple{751, UInt8}
end

function Base.getproperty(x::Ptr{peak_message_data_device_reconnected}, f::Symbol)
    f === :cameraDescriptor && return Ptr{peak_camera_descriptor}(x + 0)
    f === :reconnectInformation && return Ptr{peak_reconnect_information}(x + 652)
    f === :reserved && return Ptr{NTuple{32, UInt8}}(x + 719)
    return getfield(x, f)
end

function Base.getproperty(x::peak_message_data_device_reconnected, f::Symbol)
    r = Ref{peak_message_data_device_reconnected}(x)
    ptr = Base.unsafe_convert(Ptr{peak_message_data_device_reconnected}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_message_data_device_reconnected}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_message_data_device_reconnected, private::Bool = false)
    (:cameraDescriptor, :reconnectInformation, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_message_data_device_disconnected
    data::NTuple{684, UInt8}
end

function Base.getproperty(x::Ptr{peak_message_data_device_disconnected}, f::Symbol)
    f === :cameraDescriptor && return Ptr{peak_camera_descriptor}(x + 0)
    f === :reserved && return Ptr{NTuple{32, UInt8}}(x + 652)
    return getfield(x, f)
end

function Base.getproperty(x::peak_message_data_device_disconnected, f::Symbol)
    r = Ref{peak_message_data_device_disconnected}(x)
    ptr = Base.unsafe_convert(Ptr{peak_message_data_device_disconnected}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_message_data_device_disconnected}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_message_data_device_disconnected, private::Bool = false)
    (:cameraDescriptor, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

@cenum peak_firmware_update_step::UInt32 begin
    PEAK_FIRMWARE_UPDATE_STEP_TOTAL = 0
    PEAK_FIRMWARE_UPDATE_STEP_CHECKPRECONDITIONS = 1
    PEAK_FIRMWARE_UPDATE_STEP_ACQUIREUPDATEDATA = 2
    PEAK_FIRMWARE_UPDATE_STEP_WRITEFEATURE = 3
    PEAK_FIRMWARE_UPDATE_STEP_EXECUTEFEATURE = 4
    PEAK_FIRMWARE_UPDATE_STEP_ASSERTFEATURE = 5
    PEAK_FIRMWARE_UPDATE_STEP_UPLOADFILE = 6
    PEAK_FIRMWARE_UPDATE_STEP_RESETDEVICE = 7
end

@cenum peak_firmware_update_status::UInt32 begin
    PEAK_FIRMWARE_UPDATE_STATUS_STARTED = 0
    PEAK_FIRMWARE_UPDATE_STATUS_PROGRESS = 1
    PEAK_FIRMWARE_UPDATE_STATUS_FINSIHED = 2
    PEAK_FIRMWARE_UPDATE_STATUS_FAILED = 3
end

struct peak_message_data_firmware_update
    cameraId::peak_camera_id
    serialNumber::NTuple{64, Cchar}
    step::peak_firmware_update_step
    stepStatus::peak_firmware_update_status
    stepProgressPercentage::Cdouble
    description::NTuple{256, Cchar}
    reserved::NTuple{32, Cchar}
end

struct peak_message_queue_statistics_info
    numQueued::UInt64
    numDelivered::UInt64
    numDropped::UInt64
    numInQueue::UInt64
    numMaxQueueSize::UInt64
    reserved::NTuple{32, UInt8}
end

struct peak_message_info
    type::peak_message_type
    hCam::peak_camera_handle
    messageID::UInt64
    hostMessageTimestamp_ns::UInt64
    dataType::peak_message_data_type
    reserved::NTuple{256, UInt8}
end

const peak_message_queue_handle = Ptr{peak_message_queue}

const peak_message_handle = Ptr{peak_message}

const peak_i2c_handle = Ptr{peak_i2c}

@cenum peak_i2c_mode::UInt32 begin
    PEAK_I2C_MODE_INVALID = 0
    PEAK_I2C_MODE_STANDARD = 100
    PEAK_I2C_MODE_FAST = 400
    PEAK_I2C_MODE_FAST_PLUS = 1000
end

@cenum peak_i2c_register_address_length::UInt32 begin
    PEAK_I2C_REGISTER_ADDRESS_LENGTH_INVALID = 0
    PEAK_I2C_REGISTER_ADDRESS_LENGTH_0BIT = 1
    PEAK_I2C_REGISTER_ADDRESS_LENGTH_8BIT = 2
    PEAK_I2C_REGISTER_ADDRESS_LENGTH_16BIT = 3
    PEAK_I2C_REGISTER_ADDRESS_LENGTH_24BIT = 4
end

@cenum peak_endianness::UInt32 begin
    PEAK_ENDIANNESS_INVALID = 0
    PEAK_ENDIANNESS_BIG_ENDIAN = 1
    PEAK_ENDIANNESS_LITTLE_ENDIAN = 2
end

@cenum peak_i2c_operation_status::UInt32 begin
    PEAK_I2C_OPERATION_STATUS_INVALID = 0
    PEAK_I2C_OPERATION_STATUS_READY = 1
    PEAK_I2C_OPERATION_STATUS_ERROR = 2
    PEAK_I2C_OPERATION_STATUS_TIMEOUT_ERROR = 3
    PEAK_I2C_OPERATION_STATUS_INVALID_DEVICE_ADDRESS = 4
end

const peak_imagewriter_handle = Ptr{peak_imagewriter}

@cenum peak_imagefile_format::UInt32 begin
    PEAK_IMAGEFILE_FORMAT_INVALID = 0
    PEAK_IMAGEFILE_FORMAT_PNG = 1
    PEAK_IMAGEFILE_FORMAT_JPEG = 2
    PEAK_IMAGEFILE_FORMAT_TIFF = 3
    PEAK_IMAGEFILE_FORMAT_BMP = 4
    PEAK_IMAGEFILE_FORMAT_RAW = 5
end

const papientitiy_imagefile_format = peak_imagefile_format

@cenum peak_test_pattern::UInt32 begin
    PEAK_TEST_PATTERN_INVALID = 0
    PEAK_TEST_PATTERN_OFF = 1
    PEAK_TEST_PATTERN_BLACK = 2
    PEAK_TEST_PATTERN_CHESSPATTERN = 3
    PEAK_TEST_PATTERN_COLORBAR = 4
    PEAK_TEST_PATTERN_FPGABLACK = 5
    PEAK_TEST_PATTERN_FPGACHESSBOARD = 6
    PEAK_TEST_PATTERN_FPGACOLORSTRIPE = 7
    PEAK_TEST_PATTERN_FPGAFRAMECOUNT = 8
    PEAK_TEST_PATTERN_FPGAGRAYSCALE = 9
    PEAK_TEST_PATTERN_FPGAVERTICALGRAYSCALE = 10
    PEAK_TEST_PATTERN_FPGAWHITE = 11
    PEAK_TEST_PATTERN_GREYDIAGONALRAMP = 12
    PEAK_TEST_PATTERN_GREYDIAGONALRAMPMOVING = 13
    PEAK_TEST_PATTERN_GREYHORIZONTALRAMP = 14
    PEAK_TEST_PATTERN_GREYVERTICALRAMP = 15
    PEAK_TEST_PATTERN_GREYWEDGEMOVINGSENSOR = 16
    PEAK_TEST_PATTERN_GREYWEDGESENSOR = 17
    PEAK_TEST_PATTERN_RAMPINGPATTERN = 18
    PEAK_TEST_PATTERN_SEQUENCEPATTERN1 = 19
    PEAK_TEST_PATTERN_SEQUENCEPATTERN2 = 20
    PEAK_TEST_PATTERN_WHITE = 21
end

@cenum peak_led_target::UInt32 begin
    PEAK_LED_TARGET_INVALID = 0
    PEAK_LED_TARGET_NETWORK = 1
    PEAK_LED_TARGET_STATUS = 2
end

@cenum peak_led_mode::UInt32 begin
    PEAK_LED_MODE_INVALID = 0
    PEAK_LED_MODE_OFF = 1
    PEAK_LED_MODE_BLINK_SLOW = 2
    PEAK_LED_MODE_BLINK_FAST = 3
    PEAK_LED_MODE_CAMERA_STATUS = 4
    PEAK_LED_MODE_NETWORK_STATUS = 5
end

@cenum peak_lut_selector::UInt32 begin
    PEAK_LUT_8BIT = 0
    PEAK_LUT_10BIT = 1
    PEAK_LUT_12BIT = 2
end

@cenum peak_lut_channel::UInt32 begin
    PEAK_LUT_CHANNEL_RED = 0
    PEAK_LUT_CHANNEL_GREEN = 1
    PEAK_LUT_CHANNEL_BLUE = 2
    PEAK_LUT_CHANNEL_ALL = 3
end

@cenum peak_lut_preset::UInt32 begin
    PEAK_LUT_PRESET_IDENTITY = 0
    PEAK_LUT_PRESET_INVERSE = 1
    PEAK_LUT_PRESET_JET = 2
    PEAK_LUT_PRESET_HOT = 3
    PEAK_LUT_PRESET_RAINBOW = 4
    PEAK_LUT_PRESET_ONLY_RED = 5
    PEAK_LUT_PRESET_ONLY_GREEN = 6
    PEAK_LUT_PRESET_ONLY_BLUE = 7
    PEAK_LUT_PRESET_DIGITAL_GAIN2 = 8
    PEAK_LUT_PRESET_DIGITAL_BLACK_25_PERCENT = 9
    PEAK_LUT_PRESET_BINARIZE = 10
end

@cenum peak_chunks_type::UInt32 begin
    PEAK_CHUNKS_TYPE_INVALID = 0
    PEAK_CHUNKS_TYPE_FRAME_INFO = 1
    PEAK_CHUNKS_TYPE_EXPOSURE = 2
    PEAK_CHUNKS_TYPE_GAIN = 3
    PEAK_CHUNKS_TYPE_SEQUENCER = 4
    PEAK_CHUNKS_TYPE_TIMESTAMP = 5
    PEAK_CHUNKS_TYPE_EXPOSURE_TRIGGER = 6
    PEAK_CHUNKS_TYPE_USABLE_ROI = 7
    PEAK_CHUNKS_TYPE_LINE_STATUS = 8
    PEAK_CHUNKS_TYPE_AUTO_FEATURE_STATUS = 9
    PEAK_CHUNKS_TYPE_PTP_STATUS = 10
end

struct peak_chunks_frame_info
    data::NTuple{84, UInt8}
end

function Base.getproperty(x::Ptr{peak_chunks_frame_info}, f::Symbol)
    f === :pixelFormat && return Ptr{peak_pixel_format}(x + 0)
    f === :roi && return Ptr{peak_roi}(x + 4)
    f === :reserved && return Ptr{NTuple{64, UInt8}}(x + 20)
    return getfield(x, f)
end

function Base.getproperty(x::peak_chunks_frame_info, f::Symbol)
    r = Ref{peak_chunks_frame_info}(x)
    ptr = Base.unsafe_convert(Ptr{peak_chunks_frame_info}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_chunks_frame_info}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_chunks_frame_info, private::Bool = false)
    (:pixelFormat, :roi, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_chunks_exposure
    exposureTime_us::Cdouble
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_gain
    analogMasterGain::Cdouble
    digitalMasterGain::Cdouble
    digitalRedGain::Cdouble
    digitalGreenGain::Cdouble
    digitalBlueGain::Cdouble
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_sequencer
    sequencerSetActive::Int64
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_timestamp
    timestamp::Int64
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_exposure_trigger
    timestamp::Int64
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_usable_roi
    data::NTuple{80, UInt8}
end

function Base.getproperty(x::Ptr{peak_chunks_usable_roi}, f::Symbol)
    f === :roi && return Ptr{peak_roi}(x + 0)
    f === :reserved && return Ptr{NTuple{64, UInt8}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::peak_chunks_usable_roi, f::Symbol)
    r = Ref{peak_chunks_usable_roi}(x)
    ptr = Base.unsafe_convert(Ptr{peak_chunks_usable_roi}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{peak_chunks_usable_roi}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::peak_chunks_usable_roi, private::Bool = false)
    (:roi, :reserved, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct peak_chunks_line_status
    lineStatusAll::UInt32
    reserved::NTuple{64, UInt8}
end

@cenum peak_auto_feature_status::UInt32 begin
    PEAK_AUTO_FEATURE_STATUS_INVALID = 0
    PEAK_AUTO_FEATURE_STATUS_OFF = 1
    PEAK_AUTO_FEATURE_STATUS_DONE = 2
    PEAK_AUTO_FEATURE_STATUS_ACTIVE = 3
    PEAK_AUTO_FEATURE_STATUS_STUCK = 4
end

struct peak_chunks_autofeature_status
    status::peak_auto_feature_status
    reserved::NTuple{64, UInt8}
end

struct peak_chunks_autofeature
    autoBrightnessStatus::peak_chunks_autofeature_status
    autoWhiteBalanceStatus::peak_chunks_autofeature_status
    reserved::NTuple{64, UInt8}
end

@cenum peak_ptp_status::UInt32 begin
    PEAK_PTP_STATUS_INVALID = 0
    PEAK_PTP_STATUS_INITIALIZING = 1
    PEAK_PTP_STATUS_FAULTY = 2
    PEAK_PTP_STATUS_DISABLED = 3
    PEAK_PTP_STATUS_LISTENING = 4
    PEAK_PTP_STATUS_PRE_MASTER = 5
    PEAK_PTP_STATUS_MASTER = 6
    PEAK_PTP_STATUS_PASSIVE = 7
    PEAK_PTP_STATUS_UNCALIBRATED = 8
    PEAK_PTP_STATUS_SLAVE = 9
end

struct peak_chunks_ptp_status
    ptpStatus::peak_ptp_status
    reserved::NTuple{64, UInt8}
end

struct var"##Ctag#230"
    element_00::Cdouble
    element_01::Cdouble
    element_02::Cdouble
    element_10::Cdouble
    element_11::Cdouble
    element_12::Cdouble
    element_20::Cdouble
    element_21::Cdouble
    element_22::Cdouble
end
function Base.getproperty(x::Ptr{var"##Ctag#230"}, f::Symbol)
    f === :element_00 && return Ptr{Cdouble}(x + 0)
    f === :element_01 && return Ptr{Cdouble}(x + 8)
    f === :element_02 && return Ptr{Cdouble}(x + 16)
    f === :element_10 && return Ptr{Cdouble}(x + 24)
    f === :element_11 && return Ptr{Cdouble}(x + 32)
    f === :element_12 && return Ptr{Cdouble}(x + 40)
    f === :element_20 && return Ptr{Cdouble}(x + 48)
    f === :element_21 && return Ptr{Cdouble}(x + 56)
    f === :element_22 && return Ptr{Cdouble}(x + 64)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#230", f::Symbol)
    r = Ref{var"##Ctag#230"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#230"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#230"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


struct var"##Ctag#231"
    high_part::UInt16
    low_part::UInt32
end
function Base.getproperty(x::Ptr{var"##Ctag#231"}, f::Symbol)
    f === :high_part && return Ptr{UInt16}(x + 0)
    f === :low_part && return Ptr{UInt32}(x + 2)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#231", f::Symbol)
    r = Ref{var"##Ctag#231"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#231"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#231"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


# These are C declaration macros (`__declspec` and calling conventions), not
# values used at runtime.  The generated function bindings below already use
# the appropriate C ABI through `ccall`, so represent their return aliases by
# their Julia types instead of evaluating the Windows-only macros.
const PEAK_API_STATUS = peak_status
const PEAK_API_ACCESS_STATUS = peak_access_status
const PEAK_API_BOOL = peak_bool
const PEAK_API_CAMERA_ID = peak_camera_id

const PEAK_INVALID_HANDLE = NULL

const PEAK_INFINITE = 0xffffffff

const PEAK_TRUE = 1

const PEAK_FALSE = 0

const PEAK_IDENTITY_MATRIX = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)

const PEAK_INVALID_CAMERA_ID = UINT64_C(0)

const PEAK_TRIGGER_MODE_HARDWARE_TRIGGER = peak_trigger_mode(PEAK_TRIGGER_TARGET_FRAME_START, PEAK_IO_CHANNEL_TRIGGER_INPUT)

const PEAK_TRIGGER_MODE_SOFTWARE_TRIGGER = peak_trigger_mode(PEAK_TRIGGER_TARGET_FRAME_START, PEAK_IO_CHANNEL_SOFTWARE)

const PEAK_FLASH_MODE_EXPOSURE_ACTIVE = peak_flash_mode(PEAK_FLASH_REFERENCE_EXPOSURE_ACTIVE, PEAK_IO_CHANNEL_FLASH_OUTPUT)

const PEAK_FLASH_MODE_ACQUISITION_ACTIVE = peak_flash_mode(PEAK_FLASH_REFERENCE_ACQUISITION_ACTIVE, PEAK_IO_CHANNEL_FLASH_OUTPUT)

const PEAK_FLASH_MODE_GLOBAL_START_WINDOW = peak_flash_mode(PEAK_FLASH_REFERENCE_GLOBAL_START_WINDOW, PEAK_IO_CHANNEL_FLASH_OUTPUT)

const PEAK_ROTATION_ANGLE_0 = 0

const PEAK_ROTATION_ANGLE_180 = 180

const PEAK_ROTATION_ANGLE_CLOCKWISE_90 = -90

const PEAK_ROTATION_ANGLE_CLOCKWISE_270 = -270

const PEAK_ROTATION_ANGLE_COUNTERCLOCKWISE_90 = 90

const PEAK_ROTATION_ANGLE_COUNTERCLOCKWISE_270 = 270

const PEAK_LINKSPEED_ETH_10M = 1250000

const PEAK_LINKSPEED_ETH_100M = 12500000

const PEAK_LINKSPEED_USB2_HIGH_SPEED = 60000000

const PEAK_LINKSPEED_ETH_1G = 125000000

const PEAK_LINKSPEED_ETH_5G = 625000000

const PEAK_LINKSPEED_ETH_10G = 1250000000

const PEAK_LINKSPEED_USB3_SUPER_SPEED = 500000000
