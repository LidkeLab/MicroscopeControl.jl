const DWORD = Cuint

const WORD = Cushort

const BYTE = Cuchar

const __int64 = Clonglong

const __int32 = Cint

const BOOL = Cuint

"""
    KBOOL_ARG

The type to pass a Kinesis C++ `bool` ARGUMENT: a zero-extended `Cuint`
carrying exactly 0 or 1.

This is robust whichever width the callee really reads. A `bool` callee takes
the low byte and sees 0 or 1; a `BOOL` callee takes all four and sees 0 or 1.
Passing a 1-byte `Bool` is NOT robust in this direction: the upper three bytes
of the register are undefined, so a `false` can arrive as true. That matters
for `LD_EnableMaxCurrentAdjust(serialNo, enableAdjust, enableDiode)`, whose
second flag enables the laser diode during a max-current adjustment.
"""
const KBOOL_ARG = Cuint

"""
    KBOOL_RET

The type to read a Kinesis C++ `bool` RETURN: one byte.

The installed vendor header declares these `bool`, which on MSVC x86-64
returns in `AL` and leaves the rest of `EAX` **undefined**. Reading four bytes
can therefore turn a `false` into a nonzero value — `LD_CheckConnection`
reporting a disconnected controller as connected. Reading the low byte is
correct under the `bool` ABI and still correct under a `BOOL` ABI returning
0 or 1.

**History, because this was got wrong twice.** v0.2.3 retyped both roles to a
1-byte `Bool`, which was right for returns and wrong for arguments. A copy of
the header on the lab NAS appeared to contradict it — but that copy is a
Clang.jl generation input, hand-edited to parse without Windows headers: its
`typedef unsigned int BOOL` and its commented-out `#pragma pack` are artefacts
of that editing, not the vendor's ABI. The installed header has 32 lowercase
`bool`, zero `BOOL`, and an active `#pragma pack(1)`. Splitting the two roles
is what is actually correct, and is safe under either reading.
"""
const KBOOL_RET = Bool

"""
    BOOL

Retained for `TLI_DeviceInfo`'s fields only. Note the Kinesis headers
`typedef unsigned int BOOL` (verified at line 37 of
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

**[limitation] This layout is wrong for the real DLL, and is left alone
deliberately.**

The installed vendor header declares this struct under an ACTIVE
`#pragma pack(1)` with C++ `bool` flags. Packed, the real layout is
**100 bytes with `PID` at offset 85**: `typeID` 4 + `description` 65 +
`serialNo` 16 puts `PID` at 85 with no padding, and the five flags are one
byte each. This declaration uses 4-byte `BOOL` and default alignment, so it
measures **120 bytes with `PID` at offset 88** (verified by execution) and is
wrong from `PID` onward.

Nothing in this package calls `TLI_GetDeviceInfo`, so this is latent rather
than a hazard, and correcting it means changing field types AND adding
packing — not a change to make without a controller to read a real device
list back from. Fix it against the installed header with the size asserted,
or do not call it.

**A copy of this header on the lab NAS says otherwise; do not trust it.** That
copy (`Personal Folders/Sheng/code/generate_lib/lib/`) is a Clang.jl
generation input, hand-edited to parse without Windows headers: the vendor
preamble was replaced with local typedefs including
`typedef unsigned int BOOL`, `OaIdl.h` and `__declspec` were removed, both
pack pragmas were commented out, and every lowercase `bool` was rewritten to
`BOOL`. Those are artefacts of the editing, not the vendor's ABI. This
docstring briefly claimed, on the strength of that copy, that the layout was
correct; it is not.
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

