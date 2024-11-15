mutable struct okFrontPanelHandle end

const okFrontPanel_HANDLE = Ptr{okFrontPanelHandle}

const okEDeviceInterface = Cint

const okEUSBSpeed = Cint

const okBool = Cchar

const UINT32 = Cuint

struct okTFlashLayout
    sectorCount::UINT32
    sectorSize::UINT32
    pageSize::UINT32
    minUserSector::UINT32
    maxUserSector::UINT32
end

@enum okEFPGAVendor::UInt32 begin
    okFPGAVENDOR_UNKNOWN = 0
    okFPGAVENDOR_XILINX = 1
    okFPGAVENDOR_INTEL = 2
end

struct okTDeviceInfo
    deviceID::NTuple{33, Cchar}
    serialNumber::NTuple{11, Cchar}
    productName::NTuple{128, Cchar}
    productID::Cint
    deviceInterface::okEDeviceInterface
    usbSpeed::okEUSBSpeed
    deviceMajorVersion::Cint
    deviceMinorVersion::Cint
    hostInterfaceMajorVersion::Cint
    hostInterfaceMinorVersion::Cint
    isPLL22150Supported::okBool
    isPLL22393Supported::okBool
    isFrontPanelEnabled::okBool
    wireWidth::Cint
    triggerWidth::Cint
    pipeWidth::Cint
    registerAddressWidth::Cint
    registerDataWidth::Cint
    flashSystem::okTFlashLayout
    flashFPGA::okTFlashLayout
    hasFMCEEPROM::okBool
    hasResetProfiles::okBool
    fpgaVendor::okEFPGAVendor
    interfaceCount::Cint
    interfaceIndex::Cint
    configuresFromSystemFlash::okBool
    hasQuadConfigFlash::okBool
end

@enum ok_ErrorCode::Int32 begin
    ok_NoError = 0
    ok_Failed = -1
    ok_Timeout = -2
    ok_DoneNotHigh = -3
    ok_TransferError = -4
    ok_CommunicationError = -5
    ok_InvalidBitstream = -6
    ok_FileError = -7
    ok_DeviceNotOpen = -8
    ok_InvalidEndpoint = -9
    ok_InvalidBlockSize = -10
    ok_I2CRestrictedAddress = -11
    ok_I2CBitError = -12
    ok_I2CNack = -13
    ok_I2CUnknownStatus = -14
    ok_UnsupportedFeature = -15
    ok_FIFOUnderflow = -16
    ok_FIFOOverflow = -17
    ok_DataAlignmentError = -18
    ok_InvalidResetProfile = -19
    ok_InvalidParameter = -20
end

const UINT8 = Cuchar

const okFP_dll_pchar = Ptr{Cchar}

mutable struct okPLL22150Handle end

const okPLL22150_HANDLE = Ptr{okPLL22150Handle}

mutable struct okPLL22393Handle end

const okPLL22393_HANDLE = Ptr{okPLL22393Handle}

mutable struct okDeviceSensorsHandle end

const okDeviceSensors_HANDLE = Ptr{okDeviceSensorsHandle}

mutable struct okDeviceSettingNamesHandle end

const okDeviceSettingNames_HANDLE = Ptr{okDeviceSettingNamesHandle}

mutable struct okDeviceSettingsHandle end

const okDeviceSettings_HANDLE = Ptr{okDeviceSettingsHandle}

mutable struct okBufferHandle end

const okBuffer_HANDLE = Ptr{okBufferHandle}

mutable struct okScriptValueHandle end

const okScriptValue_HANDLE = Ptr{okScriptValueHandle}

mutable struct okScriptValuesHandle end

const okScriptValues_HANDLE = Ptr{okScriptValuesHandle}

mutable struct okScriptEngineHandle end

const okScriptEngine_HANDLE = Ptr{okScriptEngineHandle}

# typedef void ( * okScriptEngineAsyncCallback ) ( void * , const char * , okScriptValues_HANDLE )
const okScriptEngineAsyncCallback = Ptr{Cvoid}

mutable struct okFrontPanelManagerHandle end

const okFrontPanelManager_HANDLE = Ptr{okFrontPanelManagerHandle}

mutable struct okCFrontPanelManagerHandle end

const okCFrontPanelManager_HANDLE = Ptr{okCFrontPanelManagerHandle}

mutable struct okCFrontPanelDevicesHandle end

const okCFrontPanelDevices_HANDLE = Ptr{okCFrontPanelDevicesHandle}

const Bool = Cint

@enum ok_ClockSource_22150::UInt32 begin
    ok_ClkSrc22150_Ref = 0
    ok_ClkSrc22150_Div1ByN = 1
    ok_ClkSrc22150_Div1By2 = 2
    ok_ClkSrc22150_Div1By3 = 3
    ok_ClkSrc22150_Div2ByN = 4
    ok_ClkSrc22150_Div2By2 = 5
    ok_ClkSrc22150_Div2By4 = 6
end

@enum ok_ClockSource_22393::UInt32 begin
    ok_ClkSrc22393_Ref = 0
    ok_ClkSrc22393_PLL0_0 = 2
    ok_ClkSrc22393_PLL0_180 = 3
    ok_ClkSrc22393_PLL1_0 = 4
    ok_ClkSrc22393_PLL1_180 = 5
    ok_ClkSrc22393_PLL2_0 = 6
    ok_ClkSrc22393_PLL2_180 = 7
end

@enum ok_DividerSource::UInt32 begin
    ok_DivSrc_Ref = 0
    ok_DivSrc_VCO = 1
end

@enum ok_BoardModel::UInt32 begin
    ok_brdUnknown = 0
    ok_brdXEM3001v1 = 1
    ok_brdXEM3001v2 = 2
    ok_brdXEM3010 = 3
    ok_brdXEM3005 = 4
    ok_brdXEM3001CL = 5
    ok_brdXEM3020 = 6
    ok_brdXEM3050 = 7
    ok_brdXEM9002 = 8
    ok_brdXEM3001RB = 9
    ok_brdXEM5010 = 10
    ok_brdXEM6110LX45 = 11
    ok_brdXEM6110LX150 = 15
    ok_brdXEM6001 = 12
    ok_brdXEM6010LX45 = 13
    ok_brdXEM6010LX150 = 14
    ok_brdXEM6006LX9 = 16
    ok_brdXEM6006LX16 = 17
    ok_brdXEM6006LX25 = 18
    ok_brdXEM5010LX110 = 19
    ok_brdZEM4310 = 20
    ok_brdXEM6310LX45 = 21
    ok_brdXEM6310LX150 = 22
    ok_brdXEM6110v2LX45 = 23
    ok_brdXEM6110v2LX150 = 24
    ok_brdXEM6002LX9 = 25
    ok_brdXEM6310MTLX45T = 26
    ok_brdXEM6320LX130T = 27
    ok_brdXEM7350K70T = 28
    ok_brdXEM7350K160T = 29
    ok_brdXEM7350K410T = 30
    ok_brdXEM6310MTLX150T = 31
    ok_brdZEM5305A2 = 32
    ok_brdZEM5305A7 = 33
    ok_brdXEM7001A15 = 34
    ok_brdXEM7001A35 = 35
    ok_brdXEM7360K160T = 36
    ok_brdXEM7360K410T = 37
    ok_brdZEM5310A4 = 38
    ok_brdZEM5310A7 = 39
    ok_brdZEM5370A5 = 40
    ok_brdXEM7010A50 = 41
    ok_brdXEM7010A200 = 42
    ok_brdXEM7310A75 = 43
    ok_brdXEM7310A200 = 44
    ok_brdXEM7320A75T = 45
    ok_brdXEM7320A200T = 46
    ok_brdXEM7305 = 47
    ok_brdFPX1301 = 48
    ok_brdXEM8350KU060 = 49
    ok_brdXEM8350KU085 = 50
    ok_brdXEM8350KU115 = 51
    ok_brdXEM8350SECONDARY = 52
    ok_brdXEM7310MTA75 = 53
    ok_brdXEM7310MTA200 = 54
    ok_brdXEM9025 = 55
    ok_brdXEM8320AU25P = 56
    ok_brdXEM8310AU25P = 57
    ok_brdFPX9301 = 58
end

const okEProduct = Cint

@enum okEFPGAConfigurationMethod::UInt32 begin
    ok_FPGAConfigurationMethod_NVRAM = 0
    ok_FPGAConfigurationMethod_JTAG = 1
end

struct okTRegisterEntry
    address::UINT32
    data::UINT32
end

struct okTTriggerEntry
    address::UINT32
    mask::UINT32
end

struct okTFPGAResetProfile
    magic::UINT32
    configFileLocation::UINT32
    configFileLength::UINT32
    doneWaitUS::UINT32
    resetWaitUS::UINT32
    registerWaitUS::UINT32
    padBytes1::NTuple{28, UINT32}
    wireInValues::NTuple{32, UINT32}
    registerEntryCount::UINT32
    registerEntries::NTuple{256, okTRegisterEntry}
    triggerEntryCount::UINT32
    triggerEntries::NTuple{32, okTTriggerEntry}
    padBytes2::NTuple{1520, UINT8}
end

struct okTDeviceMatchInfo
    productName::NTuple{128, Cchar}
    productBaseID::okEProduct
    productID::Cint
    usbVID::UINT32
    usbPID::UINT32
    pciDID::UINT32
end

@enum okEDeviceSensorType::UInt32 begin
    okDEVICESENSOR_INVALID = 0
    okDEVICESENSOR_BOOL = 1
    okDEVICESENSOR_INTEGER = 2
    okDEVICESENSOR_FLOAT = 3
    okDEVICESENSOR_VOLTAGE = 4
    okDEVICESENSOR_CURRENT = 5
    okDEVICESENSOR_TEMPERATURE = 6
    okDEVICESENSOR_FAN_RPM = 7
end

struct okTDeviceSensor
    id::Cint
    type::okEDeviceSensorType
    name::NTuple{64, Cchar}
    description::NTuple{256, Cchar}
    min::Cdouble
    max::Cdouble
    step::Cdouble
    value::Cdouble
end

struct okTCallbackInfo
    fd::Cint
    callback::Ptr{Cvoid}
    param::Ptr{Cvoid}
end

# typedef void ( * okTProgressCallback ) ( int maximum , int current , void * arg )
const okTProgressCallback = Ptr{Cvoid}

const ok_FPGAConfigurationMethod = okEFPGAConfigurationMethod

mutable struct okErrorPrivate end

const okError = okErrorPrivate

# typedef void ( * okFrontPanelManager_OnDeviceCallback_t ) ( void * context , const char * serial )
const okFrontPanelManager_OnDeviceCallback_t = Ptr{Cvoid}

const MAX_SERIALNUMBER_LENGTH = 10

const MAX_DEVICEID_LENGTH = 32

const MAX_BOARDMODELSTRING_LENGTH = 64

const TRUE = 1

const FALSE = 0

const OK_MAX_DEVICEID_LENGTH = 33

const OK_MAX_SERIALNUMBER_LENGTH = 11

const OK_MAX_PRODUCT_NAME_LENGTH = 128

const OK_MAX_BOARD_MODEL_STRING_LENGTH = 128

const OK_USBSPEED_UNKNOWN = 0

const OK_USBSPEED_FULL = 1

const OK_USBSPEED_HIGH = 2

const OK_USBSPEED_SUPER = 3

const OK_INTERFACE_UNKNOWN = 0

const OK_INTERFACE_USB2 = 1

const OK_INTERFACE_PCIE = 2

const OK_INTERFACE_USB3 = 3

const OK_PRODUCT_UNKNOWN = 0

const OK_PRODUCT_XEM3001V1 = 1

const OK_PRODUCT_XEM3001V2 = 2

const OK_PRODUCT_XEM3010 = 3

const OK_PRODUCT_XEM3005 = 4

const OK_PRODUCT_XEM3001CL = 5

const OK_PRODUCT_XEM3020 = 6

const OK_PRODUCT_XEM3050 = 7

const OK_PRODUCT_XEM9002 = 8

const OK_PRODUCT_XEM3001RB = 9

const OK_PRODUCT_XEM5010 = 10

const OK_PRODUCT_XEM6110LX45 = 11

const OK_PRODUCT_XEM6001 = 12

const OK_PRODUCT_XEM6010LX45 = 13

const OK_PRODUCT_XEM6010LX150 = 14

const OK_PRODUCT_XEM6110LX150 = 15

const OK_PRODUCT_XEM6006LX9 = 16

const OK_PRODUCT_XEM6006LX16 = 17

const OK_PRODUCT_XEM6006LX25 = 18

const OK_PRODUCT_XEM5010LX110 = 19

const OK_PRODUCT_ZEM4310 = 20

const OK_PRODUCT_XEM6310LX45 = 21

const OK_PRODUCT_XEM6310LX150 = 22

const OK_PRODUCT_XEM6110V2LX45 = 23

const OK_PRODUCT_XEM6110V2LX150 = 24

const OK_PRODUCT_XEM6002LX9 = 25

const OK_PRODUCT_XEM6310MTLX45T = 26

const OK_PRODUCT_XEM6320LX130T = 27

const OK_PRODUCT_XEM7350K70T = 28

const OK_PRODUCT_XEM7350K160T = 29

const OK_PRODUCT_XEM7350K410T = 30

const OK_PRODUCT_XEM6310MTLX150T = 31

const OK_PRODUCT_ZEM5305A2 = 32

const OK_PRODUCT_ZEM5305A7 = 33

const OK_PRODUCT_XEM7001A15 = 34

const OK_PRODUCT_XEM7001A35 = 35

const OK_PRODUCT_XEM7360K160T = 36

const OK_PRODUCT_XEM7360K410T = 37

const OK_PRODUCT_ZEM5310A4 = 38

const OK_PRODUCT_ZEM5310A7 = 39

const OK_PRODUCT_ZEM5370A5 = 40

const OK_PRODUCT_XEM7010A50 = 41

const OK_PRODUCT_XEM7010A200 = 42

const OK_PRODUCT_XEM7310A75 = 43

const OK_PRODUCT_XEM7310A200 = 44

const OK_PRODUCT_XEM7320A75T = 45

const OK_PRODUCT_XEM7320A200T = 46

const OK_PRODUCT_XEM7305 = 47

const OK_PRODUCT_FPX1301 = 48

const OK_PRODUCT_XEM8350KU060 = 49

const OK_PRODUCT_XEM8350KU085 = 50

const OK_PRODUCT_XEM8350KU115 = 51

const OK_PRODUCT_XEM8350SECONDARY = 52

const OK_PRODUCT_XEM7310MTA75 = 53

const OK_PRODUCT_XEM7310MTA200 = 54

const OK_PRODUCT_XEM9025 = 55

const OK_PRODUCT_XEM8320AU25P = 56

const OK_PRODUCT_XEM8310AU25P = 57

const OK_PRODUCT_FPX9301 = 58

const OK_PRODUCT_OEM_START = 11000

const OK_FPGACONFIGURATIONMETHOD_NVRAM = 0

const OK_FPGACONFIGURATIONMETHOD_JTAG = 1

const okFPGARESETPROFILE_MAGIC = 0xbe097c3d

const OK_MAX_DEVICE_SENSOR_NAME_LENGTH = 64

const OK_MAX_DEVICE_SENSOR_DESCRIPTION_LENGTH = 256

const OK_API_VERSION_MAJOR = 5

const OK_API_VERSION_MINOR = 3

const OK_API_VERSION_MICRO = 0

const OK_API_VERSION_STRING = "5.3.0"

