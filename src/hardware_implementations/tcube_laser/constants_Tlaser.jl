const DWORD = Cuint

const WORD = Cushort

const BYTE = Cuchar

const __int64 = Clonglong

const __int32 = Cint

const BOOL = Cuint

struct tagSAFEARRAYBOUND
    cElements::Culong
    lLbound::Clong
end

const SAFEARRAYBOUND = tagSAFEARRAYBOUND

struct tagSAFEARRAY
    cDims::Cushort
    fFeatures::Cushort
    cbElements::Culong
    cLocks::Culong
    pvData::Ptr{Cvoid}
    rgsabound::NTuple{1, SAFEARRAYBOUND}
end

const SAFEARRAY = tagSAFEARRAY

@enum FT_Status::UInt32 begin
    FT_OK = 0
    FT_InvalidHandle = 1
    FT_DeviceNotFound = 2
    FT_DeviceNotOpened = 3
    FT_IOError = 4
    FT_InsufficientResources = 5
    FT_InvalidParameter = 6
    FT_DeviceNotPresent = 7
    FT_IncorrectDevice = 8
end

@enum MOT_MotorTypes::UInt32 begin
    MOT_NotMotor = 0
    MOT_DCMotor = 1
    MOT_StepperMotor = 2
    MOT_BrushlessMotor = 3
    MOT_CustomMotor = 100
end

struct TLI_DeviceInfo
    typeID::DWORD
    description::NTuple{65, Cchar}
    serialNo::NTuple{16, Cchar}
    PID::DWORD
    isKnownType::BOOL
    motorType::MOT_MotorTypes
    isPiezoDevice::BOOL
    isLaser::BOOL
    isCustomType::BOOL
    isRack::BOOL
    maxChannels::Cshort
end

struct TLI_HardwareInformation
    serialNumber::DWORD
    modelNumber::NTuple{8, Cchar}
    type::WORD
    firmwareVersion::DWORD
    notes::NTuple{48, Cchar}
    deviceDependantData::NTuple{12, BYTE}
    hardwareVersion::WORD
    modificationState::WORD
    numChannels::Cshort
end

@enum LD_InputSourceFlags::UInt32 begin
    LD_SoftwareOnly = 1
    LD_ExternalSignal = 2
    LD_Potentiometer = 4
end

@enum LD_DisplayUnits::UInt32 begin
    LD_ILim = 1
    LD_ILD = 2
    LD_IPD = 3
    LD_PLD = 4
end

@enum LD_TIA_RANGES::UInt32 begin
    LD_TIA_10uA = 1
    LD_TIA_100uA = 2
    LD_TIA_1mA = 4
    LD_TIA_10mA = 8
end

@enum LD_POLARITY::UInt32 begin
    LD_CathodeGrounded = 1
    LD_AnodeGrounded = 2
end

