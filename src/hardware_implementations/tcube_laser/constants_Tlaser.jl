const DWORD = Cuint

const WORD = Cushort

const BYTE = Cuchar

const __int64 = Clonglong

const __int32 = Cint

"""
    BOOL

Four bytes. **Retained for `TLI_DeviceInfo`'s fields only**, which nothing in
this package calls — see that struct's docstring. Do not use it for a new
binding: use [`KBOOL_ARG`](@ref) for an argument and [`KBOOL_RET`](@ref) for a
return.

`[limitation]` The vendor headers do **not** declare `BOOL` for these fields.
Two rigs have now read their own vendor-installed
`Thorlabs.MotionControl.TCube.LaserDiode.h` — Kinesis 1.14.10 on the seq-sr rig
and 1.14.47.22504 on quickbeam — and **both declare lowercase C++ `bool` with
`#pragma pack(1)` active**. This `Cuint` is therefore wrong for
`TLI_DeviceInfo`, and is left in place only because no single layout fits both
versions anyway (they disagree on `serialNo`'s length), so there is nothing to
change it *to*.

**History, because this was got wrong twice in opposite directions.** v0.2.3
retyped both boolean roles to a one-byte `Bool`. A copy of the header on the lab
NAS appeared to contradict that, carrying `typedef unsigned int BOOL` and no
lowercase `bool` at all, and on its strength the change was reverted — but that
file is a Clang.jl generation input, hand-edited to parse without the Windows
SDK, and its typedefs are artefacts of the editing rather than the vendor's ABI.
Splitting the two roles is the correct answer, and the vendor-installed headers
since read off both rigs confirm it.
"""
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

**[limitation] This layout does not match either Kinesis version we have
looked at, and it is left alone deliberately, because there is no single
layout that would match both.**

Two rigs read their installed headers and reported different declarations:

| | Kinesis 1.14.10 (seq-sr rig) | Kinesis 1.14.47.22504 (quickbeam) |
|---|---|---|
| `serialNo` | `char serialNo[9]` | `char serialNo[16]` |
| flags | 1-byte C++ `bool` | 1-byte C++ `bool` |
| `#pragma pack(1)` | ACTIVE (lines 63-125) | ACTIVE |
| reported size | — | 100 bytes, `PID` at 85 |

This declaration uses `NTuple{16,Cchar}`, 4-byte `BOOL` flags and default
alignment, measuring **120 bytes with `PID` at offset 88** (verified by
execution). It is wrong for both, and the field that differs between the two
vendor versions is an array LENGTH, so no reinterpretation fixes both at once.

`[policy]` Do not call `TLI_GetDeviceInfo` through this declaration. Nothing
in this package does — `initialize` uses only `TLI_BuildDeviceList` and
`TLI_GetDeviceListSize`, both of which return counts and touch no struct
(verified). If a caller ever needs device info, declare the struct for the
SDK version in use, assert `sizeof`, and keep it beside the header it was
read from.

**One copy of this header on the lab NAS contradicts all of the above; do not
trust it.** `Personal Folders/Sheng/code/generate_lib/lib/` holds a Clang.jl
generation input, hand-edited to parse without Windows headers: local
typedefs including `typedef unsigned int BOOL`, `OaIdl.h` and `__declspec`
stripped, both pack pragmas commented out, every lowercase `bool` rewritten.
Those are artefacts of the editing. This docstring briefly asserted, on the
strength of that file, that our layout was correct; it is not, and the round
trip cost two wrong rulings in opposite directions.
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

