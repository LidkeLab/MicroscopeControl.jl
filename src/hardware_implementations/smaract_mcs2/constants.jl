#=
Constants used by the SmarAct MCS2 driver.

Values are transcribed from the vendor header
    C:\SmarAct\MCS2\SDK\C\include\SmarActControlConstants.h
(SmarActCTL 1.5.x). Only the subset needed by this driver is listed; consult the
MCS2 Programmers Guide for the full property reference.
=#

const SA_CTL_ERROR_NONE = UInt32(0x0000)

const SA_CTL_FALSE = Int32(0)
const SA_CTL_TRUE = Int32(1)
const SA_CTL_INFINITE = Int32(-1)   # 0xFFFFFFFF as a signed 32-bit property value

# Channel (driver) types
const SA_CTL_STICK_SLIP_PIEZO_DRIVER = Int32(0x0001)
const SA_CTL_MAGNETIC_DRIVER = Int32(0x0002)
const SA_CTL_PIEZO_SCANNER_DRIVER = Int32(0x0003)

# Base units reported by SA_CTL_PKEY_POS_BASE_UNIT
const SA_CTL_UNIT_METER = Int32(0x00000002)
const SA_CTL_UNIT_DEGREE = Int32(0x00000003)

# --- Property keys -----------------------------------------------------------
# Device
const SA_CTL_PKEY_NUMBER_OF_CHANNELS = UInt32(0x020F0017)
const SA_CTL_PKEY_DEVICE_STATE = UInt32(0x020F000F)
const SA_CTL_PKEY_DEVICE_SERIAL_NUMBER = UInt32(0x020F005E)
const SA_CTL_PKEY_DEVICE_NAME = UInt32(0x020F003D)
const SA_CTL_PKEY_INTERFACE_TYPE = UInt32(0x020F0066)

# Positioner / channel
const SA_CTL_PKEY_CHANNEL_TYPE = UInt32(0x02020066)
const SA_CTL_PKEY_CHANNEL_STATE = UInt32(0x0305000F)
const SA_CTL_PKEY_POSITIONER_TYPE = UInt32(0x0302003C)
const SA_CTL_PKEY_POSITIONER_TYPE_NAME = UInt32(0x0302003D)
const SA_CTL_PKEY_AMPLIFIER_ENABLED = UInt32(0x0302000D)
const SA_CTL_PKEY_ACTUATOR_MODE = UInt32(0x03020019)
const SA_CTL_PKEY_MOVE_MODE = UInt32(0x03050087)
const SA_CTL_PKEY_POSITION = UInt32(0x0305001D)          # i64, pm (linear)
const SA_CTL_PKEY_TARGET_POSITION = UInt32(0x0305001E)   # i64, pm (linear)
const SA_CTL_PKEY_MOVE_VELOCITY = UInt32(0x03050029)     # i64, pm/s
const SA_CTL_PKEY_MOVE_ACCELERATION = UInt32(0x0305002B) # i64, pm/s^2
const SA_CTL_PKEY_HOLD_TIME = UInt32(0x03050028)         # i32, ms
const SA_CTL_PKEY_MAX_CL_FREQUENCY = UInt32(0x0305002F)  # i32, Hz
const SA_CTL_PKEY_STEP_FREQUENCY = UInt32(0x0305002E)
const SA_CTL_PKEY_STEP_AMPLITUDE = UInt32(0x03050030)
const SA_CTL_PKEY_POS_BASE_UNIT = UInt32(0x03090042)
const SA_CTL_PKEY_POS_MOVEMENT_TYPE = UInt32(0x0309003F)

# Scale / software travel limits
const SA_CTL_PKEY_LOGICAL_SCALE_OFFSET = UInt32(0x02040024)  # i64, pm
const SA_CTL_PKEY_LOGICAL_SCALE_INVERSION = UInt32(0x02040025)
const SA_CTL_PKEY_RANGE_LIMIT_MIN = UInt32(0x02040020)       # i64, pm
const SA_CTL_PKEY_RANGE_LIMIT_MAX = UInt32(0x02040021)       # i64, pm

# Calibration / referencing
const SA_CTL_PKEY_CALIBRATION_OPTIONS = UInt32(0x0306005D)
const SA_CTL_PKEY_REFERENCING_OPTIONS = UInt32(0x0307005D)

# --- Move modes --------------------------------------------------------------
const SA_CTL_MOVE_MODE_CL_ABSOLUTE = Int32(0)
const SA_CTL_MOVE_MODE_CL_RELATIVE = Int32(1)
const SA_CTL_MOVE_MODE_SCAN_ABSOLUTE = Int32(2)
const SA_CTL_MOVE_MODE_SCAN_RELATIVE = Int32(3)
const SA_CTL_MOVE_MODE_STEP = Int32(4)

# --- Actuator modes ----------------------------------------------------------
const SA_CTL_ACTUATOR_MODE_NORMAL = Int32(0)
const SA_CTL_ACTUATOR_MODE_QUIET = Int32(1)
const SA_CTL_ACTUATOR_MODE_LOW_VIBRATION = Int32(2)

# --- Channel state bits ------------------------------------------------------
const SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING = Int32(0x00000001)
const SA_CTL_CH_STATE_BIT_CLOSED_LOOP_ACTIVE = Int32(0x00000002)
const SA_CTL_CH_STATE_BIT_CALIBRATING = Int32(0x00000004)
const SA_CTL_CH_STATE_BIT_REFERENCING = Int32(0x00000008)
const SA_CTL_CH_STATE_BIT_MOVE_DELAYED = Int32(0x00000010)
const SA_CTL_CH_STATE_BIT_SENSOR_PRESENT = Int32(0x00000020)
const SA_CTL_CH_STATE_BIT_IS_CALIBRATED = Int32(0x00000040)
const SA_CTL_CH_STATE_BIT_IS_REFERENCED = Int32(0x00000080)
const SA_CTL_CH_STATE_BIT_END_STOP_REACHED = Int32(0x00000100)
const SA_CTL_CH_STATE_BIT_RANGE_LIMIT_REACHED = Int32(0x00000200)
const SA_CTL_CH_STATE_BIT_FOLLOWING_LIMIT_REACHED = Int32(0x00000400)
const SA_CTL_CH_STATE_BIT_MOVEMENT_FAILED = Int32(0x00000800)
const SA_CTL_CH_STATE_BIT_IS_STREAMING = Int32(0x00001000)
const SA_CTL_CH_STATE_BIT_POSITIONER_OVERLOAD = Int32(0x00002000)
const SA_CTL_CH_STATE_BIT_OVER_TEMPERATURE = Int32(0x00004000)
const SA_CTL_CH_STATE_BIT_REFERENCE_MARK = Int32(0x00008000)
const SA_CTL_CH_STATE_BIT_IS_PHASED = Int32(0x00010000)
const SA_CTL_CH_STATE_BIT_POSITIONER_FAULT = Int32(0x00020000)
const SA_CTL_CH_STATE_BIT_AMPLIFIER_ENABLED = Int32(0x00040000)
const SA_CTL_CH_STATE_BIT_IN_POSITION = Int32(0x00080000)

# Human readable names for the channel state bits, used by `channelstatus`.
const CHANNEL_STATE_NAMES = [
    SA_CTL_CH_STATE_BIT_ACTIVELY_MOVING => "activelyMoving",
    SA_CTL_CH_STATE_BIT_CLOSED_LOOP_ACTIVE => "closedLoopActive",
    SA_CTL_CH_STATE_BIT_CALIBRATING => "calibrating",
    SA_CTL_CH_STATE_BIT_REFERENCING => "referencing",
    SA_CTL_CH_STATE_BIT_MOVE_DELAYED => "moveDelayed",
    SA_CTL_CH_STATE_BIT_SENSOR_PRESENT => "sensorPresent",
    SA_CTL_CH_STATE_BIT_IS_CALIBRATED => "isCalibrated",
    SA_CTL_CH_STATE_BIT_IS_REFERENCED => "isReferenced",
    SA_CTL_CH_STATE_BIT_END_STOP_REACHED => "endStopReached",
    SA_CTL_CH_STATE_BIT_RANGE_LIMIT_REACHED => "rangeLimitReached",
    SA_CTL_CH_STATE_BIT_FOLLOWING_LIMIT_REACHED => "followingLimitReached",
    SA_CTL_CH_STATE_BIT_MOVEMENT_FAILED => "movementFailed",
    SA_CTL_CH_STATE_BIT_IS_STREAMING => "isStreaming",
    SA_CTL_CH_STATE_BIT_POSITIONER_OVERLOAD => "positionerOverload",
    SA_CTL_CH_STATE_BIT_OVER_TEMPERATURE => "overTemperature",
    SA_CTL_CH_STATE_BIT_REFERENCE_MARK => "referenceMark",
    SA_CTL_CH_STATE_BIT_IS_PHASED => "isPhased",
    SA_CTL_CH_STATE_BIT_POSITIONER_FAULT => "positionerFault",
    SA_CTL_CH_STATE_BIT_AMPLIFIER_ENABLED => "amplifierEnabled",
    SA_CTL_CH_STATE_BIT_IN_POSITION => "inPosition",
]

# --- Referencing option bits -------------------------------------------------
const SA_CTL_REF_OPT_BIT_START_DIR = Int32(0x00000001)
const SA_CTL_REF_OPT_BIT_REVERSE_DIR = Int32(0x00000002)
const SA_CTL_REF_OPT_BIT_AUTO_ZERO = Int32(0x00000004)
const SA_CTL_REF_OPT_BIT_ABORT_ON_ENDSTOP = Int32(0x00000008)
const SA_CTL_REF_OPT_BIT_CONTINUE_ON_REF_FOUND = Int32(0x00000010)
const SA_CTL_REF_OPT_BIT_STOP_ON_REF_FOUND = Int32(0x00000020)

# --- Unit conversion ---------------------------------------------------------
# The MCS2 works in picometres for linear positioners; this driver presents
# microns to the rest of MicroscopeControl.
const PM_PER_MICRON = 1_000_000

"Convert microns to the picometres expected by the MCS2 API."
um2pm(x::Real) = round(Int64, x * PM_PER_MICRON)

"Convert picometres reported by the MCS2 API to microns."
pm2um(x::Integer) = Float64(x) / PM_PER_MICRON
