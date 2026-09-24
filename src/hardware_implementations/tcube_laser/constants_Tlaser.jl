const DWORD = Cuint

const WORD = Cushort

const BYTE = Cuchar

const __int64 = Clonglong

const __int32 = Cint

const BOOL = Cuint

"""
    BOOL

The Kinesis headers `typedef unsigned int BOOL` (verified at line 37 of
`Thorlabs.MotionControl.TCube.LaserDiode.h`), so this is four bytes, and every
`BOOL` argument and return in `functions_Tlaser.jl` is that width.

**History, because this was got wrong once.** v0.2.3 changed these to a
one-byte `Bool` on a report that the header declared C++ `bool`. It does not:
that header contains no lowercase `bool` at all. The change was reverted
because it is wrong in the dangerous direction for ARGUMENTS — passing one
byte where the callee reads four leaves the upper three undefined, so a
`false` can arrive as true. `LD_EnableMaxCurrentAdjust(serial, true, false)`
is the call that matters: its second flag enables the laser diode during a
max-current adjustment.

If a future Kinesis version really does declare `bool`, check the header for
that version before changing this, and change arguments and returns
separately — four bytes is safe for an argument under either ABI, one byte is
not.
"""

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

"""
    TLI_DeviceInfo

Mirrors the `TLI_DeviceInfo` struct in the Kinesis headers. `BOOL` is four
bytes there (`typedef unsigned int BOOL`, line 37), the fields are in this
order, and the struct is NOT packed -- the header's `#pragma pack(1)` is
commented out, so default alignment applies and both declarations come to 120
bytes with `PID` at offset 88.

**This declaration carried a `[limitation]` warning in v0.2.3 saying it was
suspect and wrong from `PID` onward. That warning was itself wrong** and is
removed. It came from a second-hand report that the header packs to one byte
and declares the flags as C++ `bool`; the header on the lab NAS does neither.
Nothing in this package calls `TLI_GetDeviceInfo`, so nothing depended on
either claim -- but a false warning costs the next reader a hunt for a defect
that is not there, which is why it is deleted rather than softened.
"""
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

